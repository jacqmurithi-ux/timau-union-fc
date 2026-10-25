begin;

-- Replace the owner-executed view with a public-safe projection table.
-- The API can read only these safe columns; source club records remain private.
drop view if exists public.public_partners;
create table if not exists public.public_partners (
 id uuid primary key,
 name text,
 support_type text,
 public_description text,
 website text,
 fan_offer_text text,
 updated_at timestamptz not null default now()
);
alter table public.public_partners enable row level security;
revoke all on public.public_partners from public, anon, authenticated;
grant select on public.public_partners to anon, authenticated;
drop policy if exists public_partner_read on public.public_partners;
create policy public_partner_read on public.public_partners
 for select to anon, authenticated using (true);

create or replace function private.sync_public_sponsor(_record_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $sync_sponsor$
begin
 delete from public.public_partners where id=_record_id;
 insert into public.public_partners(id,name,support_type,public_description,website,fan_offer_text,updated_at)
 select c.id,
  nullif(btrim(c.data->>'name'),''),
  nullif(btrim(c.data->>'support_type'),''),
  nullif(btrim(s.public_description),''),
  case when coalesce(c.data->>'website','') ~* '^https?://' then c.data->>'website' else null end,
  case when s.fan_offer_enabled then nullif(btrim(s.fan_offer_text),'') else null end,
  now()
 from private.club_records c
 join public.sponsor_public_settings s on s.sponsor_record_id=c.id
 where c.id=_record_id
   and c.record_type='sponsor'
   and c.publication_status='approved'
   and s.show_on_public_wall;
end
$sync_sponsor$;
revoke all on function private.sync_public_sponsor(uuid) from public, anon, authenticated;

create or replace function private.sync_public_sponsor_from_record()
returns trigger
language plpgsql
security definer
set search_path=''
as $sync_record$
begin
 if tg_op='DELETE' then
  perform private.sync_public_sponsor(old.id);
  return old;
 end if;
 perform private.sync_public_sponsor(new.id);
 return new;
end
$sync_record$;
revoke all on function private.sync_public_sponsor_from_record() from public, anon, authenticated;

create or replace function private.sync_public_sponsor_from_settings()
returns trigger
language plpgsql
security definer
set search_path=''
as $sync_settings$
begin
 if tg_op='DELETE' then
  perform private.sync_public_sponsor(old.sponsor_record_id);
  return old;
 end if;
 perform private.sync_public_sponsor(new.sponsor_record_id);
 return new;
end
$sync_settings$;
revoke all on function private.sync_public_sponsor_from_settings() from public, anon, authenticated;

drop trigger if exists club_records_sync_public_sponsor on private.club_records;
create trigger club_records_sync_public_sponsor
 after insert or update or delete on private.club_records
 for each row execute function private.sync_public_sponsor_from_record();

drop trigger if exists sponsor_public_settings_sync_public_sponsor on public.sponsor_public_settings;
create trigger sponsor_public_settings_sync_public_sponsor
 after insert or update or delete on public.sponsor_public_settings
 for each row execute function private.sync_public_sponsor_from_settings();

-- Backfill only sponsors that are approved and explicitly opted into publication.
do $backfill$
declare r record;
begin
 for r in select id from private.club_records where record_type='sponsor' loop
  perform private.sync_public_sponsor(r.id);
 end loop;
end
$backfill$;

comment on table public.public_partners is
 'Public-safe cache of approved sponsor records explicitly opted into publication. Never store contact details or internal notes here.';
commit;
