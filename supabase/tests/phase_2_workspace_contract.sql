-- Read-only catalog/grant checks; run after the reviewed schema is installed in Union Test.
do $check$
declare r regclass;
begin
 r:=to_regclass('private.club_records'); if r is null then raise exception 'Missing private.club_records'; end if;
 if not exists(select 1 from pg_class where oid=r and relrowsecurity) then raise exception 'RLS disabled on club_records'; end if;
 r:=to_regclass('private.club_record_audit'); if r is null then raise exception 'Missing private.club_record_audit'; end if;
 if not exists(select 1 from pg_class where oid=r and relrowsecurity) then raise exception 'RLS disabled on club_record_audit'; end if;
 if has_table_privilege('anon','private.club_records','select') or has_table_privilege('authenticated','private.club_records','select') or has_table_privilege('anon','private.club_records','insert') or has_table_privilege('authenticated','private.club_records','insert') then raise exception 'Direct record-table access is granted'; end if;
 if has_function_privilege('anon','public.club_save_record(uuid,text,jsonb)','execute') then raise exception 'anon can execute save RPC'; end if;
 if has_function_privilege('anon','public.club_set_publication_status(uuid,text,text)','execute') then raise exception 'anon can execute publication RPC'; end if;
 if has_function_privilege('anon','public.club_get_workspace_bundle()','execute') then raise exception 'anon can execute private bundle RPC'; end if;
 if has_function_privilege('anon','private.current_club_roles()','execute') then raise exception 'anon can execute internal role helper'; end if;
 if has_function_privilege('anon','private.valid_club_record_data(text,jsonb)','execute') then raise exception 'anon can execute internal data validator'; end if;
 if not has_function_privilege('authenticated','public.club_save_record(uuid,text,jsonb)','execute') then raise exception 'authenticated cannot execute save RPC'; end if;
 if not has_function_privilege('anon','public.get_published_club_content()','execute') then raise exception 'anon cannot execute public-content RPC'; end if;
end $check$;
select 'catalog and grant checks passed' as result;
