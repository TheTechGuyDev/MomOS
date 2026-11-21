-- MomOS Phase 8: web push subscriptions, event notifications, all badge rules

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
create policy "own subs read" on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
create policy "own subs delete" on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());
revoke insert, update on public.push_subscriptions from anon, authenticated;

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_ua text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_endpoint !~ '^https://' then raise exception 'bad endpoint'; end if;
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(p_ua, 300))
  on conflict (endpoint) do update
    set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth, user_agent = excluded.user_agent;
end $$;
revoke execute on function public.save_push_subscription(text, text, text, text) from anon, public;
grant execute on function public.save_push_subscription(text, text, text, text) to authenticated;

alter table public.family_events add column if not exists notified_at timestamptz;

-- Final badge rules covering every module
create or replace function public.check_badges(p_user uuid)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  v_xp int; v_cur int; v_best int; v_quests int; v_checkins int; v_all int;
  v_logs int; v_vacc int; v_tasks int; v_rem int; v_places int;
  v_moods int; v_water int; v_breath int; v_grat int; v_chores int;
  v_lessons int; v_tracks int; v_total_tracks int;
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
  select count(*) into v_tasks from public.xp_events where user_id = p_user and source = 'kid_task';
  select count(*) into v_rem from public.xp_events where user_id = p_user and source = 'reminder_done';
  select count(*) into v_places from public.xp_events where user_id = p_user and source = 'place';
  select count(*) into v_moods from public.mood_logs where user_id = p_user;
  select count(*) into v_water from public.xp_events where user_id = p_user and source = 'water_goal';
  select coalesce(sum(breathing_sessions), 0) into v_breath from public.daily_wellness where user_id = p_user;
  select coalesce(sum(cardinality(gratitude)), 0) into v_grat from public.daily_wellness where user_id = p_user;
  select count(*) into v_chores from public.xp_events where user_id = p_user and source = 'chore';
  select count(*) into v_lessons from public.lesson_progress where user_id = p_user;
  select count(*) into v_tracks from (
    select l.track from public.lessons l
    left join public.lesson_progress p on p.lesson_key = l.key and p.user_id = p_user
    group by l.track having count(*) = count(p.lesson_key)) t;
  select count(distinct track) into v_total_tracks from public.lessons;

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
    case when v_tasks >= 10 then 'tasks_10' end,
    case when v_rem >= 10 then 'reminders_10' end,
    case when v_places >= 5 then 'places_5' end,
    case when v_moods >= 7 then 'mood_7' end,
    case when v_water >= 7 then 'water_7' end,
    case when v_breath >= 10 then 'breathe_10' end,
    case when v_grat >= 10 then 'grateful_10' end,
    case when v_chores >= 10 then 'chores_10' end,
    case when v_lessons >= 1 then 'lesson_1' end,
    case when v_lessons >= 10 then 'lessons_10' end,
    case when v_tracks >= 1 then 'track_1' end,
    case when v_tracks >= v_total_tracks then 'analyst' end
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

-- Home screen: what's coming up (my reminders + shared ones + family events)
create or replace function public.coming_up()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'reminders', coalesce((select jsonb_agg(r order by r.due_at) from (
        select id, title, due_at, shared from public.reminders
        where not done and due_at is not null and due_at < now() + interval '36 hours'
          and (user_id = auth.uid() or (shared and family_id = public.my_family_id()))
        order by due_at limit 5) r), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(e order by e.starts_at) from (
        select id, title, starts_at, all_day, emoji from public.family_events
        where family_id = public.my_family_id() and starts_at >= date_trunc('day', now()) and starts_at < now() + interval '3 days'
        order by starts_at limit 4) e), '[]'::jsonb)
  )
$$;
revoke execute on function public.coming_up() from anon, public;
grant execute on function public.coming_up() to authenticated;
