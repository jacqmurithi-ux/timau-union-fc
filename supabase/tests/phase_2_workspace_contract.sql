-- Static catalog, grants, function configuration and permission-map checks.
-- Run only after the reviewed schema is installed in Union Test. No user data is changed.
do $check$
declare
  r regclass;
  fn regprocedure;
  cfg text[];
  role_key text;
  priv text;
begin
  r:=to_regclass('private.club_records');
  if r is null then raise exception 'Missing private.club_records'; end if;
  if not exists(select 1 from pg_class where oid=r and relrowsecurity) then raise exception 'RLS disabled on club_records'; end if;
  r:=to_regclass('private.club_record_audit');
  if r is null then raise exception 'Missing private.club_record_audit'; end if;
  if not exists(select 1 from pg_class where oid=r and relrowsecurity) then raise exception 'RLS disabled on club_record_audit'; end if;

  foreach priv in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
    if has_table_privilege('anon','private.club_records',priv)
       or has_table_privilege('authenticated','private.club_records',priv)
       or has_table_privilege('anon','private.club_record_audit',priv)
       or has_table_privilege('authenticated','private.club_record_audit',priv) then
      raise exception 'Direct private table privilege remains: %', priv;
    end if;
  end loop;

  if has_function_privilege('anon','public.club_save_record(uuid,text,jsonb)','execute')
     or has_function_privilege('anon','public.club_set_publication_status(uuid,text,text)','execute')
     or has_function_privilege('anon','public.club_get_workspace_bundle()','execute') then
    raise exception 'anon can execute a private workspace RPC';
  end if;
  if has_function_privilege('anon','private.current_club_roles()','execute')
     or has_function_privilege('authenticated','private.current_club_roles()','execute')
     or has_function_privilege('anon','private.role_can_manage_record(text[],text)','execute')
     or has_function_privilege('authenticated','private.role_can_manage_record(text[],text)','execute')
     or has_function_privilege('anon','private.valid_club_record_data(text,jsonb)','execute')
     or has_function_privilege('authenticated','private.valid_club_record_data(text,jsonb)','execute') then
    raise exception 'An internal helper is directly executable by an API role';
  end if;
  if not has_function_privilege('authenticated','public.club_save_record(uuid,text,jsonb)','execute')
     or not has_function_privilege('authenticated','public.club_set_publication_status(uuid,text,text)','execute')
     or not has_function_privilege('authenticated','public.club_get_workspace_bundle()','execute')
     or not has_function_privilege('anon','public.get_published_club_content()','execute') then
    raise exception 'Expected RPC execute grant is missing';
  end if;

  foreach fn in array array[
    'public.club_get_workspace_bundle()'::regprocedure,
    'public.club_save_record(uuid,text,jsonb)'::regprocedure,
    'public.club_set_publication_status(uuid,text,text)'::regprocedure,
    'public.get_published_club_content()'::regprocedure
  ] loop
    select p.proconfig into cfg from pg_proc p where p.oid=fn;
    if not exists(select 1 from unnest(coalesce(cfg,array[]::text[])) as settings(setting) where setting like 'search_path=%') then
      raise exception 'SECURITY DEFINER RPC lacks fixed search_path: %', fn;
    end if;
    if not (select prosecdef from pg_proc where oid=fn) then
      raise exception 'Expected SECURITY DEFINER RPC is not SECURITY DEFINER: %', fn;
    end if;
  end loop;

  if not private.role_can_manage_record(array['chairman']::text[],'sponsor')
     or not private.role_can_manage_record(array['secretary']::text[],'news')
     or not private.role_can_manage_record(array['team_manager']::text[],'fixture')
     or not private.role_can_manage_record(array['coach']::text[],'activity')
     or not private.role_can_manage_record(array['media_team']::text[],'news')
     or not private.role_can_manage_record(array['sponsor_lead']::text[],'sponsor') then
    raise exception 'An expected role/type permission is missing';
  end if;
  if private.role_can_manage_record(array['media_team']::text[],'sponsor')
     or private.role_can_manage_record(array['sponsor_lead']::text[],'news')
     or private.role_can_manage_record(array['coach']::text[],'sponsor')
     or private.role_can_manage_record(array['treasurer']::text[],'fixture')
     or private.role_can_manage_record(array['player']::text[],'news')
     or private.role_can_manage_record(array['supporter']::text[],'activity') then
    raise exception 'A disallowed role/type permission was granted';
  end if;
end $check$;
select 'catalog, grants, SECURITY DEFINER configuration and role-map checks passed' as result;
