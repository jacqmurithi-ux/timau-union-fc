-- Timau Union FC Phase 1 catalog/privilege smoke tests.
-- Run ONLY against Union Test (dzpquzfghapjodmrmavw): dzpquzfghapjodmrmavw.
-- Safe to rerun: checks catalog/grants, calls one intentionally denied RPC,
-- and creates/removes one temporary rate-limit counter. Never run in production.

DO $test$
DECLARE
  table_name text;
  privilege_name text;
  missing_tables text;
  rpc_count integer;
  violation_count integer;
  i integer;
  rate_allowed boolean;
  rate_test_actor uuid := '00000000-0000-4000-8000-000000000091';
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

  SELECT count(*) INTO rpc_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname LIKE 'club_admin_%';

  IF rpc_count <> 10 THEN
    RAISE EXCEPTION 'FAIL: expected 10 privileged RPCs including rate limiter, found %', rpc_count;
  END IF;

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

  FOR i IN 1..10 LOOP
    rate_allowed := public.club_admin_consume_rate_limit(rate_test_actor, 'activation');
    IF NOT rate_allowed THEN
      RAISE EXCEPTION 'FAIL: activation rate-limit denied request % before limit', i;
    END IF;
  END LOOP;
  rate_allowed := public.club_admin_consume_rate_limit(rate_test_actor, 'activation');
  IF rate_allowed THEN
    RAISE EXCEPTION 'FAIL: activation rate-limit did not deny request 11';
  END IF;
  DELETE FROM private.api_rate_limit_counters WHERE actor_user_id = rate_test_actor;

  RAISE NOTICE 'PASS: RLS, effective table privileges, ten privileged RPCs, fixed search_path, non-Chairman denial, and rate limit threshold';
END
$test$;
