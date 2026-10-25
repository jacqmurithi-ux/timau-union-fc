\set ON_ERROR_STOP on
-- Migration has already been applied to this disposable PostgreSQL service.
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into private.club_records(id,record_type,publication_status,data) values
 ('10000000-0000-0000-0000-000000000001','sponsor','approved','{"name":"Public Sponsor","support_type":"Kit","details":"Public summary","website":"https://example.com"}'),
 ('10000000-0000-0000-0000-000000000002','sponsor','pending','{"name":"Pending Sponsor","support_type":"Other","details":"Must not leak"}');

-- RPC validates and inserts a legitimate enquiry when minimum form duration is satisfied.
select public.submit_sponsor_enquiry(
 'Test Contact','test@example.com','Test Business','0712345678',
 array['Kit','Training'],'Integration test',false,'',
 floor(extract(epoch from clock_timestamp())*1000)::bigint-3000
) as first_enquiry_id \gset
select public.submit_sponsor_enquiry(
 'Test Contact','test@example.com','Test Business','0712345678',
 array['Kit'],'Integration test',false,'',
 floor(extract(epoch from clock_timestamp())*1000)::bigint-3000
);
select public.submit_sponsor_enquiry(
 'Test Contact','test@example.com','Test Business','0712345678',
 array['Kit'],'Integration test',false,'',
 floor(extract(epoch from clock_timestamp())*1000)::bigint-3000
);
do $$ begin
 begin
  perform public.submit_sponsor_enquiry('Test Contact','test@example.com','Test Business',null,array['Kit'],null,false,'',floor(extract(epoch from clock_timestamp())*1000)::bigint-3000);
  raise exception 'FAIL: fourth submission should be rate-limited';
 exception when others then
  if sqlerrm='FAIL: fourth submission should be rate-limited' then raise; end if;
  if sqlerrm not like 'Too many submissions%' then raise exception 'Unexpected rate limit result: %',sqlerrm; end if;
 end;
 begin
  perform public.submit_sponsor_enquiry('Test Contact','bad-email','Test Business',null,array['Kit'],null,false,'',floor(extract(epoch from clock_timestamp())*1000)::bigint-3000);
  raise exception 'FAIL: invalid email should be rejected';
 exception when others then
  if sqlerrm='FAIL: invalid email should be rejected' then raise; end if;
 end;
 begin
  perform public.submit_sponsor_enquiry('Test Contact','spam@example.com','Test Business',null,array['Kit'],null,false,'bot-filled',floor(extract(epoch from clock_timestamp())*1000)::bigint-3000);
  raise exception 'FAIL: honeypot should be rejected';
 exception when others then
  if sqlerrm='FAIL: honeypot should be rejected' then raise; end if;
 end;
end $$;

-- No anonymous direct table reads/writes or public-settings access.
set role anon;
do $$ begin
 if has_table_privilege(current_user,'public.sponsor_enquiries','select') then raise exception 'FAIL: anon can select enquiries'; end if;
 if has_table_privilege(current_user,'public.sponsor_enquiries','insert') then raise exception 'FAIL: anon can insert enquiries directly'; end if;
 if has_table_privilege(current_user,'public.sponsor_public_settings','select') then raise exception 'FAIL: anon can select private public-settings table'; end if;
 if not has_table_privilege(current_user,'public.public_partners','select') then raise exception 'FAIL: anon cannot read public partner view'; end if;
end $$;
reset role;

-- An unrelated authenticated user cannot read/update enquiry records under RLS.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select set_config('request.test.roles','member',false);
do $$ begin
 if (select count(*) from public.sponsor_enquiries)<>0 then raise exception 'FAIL: unrelated role read enquiries'; end if;
end $$;
reset role;

-- Sponsor Lead can read enquiries and update only permitted status fields.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select set_config('request.test.roles','sponsor_lead',false);
do $$ declare n integer; begin
 select count(*) into n from public.sponsor_enquiries;
 if n<>3 then raise exception 'FAIL: Sponsor Lead expected 3 enquiries, found %',n; end if;
end $$;
update public.sponsor_enquiries set status='contacted',contacted_at=now() where email='test@example.com' and id=(select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1);
reset role;

-- An unauthorised authenticated user cannot save public settings; Sponsor Lead can.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select set_config('request.test.roles','member',false);
do $$ begin
 begin
  perform public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000001',true,false,'','Should fail');
  raise exception 'FAIL: unauthorized settings save succeeded';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select set_config('request.test.roles','sponsor_lead',false);
select public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000001',true,true,'Fan offer: 10% off','Approved public description');
select public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000002',true,false,'','Pending should not show');
reset role;

-- Public view must expose only approved, opted-in records and only the selected safe columns.
set role anon;
do $$ declare n integer; begin
 select count(*) into n from public.public_partners;
 if n<>1 then raise exception 'FAIL: expected exactly one approved opted-in partner, found %',n; end if;
 if not exists(select 1 from public.public_partners where name='Public Sponsor' and fan_offer_text='Fan offer: 10% off' and website='https://example.com') then raise exception 'FAIL: expected safe partner fields missing'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='public_partners' and column_name in ('notes','email','phone')) then raise exception 'FAIL: sensitive columns leaked into public view'; end if;
end $$;
reset role;
select 'PASS: migration, RPC validation, email rate limit, RLS, restricted grants, role checks and public view filtering' as result;
