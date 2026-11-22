-- MomOS Life Manager: planner, home manager, kitchen, school, sharing, money, closet, journal, me time

-- ---------- helpers ----------
create or replace function public.touch_updated()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

-- Owner-or-family read for tables with user_id + family_id + shared
-- (written out per table below)

-- ---------- Planner ----------
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  family_id uuid references public.families(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  emoji text not null default '🎯',
  category text not null default 'personal' check (category in ('personal','health','learning','money','home','family','career')),
  period text not null default 'once' check (period in ('daily','weekly','once')),
  target numeric,
  progress numeric not null default 0,
  unit text,
  due_date date,
  done boolean not null default false,
  shared boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.goal_checkins (
  goal_id uuid not null references public.goals(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null default public.today_lagos(),
  primary key (goal_id, day)
);

create table public.important_dates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  emoji text not null default '🎂',
  kind text not null default 'birthday' check (kind in ('birthday','anniversary','school','religious','other')),
  month int not null check (month between 1 and 12),
  day int not null check (day between 1 and 31),
  year int,
  remind_days_before int not null default 1,
  shared boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- Home manager ----------
create table public.household_tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  emoji text not null default '🧹',
  area text not null default 'cleaning' check (area in ('cleaning','laundry','maintenance','kitchen','garden','other')),
  frequency text not null default 'weekly' check (frequency in ('daily','weekly','monthly','once')),
  next_due date not null default public.today_lagos(),
  last_done timestamptz,
  last_done_by uuid references auth.users(id) on delete set null,
  assignee uuid references auth.users(id) on delete set null,
  times_done int not null default 0,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  name text not null,
  emoji text not null default '🧾',
  category text not null default 'other' check (category in ('electricity','water','gas','internet','tv','phone','rent','school','health','other')),
  amount numeric,
  next_due date not null,
  repeat text not null default 'monthly' check (repeat in ('monthly','termly','yearly','once')),
  shared boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);
create table public.bill_payments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.bills(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  amount numeric not null,
  paid_on date not null default public.today_lagos(),
  paid_by uuid default auth.uid() references auth.users(id) on delete set null
);

create table public.utility_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  kind text not null check (kind in ('electricity','water','gas','fuel')),
  units numeric,
  amount numeric,
  logged_on date not null default public.today_lagos(),
  note text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  place text not null default 'kitchen' check (place in ('kitchen','fridge','freezer','household','bathroom','baby')),
  qty numeric not null default 1,
  unit text,
  low_at numeric,
  expires_on date,
  price numeric,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create trigger inventory_touch before update on public.inventory_items for each row execute function public.touch_updated();

create table public.appliances (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  emoji text not null default '🔌',
  brand text,
  bought_on date,
  warranty_until date,
  last_service date,
  service_every_months int,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------- Kitchen ----------
create table public.food_prefs (
  family_id uuid primary key references public.families(id) on delete cascade,
  likes text[] not null default '{}',
  dislikes text[] not null default '{}',
  allergies text[] not null default '{}',
  monthly_food_budget numeric,
  monthly_shopping_budget numeric,
  notes text,
  updated_at timestamptz not null default now()
);
create trigger food_prefs_touch before update on public.food_prefs for each row execute function public.touch_updated();

alter table public.shopping_items
  add column if not exists price numeric,
  add column if not exists store text,
  add column if not exists archived boolean not null default false;

-- ---------- Family / school ----------
create table public.kid_schedule (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  weekday int not null check (weekday between 1 and 7),
  start_time text not null,
  end_time text,
  title text not null,
  kind text not null default 'class' check (kind in ('class','activity','pickup','other')),
  created_at timestamptz not null default now()
);
alter table public.kid_tasks drop constraint if exists kid_tasks_category_check;
alter table public.kid_tasks add constraint kid_tasks_category_check
  check (category in ('homework','school_event','activity','exam','supplies','medical','other'));
alter table public.family_events add column if not exists child_id uuid references public.children(id) on delete set null;

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  author uuid default auth.uid() references auth.users(id) on delete set null,
  emoji text not null default '📣',
  message text not null check (length(trim(message)) > 0),
  pinned boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists share_settings jsonb not null default
    '{"calendar":true,"shopping":true,"chores":true,"meals":true,"household":true,"expenses":false,"goals":false}'::jsonb;
grant update (share_settings) on public.profiles to authenticated;

-- ---------- MyPocket ----------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  kind text not null default 'expense' check (kind in ('expense','income')),
  amount numeric not null check (amount > 0),
  category text not null default 'other',
  note text,
  on_date date not null default public.today_lagos(),
  shared boolean not null default false,
  created_at timestamptz not null default now()
);
create index transactions_user_date on public.transactions (user_id, on_date desc);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null,
  monthly_limit numeric not null check (monthly_limit > 0),
  unique (user_id, category)
);

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  emoji text not null default '🏦',
  target numeric not null check (target > 0),
  saved numeric not null default 0,
  deadline date,
  created_at timestamptz not null default now()
);

