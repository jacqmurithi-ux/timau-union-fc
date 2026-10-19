-- Timau Union FC Phase 1 catalog/privilege smoke tests.
-- Run ONLY against Union Test (dzpquzfghapjodmrmavw): dzpquzfghapjodmrmavw.
-- Safe to rerun: checks catalog/grants and calls one intentionally denied RPC;
-- it must not create or modify records. Never run this as a production migration.

DO $test$
DECLARE
  table_name text;
  privilege_name text;
  missing_tables text;
  violation_count integer;
BEGIN
  SELECT string_agg(t.table_name, ', ')
    INTO missing_tables
  FROM (VALUES
    ('user_profiles'),
    ('club_memberships'),
    ('role_assignments'),
    ('audit_events'),
    ('invitation_requests')
  ) AS t(table_name)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_tables p
    WHERE p.schemaname = 'public'
      AND p.tablename = t.table_name
      AND p.rowsecurity
  );

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: RLS missing on: %', missing_tables;
  END IF;

  FOREACH table_name IN ARRAY ARRAY[
    'user_profiles',
    'club_memberships',
    'role_assignments',
    'audit_events',
    'invitation_requests'
  ] LOOP
    IF has_table_privilege('anon', format('public.%I', table_name), 'SELECT') THEN
      RAISE EXCEPTION 'FAIL: anon has effective SELECT on public.%', table_name;
    END IF;

    FOREACH privilege_name IN ARRAY ARRAY[
      'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
    ] LOOP
      IF has_table_privilege('authenticated', format('public.%I', table_name), privilege_name) THEN
        RAISE EXCEPTION 'FAIL: authenticated has effective % on public.%', privilege_name, table_name;
      END IF;
    END LOOP;
  END LOOP;

  SELECT count(*) INTO violation_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname LIKE 'club_admin_%'
    AND (
      has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR NOT has_function_privilege('service_role', p.oid, 'EXECUTE')
      OR NOT p.prosecdef
      OR NOT EXISTS (
        SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg
        WHERE cfg = 'search_path=""'
      )
    );

  IF violation_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: % privileged RPC grant/security configuration violations', violation_count;
  END IF;

  -- A non-existent/non-Chairman actor must never create an invitation.
  BEGIN
    PERFORM public.club_admin_begin_invitation(
      '00000000-0000-4000-8000-000000000001'::uuid,
      'simulated@example.invalid',
      'secretary',
      '00000000-0000-4000-8000-000000000002'::uuid
    );
    RAISE EXCEPTION 'FAIL: nonexistent/non-Chairman actor unexpectedly created an invitation';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- Expected denial.
  END;

  RAISE NOTICE 'PASS: RLS, effective table privileges, privileged RPC grants/search_path, and non-Chairman denial';
END
$test$;
