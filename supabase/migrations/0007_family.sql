-- MomOS Phase 6: Family sync (shared calendar, chores, shopping list)

create table public.family_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz not null,
  all_day boolean not null default false,
  location text,
  notes text,
  emoji text not null default '📅',
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index family_events_time on public.family_events (family_id, starts_at);

create table public.chores (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  assignee uuid references auth.users(id) on delete set null,
  due_date date,
  repeat text not null default 'none' check (repeat in ('none','daily','weekly')),
  done boolean not null default false,
  done_by uuid references auth.users(id) on delete set null,
  done_at timestamptz,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index chores_family on public.chores (family_id, done, due_date);

create table public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  qty text,
  category text not null default 'other',
  checked boolean not null default false,
  added_by uuid default auth.uid() references auth.users(id) on delete set null,
  checked_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  checked_at timestamptz
);
create index shopping_family on public.shopping_items (family_id, checked, created_at desc);

alter table public.family_events enable row level security;
alter table public.chores enable row level security;
alter table public.shopping_items enable row level security;

do $$
declare t text;
begin
  foreach t in array array['family_events','chores','shopping_items'] loop
    execute format('create policy "%1$s read" on public.%1$s for select to authenticated using (family_id = public.my_family_id())', t);
    execute format('create policy "%1$s insert" on public.%1$s for insert to authenticated with check (family_id = public.my_family_id())', t);
    execute format('create policy "%1$s update" on public.%1$s for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id())', t);
    execute format('create policy "%1$s delete" on public.%1$s for delete to authenticated using (family_id = public.my_family_id())', t);
  end loop;
end $$;

create trigger family_events_created_by before insert on public.family_events for each row execute function public.force_created_by();
create trigger chores_created_by before insert on public.chores for each row execute function public.force_created_by();

-- Assignee must be in the same family
create or replace function public.chores_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.assignee is not null and not exists (
    select 1 from public.profiles where id = new.assignee and family_id = new.family_id) then
    raise exception 'Assignee is not in this family';
  end if;
  if tg_op = 'UPDATE' and new.done and not old.done then
    new.done_by := auth.uid();
    new.done_at := now();
    if auth.uid() is not null then perform public.award_xp('chore', new.id::text || ':' || coalesce(old.due_date::text, '')); end if;
    if old.repeat <> 'none' then
      new.due_date := coalesce(old.due_date, public.today_lagos()) + case old.repeat when 'daily' then 1 else 7 end;
      while new.due_date < public.today_lagos() loop
        new.due_date := new.due_date + case old.repeat when 'daily' then 1 else 7 end;
      end loop;
      new.done := false;
    end if;
  elsif tg_op = 'UPDATE' and not new.done then
    new.done_by := null;
    new.done_at := null;
  end if;
  return new;
end $$;
create trigger chores_guard before insert or update on public.chores for each row execute function public.chores_guard();
revoke execute on function public.chores_guard() from anon, authenticated, public;

create or replace function public.shopping_touch()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then new.added_by := auth.uid(); end if;
  if new.checked and (tg_op = 'INSERT' or not old.checked) then
    new.checked_by := auth.uid(); new.checked_at := now();
  elsif not new.checked then
    new.checked_by := null; new.checked_at := null;
  end if;
  return new;
end $$;
create trigger shopping_touch before insert or update on public.shopping_items for each row execute function public.shopping_touch();

insert into public.xp_rules (source, points, daily_cap) values ('chore', 4, 10);

insert into public.badges (key, name, emoji, description, sort) values
  ('chores_10', 'Team Player', '🤝', 'Complete 10 family chores', 23);

-- Live updates for the shopping list and chores
alter publication supabase_realtime add table public.shopping_items, public.chores;
