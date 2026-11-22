-- Smart notifications: reminder levels, quiet hours, morning summary

alter table public.reminders
  add column if not exists level text not null default 'gentle' check (level in ('gentle','important','alarm'));

alter table public.profiles
  add column if not exists quiet_start int not null default 22 check (quiet_start between 0 and 23),
  add column if not exists quiet_end int not null default 6 check (quiet_end between 0 and 23),
  add column if not exists morning_summary boolean not null default true,
  add column if not exists summary_hour int not null default 7 check (summary_hour between 4 and 11),
  add column if not exists last_summary_on date;

grant update (quiet_start, quiet_end, morning_summary, summary_hour) on public.profiles to authenticated;

-- In-app: reminders that just became due (for the alarm screen / chime while the app is open)
create or replace function public.due_now()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(r order by r.due_at), '[]'::jsonb) from (
    select id, title, notes, due_at, level, repeat, shared
    from public.reminders
    where not done and due_at is not null
      and due_at <= now() and due_at > now() - interval '15 minutes'
      and (user_id = auth.uid() or (shared and family_id = public.my_family_id()))
    order by due_at limit 5) r
$$;
revoke execute on function public.due_now() from anon, public;
grant execute on function public.due_now() to authenticated;

-- Next open reminder after a given time, for "Next up" lines
create or replace function public.next_up(p_after timestamptz default now())
returns jsonb language sql stable security definer set search_path = public as $$
  select to_jsonb(r) from (
    select id, title, due_at from public.reminders
    where not done and due_at > p_after
      and (user_id = auth.uid() or (shared and family_id = public.my_family_id()))
    order by due_at limit 1) r
$$;
revoke execute on function public.next_up(timestamptz) from anon, public;
grant execute on function public.next_up(timestamptz) to authenticated;

-- Alarms re-ring every minute (max 5) until stopped
alter table public.reminders
  add column if not exists alarm_rings int not null default 0,
  add column if not exists alarm_acked boolean not null default false;

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
          when 'daily' then interval '1 day' when 'weekly' then interval '7 days' else interval '1 month' end;
      while new.due_at < now() loop
        new.due_at := new.due_at + case old.repeat
            when 'daily' then interval '1 day' when 'weekly' then interval '7 days' else interval '1 month' end;
      end loop;
      new.done := false;
      new.done_at := null;
    else
      new.done_at := now();
    end if;
    new.notified_at := null;
    new.alarm_rings := 0;
    new.alarm_acked := false;
  elsif not new.done then
    new.done_at := null;
    if new.due_at is distinct from old.due_at then
      new.notified_at := null;
      new.alarm_rings := 0;
      new.alarm_acked := false;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.reminders_on_update() from anon, authenticated, public;
