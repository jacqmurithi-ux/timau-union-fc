begin;
create table if not exists public.sponsor_enquiries (
 id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(),
 name text not null check(char_length(btrim(name)) between 2 and 120),
 email text not null check(char_length(btrim(email)) between 5 and 254),
 business text not null check(char_length(btrim(business)) between 2 and 160),
 phone text check(phone is null or char_length(phone)<=40),
 interests text[] not null check(cardinality(interests) between 1 and 6 and interests <@ array['Kit','Match day','Training','Website / social','Community partner','Other']::text[]),
 message text check(message is null or char_length(message)<=2000), news_opt_in boolean not null default false,
 status text not null default 'new' check(status in ('new','contacted','in_discussion','agreement_reached','account_setup','linked')), contacted_at timestamptz, linked_sponsor_record_id uuid references private.club_records(id), notes text
);
alter table public.sponsor_enquiries enable row level security;
revoke all on public.sponsor_enquiries from anon,authenticated;
-- Only the validated RPC may insert. RLS limits reads and updates to approved staff roles.
drop policy if exists sponsor_enquiries_submit on public.sponsor_enquiries;
create policy sponsor_enquiries_staff_read on public.sponsor_enquiries for select to authenticated using(private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()));
grant select on public.sponsor_enquiries to authenticated;
-- Lifecycle changes must pass through an audited RPC; authenticated clients cannot update enquiry rows directly.
revoke update,insert,delete on public.sponsor_enquiries from authenticated;
create index if not exists sponsor_enquiries_email_created_idx on public.sponsor_enquiries (lower(email), created_at desc);

create or replace function public.sponsor_enquiry_set_status(
 _enquiry_id uuid,
 _status text,
 _reason text,
 _sponsor_record_id uuid default null
) returns void
language plpgsql security definer set search_path='' as $sponsor_status$
declare v_actor uuid:=auth.uid(); v_before text; v_before_record uuid;
begin
 if v_actor is null or not (
   private.is_active_platform_admin(v_actor) or
   'sponsor_lead'=any(private.current_club_roles()) or
   'chairman'=any(private.current_club_roles())
 ) then
   raise exception 'Sponsor Lead, Chairman or Platform Admin required' using errcode='42501';
 end if;
 if _enquiry_id is null or _status is null or _status not in ('new','contacted','in_discussion','agreement_reached','account_setup','linked') then
   raise exception 'Choose a valid enquiry and status.' using errcode='22023';
 end if;
 if char_length(btrim(coalesce(_reason,'')))<3 or char_length(_reason)>1000 then
   raise exception 'A reason of 3 to 1000 characters is required.' using errcode='22023';
 end if;
 select status,linked_sponsor_record_id into v_before,v_before_record from public.sponsor_enquiries where id=_enquiry_id for update;
 if not found then raise exception 'Sponsorship enquiry not found.' using errcode='P0002'; end if;
 if _status='linked' then
   if _sponsor_record_id is null or not exists(select 1 from private.club_records c where c.id=_sponsor_record_id and c.record_type='sponsor' and c.publication_status='approved') then
     raise exception 'Choose an approved sponsor record that is already linked to an active Sponsor account.' using errcode='22023';
   end if;
   if not exists(select 1 from private.sponsor_user_links l where l.sponsor_record_id=_sponsor_record_id and l.active) then
     raise exception 'Link an approved, verified Sponsor account to this record before marking the enquiry Linked.' using errcode='22023';
   end if;
 elsif _sponsor_record_id is not null then
   raise exception 'A sponsor record can only be supplied when status is Linked.' using errcode='22023';
 end if;
 update public.sponsor_enquiries set status=_status,
   linked_sponsor_record_id=case when _status='linked' then _sponsor_record_id else null end,
   contacted_at=case when _status='contacted' then coalesce(contacted_at,now()) else contacted_at end
 where id=_enquiry_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(v_actor,'sponsor_enquiries',_enquiry_id,'sponsor_enquiry_status_changed',
   jsonb_build_object('status',v_before,'linked_sponsor_record_id',v_before_record),jsonb_build_object('status',_status,'linked_sponsor_record_id',case when _status='linked' then _sponsor_record_id else null end),btrim(_reason));
end $sponsor_status$;
revoke all on function public.sponsor_enquiry_set_status(uuid,text,text,uuid) from public,anon;
grant execute on function public.sponsor_enquiry_set_status(uuid,text,text,uuid) to authenticated;

create or replace function public.submit_sponsor_enquiry(p_name text,p_email text,p_business text,p_phone text,p_interests text[],p_message text default null,p_news_opt_in boolean default false,p_website_confirm text default '',p_form_started_ms bigint default 0) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_ms bigint;
begin
 v_ms:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
 if coalesce(p_website_confirm,'')<>'' then raise exception 'Unable to submit this form.' using errcode='22023'; end if;
 if p_form_started_ms<=0 or v_ms-p_form_started_ms<2500 or v_ms-p_form_started_ms>86400000 then raise exception 'Please review the form and try again.' using errcode='22023'; end if;
 if char_length(btrim(coalesce(p_name,''))) not between 2 and 120 or char_length(btrim(coalesce(p_email,''))) not between 5 and 254 or p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' or char_length(btrim(coalesce(p_business,''))) not between 2 and 160 or char_length(coalesce(p_phone,''))>40 or char_length(coalesce(p_message,''))>2000 or coalesce(cardinality(p_interests),0) not between 1 and 6 or not(p_interests <@ array['Kit','Match day','Training','Website / social','Community partner','Other']::text[]) then raise exception 'Please check the required fields and selected interests.' using errcode='22023'; end if;
 -- Serialize submissions per normalized email to prevent concurrent requests bypassing the per-email limit.
 perform pg_advisory_xact_lock(hashtextextended(lower(btrim(p_email)),0));
 if (select count(*) from public.sponsor_enquiries e
     where lower(e.email)=lower(btrim(p_email))
       and e.created_at > clock_timestamp()-interval '15 minutes') >= 3 then
   raise exception 'Too many submissions for this email. Please try again in 15 minutes.' using errcode='P0001';
 end if;
 insert into public.sponsor_enquiries(name,email,business,phone,interests,message,news_opt_in,status) values(btrim(p_name),lower(btrim(p_email)),btrim(p_business),nullif(btrim(coalesce(p_phone,'')),''),p_interests,nullif(btrim(coalesce(p_message,'')),''),coalesce(p_news_opt_in,false),'new') returning id into v_id;
 return v_id;
