\set ON_ERROR_STOP on
-- Migration has already been applied to this disposable PostgreSQL service.
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000001','lead@example.test',now()),
 ('00000000-0000-0000-0000-000000000002','sponsor@example.test',now()),
 ('00000000-0000-0000-0000-000000000003','member@example.test',now()),
 ('00000000-0000-0000-0000-000000000004','unverified@example.test',null);
insert into private.role_assignments(user_id,role_key,active) values
 ('00000000-0000-0000-0000-000000000002','sponsor',true),
 ('00000000-0000-0000-0000-000000000004','sponsor',true);
insert into private.account_access(user_id,status) values
 ('00000000-0000-0000-0000-000000000002','approved'),
 ('00000000-0000-0000-0000-000000000004','approved');
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
select public.sponsor_enquiry_set_status((select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1),'in_discussion','Follow-up discussion started');
do $test$ begin if not exists(select 1 from public.sponsor_enquiries where email='test@example.com' and status='in_discussion') then raise exception 'FAIL: Sponsor Lead could not progress enquiry to In Discussion'; end if; end $test$;
select public.sponsor_enquiry_set_status((select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1),'agreement_reached','Commercial terms agreed');
select public.sponsor_enquiry_set_status((select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1),'account_setup','Guided account setup started');
do $test$ begin if (select count(*) from private.sponsor_workspace_audit where record_table='sponsor_enquiries' and action_key='sponsor_enquiry_status_changed') < 3 then raise exception 'FAIL: enquiry status changes were not audit-logged'; end if; end $test$;
reset role;

-- An unauthorised authenticated user cannot update enquiries directly or change lifecycle via RPC.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select set_config('request.test.roles','member',false);
do $test$ begin
 if has_table_privilege('authenticated','public.sponsor_enquiries','UPDATE') then raise exception 'FAIL: authenticated role can directly update enquiries'; end if;
 begin
  perform public.sponsor_enquiry_set_status((select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1),'contacted','unauthorised attempt',null);
  raise exception 'FAIL: unauthorised member changed enquiry status';
 exception when insufficient_privilege then null;
 end;
 begin
  perform public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000001',true,false,'','Should fail');
  raise exception 'FAIL: unauthorized settings save succeeded';
 exception when insufficient_privilege then null;
 end;
end $test$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select set_config('request.test.roles','sponsor_lead',false);
select public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000001',true,true,'Fan offer: 10% off','Approved public description');
select public.sponsor_public_settings_save('10000000-0000-0000-0000-000000000002',true,false,'','Pending should not show');
do $test$ begin if not exists(select 1 from private.sponsor_workspace_audit where record_table='sponsor_public_settings' and action_key='sponsor_public_settings_updated') then raise exception 'FAIL: public display settings were not audit-logged'; end if; end $test$;
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

-- Test the existing sponsor-account linking RPC in an isolated PostgreSQL fixture.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select set_config('request.test.roles','sponsor_lead',false);
select public.sponsor_lead_set_user_link(
 '00000000-0000-0000-0000-000000000002',
 '10000000-0000-0000-0000-000000000001',
 true,
 'Integration test approved sponsor account link'
);
select public.sponsor_enquiry_set_status((select id from public.sponsor_enquiries where email='test@example.com' order by created_at asc limit 1),'linked','Approved Sponsor account linked separately','10000000-0000-0000-0000-000000000001');
do $test$ begin if not exists(select 1 from public.sponsor_enquiries where email='test@example.com' and status='linked' and linked_sponsor_record_id='10000000-0000-0000-0000-000000000001') then raise exception 'FAIL: enquiry cannot be marked linked before an active Sponsor link'; end if; end $test$;
reset role;
do $test$ begin
 if not exists(select 1 from private.sponsor_user_links where user_id='00000000-0000-0000-0000-000000000002' and sponsor_record_id='10000000-0000-0000-0000-000000000001' and active) then
  raise exception 'FAIL: sponsor account link was not created';
 end if;
 if not exists(select 1 from private.sponsor_workspace_audit where record_table='sponsor_enquiries' and action_key='sponsor_enquiry_status_changed' and after_data->>'status'='linked') then raise exception 'FAIL: linked enquiry status was not audit-logged'; end if;
 if not exists(select 1 from private.sponsor_workspace_audit where record_table='sponsor_user_links' and action_key='sponsor_user_linked_or_changed') then
  raise exception 'FAIL: sponsor link creation was not audited';
 end if;
end $test$;
reset role;

-- Unauthorised member cannot create a sponsor link.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select set_config('request.test.roles','member',false);
do $test$ begin
 begin
  perform public.sponsor_lead_set_user_link('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001',true,'unauthorised attempt');
  raise exception 'FAIL: member created sponsor link';
 exception when insufficient_privilege then null;
 end;
end $test$;
reset role;

-- An unverified Sponsor account cannot be linked even when its access status says approved.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select set_config('request.test.roles','sponsor_lead',false);
do $test$ begin
 begin
  perform public.sponsor_lead_set_user_link('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001',true,'unverified account attempt');
  raise exception 'FAIL: unverified sponsor account was linked';
 exception when sqlstate '22023' then
  if sqlerrm not like 'Target account must be email-verified%' then raise; end if;
 end;
end $test$;

-- Sponsor Lead can unlink the account; unlinking is also audit logged.
select public.sponsor_lead_set_user_link(
 '00000000-0000-0000-0000-000000000002',null,false,'Integration test unlink'
);
reset role;
do $test$ begin
 if exists(select 1 from private.sponsor_user_links where user_id='00000000-0000-0000-0000-000000000002' and active) then
  raise exception 'FAIL: sponsor link remained active after unlink';
 end if;
 if not exists(select 1 from private.sponsor_workspace_audit where record_table='sponsor_user_links' and action_key='sponsor_user_unlinked') then
  raise exception 'FAIL: sponsor unlink was not audited';
 end if;
end $test$;
reset role;

select 'PASS: migration, RLS, enquiry anti-spam, sponsor account linking/unlinking, role checks and audit logging' as result;