-- ---------- MyCloset ----------
create table public.closet_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  category text not null default 'top' check (category in ('top','bottom','dress','native','outerwear','shoes','bag','accessory','scarf')),
  color text,
  occasions text[] not null default '{}',
  photo_path text,
  favorite boolean not null default false,
  last_worn date,
  created_at timestamptz not null default now()
);
create table public.outfits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  item_ids uuid[] not null default '{}',
  occasion text,
  planned_for date,
  created_at timestamptz not null default now()
);
create table public.closet_wishlist (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  price numeric,
  link text,
  priority int not null default 2 check (priority between 1 and 3),
  bought boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- MySpace journal ----------
create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text,
  body text,
  mood int check (mood between 1 and 5),
  kind text not null default 'diary' check (kind in ('diary','reflection','memory','aspiration')),
  photo_paths text[] not null default '{}',
  audio_path text,
  audio_seconds int,
  created_at timestamptz not null default now()
);
create index journal_user on public.journal_entries (user_id, created_at desc);

-- ---------- Me time ----------
create table public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  emoji text not null default '🌸',
  category text not null default 'self_care' check (category in ('self_care','exercise','reading','rest','hobby','prayer','learning')),
  time_of_day text,
  days int[] not null default '{1,2,3,4,5,6,7}',
  minutes int,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  routine_id uuid references public.routines(id) on delete set null,
  category text not null default 'self_care',
  name text not null,
  minutes int,
  on_date date not null default public.today_lagos(),
  note text,
  created_at timestamptz not null default now()
);
create index activity_user_date on public.activity_logs (user_id, on_date desc);

