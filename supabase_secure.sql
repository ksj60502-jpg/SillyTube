-- SillyTube: bezpieczna konfiguracja RLS + Storage + automatyczne profile/kanały
-- Uruchom ten skrypt w Supabase SQL Editor.

alter table profiles enable row level security;
alter table channels enable row level security;
alter table subscriptions enable row level security;
alter table videos enable row level security;
alter table promo_codes enable row level security;

drop policy if exists "profiles public read" on profiles;
create policy "profiles public read" on profiles for select using (true);

drop policy if exists "profiles own update" on profiles;
create policy "profiles own update" on profiles for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "channels public read" on channels;
create policy "channels public read" on channels for select using (true);

drop policy if exists "channels owner insert" on channels;
create policy "channels owner insert" on channels for insert with check (auth.uid() = owner_id);

drop policy if exists "channels owner update" on channels;
create policy "channels owner update" on channels for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "subscriptions public read" on subscriptions;
create policy "subscriptions public read" on subscriptions for select using (true);

drop policy if exists "subscriptions own insert" on subscriptions;
create policy "subscriptions own insert" on subscriptions
for insert with check (auth.uid() = subscriber_id);

drop policy if exists "subscriptions own delete" on subscriptions;
create policy "subscriptions own delete" on subscriptions
for delete using (auth.uid() = subscriber_id);

drop policy if exists "videos public read" on videos;
create policy "videos public read" on videos for select using (true);

drop policy if exists "videos owner insert" on videos;
create policy "videos owner insert" on videos
for insert with check (auth.uid() = owner_id);

drop policy if exists "videos owner update" on videos;
create policy "videos owner update" on videos
for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "videos owner delete" on videos;
create policy "videos owner delete" on videos
for delete using (auth.uid() = owner_id);

-- Nie pozwalamy klientowi bezpośrednio zmieniać salda.
drop policy if exists "promo no public read" on promo_codes;

-- Automatyczne utworzenie profilu i kanału po rejestracji.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  uname text;
begin
  uname := 'user_' || substr(new.id::text, 1, 8);

  insert into public.profiles(id, username)
  values(new.id, uname)
  on conflict (id) do nothing;

  insert into public.channels(owner_id, name)
  values(new.id, uname)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Bezpieczne wykorzystanie kodów z serwera. Kod można zmieniać tylko w SQL.
create or replace function public.redeem_promo(p_code text)
returns numeric
language plpgsql
security definer set search_path = public
as $$
declare
  r promo_codes%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Musisz być zalogowany';
  end if;

  select * into r
  from promo_codes
  where code = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'Nieprawidłowy kod';
  end if;

  if r.uses >= r.max_uses then
    raise exception 'Kod został już wykorzystany';
  end if;

  update promo_codes set uses = uses + 1 where code = r.code;
  update profiles set psc_balance = psc_balance + r.amount where id = auth.uid();

  return r.amount;
end;
$$;

revoke all on function public.redeem_promo(text) from public;
grant execute on function public.redeem_promo(text) to authenticated;

-- Wirtualne saldo +10 zł za NOWĄ subskrypcję.
create or replace function reward_new_subscription()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update profiles p
  set psc_balance = p.psc_balance + 10.00
  from channels c
  where p.id = c.owner_id and c.id = new.channel_id;
  return new;
end;
$$;

drop trigger if exists subscription_reward on subscriptions;
create trigger subscription_reward
after insert on subscriptions
for each row execute function reward_new_subscription();

-- Publiczne buckety na odczyt. Upload kontrolują polityki obiektów.
insert into storage.buckets (id, name, public)
values ('videos', 'videos', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('thumbnails', 'thumbnails', true)
on conflict (id) do update set public = true;

drop policy if exists "video uploads own folder" on storage.objects;
create policy "video uploads own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'videos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "thumbnail uploads own folder" on storage.objects;
create policy "thumbnail uploads own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'thumbnails'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "video owner delete" on storage.objects;
create policy "video owner delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'videos'
  and owner_id = auth.uid()
);

drop policy if exists "thumbnail owner delete" on storage.objects;
create policy "thumbnail owner delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'thumbnails'
  and owner_id = auth.uid()
);

-- Kody możesz dodawać/zmieniać TYLKO tutaj.
insert into promo_codes(code, amount, max_uses)
values
 ('SILLY10', 10, 999999),
 ('WELCOME50', 50, 1)
on conflict (code) do update set amount = excluded.amount, max_uses = excluded.max_uses;
