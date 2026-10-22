-- Fix homepage hero save permission failures caused by the nested
-- private.is_active_platform_admin(auth.uid()) execute privilege.
-- This wrapper checks only the caller; it cannot inspect arbitrary users.
begin;

create or replace function public.homepage_hero_is_current_user_platform_admin()
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select auth.uid() is not null
     and private.is_active_platform_admin(auth.uid())
$function$;
revoke all on function public.homepage_hero_is_current_user_platform_admin() from public, anon;
grant execute on function public.homepage_hero_is_current_user_platform_admin() to authenticated;

create or replace function public.homepage_hero_can_manage()
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select auth.uid() is not null and (
    public.homepage_hero_is_current_user_platform_admin()
    or 'media_team' = any(private.current_club_roles())
  )
$function$;
revoke all on function public.homepage_hero_can_manage() from public, anon;
grant execute on function public.homepage_hero_can_manage() to authenticated;

commit;
