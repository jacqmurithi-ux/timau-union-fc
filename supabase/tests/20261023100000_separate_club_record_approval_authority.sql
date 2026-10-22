-- Candidate regression checks for 20261023100000_separate_club_record_approval_authority.sql
-- Run only in a disposable/test project using transaction rollback and role fixtures.
-- These checks test the pure approval predicate without impersonating production users.

begin;

do $test$
declare
  coach text[] := array['coach'];
  tm text[] := array['team_manager'];
  secretary text[] := array['secretary'];
  media text[] := array['media_team'];
  sponsor_lead text[] := array['sponsor_lead'];
  chairman text[] := array['chairman'];
  tm_secretary text[] := array['team_manager','secretary'];
begin
  if private.role_can_approve_record(coach,'player') then
    raise exception 'FAIL: Coach must not approve shared player records';
  end if;
  if private.role_can_approve_record(coach,'fixture') then
    raise exception 'FAIL: Coach must not approve shared fixture records';
  end if;
  if private.role_can_approve_record(coach,'activity') then
    raise exception 'FAIL: Coach must not approve shared activity records';
  end if;
  if not private.role_can_manage_record(coach,'fixture') then
    raise exception 'FAIL: internal fixture management/read eligibility unexpectedly changed';
  end if;
  if not private.role_can_approve_record(tm,'player')
     or not private.role_can_approve_record(tm,'fixture')
     or not private.role_can_approve_record(tm,'activity') then
    raise exception 'FAIL: existing Team Manager approval path was not preserved';
  end if;
  if not private.role_can_approve_record(secretary,'news')
     or not private.role_can_approve_record(secretary,'player')
     or not private.role_can_approve_record(media,'news')
     or not private.role_can_approve_record(sponsor_lead,'sponsor')
     or not private.role_can_approve_record(chairman,'player') then
    raise exception 'FAIL: existing record-type approval paths were not preserved';
  end if;
  if private.role_can_approve_record(media,'player')
     or private.role_can_approve_record(sponsor_lead,'news') then
    raise exception 'FAIL: media/sponsor approval crossed its existing record-type boundary';
  end if;
  if not private.role_can_approve_record(tm_secretary,'fixture')
     or private.role_can_approve_record(tm_secretary,'news') then
    raise exception 'FAIL: combined Team Manager/Secretary role precedence differs from the existing helper';
  end if;
end
$test$;

-- Direct RPC authorization, workspace metadata, audit-reason and role-path checks.
-- current_club_roles is replaced only inside this transaction to simulate role sessions
-- in an isolated test project; ROLLBACK restores the original function and removes fixtures.
create or replace function private.current_club_roles()
returns text[]
language sql
stable
security definer
set search_path to ''
as $function$
  select case current_setting('request.jwt.claim.test_role',true)
    when 'coach' then array['coach']::text[]
    when 'secretary' then array['secretary']::text[]
    when 'team_manager' then array['team_manager']::text[]
    when 'media_team' then array['media_team']::text[]
    when 'sponsor_lead' then array['sponsor_lead']::text[]
    when 'chairman' then array['chairman']::text[]
    else array[]::text[]
  end
$function$;

insert into private.club_records(id,record_type,data,publication_status,created_by,updated_by)
select v.id,v.record_type,jsonb_build_object('name','Security Regression '||v.record_type),
       'draft',u.id,u.id
from (values
  ('22222222-2222-4222-8222-222222222222'::uuid,'player'::text),
  ('33333333-3333-4333-8333-333333333333'::uuid,'fixture'::text),
  ('44444444-4444-4444-8444-444444444444'::uuid,'activity'::text),
  ('55555555-5555-4555-8555-555555555555'::uuid,'news'::text),
  ('66666666-6666-4666-8666-666666666666'::uuid,'sponsor'::text)
) v(id,record_type)
cross join lateral (
  select id from auth.users
  where email_confirmed_at is not null
  order by created_at limit 1
) u;

do $rpc_test$
declare
  v_user uuid;
  v_bundle jsonb;
  v_record jsonb;
  v_denied boolean;
  v_case record;
begin
  select id into v_user from auth.users
  where email_confirmed_at is not null
  order by created_at limit 1;
  if v_user is null then raise exception 'TEST_FAILURE: confirmed test user required'; end if;
  perform set_config('request.jwt.claim.sub',v_user::text,true);

  -- Direct RPC denial for Coach, even though Coach retains internal visibility.
  perform set_config('request.jwt.claim.test_role','coach',true);
  v_denied:=false;
  begin
    perform public.club_set_publication_status(
      '22222222-2222-4222-8222-222222222222'::uuid,'approved','coach bypass regression'
    );
    raise exception 'TEST_FAILURE: Coach direct RPC unexpectedly approved a shared player record';
  exception when others then
    if sqlerrm like 'Your role cannot approve%' then v_denied:=true;
    elsif sqlerrm like 'TEST_FAILURE:%' then raise;
    else raise;
    end if;
  end;
  if not v_denied then raise exception 'TEST_FAILURE: Coach direct RPC was not denied'; end if;

  v_bundle:=public.club_get_workspace_bundle();
  if coalesce((v_bundle->>'can_approve')::boolean,true) then
    raise exception 'TEST_FAILURE: Coach top-level can_approve should be false';
  end if;
  select x into v_record from jsonb_array_elements(v_bundle->'records') x
    where x->>'id'='22222222-2222-4222-8222-222222222222';
  if v_record is null then
    raise exception 'TEST_FAILURE: Coach internal record visibility unexpectedly changed';
  end if;
  if coalesce((v_record->>'can_approve')::boolean,true) then
    raise exception 'TEST_FAILURE: Coach per-record can_approve should be false';
  end if;

  -- Direct RPC allow-paths retained for each role/type represented by the existing helper.
  for v_case in
    select * from (values
      ('secretary'::text,'22222222-2222-4222-8222-222222222222'::uuid,'Secretary regression allowed path'),
      ('team_manager'::text,'33333333-3333-4333-8333-333333333333'::uuid,'Team Manager regression allowed path'),
      ('team_manager'::text,'44444444-4444-4444-8444-444444444444'::uuid,'Team Manager activity regression path'),
      ('media_team'::text,'55555555-5555-4555-8555-555555555555'::uuid,'Media Team regression allowed path'),
      ('sponsor_lead'::text,'66666666-6666-4666-8666-666666666666'::uuid,'Sponsor Lead regression allowed path'),
      ('chairman'::text,'22222222-2222-4222-8222-222222222222'::uuid,'Chairman regression allowed path')
    ) as cases(role_name,record_id,reason)
  loop
    perform set_config('request.jwt.claim.test_role',v_case.role_name,true);
    if not public.club_set_publication_status(v_case.record_id,'draft',v_case.reason) then
      raise exception 'TEST_FAILURE: allowed RPC path failed for %',v_case.role_name;
    end if;
    if not exists(
      select 1 from private.club_record_audit a
      where a.record_id=v_case.record_id
        and a.reason=v_case.reason
        and a.action_key='publication_draft'
    ) then
      raise exception 'TEST_FAILURE: audit reason missing for %',v_case.role_name;
    end if;
  end loop;
end
$rpc_test$;

rollback;