-- ---------- Row Level Security ----------
do $$
declare t text;
begin
  -- family-shared tables
  foreach t in array array['household_tasks','utility_logs','inventory_items','appliances','kid_schedule','announcements','bill_payments'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "%1$s family all" on public.%1$I for all to authenticated using (family_id = public.my_family_id()) with check (family_id = public.my_family_id())', t);
  end loop;
  -- private-to-owner tables
  foreach t in array array['budgets','savings_goals','closet_items','outfits','closet_wishlist','journal_entries','routines','activity_logs','goal_checkins'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "%1$s own" on public.%1$I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
  -- owner, plus family when shared
  foreach t in array array['goals','important_dates','bills','transactions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "%1$s read" on public.%1$I for select to authenticated using (user_id = auth.uid() or (shared and family_id = public.my_family_id()))', t);
    execute format('create policy "%1$s insert" on public.%1$I for insert to authenticated with check (user_id = auth.uid() and (family_id is null or family_id = public.my_family_id()))', t);
    execute format('create policy "%1$s update" on public.%1$I for update to authenticated using (user_id = auth.uid() or (shared and family_id = public.my_family_id())) with check (family_id is null or family_id = public.my_family_id())', t);
    execute format('create policy "%1$s delete" on public.%1$I for delete to authenticated using (user_id = auth.uid())', t);
  end loop;
end $$;

alter table public.food_prefs enable row level security;
create policy "food prefs family" on public.food_prefs for all to authenticated
  using (family_id = public.my_family_id()) with check (family_id = public.my_family_id());

-- owners can never be spoofed
do $$
declare t text;
begin
  foreach t in array array['goals','important_dates','bills','transactions','budgets','savings_goals','closet_items','outfits','closet_wishlist','journal_entries','routines','activity_logs','goal_checkins'] loop
    execute format('create trigger %1$s_owner before insert on public.%1$I for each row execute function public.force_user_id()', t);
  end loop;
end $$;
create trigger household_created_by before insert on public.household_tasks for each row execute function public.force_created_by();
create or replace function public.announcement_author()
returns trigger language plpgsql as $$
begin new.author := auth.uid(); return new; end $$;
create trigger announcements_author before insert on public.announcements for each row execute function public.announcement_author();

-- ---------- XP for the new modules ----------
insert into public.xp_rules (source, points, daily_cap) values
  ('household', 4, 10), ('goal', 5, 6), ('bill_paid', 3, 10), ('expense', 1, 15),
  ('journal', 5, 2), ('routine', 3, 8), ('outfit', 2, 3)
on conflict (source) do nothing;

-- Complete a household task: roll it to the next due date
create or replace function public.complete_household_task(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare t public.household_tasks; v_next date;
begin
  select * into t from public.household_tasks where id = p_id and family_id = public.my_family_id();
  if t.id is null then raise exception 'not found'; end if;
  v_next := case t.frequency
    when 'daily' then public.today_lagos() + 1
    when 'weekly' then greatest(t.next_due, public.today_lagos()) + 7
    when 'monthly' then (greatest(t.next_due, public.today_lagos()) + interval '1 month')::date
    else null end;
  if t.frequency = 'once' then
    delete from public.household_tasks where id = p_id;
  else
    update public.household_tasks set next_due = v_next, last_done = now(), last_done_by = auth.uid(), times_done = times_done + 1 where id = p_id;
  end if;
  return public.award_xp('household', p_id::text || ':' || public.today_lagos()::text);
end $$;

-- Pay a bill: record the payment, optionally log the expense, roll the due date
create or replace function public.pay_bill(p_id uuid, p_amount numeric, p_log_expense boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare b public.bills;
begin
  select * into b from public.bills where id = p_id and (user_id = auth.uid() or (shared and family_id = public.my_family_id()));
  if b.id is null then raise exception 'not found'; end if;
  insert into public.bill_payments (bill_id, family_id, amount) values (b.id, b.family_id, p_amount);
  if p_log_expense and p_amount > 0 then
    insert into public.transactions (user_id, family_id, kind, amount, category, note, shared)
    values (auth.uid(), b.family_id, 'expense', p_amount, case when b.category in ('school') then 'children' else 'bills' end, b.name, b.shared);
  end if;
  if b.repeat = 'once' then
    delete from public.bills where id = b.id;
  else
    update public.bills set next_due = (b.next_due + case b.repeat when 'monthly' then interval '1 month' when 'termly' then interval '4 months' else interval '1 year' end)::date
    where id = b.id;
  end if;
  return public.award_xp('bill_paid', b.id::text || ':' || b.next_due::text);
end $$;

-- Daily goal check-in or progress update
create or replace function public.goal_progress(p_id uuid, p_add numeric default 1)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g public.goals;
begin
  select * into g from public.goals where id = p_id and user_id = auth.uid();
  if g.id is null then raise exception 'not found'; end if;
  if g.period = 'daily' then
    insert into public.goal_checkins (goal_id, user_id) values (p_id, auth.uid()) on conflict do nothing;
  else
    update public.goals set progress = progress + p_add,
      done = (target is not null and progress + p_add >= target) where id = p_id;
  end if;
  return public.award_xp('goal', p_id::text || ':' || public.today_lagos()::text);
end $$;

-- Small XP triggers
create or replace function public.xp_generic()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then perform public.award_xp(tg_argv[0], new.id::text); end if;
  return new;
end $$;
create trigger journal_xp after insert on public.journal_entries for each row execute function public.xp_generic('journal');
create trigger activity_xp after insert on public.activity_logs for each row execute function public.xp_generic('routine');
create trigger expense_xp after insert on public.transactions for each row execute function public.xp_generic('expense');
create trigger outfit_xp after insert on public.outfits for each row execute function public.xp_generic('outfit');

revoke execute on function public.xp_generic() from anon, authenticated, public;
revoke execute on function public.complete_household_task(uuid) from anon, public;
revoke execute on function public.pay_bill(uuid, numeric, boolean) from anon, public;
revoke execute on function public.goal_progress(uuid, numeric) from anon, public;
grant execute on function public.complete_household_task(uuid) to authenticated;
grant execute on function public.pay_bill(uuid, numeric, boolean) to authenticated;
grant execute on function public.goal_progress(uuid, numeric) to authenticated;

-- Closet photos and journal media are private; household/kitchen photos use memory-media family folder
insert into storage.buckets (id, name, public, file_size_limit) values ('private-media', 'private-media', false, 10485760)
on conflict (id) do nothing;
create policy "private media own" on storage.objects for all to authenticated
  using (bucket_id = 'private-media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'private-media' and (storage.foldername(name))[1] = auth.uid()::text);

alter publication supabase_realtime add table public.announcements, public.household_tasks, public.inventory_items;

