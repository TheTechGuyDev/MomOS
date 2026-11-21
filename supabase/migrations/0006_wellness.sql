-- MomOS Phase 5: Wellness (mood, water, her sleep, breathing, gratitude). Private to each user.

create table public.mood_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mood int not null check (mood between 1 and 5),
  tags text[] not null default '{}',
  note text,
  created_at timestamptz not null default now()
);
create index mood_logs_user on public.mood_logs (user_id, created_at desc);

create table public.daily_wellness (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  water int not null default 0 check (water between 0 and 30),
  water_goal int not null default 8 check (water_goal between 1 and 30),
  sleep_hours numeric(3,1) check (sleep_hours between 0 and 24),
  sleep_quality int check (sleep_quality between 1 and 5),
  breathing_sessions int not null default 0,
  gratitude text[] not null default '{}',
  primary key (user_id, day)
);

alter table public.mood_logs enable row level security;
alter table public.daily_wellness enable row level security;
create policy "mood own read" on public.mood_logs for select to authenticated using (user_id = auth.uid());
create policy "mood own insert" on public.mood_logs for insert to authenticated with check (user_id = auth.uid());
create policy "mood own delete" on public.mood_logs for delete to authenticated using (user_id = auth.uid());
create policy "wellness own read" on public.daily_wellness for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.daily_wellness from anon, authenticated;
create trigger mood_user before insert on public.mood_logs for each row execute function public.force_user_id();

insert into public.xp_rules (source, points, daily_cap) values
  ('mood', 3, 3),
  ('water_goal', 5, 1),
  ('my_sleep', 2, 1),
  ('breathing', 3, 3),
  ('gratitude', 3, 3);

create or replace function public.xp_on_mood()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp('mood', new.id::text); end if;
  return new;
end $$;
create trigger mood_xp after insert on public.mood_logs for each row execute function public.xp_on_mood();
revoke execute on function public.xp_on_mood() from anon, authenticated, public;

create or replace function public._wellness_row()
returns public.daily_wellness language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness;
begin
  insert into public.daily_wellness (user_id, day) values (auth.uid(), public.today_lagos())
  on conflict do nothing;
  select * into r from public.daily_wellness where user_id = auth.uid() and day = public.today_lagos();
  return r;
end $$;
revoke execute on function public._wellness_row() from anon, authenticated, public;

create or replace function public.wellness_today()
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  r := public._wellness_row();
  return to_jsonb(r);
end $$;

create or replace function public.set_water(p_count int, p_goal int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness; v_res jsonb := '{"gained":0}'::jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public._wellness_row();
  update public.daily_wellness
     set water = greatest(0, least(30, p_count)),
         water_goal = case when p_goal is null then water_goal else greatest(1, least(30, p_goal)) end
   where user_id = auth.uid() and day = public.today_lagos()
   returning * into r;
  if r.water >= r.water_goal then
    v_res := public.award_xp('water_goal', public.today_lagos()::text);
  end if;
  return v_res || jsonb_build_object('row', to_jsonb(r));
end $$;

create or replace function public.log_my_sleep(p_hours numeric, p_quality int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public._wellness_row();
  update public.daily_wellness set sleep_hours = p_hours, sleep_quality = p_quality
   where user_id = auth.uid() and day = public.today_lagos() returning * into r;
  return public.award_xp('my_sleep', public.today_lagos()::text) || jsonb_build_object('row', to_jsonb(r));
end $$;

create or replace function public.breathing_done()
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public._wellness_row();
  update public.daily_wellness set breathing_sessions = breathing_sessions + 1
   where user_id = auth.uid() and day = public.today_lagos() returning * into r;
  return public.award_xp('breathing', public.today_lagos()::text || ':' || r.breathing_sessions)
         || jsonb_build_object('row', to_jsonb(r));
end $$;

create or replace function public.add_gratitude(p_text text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.daily_wellness; v_text text := left(trim(coalesce(p_text, '')), 300);
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if length(v_text) < 2 then raise exception 'Write something you are grateful for'; end if;
  perform public._wellness_row();
  update public.daily_wellness set gratitude = array_append(gratitude, v_text)
   where user_id = auth.uid() and day = public.today_lagos() returning * into r;
  return public.award_xp('gratitude', public.today_lagos()::text || ':' || cardinality(r.gratitude))
         || jsonb_build_object('row', to_jsonb(r));
end $$;

revoke execute on function public.wellness_today() from anon, public;
revoke execute on function public.set_water(int, int) from anon, public;
revoke execute on function public.log_my_sleep(numeric, int) from anon, public;
revoke execute on function public.breathing_done() from anon, public;
revoke execute on function public.add_gratitude(text) from anon, public;
grant execute on function public.wellness_today() to authenticated;
grant execute on function public.set_water(int, int) to authenticated;
grant execute on function public.log_my_sleep(numeric, int) to authenticated;
grant execute on function public.breathing_done() to authenticated;
grant execute on function public.add_gratitude(text) to authenticated;

insert into public.badges (key, name, emoji, description, sort) values
  ('mood_7',      'Self-Aware',     '💗', 'Do 7 mood check-ins', 19),
  ('water_7',     'Hydration Hero', '💧', 'Reach your water goal on 7 days', 20),
  ('breathe_10',  'Calm Breather',  '🌬️', 'Finish 10 breathing sessions', 21),
  ('grateful_10', 'Grateful Heart', '🙏', 'Write 10 gratitude notes', 22);
