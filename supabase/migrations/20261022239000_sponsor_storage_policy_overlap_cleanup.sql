-- Remove legacy permissive policies that would OR with the stricter agreement ACL.
-- Keep only the operation-specific policies backed by can_access_sponsor_agreement_object.
begin;

drop policy if exists "sponsor agreements private read" on storage.objects;
drop policy if exists "sponsor agreements private upload" on storage.objects;
drop policy if exists "sponsor agreements private update" on storage.objects;
drop policy if exists "sponsor agreements private delete" on storage.objects;

commit;
