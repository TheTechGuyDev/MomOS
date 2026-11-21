-- MomOS Phase 4: Memory assistant (reminders, where-I-kept-it, brain dump & voice notes)

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  notes text,
  due_at timestamptz,
  repeat text not null default 'none' check (repeat in ('none','daily','weekly','monthly')),
  shared boolean not null default false,
  done boolean not null default false,
  done_at timestamptz,
  notified_at timestamptz,
  created_at timestamptz not null default now()
);
create index reminders_due on public.reminders (done, due_at);
create index reminders_user on public.reminders (user_id);

create table public.places (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  item text not null check (length(trim(item)) > 0),
  location text not null check (length(trim(location)) > 0),
  photo_path text,
  updated_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index places_family on public.places (family_id, updated_at desc);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text,
  audio_path text,
  audio_seconds int,
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  check (coalesce(length(trim(body)), 0) > 0 or audio_path is not null)
);
create index notes_user on public.notes (user_id, pinned desc, created_at desc);

alter table public.reminders enable row level security;
alter table public.places enable row level security;
alter table public.notes enable row level security;

create policy "reminders read" on public.reminders for select to authenticated
  using (user_id = auth.uid() or (shared and family_id = public.my_family_id()));
create policy "reminders insert" on public.reminders for insert to authenticated
  with check (user_id = auth.uid() and family_id = public.my_family_id());
create policy "reminders update" on public.reminders for update to authenticated
  using (user_id = auth.uid() or (shared and family_id = public.my_family_id()))
  with check (family_id = public.my_family_id());
create policy "reminders delete" on public.reminders for delete to authenticated
  using (user_id = auth.uid());

create policy "places family read" on public.places for select to authenticated using (family_id = public.my_family_id());
create policy "places family insert" on public.places for insert to authenticated with check (family_id = public.my_family_id());
create policy "places family update" on public.places for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id());
create policy "places family delete" on public.places for delete to authenticated using (family_id = public.my_family_id());

create policy "notes own" on public.notes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Owner columns can never be spoofed
create or replace function public.force_user_id()
returns trigger language plpgsql as $$
begin new.user_id := auth.uid(); return new; end $$;
create trigger reminders_user before insert on public.reminders for each row execute function public.force_user_id();
create trigger notes_user before insert on public.notes for each row execute function public.force_user_id();

create or replace function public.places_touch()
returns trigger language plpgsql as $$
begin new.updated_by := auth.uid(); new.updated_at := now(); return new; end $$;
create trigger places_touch before insert or update on public.places for each row execute function public.places_touch();

-- XP
insert into public.xp_rules (source, points, daily_cap) values
  ('reminder_done', 3, 10),
  ('place', 2, 10),
  ('note', 2, 10);

-- Completing a repeating reminder rolls it forward instead of closing it
create or replace function public.reminders_on_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.user_id := old.user_id;
  if new.done and not old.done then
    if auth.uid() is not null then
      perform public.award_xp('reminder_done', old.id::text || ':' || coalesce(old.due_at::text, ''));
    end if;
    if old.repeat <> 'none' and old.due_at is not null then
      new.due_at := old.due_at + case old.repeat
          when 'daily' then interval '1 day'
          when 'weekly' then interval '7 days'
          else interval '1 month' end;
      -- skip ahead if it was very overdue
      while new.due_at < now() loop
        new.due_at := new.due_at + case old.repeat
            when 'daily' then interval '1 day'
            when 'weekly' then interval '7 days'
            else interval '1 month' end;
      end loop;
      new.done := false;
      new.done_at := null;
    else
      new.done_at := now();
    end if;
    new.notified_at := null;
  elsif not new.done then
    new.done_at := null;
    if new.due_at is distinct from old.due_at then new.notified_at := null; end if;
  end if;
  return new;
end $$;
create trigger reminders_on_update before update on public.reminders for each row execute function public.reminders_on_update();

create or replace function public.xp_on_place()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp('place', new.id::text); end if;
  return new;
end $$;
create trigger places_xp after insert on public.places for each row execute function public.xp_on_place();

create or replace function public.xp_on_note()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp('note', new.id::text); end if;
  return new;
end $$;
create trigger notes_xp after insert on public.notes for each row execute function public.xp_on_note();

revoke execute on function public.reminders_on_update() from anon, authenticated, public;
revoke execute on function public.xp_on_place() from anon, authenticated, public;
revoke execute on function public.xp_on_note() from anon, authenticated, public;

-- Media: personal folder <uid>/..., family folder family/<family_id>/...
insert into storage.buckets (id, name, public, file_size_limit)
values ('memory-media', 'memory-media', false, 10485760)
on conflict (id) do nothing;

create policy "memory media insert" on storage.objects for insert to authenticated with check (
  bucket_id = 'memory-media' and (
    (storage.foldername(name))[1] = auth.uid()::text or
    ((storage.foldername(name))[1] = 'family' and (storage.foldername(name))[2] = public.my_family_id()::text)
  ));
create policy "memory media read" on storage.objects for select to authenticated using (
  bucket_id = 'memory-media' and (
    (storage.foldername(name))[1] = auth.uid()::text or
    ((storage.foldername(name))[1] = 'family' and (storage.foldername(name))[2] = public.my_family_id()::text)
  ));
create policy "memory media delete" on storage.objects for delete to authenticated using (
  bucket_id = 'memory-media' and (
    (storage.foldername(name))[1] = auth.uid()::text or
    ((storage.foldername(name))[1] = 'family' and (storage.foldername(name))[2] = public.my_family_id()::text)
  ));

-- Badges
insert into public.badges (key, name, emoji, description, sort) values
  ('reminders_10', 'Never Forget', '🧠', 'Complete 10 reminders', 17),
  ('places_5',     'Finder',       '🔎', 'Save where 5 things are kept', 18);
