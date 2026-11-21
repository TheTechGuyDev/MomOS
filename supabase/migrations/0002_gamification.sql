-- MomOS Phase 2: XP, levels, daily check-ins, streaks, quests, badges

create table public.xp_rules (
  source text primary key,
  points integer not null,
  daily_cap integer not null default 1000
);

insert into public.xp_rules (source, points, daily_cap) values
  ('checkin', 10, 1),
  ('quest',   15, 4),
  ('bonus_all_quests', 25, 1);

create table public.xp_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null references public.xp_rules(source),
  ref text,
  points integer not null,
  day date not null default (now() at time zone 'Africa/Lagos')::date,
  created_at timestamptz not null default now()
);
create unique index xp_events_once on public.xp_events (user_id, source, ref) where ref is not null;
create index xp_events_user_day on public.xp_events (user_id, day);

create table public.daily_checkins (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

create table public.badges (
  key text primary key,
  name text not null,
  emoji text not null,
  description text not null,
  sort integer not null default 0
);

insert into public.badges (key, name, emoji, description, sort) values
  ('first_checkin', 'Hello, Day!',      '🌅', 'Do your first daily check-in', 1),
  ('streak_3',      'On a Roll',        '🔥', 'Check in 3 days in a row', 2),
  ('streak_7',      'Week Warrior',     '⚡', 'Check in 7 days in a row', 3),
  ('streak_30',     'Unstoppable Mum',  '👑', 'Check in 30 days in a row', 4),
  ('quests_1',      'Quest Starter',    '🎯', 'Complete your first daily quest', 5),
  ('quests_25',     'Quest Pro',        '🏹', 'Complete 25 daily quests', 6),
  ('quests_100',    'Quest Legend',     '🐉', 'Complete 100 daily quests', 7),
  ('all_quests',    'Clean Sweep',      '✨', 'Finish every quest in one day', 8),
  ('xp_100',        'Getting Started',  '🌱', 'Earn 100 XP', 9),
  ('xp_500',        'Blooming',         '🌷', 'Earn 500 XP', 10),
  ('xp_1000',       'Superstar',        '🌟', 'Earn 1,000 XP', 11),
  ('xp_5000',       'Hall of Fame',     '🏆', 'Earn 5,000 XP', 12);

create table public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_key text not null references public.badges(key),
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_key)
);

-- Today's date in Lagos
create or replace function public.today_lagos()
returns date language sql stable as $$ select (now() at time zone 'Africa/Lagos')::date $$;

-- Current and best streak for a user
create or replace function public.streak_info(p_user uuid)
returns table(current_streak int, best_streak int)
language sql stable security definer set search_path = public as $$
  with d as (
    select day, day - (row_number() over (order by day))::int as grp
    from public.daily_checkins where user_id = p_user
  ), islands as (
    select min(day) s, max(day) e, count(*)::int n from d group by grp
  )
  select
    coalesce((select n from islands where e >= public.today_lagos() - 1 order by e desc limit 1), 0),
    coalesce((select max(n) from islands), 0)
$$;

-- Grants any badges the user now qualifies for; returns newly earned keys
create or replace function public.check_badges(p_user uuid)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  v_xp int; v_cur int; v_best int; v_quests int; v_checkins int; v_all int;
  v_new text[] := '{}';
  k text;
begin
  select xp into v_xp from public.profiles where id = p_user;
  select current_streak, best_streak into v_cur, v_best from public.streak_info(p_user);
  select count(*) into v_quests from public.xp_events where user_id = p_user and source = 'quest';
  select count(*) into v_checkins from public.daily_checkins where user_id = p_user;
  select count(*) into v_all from public.xp_events where user_id = p_user and source = 'bonus_all_quests';

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
    case when v_xp >= 5000 then 'xp_5000' end
  ] loop
    if k is not null then
      insert into public.user_badges (user_id, badge_key) values (p_user, k)
      on conflict do nothing;
      if found then v_new := array_append(v_new, k); end if;
    end if;
  end loop;
  return v_new;
end $$;

