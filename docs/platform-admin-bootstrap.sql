-- Timau Union FC — one-time first Platform Admin bootstrap
-- HUMAN-RUN ONLY in the Supabase SQL Editor, after the access migration has been
-- reviewed and applied. Never run this from the browser or GitHub Pages.
-- Replace the placeholder with the exact email of an existing, email-verified Auth user.
-- This provisions platform-level authority only; it does not approve club membership
-- or assign a club role. Do not put a password, API key, JWT, or database URL here.

do $bootstrap$
declare
  v_email text := lower(btrim('REPLACE_WITH_ADMIN_EMAIL'));
  v_user_id uuid;
  v_display_name text;
  v_reason text := 'Initial Platform Admin bootstrap via Supabase SQL Editor by the authorized project owner; auth.uid() is not available in this context.';
  v_was_active boolean := false;
begin
  if v_email = '' or v_email = 'replace_with_admin_email' or position('@' in v_email) < 2 then
    raise exception 'Replace REPLACE_WITH_ADMIN_EMAIL with the intended verified email before running.';
  end if;

  select u.id,
         coalesce(nullif(btrim(u.raw_user_meta_data ->> 'display_name'), ''),
                  nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
                  'Platform Admin')
    into v_user_id, v_display_name
  from auth.users u
  where lower(u.email) = v_email
    and u.email_confirmed_at is not null;

  if v_user_id is null then
    raise exception 'No email-verified Auth user exists for the supplied email. Create and verify the account first.';
  end if;

  select pa.active into v_was_active
  from private.platform_admins pa
  where pa.user_id = v_user_id
  for update;
  v_was_active := coalesce(v_was_active, false);

  insert into private.user_profiles(user_id, display_name)
  values (v_user_id, left(v_display_name, 120))
  on conflict (user_id) do nothing;

  insert into private.platform_admins(user_id, active, created_by)
  values (v_user_id, true, null)
  on conflict (user_id) do update
    set active = true, disabled_at = null, disabled_by = null;

  if not v_was_active then
    insert into private.audit_events(
      actor_user_id, target_user_id, action_key, old_value, new_value, reason
    )
    values (
      null, v_user_id, 'platform_admin_bootstrap',
      jsonb_build_object('platform_admin', false),
      jsonb_build_object('platform_admin', true),
      v_reason
    );
  end if;
end;
$bootstrap$;
