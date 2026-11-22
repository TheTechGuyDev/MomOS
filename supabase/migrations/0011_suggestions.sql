-- "What's next for you": suggestions based on the past week's activity

create or replace function public.smart_suggestions()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_fam uuid := public.my_family_id();
  v_today date := public.today_lagos();
  v_hour int := extract(hour from (now() at time zone 'Africa/Lagos'))::int;
  out jsonb := '[]'::jsonb;
  n int; r record; v numeric; s record;
begin
  if v_uid is null then return out; end if;

  -- Overdue reminders
  select count(*) into n from public.reminders
   where not done and due_at < now() and due_at > now() - interval '7 days'
     and (user_id = v_uid or (shared and family_id = v_fam));
  if n > 0 then
    out := out || jsonb_build_object('emoji','⚠️','title', n || ' overdue reminder' || case when n > 1 then 's' else '' end,
      'why','Tick them off or snooze them so nothing slips','action','tab:2','priority',100);
  end if;

  -- Next reminder in the next 3 hours
  select title, due_at into r from public.reminders
   where not done and due_at > now() and due_at < now() + interval '3 hours'
     and (user_id = v_uid or (shared and family_id = v_fam))
   order by due_at limit 1;
  if found then
    out := out || jsonb_build_object('emoji','🔔','title','Next: ' || r.title,
      'why','At ' || to_char(r.due_at at time zone 'Africa/Lagos', 'FMHH12:MI AM'),'action','tab:2','priority',90);
  end if;

  -- Not checked in today
  if not exists (select 1 from public.daily_checkins where user_id = v_uid and day = v_today) then
    select current_streak into n from public.streak_info(v_uid);
    out := out || jsonb_build_object('emoji','☀️','title','Check in for today',
      'why', case when n > 0 then 'Keep your ' || n || '-day streak going' else 'Start a new streak, +10 XP' end,
      'action','checkin','priority',85);
  end if;

  -- Baby feeds: under-3s only, if feeds were logged this week
  for r in
    select c.id, c.name,
      (select max(started_at) from public.kid_logs l where l.child_id = c.id and l.kind = 'feed') as last_feed
    from public.children c
    where c.family_id = v_fam and c.birth_date > (v_today - interval '3 years')
  loop
    if r.last_feed is not null and r.last_feed > now() - interval '7 days' and r.last_feed < now() - interval '3 hours' then
      out := out || jsonb_build_object('emoji','🍼','title', r.name || '''s last feed was ' ||
        floor(extract(epoch from now() - r.last_feed) / 3600)::int || 'h ago',
        'why','Log the next feed when it happens','action','tab:1','priority',88);
    end if;
  end loop;

  -- School tasks due today or tomorrow
  select count(*) into n from public.kid_tasks
   where family_id = v_fam and not done and due_date between v_today and v_today + 1;
  if n > 0 then
    out := out || jsonb_build_object('emoji','🎒', 'title', n || ' school task' || case when n > 1 then 's' else '' end || ' due soon',
      'why','Due today or tomorrow','action','tab:1','priority',72);
  end if;

  -- Chores for me (or anyone) due today
  select count(*) into n from public.chores
   where family_id = v_fam and not done and due_date <= v_today and (assignee = v_uid or assignee is null);
  if n > 0 then
    out := out || jsonb_build_object('emoji','🧺', 'title', n || ' chore' || case when n > 1 then 's' else '' end || ' for today',
      'why','Share the load in the Family hub','action','family:1','priority',62);
  end if;

  -- Water: behind schedule after midday
  select water, water_goal into s from public.daily_wellness where user_id = v_uid and day = v_today;
  if v_hour >= 12 and coalesce(s.water, 0) < coalesce(s.water_goal, 8) * (v_hour - 6) / 16.0 then
    out := out || jsonb_build_object('emoji','💧','title','Time for a glass of water',
      'why','You''re at ' || coalesce(s.water, 0) || ' of ' || coalesce(s.water_goal, 8) || ' glasses today','action','tab:3','priority',70);
  end if;

  -- Her sleep this week
  select avg(sleep_hours) into v from public.daily_wellness
   where user_id = v_uid and day > v_today - 7 and sleep_hours is not null;
  if v is not null and v < 6 then
    out := out || jsonb_build_object('emoji','😴','title','Rest when the baby naps today',
      'why','You''ve averaged ' || round(v, 1) || ' hours of sleep this week','action','tab:3','priority',75);
  end if;

  -- Mood: low week -> breathing; no check-in for 2 days -> nudge
  select avg(mood), count(*) into s from public.mood_logs where user_id = v_uid and created_at > now() - interval '7 days';
  if s.count >= 2 and s.avg <= 2.5 then
    out := out || jsonb_build_object('emoji','🌬️','title','Take a 1-minute breathing break',
      'why','This week has felt heavy. Be gentle with yourself','action','breathing','priority',80);
  elsif not exists (select 1 from public.mood_logs where user_id = v_uid and created_at > now() - interval '2 days') then
    out := out || jsonb_build_object('emoji','💗','title','How are you feeling today?',
      'why','A quick mood check-in, +3 XP','action','tab:3','priority',50);
  end if;

  -- Quests in the evening
  select count(*) into n from public.xp_events where user_id = v_uid and source = 'quest' and day = v_today;
  if v_hour >= 17 and n < 4 then
    out := out || jsonb_build_object('emoji','🎯','title', (4 - n) || ' quest' || case when 4 - n > 1 then 's' else '' end || ' left today',
      'why','Finish all 4 for a +25 XP bonus','action','quests','priority',58);
  end if;

  -- Learning
  select max(completed_at), count(*) into s from public.lesson_progress where user_id = v_uid;
  if s.count = 0 then
    out := out || jsonb_build_object('emoji','🎓','title','Start your Data Analysis journey',
      'why','Your first lesson takes about 6 minutes','action','tab:4','priority',40);
  elsif s.max < now() - interval '3 days' then
    out := out || jsonb_build_object('emoji','📚','title','Pick up your learning again',
      'why', floor(extract(epoch from now() - s.max) / 86400)::int || ' days since your last lesson','action','tab:4','priority',45);
  end if;

  -- Gratitude this week
  if not exists (select 1 from public.daily_wellness where user_id = v_uid and day > v_today - 7 and cardinality(gratitude) > 0) then
    out := out || jsonb_build_object('emoji','🙏','title','Write one good thing about today',
      'why','Small moments add up','action','tab:3','priority',30);
  end if;

  return (select coalesce(jsonb_agg(x order by (x->>'priority')::int desc), '[]'::jsonb) from jsonb_array_elements(out) x);
end $$;
revoke execute on function public.smart_suggestions() from anon, public;
grant execute on function public.smart_suggestions() to authenticated;
