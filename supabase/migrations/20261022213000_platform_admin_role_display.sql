-- Show the actual Platform Admin access in the account queue and self-status.
-- Platform Admin is a platform permission, not a club officer assignment; do not
-- insert a fake role_assignments row just to make the UI display it.
begin;

create or replace function public.admin_list_access_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null or not private.is_active_platform_admin(v_uid) then
    raise exception 'Active Platform Admin required' using errcode = '42501';
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id', u.id,
    'email', u.email,
    'email_verified', u.email_confirmed_at is not null,
    'display_name', p.display_name,
    'status', aa.status,
    'requested_at', aa.requested_at,
    'decided_at', aa.decided_at,
    'decided_by', aa.decided_by,
    'role', case
      when pa.active and u.email_confirmed_at is not null and aa.status='approved' then 'platform_admin'
      else ra.role_key
    end
  ) order by case aa.status when 'pending' then 0 else 1 end, aa.requested_at desc), '[]'::jsonb)
  into v_result
  from private.account_access aa
  join auth.users u on u.id = aa.user_id
  left join private.user_profiles p on p.user_id = u.id
  left join private.role_assignments ra on ra.user_id = u.id and ra.active
  left join private.platform_admins pa on pa.user_id = u.id;

  return v_result;
end;
$function$;
revoke all on function public.admin_list_access_requests() from public, anon;
grant execute on function public.admin_list_access_requests() to authenticated;

create or replace function public.get_my_access_status()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_email_verified boolean;
  v_role text;
  v_is_admin boolean;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select u.email_confirmed_at is not null, aa.status, ra.role_key,
         (private.is_active_platform_admin(v_uid) and u.email_confirmed_at is not null)
    into v_email_verified, v_status, v_role, v_is_admin
  from auth.users u
  left join private.account_access aa on aa.user_id = u.id
  left join private.role_assignments ra on ra.user_id = u.id and ra.active
  where u.id = v_uid;

  if not found then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;

  return pg_catalog.jsonb_build_object(
    'email_verified', coalesce(v_email_verified, false),
    'status', case when coalesce(v_is_admin, false) then 'platform_admin' else coalesce(v_status, 'pending') end,
    'platform_admin', coalesce(v_is_admin, false),
    'role', case
      when coalesce(v_is_admin, false) then 'platform_admin'
      when v_status = 'approved' and v_email_verified then v_role
      else null
    end,
    'access_granted', coalesce(v_is_admin, false) or coalesce(v_status = 'approved' and v_email_verified and v_role is not null, false)
  );
end;
$function$;
revoke all on function public.get_my_access_status() from public, anon;
grant execute on function public.get_my_access_status() to authenticated;

commit;
