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

rollback;
