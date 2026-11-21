-- MomOS Phase 7: Learn (lesson progress, portfolio, SQL practice lab, AI tutor usage)

create table public.lessons (
  key text primary key,
  track text not null,
  sort int not null default 0
);

insert into public.lessons (key, track, sort) values
  ('fnd1','fnd',1),('fnd2','fnd',2),('fnd3','fnd',3),('fnd4','fnd',4),
  ('xl1','xl',1),('xl2','xl',2),('xl3','xl',3),('xl4','xl',4),('xl5','xl',5),
  ('sql1','sql',1),('sql2','sql',2),('sql3','sql',3),('sql4','sql',4),('sql5','sql',5),('sql6','sql',6),
  ('bi1','bi',1),('bi2','bi',2),('bi3','bi',3),('bi4','bi',4),
  ('py1','py',1),('py2','py',2),('py3','py',3),('py4','py',4);

create table public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_key text not null references public.lessons(key),
  best_score int not null default 0,
  total int not null default 0,
  completed_at timestamptz not null default now(),
  primary key (user_id, lesson_key)
);

create table public.portfolio_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text,
  tools text[] not null default '{}',
  link text,
  created_at timestamptz not null default now()
);

create table public.tutor_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index tutor_usage_user on public.tutor_usage (user_id, created_at);

alter table public.lessons enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.portfolio_projects enable row level security;
alter table public.tutor_usage enable row level security;
create policy "lessons readable" on public.lessons for select to authenticated using (true);
create policy "own progress" on public.lesson_progress for select to authenticated using (user_id = auth.uid());
create policy "own portfolio" on public.portfolio_projects for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke insert, update, delete on public.lessons, public.lesson_progress, public.tutor_usage from anon, authenticated;
create trigger portfolio_user before insert on public.portfolio_projects for each row execute function public.force_user_id();

insert into public.xp_rules (source, points, daily_cap) values
  ('lesson', 20, 6),
  ('perfect_quiz', 5, 6),
  ('track_done', 50, 5);

insert into public.badges (key, name, emoji, description, sort) values
  ('lesson_1',  'First Lesson',      '📘', 'Finish your first lesson', 24),
  ('lessons_10','Keen Learner',      '📚', 'Finish 10 lessons', 25),
  ('track_1',   'Certified',         '🎓', 'Complete a full learning track', 26),
  ('analyst',   'Data Analyst Path', '📊', 'Complete every learning track', 27);