-- Awards XP by rule (points decided server-side), idempotent per ref, capped per day
create or replace function public.award_xp(p_source text, p_ref text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  r public.xp_rules;
  v_today int;
  v_gain int := 0;
  v_xp int;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  select * into r from public.xp_rules where source = p_source;
  if r.source is null then raise exception 'unknown xp source'; end if;

  select count(*) into v_today from public.xp_events
   where user_id = v_uid and source = p_source and day = public.today_lagos();

  if v_today < r.daily_cap then
    insert into public.xp_events (user_id, source, ref, points)
    values (v_uid, p_source, p_ref, r.points)
    on conflict do nothing;
    if found then
      v_gain := r.points;
      update public.profiles set xp = xp + v_gain, updated_at = now() where id = v_uid;
    end if;
  end if;

  select xp into v_xp from public.profiles where id = v_uid;
  return jsonb_build_object('gained', v_gain, 'xp', v_xp, 'new_badges', to_jsonb(public.check_badges(v_uid)));
end $$;

create or replace function public.daily_checkin()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_res jsonb;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  insert into public.daily_checkins (user_id, day) values (v_uid, public.today_lagos())
  on conflict do nothing;
  v_res := public.award_xp('checkin', public.today_lagos()::text);
  return v_res;
end $$;

-- Completes one of today's quests; gives a bonus when all 4 are done
create or replace function public.complete_quest(p_key text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_res jsonb; v_bonus jsonb; v_done int;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if p_key !~ '^[a-z0-9_]{2,40}$' then raise exception 'bad quest'; end if;
  v_res := public.award_xp('quest', public.today_lagos()::text || ':' || p_key);
  select count(*) into v_done from public.xp_events
   where user_id = v_uid and source = 'quest' and day = public.today_lagos();
  if v_done >= 4 then
    v_bonus := public.award_xp('bonus_all_quests', public.today_lagos()::text);
    v_res := jsonb_set(v_res, '{gained}', to_jsonb((v_res->>'gained')::int + (v_bonus->>'gained')::int));
    v_res := jsonb_set(v_res, '{xp}', v_bonus->'xp');
    v_res := jsonb_set(v_res, '{new_badges}', (v_res->'new_badges') || (v_bonus->'new_badges'));
  end if;
  return v_res;
end $$;

-- Everything the Home screen needs in one call
create or replace function public.my_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); s record;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  select * into s from public.streak_info(v_uid);
  return jsonb_build_object(
    'xp', (select xp from public.profiles where id = v_uid),
    'current_streak', s.current_streak,
    'best_streak', s.best_streak,
    'checked_in_today', exists(select 1 from public.daily_checkins where user_id = v_uid and day = public.today_lagos()),
    'quests_done_today', coalesce((select jsonb_agg(split_part(ref, ':', 2)) from public.xp_events
        where user_id = v_uid and source = 'quest' and day = public.today_lagos()), '[]'::jsonb),
    'xp_today', coalesce((select sum(points) from public.xp_events where user_id = v_uid and day = public.today_lagos()), 0),
    'badges', coalesce((select jsonb_agg(badge_key) from public.user_badges where user_id = v_uid), '[]'::jsonb)
  );
end $$;

-- RLS: reads only; all writes go through the functions above
alter table public.xp_rules enable row level security;
alter table public.xp_events enable row level security;
alter table public.daily_checkins enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

create policy "rules readable" on public.xp_rules for select to authenticated using (true);
create policy "badges readable" on public.badges for select to authenticated using (true);
create policy "own xp events" on public.xp_events for select to authenticated using (user_id = auth.uid());
create policy "own checkins" on public.daily_checkins for select to authenticated using (user_id = auth.uid());
create policy "badges of self and family" on public.user_badges for select to authenticated
  using (user_id = auth.uid() or user_id in (select id from public.profiles where family_id = public.my_family_id()));

revoke insert, update, delete on public.xp_rules, public.xp_events, public.daily_checkins, public.badges, public.user_badges from anon, authenticated;

-- Internal helpers are not callable from the app
revoke execute on function public.award_xp(text, text) from anon, authenticated, public;
revoke execute on function public.check_badges(uuid) from anon, authenticated, public;
revoke execute on function public.streak_info(uuid) from anon, authenticated, public;
revoke execute on function public.daily_checkin() from anon, public;
revoke execute on function public.complete_quest(text) from anon, public;
revoke execute on function public.my_stats() from anon, public;
grant execute on function public.daily_checkin() to authenticated;
grant execute on function public.complete_quest(text) to authenticated;
grant execute on function public.my_stats() to authenticated;
