-- Integration tests for finance approval hardening. Disposable database only.
\set ON_ERROR_STOP on

-- Platform Admin must be denied even when the same identity has the Treasurer role.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000010',false);
select set_config('test.platform_admin','true',false);
select set_config('test.club_roles','treasurer',false);
do $admin_denied$
declare denied boolean:=false;
begin
 begin
  perform public.tm_review_expense('20000000-0000-0000-0000-000000000001','approved','Admin must not approve');
 exception when others then
  if sqlerrm='Platform Admin cannot approve or reject club expenses' then denied:=true;
  else raise; end if;
 end;
 if not denied then raise exception 'FAIL: Platform Admin approval was not denied'; end if;
end
$admin_denied$;
reset role;
do $admin_unchanged$
begin
 if (select status from private.club_financial_expenses where id='20000000-0000-0000-0000-000000000001')<>'pending' then
  raise exception 'FAIL: denied Platform Admin action changed expense status';
 end if;
end
$admin_unchanged$;

-- Treasurer can approve another user's pending expense and creates one ledger row plus an accurate audit snapshot.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000020',false);
select set_config('test.platform_admin','false',false);
select set_config('test.club_roles','treasurer',false);
select public.tm_review_expense('20000000-0000-0000-0000-000000000002','approved','Receipt and amount checked');
reset role;
do $approved$
declare audit_row private.club_financial_audit%rowtype;
begin
 if (select status from private.club_financial_expenses where id='20000000-0000-0000-0000-000000000002')<>'approved' then raise exception 'FAIL: Treasurer approval did not update expense'; end if;
 if (select count(*) from private.club_financial_ledger where source_expense_id='20000000-0000-0000-0000-000000000002')<>1 then raise exception 'FAIL: approval did not create exactly one ledger row'; end if;
 select * into audit_row from private.club_financial_audit where expense_id='20000000-0000-0000-0000-000000000002';
 if audit_row.old_status<>'pending' or audit_row.new_status<>'approved' or audit_row.is_admin_override then raise exception 'FAIL: approval audit statuses/override flag incorrect'; end if;
 if audit_row.old_data->>'status'<>'pending' or audit_row.new_data->>'status'<>'approved' then raise exception 'FAIL: audit snapshots do not show before/after state'; end if;
end
$approved$;

-- Self-approval must remain blocked.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
select set_config('test.platform_admin','false',false);
select set_config('test.club_roles','treasurer',false);
do $self_denied$
declare denied boolean:=false;
begin
 begin
  perform public.tm_review_expense('20000000-0000-0000-0000-000000000003','approved','Attempt self approval');
 exception when others then
  if sqlerrm='You cannot approve or reject your own expense' then denied:=true;
  else raise; end if;
 end;
 if not denied then raise exception 'FAIL: self-approval was not denied'; end if;
end
$self_denied$;
reset role;

-- Rejection changes status and is audited but must not post a ledger entry.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000030',false);
select set_config('test.platform_admin','false',false);
select set_config('test.club_roles','secretary',false);
select public.tm_review_expense('20000000-0000-0000-0000-000000000004','rejected','Duplicate receipt evidence');
reset role;
do $rejected$
begin
 if (select status from private.club_financial_expenses where id='20000000-0000-0000-0000-000000000004')<>'rejected' then raise exception 'FAIL: rejection did not update expense'; end if;
 if exists(select 1 from private.club_financial_ledger where source_expense_id='20000000-0000-0000-0000-000000000004') then raise exception 'FAIL: rejected expense created ledger row'; end if;
 if not exists(select 1 from private.club_financial_audit where expense_id='20000000-0000-0000-0000-000000000004' and old_status='pending' and new_status='rejected' and action_key='secretary_rejected') then raise exception 'FAIL: rejection audit missing'; end if;
end
$rejected$;

-- Direct calls by anonymous users must not be executable.
do $grants$
begin
 if has_function_privilege('anon','public.tm_review_expense(uuid,text,text)','EXECUTE') then raise exception 'FAIL: anon can execute expense review'; end if;
 if not has_function_privilege('authenticated','public.tm_review_expense(uuid,text,text)','EXECUTE') then raise exception 'FAIL: authenticated cannot execute expense review'; end if;
end
$grants$;

select 'PASS: finance approval integration tests' as result;
