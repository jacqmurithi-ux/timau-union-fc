-- Allow the sponsor-safe view to evaluate the caller-scoped sponsor identity helper.
-- The function returns only the sponsor record linked to auth.uid() for an approved account.
grant execute on function private.current_sponsor_record_id() to authenticated;
