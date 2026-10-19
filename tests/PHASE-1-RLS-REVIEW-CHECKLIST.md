# Phase 1 — RLS and identity schema review checklist

Status: Review checklist; not evidence of tests executed.

## Before any SQL execution

- [ ] Confirm target project is disposable/non-production and its project reference is verified.
- [ ] Review every DDL statement, extension dependency, default, constraint, index and foreign-key behavior.
- [ ] Confirm the trusted migration owner and ownership of all SECURITY DEFINER functions.
- [ ] Confirm role helper functions remain in a non-exposed schema, have a fixed empty search_path, fully qualify objects, and return false for unauthenticated calls.
- [ ] Verify private schema is not exposed through the Supabase Data API.
- [ ] Confirm only required schema/table/function grants are present.
- [ ] Confirm no client INSERT/UPDATE/DELETE policies exist for membership, role assignment or audit records.
- [ ] Confirm all tables in exposed schemas have RLS enabled.
- [ ] Confirm there is no public/anon read path to private profile, membership, role or audit data.
- [ ] Check that no public user metadata is used for authorization.
- [ ] Confirm invitation flow can create a pending auth identity and bind it to the intended email without allowing invitees to choose a role.
- [ ] Confirm account revocation is checked by protected requests and consider session/token expiry behavior.
- [ ] Check that audit detail fields cannot accidentally capture credentials, tokens or unnecessary sensitive data.

## Required negative tests

Use separate test identities for Chairman, Vice Chairman, Secretary, Team Manager, Treasurer, Coach, Sponsor Lead, Media Team, an authenticated person without active membership, and anonymous access.

- [ ] Anonymous reads of all private tables fail.
- [ ] Authenticated but non-member reads of private tables fail.
- [ ] Active member reads only their own profile, membership and role assignments unless explicitly authorized as Chairman.
- [ ] Vice Chairman cannot assign, elevate or revoke roles.
- [ ] Any user cannot create or update their own role assignment.
- [ ] Any user cannot activate their own membership or change its status.
- [ ] Any user cannot insert, update or delete audit events.
- [ ] A revoked/suspended member is denied even if their session still exists.
- [ ] A direct REST/RPC request cannot bypass the UI or access another member by changing an identifier.
- [ ] Unauthenticated calls to helper functions return false or are denied.
- [ ] Helper functions cannot be used to infer other users' roles.
- [ ] Query plans and RLS policy checks do not trigger recursive-policy errors.
- [ ] All permitted reads work for the intended role and no broader data is returned.

## Verification record

Record the date, test project reference (not secrets), migration commit, SQL runner/version, test identity/role, request method, expected result, actual result and evidence for each test. Never include access tokens or secrets in test artifacts.

## Release gate

No production migration until the draft is reviewed, tests pass in a non-production project, and a separate production migration is presented and explicitly approved. Moving a draft into a review folder does not mean it is ready to apply.
