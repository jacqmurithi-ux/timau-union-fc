begin;

-- Remove table-level privileges and any prior column-level grants that could
-- still allow clients to change approval fields directly.
revoke update on table public.sponsor_mockups from authenticated;
revoke update (status, approved_by, approved_at)
  on table public.sponsor_mockups from authenticated;

-- Editors may update descriptive/file metadata only. Status and approval
-- metadata remain writable only through the audited status SECURITY DEFINER RPC.
grant update (title, package_key, description, storage_path, mime_type, file_size, updated_by, updated_at)
  on table public.sponsor_mockups to authenticated;

-- New rows inherit status='draft' from the column default. Do not let clients
-- submit a status or approval metadata during insert.
revoke insert on table public.sponsor_mockups from authenticated;
grant insert (title, package_key, description, storage_path, mime_type, file_size, created_by, updated_by)
  on table public.sponsor_mockups to authenticated;

commit;
