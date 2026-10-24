begin;
create table if not exists public.sponsor_enquiries (
 id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(),
 name text not null check(char_length(btrim(name)) between 2 and 120),
 email text not null check(char_length(btrim(email)) between 5 and 254),
 business text not null check(char_length(btrim(business)) between 2 and 160),
 phone text check(phone is null or char_length(phone)<=40),
 interests text[] not null check(cardinality(interests) between 1 and 6 and interests <@ array['Kit','Match day','Training','Website / social','Community partner','Other']::text[]),
 message text check(message is null or char_length(message)<=2000), news_opt_in boolean not null default false,
 status text not null default 'new' check(status in ('new','contacted')), contacted_at timestamptz, notes text
);
alter table public.sponsor_enquiries enable row level security;
revoke all on public.sponsor_enquiries from anon,authenticated;
-- Only the validated RPC may insert. RLS limits reads and updates to approved staff roles.
drop policy if exists sponsor_enquiries_submit on public.sponsor_enquiries;
create policy sponsor_enquiries_staff_read on public.sponsor_enquiries for select to authenticated using(private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()));
create policy sponsor_enquiries_staff_update on public.sponsor_enquiries for update to authenticated using(private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles())) with check(private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()));
grant select on public.sponsor_enquiries to authenticated;
grant update(status,contacted_at) on public.sponsor_enquiries to authenticated;
create or replace function public.submit_sponsor_enquiry(p_name text,p_email text,p_business text,p_phone text,p_interests text[],p_message text default null,p_news_opt_in boolean default false,p_website_confirm text default '',p_form_started_ms bigint default 0) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_ms bigint;
begin
 v_ms:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
 if coalesce(p_website_confirm,'')<>'' then raise exception 'Unable to submit this form.' using errcode='22023'; end if;
 if p_form_started_ms<=0 or v_ms-p_form_started_ms<2500 or v_ms-p_form_started_ms>86400000 then raise exception 'Please review the form and try again.' using errcode='22023'; end if;
 if char_length(btrim(coalesce(p_name,''))) not between 2 and 120 or char_length(btrim(coalesce(p_email,''))) not between 5 and 254 or p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' or char_length(btrim(coalesce(p_business,''))) not between 2 and 160 or char_length(coalesce(p_phone,''))>40 or char_length(coalesce(p_message,''))>2000 or coalesce(cardinality(p_interests),0) not between 1 and 6 or not(p_interests <@ array['Kit','Match day','Training','Website / social','Community partner','Other']::text[]) then raise exception 'Please check the required fields and selected interests.' using errcode='22023'; end if;
 insert into public.sponsor_enquiries(name,email,business,phone,interests,message,news_opt_in,status) values(btrim(p_name),lower(btrim(p_email)),btrim(p_business),nullif(btrim(coalesce(p_phone,'')),''),p_interests,nullif(btrim(coalesce(p_message,'')),''),coalesce(p_news_opt_in,false),'new') returning id into v_id;
 return v_id;
end $$;
revoke all on function public.submit_sponsor_enquiry(text,text,text,text,text[],text,boolean,text,bigint) from public;
grant execute on function public.submit_sponsor_enquiry(text,text,text,text,text[],text,boolean,text,bigint) to anon,authenticated;
-- Extend the existing validator only to accept explicit public wall fields.
create or replace function private.valid_club_record_data(_type text,_data jsonb) returns boolean
language plpgsql immutable set search_path='' as $
declare v_allowed text[]; v_required text; v_key text; v_value text;
begin
 if _data is null or jsonb_typeof(_data)<>'object' then return false; end if;
 case _type
  when 'player' then v_allowed:=array['name','position','bio','squad_number','date_of_birth','fkf_number']; v_required:='name';
  when 'fixture' then v_allowed:=array['opponent','match_date','venue','result']; v_required:='opponent';
  when 'news' then v_allowed:=array['title','summary','body','category']; v_required:='title';
  when 'sponsor' then v_allowed:=array['name','support_type','details','website','show_on_public_wall','fan_offer_enabled','fan_offer_text','public_description']; v_required:='name';
  when 'activity' then v_allowed:=array['title','date','location','details']; v_required:='title';
  else return false;
 end case;
 if not (_data ? v_required) or jsonb_typeof(_data->v_required)<>'string' or length(btrim(_data->>v_required))=0 then return false; end if;
 for v_key in select jsonb_object_keys(_data) loop
  if not (v_key=any(v_allowed)) or jsonb_typeof(_data->v_key)<>'string' then return false; end if;
  v_value:=_data->>v_key;
  if length(v_value)>3000 then return false; end if;
  if v_key in ('show_on_public_wall','fan_offer_enabled') and v_value not in ('true','false') then return false; end if;
 end loop;
 return true;
end $;

create or replace view public.public_partners as select c.id,nullif(btrim(c.data->>'name'),'') name,nullif(btrim(c.data->>'support_type'),'') support_type,nullif(btrim(coalesce(c.data->>'public_description',c.data->>'details')),'') public_description,case when coalesce(c.data->>'website','') ~* '^https?://' then c.data->>'website' else null end website,case when c.data->>'fan_offer_enabled'='true' then nullif(btrim(c.data->>'fan_offer_text'),'') else null end fan_offer_text from private.club_records c where c.record_type='sponsor' and c.publication_status='approved' and c.data->>'show_on_public_wall'='true';
revoke all on public.public_partners from public,authenticated;
grant select on public.public_partners to anon,authenticated;
comment on view public.public_partners is 'Only approved sponsor records explicitly opted into the public partner wall; public-safe columns only.';
comment on table public.sponsor_enquiries is 'Public sponsorship enquiries. Cloudflare Turnstile can be added to form and server validation later.';
commit;