begin;

-- Keep mockup metadata editable while forcing all status changes through the
-- audited sponsor_mockup_set_status() SECURITY DEFINER RPC.
revoke update on table public.sponsor_mockups from authenticated;
grant update (title, package_key, description, storage_path, mime_type, file_size, updated_by, updated_at)
  on table public.sponsor_mockups to authenticated;

-- Do not allow clients to set approval metadata during insert. New mockups must
-- be drafts; approval metadata is written only by the audited status RPC.
revoke insert on table public.sponsor_mockups from authenticated;
grant insert (title, package_key, description, storage_path, mime_type, file_size, status, created_by, updated_by)
  on table public.sponsor_mockups to authenticated;

commit;
