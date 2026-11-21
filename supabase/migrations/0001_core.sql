-- MomOS core: families, profiles, auth trigger, RLS
create extension if not exists pgcrypto;

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Family',
  invite_code text not null unique default upper(substr(encode(gen_random_bytes(4),'hex'),1,6)),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Me',
  role text not null default 'mom' check (role in ('mom','dad','other')),
  family_id uuid references public.families(id) on delete set null,
  avatar_emoji text not null default '🌸',
  xp integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.my_family_id()
returns uuid language sql stable security definer set search_path = public as $$
  select family_id from public.profiles where id = auth.uid()
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, role)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)),
          coalesce(new.raw_user_meta_data->>'role','mom'));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.create_family(p_name text)
returns public.families language plpgsql security definer set search_path = public as $$
declare f public.families;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.families (name, created_by) values (coalesce(nullif(trim(p_name),''),'Our Family'), auth.uid())
  returning * into f;
  update public.profiles set family_id = f.id, updated_at = now() where id = auth.uid();
  return f;
end $$;

create or replace function public.join_family(p_code text)
returns public.families language plpgsql security definer set search_path = public as $$
declare f public.families;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into f from public.families where invite_code = upper(trim(p_code));
  if f.id is null then raise exception 'Invalid family code'; end if;
  update public.profiles set family_id = f.id, updated_at = now() where id = auth.uid();
  return f;
end $$;

alter table public.families enable row level security;
alter table public.profiles enable row level security;

create policy "family readable by members" on public.families
  for select to authenticated using (id = public.my_family_id());
create policy "family editable by members" on public.families
  for update to authenticated using (id = public.my_family_id()) with check (id = public.my_family_id());

create policy "profiles readable by self and family" on public.profiles
  for select to authenticated using (id = auth.uid() or (family_id is not null and family_id = public.my_family_id()));
create policy "profile editable by self" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- xp and family_id only change through server functions
revoke update on public.profiles from authenticated;
grant update (display_name, role, avatar_emoji, updated_at) on public.profiles to authenticated;

revoke execute on function public.create_family(text) from anon, public;
revoke execute on function public.join_family(text) from anon, public;
grant execute on function public.create_family(text) to authenticated;
grant execute on function public.join_family(text) to authenticated;