create or replace function public.complete_lesson(p_key text, p_score int, p_total int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_track text;
  v_first boolean;
  v_res jsonb := '{"gained":0,"new_badges":[]}'::jsonb;
  r jsonb;
  v_left int;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  select track into v_track from public.lessons where key = p_key;
  if v_track is null then raise exception 'unknown lesson'; end if;
  if p_total < 1 or p_score < 0 or p_score > p_total then raise exception 'bad score'; end if;
  if p_score * 3 < p_total * 2 then
    raise exception 'Score at least 2 out of 3 to pass. Have another go!';
  end if;

  v_first := not exists (select 1 from public.lesson_progress where user_id = v_uid and lesson_key = p_key);
  insert into public.lesson_progress (user_id, lesson_key, best_score, total)
  values (v_uid, p_key, p_score, p_total)
  on conflict (user_id, lesson_key) do update
    set best_score = greatest(lesson_progress.best_score, excluded.best_score), total = excluded.total;

  if v_first then
    v_res := public.award_xp('lesson', p_key);
    if p_score = p_total then
      r := public.award_xp('perfect_quiz', p_key);
      v_res := jsonb_set(v_res, '{gained}', to_jsonb((v_res->>'gained')::int + (r->>'gained')::int));
    end if;
    select count(*) into v_left from public.lessons l
     where l.track = v_track and not exists (
       select 1 from public.lesson_progress p where p.user_id = v_uid and p.lesson_key = l.key);
    if v_left = 0 then
      r := public.award_xp('track_done', v_track);
      v_res := jsonb_set(v_res, '{gained}', to_jsonb((v_res->>'gained')::int + (r->>'gained')::int));
      v_res := v_res || jsonb_build_object('track_completed', v_track);
    end if;
    r := jsonb_build_object('new_badges', to_jsonb(public.check_badges(v_uid)));
    v_res := jsonb_set(v_res, '{new_badges}', (coalesce(v_res->'new_badges', '[]'::jsonb)) || (r->'new_badges'));
  end if;
  return v_res || jsonb_build_object('first_time', v_first);
end $$;
revoke execute on function public.complete_lesson(text, int, int) from anon, public;
grant execute on function public.complete_lesson(text, int, int) to authenticated;

-- ---------- SQL practice lab: a separate, read-only sample database ----------
create schema if not exists sandbox;

create table sandbox.customers (
  id int primary key,
  name text not null,
  city text not null,
  joined_on date not null
);
create table sandbox.products (
  id int primary key,
  name text not null,
  category text not null,
  price int not null
);
create table sandbox.orders (
  id int primary key,
  customer_id int not null references sandbox.customers(id),
  product_id int not null references sandbox.products(id),
  qty int not null,
  order_date date not null
);

insert into sandbox.customers values
  (1,'Adaeze Okafor','Lagos','2025-01-12'),(2,'Tunde Bakare','Ibadan','2025-02-03'),
  (3,'Fatima Bello','Abuja','2025-02-20'),(4,'Chinedu Eze','Enugu','2025-03-15'),
  (5,'Funmi Adeyemi','Lagos','2025-04-01'),(6,'Ibrahim Musa','Kano','2025-04-22'),
  (7,'Ngozi Nwosu','Port Harcourt','2025-05-09'),(8,'Seun Ogunleye','Lagos','2025-06-18'),
  (9,'Zainab Yusuf','Abuja','2025-07-04'),(10,'Emeka Obi','Lagos','2025-08-27');

insert into sandbox.products values
  (1,'Baby Diapers (Pack)','Baby',8500),(2,'Baby Formula','Baby',12000),
  (3,'Rice 10kg','Food',18500),(4,'Vegetable Oil 3L','Food',9800),
  (5,'School Bag','School',15000),(6,'Exercise Books (10)','School',4500),
  (7,'Detergent 2kg','Household',6200),(8,'Bathing Soap (6)','Household',3600);

insert into sandbox.orders
select g,
       1 + (g * 7) % 10,
       1 + (g * 5) % 8,
       1 + (g % 3),
       date '2025-09-01' + ((g * 3) % 90)
from generate_series(1, 60) g;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'sandbox_runner') then
    create role sandbox_runner nologin;
  end if;
end $$;
grant usage on schema sandbox to sandbox_runner;
grant select on all tables in schema sandbox to sandbox_runner;
grant sandbox_runner to postgres;

-- The runner lives in the sandbox schema, owned by the read-only role
create or replace function sandbox.run_sql(q text)
returns json language plpgsql security definer set search_path = sandbox, pg_catalog as $$
declare
  v_q text := regexp_replace(trim(q), ';\s*$', '');
  v_out json;
begin
  if length(v_q) > 2000 then raise exception 'Query is too long'; end if;
  if v_q !~* '^(select|with)\s' then
    raise exception 'The SQL Lab only runs SELECT queries';
  end if;
  if v_q ~ ';' then raise exception 'Run one query at a time (remove the extra ;)'; end if;
  if v_q ~* '(pg_|information_schema|auth\.|public\.|storage\.|current_setting|set_config|dblink|lo_)' then
    raise exception 'Only the practice tables (customers, products, orders) are available here';
  end if;
  perform set_config('statement_timeout', '3000', true);
  execute format('select coalesce(json_agg(t), ''[]''::json) from (select * from (%s) s limit 200) t', v_q) into v_out;
  return v_out;
end $$;
grant create on schema sandbox to sandbox_runner;
alter function sandbox.run_sql(text) owner to sandbox_runner;
revoke create on schema sandbox from sandbox_runner;
revoke execute on function sandbox.run_sql(text) from public, anon;
grant usage on schema sandbox to authenticated;
grant execute on function sandbox.run_sql(text) to authenticated;

-- Public entry point for the app
create or replace function public.run_sandbox_sql(q text)
returns json language plpgsql security invoker set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  return sandbox.run_sql(q);
end $$;
revoke execute on function public.run_sandbox_sql(text) from anon, public;
grant execute on function public.run_sandbox_sql(text) to authenticated;
