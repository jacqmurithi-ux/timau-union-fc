-- Sponsor Lead management data for account linking and approval of sponsor profile drafts.
begin;
create or replace function public.sponsor_lead_get_link_options()
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead, Chairman or admin required' using errcode='42501';
 end if;
 return jsonb_build_object(
  'sponsor_users',coalesce((select jsonb_agg(jsonb_build_object('user_id',u.id,'email',u.email,'linked_sponsor_id',l.sponsor_record_id,'link_id',l.id)
    order by u.email)
    from auth.users u join private.role_assignments r on r.user_id=u.id and r.active and r.role_key='sponsor'
    join private.account_access aa on aa.user_id=u.id and aa.status='approved'
    left join private.sponsor_user_links l on l.user_id=u.id and l.active
    where u.email_confirmed_at is not null),'[]'::jsonb),
  'sponsors',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.data->>'name','details',c.data->>'details')
    order by c.data->>'name') from private.club_records c
    where c.record_type='sponsor' and c.publication_status='approved'),'[]'::jsonb),
  'profile_edits',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'sponsor_record_id',e.sponsor_record_id,
    'sponsor_name',c.data->>'name','requested_by',e.requested_by,'company_name',e.company_name,
    'contact_person',e.contact_person,'contact_email',e.contact_email,'contact_phone',e.contact_phone,
    'logo_url',e.logo_url,'public_description',e.public_description,'status',e.status,'created_at',e.created_at)
    order by e.created_at desc) from private.sponsor_profile_edits e
    join private.club_records c on c.id=e.sponsor_record_id where e.status in ('draft','submitted')),'[]'::jsonb)
 );
end $$;
revoke all on function public.sponsor_lead_get_link_options() from public, anon;
grant execute on function public.sponsor_lead_get_link_options() to authenticated;
create or replace function public.sponsor_lead_get_portal_notifications()
returns jsonb language plpgsql security definer set search_path=''
as $
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead or admin required' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'title',n.title,'body',n.body,'request_id',n.request_id,'created_at',n.created_at)
   order by n.created_at desc) from private.sponsor_portal_notifications n where n.recipient_user_id=auth.uid() and n.read_at is null),'[]'::jsonb);
end $;
revoke all on function public.sponsor_lead_get_portal_notifications() from public, anon;
grant execute on function public.sponsor_lead_get_portal_notifications() to authenticated;
commit;