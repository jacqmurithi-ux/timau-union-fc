-- Explicit access rules for signed sponsor agreements.
-- Object names must begin with the UUID of an existing private sponsor agreement.
-- This does not replace runtime tests of interactions with all existing storage.objects policies.
begin;

drop policy if exists sponsor_agreements_select_authorized on storage.objects;
create policy sponsor_agreements_select_authorized
on storage.objects for select to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from private.sponsor_agreements a
    where a.id = split_part(storage.objects.name, '/', 1)::uuid
  )
  and (
    private.can_access_sponsor_workspace('agreements')
    or private.can_access_sponsor_workspace('finance')
  )
);

drop policy if exists sponsor_agreements_insert_authorized on storage.objects;
create policy sponsor_agreements_insert_authorized
on storage.objects for insert to authenticated
with check (
  bucket_id = 'sponsor-agreements'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from private.sponsor_agreements a
    where a.id = split_part(storage.objects.name, '/', 1)::uuid
  )
  and private.can_access_sponsor_workspace('agreements')
);

drop policy if exists sponsor_agreements_update_authorized on storage.objects;
create policy sponsor_agreements_update_authorized
on storage.objects for update to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from private.sponsor_agreements a
    where a.id = split_part(storage.objects.name, '/', 1)::uuid
  )
  and private.can_access_sponsor_workspace('agreements')
)
with check (
  bucket_id = 'sponsor-agreements'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from private.sponsor_agreements a
    where a.id = split_part(storage.objects.name, '/', 1)::uuid
  )
  and private.can_access_sponsor_workspace('agreements')
);

drop policy if exists sponsor_agreements_delete_authorized on storage.objects;
create policy sponsor_agreements_delete_authorized
on storage.objects for delete to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from private.sponsor_agreements a
    where a.id = split_part(storage.objects.name, '/', 1)::uuid
  )
  and (
    private.is_active_platform_admin(auth.uid())
    or 'chairman' = any(private.current_club_roles())
  )
);

commit;
