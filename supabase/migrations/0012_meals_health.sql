-- Meal timetable and symptom checks

create table public.meal_plans (
  family_id uuid not null references public.families(id) on delete cascade,
  week_start date not null,
  plan jsonb not null default '{}'::jsonb,
  updated_by uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (family_id, week_start)
);
alter table public.meal_plans enable row level security;
create policy "meal plans read" on public.meal_plans for select to authenticated using (family_id = public.my_family_id());
create policy "meal plans insert" on public.meal_plans for insert to authenticated with check (family_id = public.my_family_id());
create policy "meal plans update" on public.meal_plans for update to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id());

create or replace function public.meal_plans_touch()
returns trigger language plpgsql as $$
begin new.updated_by := auth.uid(); new.updated_at := now(); return new; end $$;
create trigger meal_plans_touch before insert or update on public.meal_plans for each row execute function public.meal_plans_touch();

-- Symptom checks (private to the person who made them)
create table public.health_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  who text not null,
  symptoms text[] not null default '{}',
  answers jsonb not null default '{}'::jsonb,
  urgency text not null check (urgency in ('emergency','doctor_today','doctor_soon','self_care')),
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index health_checks_user on public.health_checks (user_id, created_at desc);
alter table public.health_checks enable row level security;
create policy "own health checks" on public.health_checks for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create trigger health_checks_user before insert on public.health_checks for each row execute function public.force_user_id();

create table public.symptom_ai_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.symptom_ai_usage enable row level security;
revoke all on public.symptom_ai_usage from anon, authenticated;
