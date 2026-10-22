-- Explicit access rules for signed sponsor agreements.
-- Object names must begin with the UUID of an existing private sponsor agreement.
-- Helper runs with a fixed search_path and exposes only a boolean authorization decision.
begin;

create or replace function private.can_access_sponsor_agreement_object(_name text, _operation text)
returns boolean
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  agreement_id uuid;
  is_admin boolean;
  current_roles text[];
begin
  if auth.uid() is null or _name is null then
    return false;
  end if;

  if split_part(_name, '/', 1) !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;

  agreement_id := split_part(_name, '/', 1)::uuid;
  if not exists (select 1 from private.sponsor_agreements a where a.id = agreement_id) then
    return false;
  end if;

  is_admin := private.is_active_platform_admin(auth.uid());
  current_roles := private.current_club_roles();

  if _operation = 'read' then
    return is_admin
      or 'chairman' = any(current_roles)
      or 'sponsor_lead' = any(current_roles)
      or 'treasurer' = any(current_roles);
  elsif _operation in ('insert', 'update') then
    return is_admin
      or 'chairman' = any(current_roles)
      or 'sponsor_lead' = any(current_roles);
  elsif _operation = 'delete' then
    return is_admin or 'chairman' = any(current_roles);
  end if;

  return false;
end
$$;

revoke all on function private.can_access_sponsor_agreement_object(text,text) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.can_access_sponsor_agreement_object(text,text) to authenticated;

drop policy if exists sponsor_agreements_select_authorized on storage.objects;
create policy sponsor_agreements_select_authorized
on storage.objects for select to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and private.can_access_sponsor_agreement_object(name, 'read')
);

drop policy if exists sponsor_agreements_insert_authorized on storage.objects;
create policy sponsor_agreements_insert_authorized
on storage.objects for insert to authenticated
with check (
  bucket_id = 'sponsor-agreements'
  and private.can_access_sponsor_agreement_object(name, 'insert')
);

drop policy if exists sponsor_agreements_update_authorized on storage.objects;
create policy sponsor_agreements_update_authorized
on storage.objects for update to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and private.can_access_sponsor_agreement_object(name, 'update')
)
with check (
  bucket_id = 'sponsor-agreements'
  and private.can_access_sponsor_agreement_object(name, 'update')
);

drop policy if exists sponsor_agreements_delete_authorized on storage.objects;
create policy sponsor_agreements_delete_authorized
on storage.objects for delete to authenticated
using (
  bucket_id = 'sponsor-agreements'
  and private.can_access_sponsor_agreement_object(name, 'delete')
);

commit;
