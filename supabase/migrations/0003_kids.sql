-- MomOS Phase 3: children, baby/child logs, school & activity tasks, vaccinations

create table public.children (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  birth_date date not null,
  emoji text not null default '👶',
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.kid_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  kind text not null check (kind in ('feed','sleep','diaper','growth','health')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  data jsonb not null default '{}'::jsonb,
  note text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index kid_logs_child_time on public.kid_logs (child_id, started_at desc);

create table public.kid_tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  title text not null,
  category text not null default 'other' check (category in ('homework','school_event','activity','other')),
  due_date date,
  done boolean not null default false,
  done_at timestamptz,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index kid_tasks_child on public.kid_tasks (child_id, done, due_date);

create table public.vaccinations (
  child_id uuid not null references public.children(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  vaccine_key text not null,
  given_on date not null default public.today_lagos(),
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  primary key (child_id, vaccine_key)
);

-- Child must belong to the caller's family
create or replace function public.is_my_child(p_child uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.children where id = p_child and family_id = public.my_family_id())
$$;

alter table public.children enable row level security;
alter table public.kid_logs enable row level security;
alter table public.kid_tasks enable row level security;
alter table public.vaccinations enable row level security;

create policy "children family read" on public.children for select to authenticated using (family_id = public.my_family_id());
create policy "children family insert" on public.children for insert to authenticated with check (family_id = public.my_family_id());
create policy "children family update" on public.children for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id());
create policy "children family delete" on public.children for delete to authenticated using (family_id = public.my_family_id());

create policy "logs family read" on public.kid_logs for select to authenticated using (family_id = public.my_family_id());
create policy "logs family insert" on public.kid_logs for insert to authenticated with check (family_id = public.my_family_id() and public.is_my_child(child_id));
create policy "logs family update" on public.kid_logs for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id() and public.is_my_child(child_id));
create policy "logs family delete" on public.kid_logs for delete to authenticated using (family_id = public.my_family_id());

create policy "tasks family read" on public.kid_tasks for select to authenticated using (family_id = public.my_family_id());
create policy "tasks family insert" on public.kid_tasks for insert to authenticated with check (family_id = public.my_family_id() and public.is_my_child(child_id));
create policy "tasks family update" on public.kid_tasks for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id() and public.is_my_child(child_id));
create policy "tasks family delete" on public.kid_tasks for delete to authenticated using (family_id = public.my_family_id());

create policy "vacc family read" on public.vaccinations for select to authenticated using (family_id = public.my_family_id());
create policy "vacc family insert" on public.vaccinations for insert to authenticated with check (family_id = public.my_family_id() and public.is_my_child(child_id));
create policy "vacc family delete" on public.vaccinations for delete to authenticated using (family_id = public.my_family_id());

-- created_by can never be spoofed
create or replace function public.force_created_by()
returns trigger language plpgsql as $$
begin new.created_by := auth.uid(); return new; end $$;
create trigger children_created_by before insert on public.children for each row execute function public.force_created_by();
create trigger kid_logs_created_by before insert on public.kid_logs for each row execute function public.force_created_by();
create trigger kid_tasks_created_by before insert on public.kid_tasks for each row execute function public.force_created_by();
create trigger vacc_created_by before insert on public.vaccinations for each row execute function public.force_created_by();

-- XP for tracking
insert into public.xp_rules (source, points, daily_cap) values
  ('kid_log', 2, 25),
  ('kid_task', 5, 10),
  ('vaccine', 10, 20);

create or replace function public.xp_on_kid_log()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp('kid_log', new.id::text); end if;
  return new;
end $$;
create trigger kid_logs_xp after insert on public.kid_logs for each row execute function public.xp_on_kid_log();

create or replace function public.xp_on_kid_task()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.done and not old.done then
    new.done_at := now();
    if auth.uid() is not null then perform public.award_xp('kid_task', new.id::text); end if;
  elsif not new.done then
    new.done_at := null;
  end if;
  return new;
end $$;
create trigger kid_tasks_xp before update on public.kid_tasks for each row execute function public.xp_on_kid_task();

create or replace function public.xp_on_vaccine()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp('vaccine', new.child_id::text || ':' || new.vaccine_key); end if;
  return new;
end $$;
create trigger vacc_xp after insert on public.vaccinations for each row execute function public.xp_on_vaccine();

-- New badges
insert into public.badges (key, name, emoji, description, sort) values
  ('logs_10',   'Super Tracker', '📋', 'Log 10 baby or child entries', 13),
  ('logs_100',  'Data Mum',      '📊', 'Log 100 baby or child entries', 14),
  ('vaccine_1', 'Protected',     '💉', 'Record a vaccination', 15),
  ('tasks_10',  'School Ready',  '🎒', 'Complete 10 school or activity tasks', 16);

create or replace function public.check_badges(p_user uuid)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  v_xp int; v_cur int; v_best int; v_quests int; v_checkins int; v_all int;
  v_logs int; v_vacc int; v_tasks int;
  v_new text[] := '{}';
  k text;
begin
  select xp into v_xp from public.profiles where id = p_user;
  select current_streak, best_streak into v_cur, v_best from public.streak_info(p_user);
  select count(*) into v_quests from public.xp_events where user_id = p_user and source = 'quest';
  select count(*) into v_checkins from public.daily_checkins where user_id = p_user;
  select count(*) into v_all from public.xp_events where user_id = p_user and source = 'bonus_all_quests';
  select count(*) into v_logs from public.kid_logs where created_by = p_user;
  select count(*) into v_vacc from public.vaccinations where created_by = p_user;
  select count(*) into v_tasks from public.kid_tasks where created_by = p_user and done;

  foreach k in array array[
    case when v_checkins >= 1 then 'first_checkin' end,
    case when v_best >= 3 then 'streak_3' end,
    case when v_best >= 7 then 'streak_7' end,
    case when v_best >= 30 then 'streak_30' end,
    case when v_quests >= 1 then 'quests_1' end,
    case when v_quests >= 25 then 'quests_25' end,
    case when v_quests >= 100 then 'quests_100' end,
    case when v_all >= 1 then 'all_quests' end,
    case when v_xp >= 100 then 'xp_100' end,
    case when v_xp >= 500 then 'xp_500' end,
    case when v_xp >= 1000 then 'xp_1000' end,
    case when v_xp >= 5000 then 'xp_5000' end,
    case when v_logs >= 10 then 'logs_10' end,
    case when v_logs >= 100 then 'logs_100' end,
    case when v_vacc >= 1 then 'vaccine_1' end,
    case when v_tasks >= 10 then 'tasks_10' end
  ] loop
    if k is not null then
      insert into public.user_badges (user_id, badge_key) values (p_user, k)
      on conflict do nothing;
      if found then v_new := array_append(v_new, k); end if;
    end if;
  end loop;
  return v_new;
end $$;
revoke execute on function public.check_badges(uuid) from anon, authenticated, public;
revoke execute on function public.xp_on_kid_log() from anon, authenticated, public;
revoke execute on function public.xp_on_kid_task() from anon, authenticated, public;
revoke execute on function public.xp_on_vaccine() from anon, authenticated, public;
