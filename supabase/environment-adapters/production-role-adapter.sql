-- Production adapter only: Phase 1 private-schema identity model.
create or replace function private.current_club_roles()
returns text[] language sql stable security definer set search_path=''
as $function$
 select coalesce(array_agg(distinct ra.role_key),array[]::text[])
 from private.role_assignments ra
 join private.account_access aa on aa.user_id=ra.user_id
 join auth.users u on u.id=ra.user_id
 where ra.user_id=auth.uid() and ra.active and aa.status='approved' and u.email_confirmed_at is not null
$function$;
revoke all on function private.current_club_roles() from public,anon,authenticated;