end $$;
revoke all on function public.submit_sponsor_enquiry(text,text,text,text,text[],text,boolean,text,bigint) from public;
grant execute on function public.submit_sponsor_enquiry(text,text,text,text,text[],text,boolean,text,bigint) to anon,authenticated;
-- Keep the existing club-record validator unchanged. Public presentation settings live in a separate, locked-down table.
create table if not exists public.sponsor_public_settings (
 sponsor_record_id uuid primary key references private.club_records(id) on delete cascade,
 show_on_public_wall boolean not null default false,
 fan_offer_enabled boolean not null default false,
 fan_offer_text text not null default '',
 public_description text not null default '',
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 check (char_length(fan_offer_text)<=1000),
 check (char_length(public_description)<=3000),
 check (fan_offer_enabled=false or char_length(btrim(fan_offer_text))>0)
);
alter table public.sponsor_public_settings enable row level security;
revoke all on public.sponsor_public_settings from public,anon,authenticated;

create or replace function public.sponsor_public_settings_save(
 _record_id uuid,
 _show_on_public_wall boolean,
 _fan_offer_enabled boolean,
 _fan_offer_text text default '',
 _public_description text default ''
) returns void
language plpgsql security definer set search_path='' as $
declare v_before jsonb;
begin
 if auth.uid() is null or not (
   private.is_active_platform_admin(auth.uid()) or
   'sponsor_lead'=any(private.current_club_roles())
 ) then
   raise exception 'Not authorised to update public sponsor settings.' using errcode='42501';
 end if;
 if _record_id is null or not exists (
   select 1 from private.club_records c where c.id=_record_id and c.record_type='sponsor'
 ) then
   raise exception 'Choose a valid sponsor record.' using errcode='22023';
 end if;
 if char_length(coalesce(_fan_offer_text,''))>1000 or char_length(coalesce(_public_description,''))>3000 then
   raise exception 'Public sponsor text is too long.' using errcode='22023';
 end if;
 if coalesce(_fan_offer_enabled,false) and char_length(btrim(coalesce(_fan_offer_text,'')))=0 then
   raise exception 'Enter the approved public offer text or disable the offer.' using errcode='22023';
 end if;
 select to_jsonb(s) into v_before from public.sponsor_public_settings s where s.sponsor_record_id=_record_id for update;
 insert into public.sponsor_public_settings(sponsor_record_id,show_on_public_wall,fan_offer_enabled,fan_offer_text,public_description,updated_at,updated_by)
 values(_record_id,coalesce(_show_on_public_wall,false),coalesce(_fan_offer_enabled,false),coalesce(_fan_offer_text,''),coalesce(_public_description,''),now(),auth.uid())
 on conflict(sponsor_record_id) do update set
  show_on_public_wall=excluded.show_on_public_wall,
  fan_offer_enabled=excluded.fan_offer_enabled,
  fan_offer_text=excluded.fan_offer_text,
  public_description=excluded.public_description,
  updated_at=excluded.updated_at,
  updated_by=excluded.updated_by;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_public_settings',_record_id,'sponsor_public_settings_updated',v_before,jsonb_build_object('show_on_public_wall',coalesce(_show_on_public_wall,false),'fan_offer_enabled',coalesce(_fan_offer_enabled,false),'fan_offer_text',coalesce(_fan_offer_text,''),'public_description',coalesce(_public_description,'')),'Public display settings updated');
end $;
revoke all on function public.sponsor_public_settings_save(uuid,boolean,boolean,text,text) from public,anon;
grant execute on function public.sponsor_public_settings_save(uuid,boolean,boolean,text,text) to authenticated;

create or replace view public.public_partners as
 select c.id,
  nullif(btrim(c.data->>'name'),'') as name,
  nullif(btrim(c.data->>'support_type'),'') as support_type,
  nullif(btrim(s.public_description),'') as public_description,
  case when coalesce(c.data->>'website','') ~* '^https?://' then c.data->>'website' else null end as website,
  case when s.fan_offer_enabled then nullif(btrim(s.fan_offer_text),'') else null end as fan_offer_text
 from private.club_records c
 join public.sponsor_public_settings s on s.sponsor_record_id=c.id
 where c.record_type='sponsor' and c.publication_status='approved' and s.show_on_public_wall;

revoke all on public.public_partners from public,authenticated;
grant select on public.public_partners to anon,authenticated;
comment on view public.public_partners is 'Only approved sponsor records explicitly opted into the public partner wall; public-safe columns only.';
comment on table public.sponsor_enquiries is 'Public sponsorship enquiries. Includes honeypot, minimum form duration and a database-enforced per-email rate limit of three submissions per 15 minutes.';
commit;