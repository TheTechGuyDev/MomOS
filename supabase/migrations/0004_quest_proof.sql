-- MomOS: quests need proof (a written note or a photo)

create table public.quest_entries (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default public.today_lagos(),
  quest_key text not null,
  note text,
  photo_path text,
  created_at timestamptz not null default now(),
  primary key (user_id, day, quest_key),
  check (coalesce(length(trim(note)), 0) >= 3 or photo_path is not null)
);

alter table public.quest_entries enable row level security;
create policy "own quest entries" on public.quest_entries for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.quest_entries from anon, authenticated;

-- Private bucket for proof photos, one folder per user
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('quest-proofs', 'quest-proofs', false, 5242880, array['image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict (id) do nothing;

create policy "quest proofs upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'quest-proofs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "quest proofs read own folder" on storage.objects for select to authenticated
  using (bucket_id = 'quest-proofs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "quest proofs update own folder" on storage.objects for update to authenticated
  using (bucket_id = 'quest-proofs' and (storage.foldername(name))[1] = auth.uid()::text);

-- Old version without proof is removed
drop function if exists public.complete_quest(text);

create or replace function public.complete_quest(p_key text, p_note text default null, p_photo_path text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_res jsonb; v_bonus jsonb; v_done int;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_photo text := nullif(trim(coalesce(p_photo_path, '')), '');
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if p_key !~ '^[a-z0-9_]{2,40}$' then raise exception 'bad quest'; end if;
  if coalesce(length(v_note), 0) < 3 and v_photo is null then
    raise exception 'Write a short note or add a photo to complete this quest';
  end if;
  if v_photo is not null then
    if split_part(v_photo, '/', 1) <> v_uid::text then raise exception 'bad photo'; end if;
    if not exists (select 1 from storage.objects where bucket_id = 'quest-proofs' and name = v_photo) then
      raise exception 'Photo upload not found, please try again';
    end if;
  end if;

  insert into public.quest_entries (user_id, day, quest_key, note, photo_path)
  values (v_uid, public.today_lagos(), p_key, v_note, v_photo)
  on conflict (user_id, day, quest_key) do update
    set note = coalesce(excluded.note, quest_entries.note),
        photo_path = coalesce(excluded.photo_path, quest_entries.photo_path);

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

revoke execute on function public.complete_quest(text, text, text) from anon, public;
grant execute on function public.complete_quest(text, text, text) to authenticated;
