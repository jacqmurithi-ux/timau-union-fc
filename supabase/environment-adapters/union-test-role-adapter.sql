-- Union Test adapter only: membership-linked identity model.
create or replace function private.current_club_roles()
returns text[] language sql stable security definer set search_path=''
as $function$
 select coalesce(array_agg(distinct ra.role_key),array[]::text[])
 from public.role_assignments ra
 join public.club_memberships cm on cm.id=ra.membership_id
 join auth.users u on u.id=cm.user_id
 where cm.user_id=auth.uid() and cm.status='active' and ra.revoked_at is null and u.email_confirmed_at is not null
$function$;
revoke all on function private.current_club_roles() from public,anon,authenticated;
