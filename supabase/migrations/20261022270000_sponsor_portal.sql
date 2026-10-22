-- Sponsor portal: dedicated account-to-sponsor links, scoped reads, draft profile edits and audit trail.
begin;

create table if not exists private.sponsor_user_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sponsor_record_id uuid not null references private.club_records(id) on delete restrict,
  active boolean not null default true,
  linked_by uuid not null references auth.users(id),
  linked_at timestamptz not null default now(),
  unlinked_by uuid references auth.users(id),
  unlinked_at timestamptz,
  reason text not null check(length(btrim(reason)) between 3 and 1000),
  constraint sponsor_user_links_unlink_consistency check ((active and unlinked_at is null and unlinked_by is null) or (not active and unlinked_at is not null and unlinked_by is not null))
);
create unique index if not exists sponsor_user_links_one_active_user on private.sponsor_user_links(user_id) where active;
create index if not exists sponsor_user_links_record_active on private.sponsor_user_links(sponsor_record_id) where active;
alter table private.sponsor_user_links enable row level security;
revoke all on private.sponsor_user_links from public, anon, authenticated;

create table if not exists private.sponsor_profile_edits (
  id uuid primary key default gen_random_uuid(),
  sponsor_record_id uuid not null references private.club_records(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade,
  company_name text not null check(length(btrim(company_name)) between 2 and 240),
  contact_person text,
  contact_email text,
  contact_phone text,
  logo_url text,
  public_description text not null default '',
  status text not null default 'draft' check(status in ('draft','submitted','approved','declined')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table private.sponsor_profile_edits enable row level security;
revoke all on private.sponsor_profile_edits from public, anon, authenticated;

create table if not exists private.sponsor_portal_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  sponsor_record_id uuid references private.club_records(id) on delete cascade,
  request_id uuid,
  notification_type text not null,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
alter table private.sponsor_portal_notifications enable row level security;
revoke all on private.sponsor_portal_notifications from public, anon, authenticated;

alter table private.sponsor_role_requests add column if not exists sponsor_record_id uuid references private.club_records(id) on delete set null;
alter table private.sponsor_role_requests add column if not exists requested_by uuid references auth.users(id) on delete set null;
alter table private.sponsor_role_requests add column if not exists request_category text;
alter table private.sponsor_role_requests drop constraint if exists sponsor_role_requests_target_role_check;
alter table private.sponsor_role_requests add constraint sponsor_role_requests_target_role_check
  check(target_role in ('media_team','secretary','sponsor_lead'));
alter table private.sponsor_role_requests drop constraint if exists sponsor_role_requests_request_type_check;
alter table private.sponsor_role_requests add constraint sponsor_role_requests_request_type_check
  check(request_type in ('sponsor_post_or_graphic','letter_or_document','change','report','logo_update','meeting','other'));

create table if not exists private.sponsor_media_shares (
  media_table text not null check(media_table in ('social_posts','fan_gallery')),
  media_record_id uuid not null,
  sponsor_record_id uuid not null references private.club_records(id) on delete cascade,
  shared_by uuid not null references auth.users(id),
  shared_at timestamptz not null default now(),
  primary key(media_table,media_record_id,sponsor_record_id)
);
alter table private.sponsor_media_shares enable row level security;
revoke all on private.sponsor_media_shares from public, anon, authenticated;

create or replace function private.current_sponsor_record_id()
returns uuid language sql stable security definer set search_path=''
as $$
  select l.sponsor_record_id
  from private.sponsor_user_links l
  join private.club_records c on c.id=l.sponsor_record_id
  join private.account_access aa on aa.user_id=l.user_id and aa.status='approved'
  join auth.users u on u.id=l.user_id and u.email_confirmed_at is not null
  where l.user_id=auth.uid() and l.active
    and c.record_type='sponsor' and c.publication_status='approved'
  limit 1
$$;
revoke all on function private.current_sponsor_record_id() from public, anon, authenticated;

-- Ensure sponsor-only accounts cannot obtain player/team-management records through the generic workspace RPC.
create or replace function public.club_get_workspace_bundle()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare r text[]; adm boolean; chair boolean; tm boolean; welfare boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 chair:='chairman'=any(r); tm:='team_manager'=any(r); welfare:='player_welfare'=any(r);
 if not adm and coalesce(array_length(r,1),0)=0 then raise exception 'Approved active club role required'; end if;
 if not adm and 'sponsor'=any(r) then
   return jsonb_build_object('roles',to_jsonb(r),'is_platform_admin',false,'can_approve',false,'records','[]'::jsonb,'tm_records','[]'::jsonb);
 end if;
 return jsonb_build_object('roles',to_jsonb(r),'is_platform_admin',adm,'can_approve',adm or coalesce(array_length(r,1),0)>0,
 'records',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'record_type',c.record_type,'data',c.data,'publication_status',c.publication_status,'created_at',c.created_at,'updated_at',c.updated_at,'approved_at',c.approved_at,'can_approve',adm or private.role_can_manage_record(r,c.record_type))) from private.club_records c where adm or chair or (private.role_can_manage_record(r,c.record_type) and private.can_manage_club_record(r,false,c.created_by))),'[]'::jsonb),
 'tm_records',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'record_type','tm_'||t.section_key,'section_key',t.section_key,'data',t.data,'publication_status',t.publication_status,'created_at',t.created_at,'updated_at',t.updated_at,'approved_at',t.approved_at,'can_approve',adm or chair or tm)) from private.tm_records t where adm or chair or tm or (welfare and t.section_key='discipline_welfare') or ('treasurer'=any(r) and t.section_key='transport_logistics' and lower(coalesce(t.data->>'treasurer_submission','')) like 'submitted%')),'[]'::jsonb));
end $function$;
revoke all on function public.club_get_workspace_bundle() from public, anon;
grant execute on function public.club_get_workspace_bundle() to authenticated;

create or replace function public.sponsor_lead_get_links()
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead or Platform Admin required' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',l.id,'user_id',l.user_id,'sponsor_record_id',l.sponsor_record_id,'active',l.active,
   'linked_at',l.linked_at,'linked_by',l.linked_by,'unlinked_at',l.unlinked_at,'reason',l.reason,
   'email',u.email,'sponsor_name',c.data->>'name'
 ) order by l.active desc,l.linked_at desc)
 from private.sponsor_user_links l
 join auth.users u on u.id=l.user_id
 join private.club_records c on c.id=l.sponsor_record_id), '[]'::jsonb);
end $$;
revoke all on function public.sponsor_lead_get_links() from public, anon;
grant execute on function public.sponsor_lead_get_links() to authenticated;

create or replace function public.sponsor_lead_set_user_link(_user_id uuid,_sponsor_record_id uuid,_link boolean,_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_roles text[]; v_link_id uuid; v_old jsonb; v_new jsonb;
begin
 if v_actor is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead or Platform Admin required' using errcode='42501';
 end if;
 if _user_id is null or _user_id=v_actor then raise exception 'Choose a different sponsor account' using errcode='22023'; end if;
 if length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000 then raise exception 'A reason of 3 to 1000 characters is required' using errcode='22023'; end if;
 select coalesce(array_agg(role_key),array[]::text[]) into v_roles from private.role_assignments where user_id=_user_id and active;
 if not ('sponsor'=any(v_roles)) then raise exception 'Target account must have the Sponsor role' using errcode='22023'; end if;
 if not exists(select 1 from private.account_access aa join auth.users u on u.id=aa.user_id
   where aa.user_id=_user_id and aa.status='approved' and u.email_confirmed_at is not null) then
   raise exception 'Target account must be email-verified and approved' using errcode='22023';
 end if;
 select to_jsonb(l) into v_old from private.sponsor_user_links l where l.user_id=_user_id and l.active for update;
 if not _link then
   if v_old is null then raise exception 'No active sponsor link exists for this user'; end if;
   update private.sponsor_user_links set active=false,unlinked_by=v_actor,unlinked_at=now(),reason=btrim(_reason)
    where user_id=_user_id and active returning id into v_link_id;
   v_new:=jsonb_build_object('active',false,'sponsor_record_id',v_old->>'sponsor_record_id');
 else
   if _sponsor_record_id is null then raise exception 'Choose a sponsor record'; end if;
   if not exists(select 1 from private.club_records c where c.id=_sponsor_record_id and c.record_type='sponsor' and c.publication_status='approved') then
     raise exception 'Sponsor record must be approved before linking'; end if;
   if v_old is not null then
     update private.sponsor_user_links set active=false,unlinked_by=v_actor,unlinked_at=now(),reason=btrim(_reason)
     where user_id=_user_id and active;
   end if;
   insert into private.sponsor_user_links(user_id,sponsor_record_id,active,linked_by,reason)
   values(_user_id,_sponsor_record_id,true,v_actor,btrim(_reason)) returning id into v_link_id;
   v_new:=jsonb_build_object('active',true,'sponsor_record_id',_sponsor_record_id);
 end if;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(v_actor,'sponsor_user_links',v_link_id,case when _link then 'sponsor_user_linked_or_changed' else 'sponsor_user_unlinked' end,v_old,v_new,btrim(_reason));
 return jsonb_build_object('ok',true,'link_id',v_link_id,'active',_link,'sponsor_record_id',case when _link then _sponsor_record_id else null end);
end $$;
revoke all on function public.sponsor_lead_set_user_link(uuid,uuid,boolean,text) from public, anon;
grant execute on function public.sponsor_lead_set_user_link(uuid,uuid,boolean,text) to authenticated;

create or replace function public.sponsor_portal_get()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_record uuid; v_sponsor jsonb; v_agreements jsonb; v_contributions jsonb; v_benefits jsonb; v_edits jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not ('sponsor'=any(private.current_club_roles())) then raise exception 'Sponsor role required' using errcode='42501'; end if;
 v_record:=private.current_sponsor_record_id();
 if v_record is null then
   return jsonb_build_object('linked',false,'message','Your account is not yet linked to a sponsor record. Please contact the club’s Sponsor Lead.');
 end if;
 select jsonb_build_object('id',c.id,'name',c.data->>'name','tier',c.data->>'tier','benefits',c.data->>'benefits',
   'support_type',c.data->>'support_type','description',c.data->>'details','website',c.data->>'website',
   'logo_url',c.data->>'logo_url','status',c.publication_status)
 into v_sponsor from private.club_records c where c.id=v_record;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'package',p.name,'tier',p.tier,'benefits',p.benefits,
   'start_date',a.start_date,'end_date',a.end_date,'status',a.status,'amount_kes',a.amount_kes,
   'payment_schedule',a.payment_schedule,'signed_document_path',a.signed_document_path,'in_kind_value',a.in_kind_value)
   order by a.start_date desc),'[]'::jsonb)
 into v_agreements from private.sponsor_agreements a left join private.sponsor_packages p on p.id=a.package_id
 where a.sponsor_record_id=v_record and a.status in ('active','expired','renewal_pending','closed');
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'agreement_id',c.agreement_id,'kind',c.contribution_kind,
   'pledged',c.pledged_amount_kes,'in_kind_description',c.in_kind_description,'pledged_on',c.pledged_on,
   'receipt_status',c.receipt_status,'received',c.received_amount_kes,'confirmed_at',c.treasurer_confirmed_at)
   order by c.pledged_on desc),'[]'::jsonb)
 into v_contributions from private.sponsor_contributions c join private.sponsor_agreements a on a.id=c.agreement_id
 where a.sponsor_record_id=v_record;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'agreement_id',b.agreement_id,'benefit_key',b.benefit_key,
   'description',b.description,'done',b.is_done,'proof_url',b.proof_url,'completed_at',b.completed_at)
   order by b.created_at),'[]'::jsonb)
 into v_benefits from private.sponsor_benefit_delivery b join private.sponsor_agreements a on a.id=b.agreement_id
 where a.sponsor_record_id=v_record;
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'company_name',e.company_name,'contact_person',e.contact_person,
   'contact_email',e.contact_email,'contact_phone',e.contact_phone,'logo_url',e.logo_url,
   'public_description',e.public_description,'status',e.status,'review_note',e.review_note)
   order by e.created_at desc),'[]'::jsonb)
 into v_edits from private.sponsor_profile_edits e where e.sponsor_record_id=v_record and e.requested_by=auth.uid();
 return jsonb_build_object('linked',true,'sponsor_id',v_record,'sponsor',v_sponsor,
   'agreements',v_agreements,'contributions',v_contributions,'benefits',v_benefits,'profile_edits',v_edits,
   'updates',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'type',c.record_type,'data',c.data,'approved_at',c.approved_at)
    order by c.approved_at desc) from private.club_records c where c.record_type in ('fixture','news') and c.publication_status='approved'),'[]'::jsonb),
   'media_posts',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'copy_text',p.copy_text,'channel',p.channel,'planned_for',p.planned_for,'posted_at',p.posted_at,'post_url',p.post_url)
    order by coalesce(p.posted_at,p.planned_for) desc) from public.social_posts p where p.status in ('approved','posted') and exists(select 1 from private.sponsor_media_shares sh where sh.media_table='social_posts' and sh.media_record_id=p.id and sh.sponsor_record_id=v_record)),'[]'::jsonb),
   'media_photos',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'caption',g.caption,'image_path',g.image_path,'photo_date',g.photo_date,'alt_text',g.alt_text)
    order by g.photo_date desc) from public.fan_gallery g where g.status='approved' and exists(select 1 from private.sponsor_media_shares sh where sh.media_table='fan_gallery' and sh.media_record_id=g.id and sh.sponsor_record_id=v_record)),'[]'::jsonb),
   'requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'title',q.title,'request_type',q.request_type,'details',q.details,'status',q.status,'created_at',q.created_at)
    order by q.created_at desc) from private.sponsor_role_requests q where q.requested_by=auth.uid() and q.sponsor_record_id=v_record),'[]'::jsonb));
end $$;
revoke all on function public.sponsor_portal_get() from public, anon;
grant execute on function public.sponsor_portal_get() to authenticated;

create or replace function private.sponsor_workspace_guard()
returns trigger language plpgsql security definer set search_path=''
as $$
declare admin boolean; r text[]; before_j jsonb; after_j jsonb; record_key uuid; table_key text; sponsor_request_allowed boolean:=false;
begin
 admin:=private.is_active_platform_admin(auth.uid());
 r:=private.current_club_roles();
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if tg_table_name='sponsor_contributions' then
   if tg_op='UPDATE' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r) or 'treasurer'=any(r)) then
     raise exception 'Not authorized to update sponsor contribution';
   end if;
   if tg_op='INSERT' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then raise exception 'Sponsor Lead or admin required'; end if;
   if tg_op='UPDATE' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r) or 'treasurer'=any(r)) then raise exception 'Not authorized'; end if;
   if tg_op='UPDATE' and (new.receipt_status is distinct from old.receipt_status or new.received_amount_kes is distinct from old.received_amount_kes or new.treasurer_confirmed_by is distinct from old.treasurer_confirmed_by or new.treasurer_confirmed_at is distinct from old.treasurer_confirmed_at) and not (admin or 'treasurer'=any(r)) then raise exception 'Only Treasurer or admin can confirm received money'; end if;
 end if;
 if tg_table_name='sponsor_role_requests' and tg_op='INSERT' and 'sponsor'=any(r) then
   sponsor_request_allowed:=new.requested_by=auth.uid() and new.sponsor_record_id=private.current_sponsor_record_id() and new.target_role='sponsor_lead' and new.status='submitted';
 end if;
 if tg_table_name<>'sponsor_contributions' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) and not sponsor_request_allowed then
   if tg_table_name='sponsor_role_requests' and tg_op='UPDATE' and ((new.status is distinct from old.status) and (('media_team'=any(r) and old.target_role='media_team') or ('secretary'=any(r) and old.target_role='secretary'))) then
     null;
   else raise exception 'Sponsor Lead or Platform Admin required'; end if;
 end if;
 if tg_op='INSERT' then before_j:=null; after_j:=to_jsonb(new); record_key:=new.id;
 elsif tg_op='UPDATE' then before_j:=to_jsonb(old); after_j:=to_jsonb(new); record_key:=new.id;
 else before_j:=to_jsonb(old); after_j:=null; record_key:=old.id; end if;
 table_key:=tg_table_name;
 if admin and tg_op='UPDATE' and before_j is distinct from after_j then
  insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
  values(auth.uid(),table_key,record_key,'admin_override',before_j,after_j,'Administrative override');
 end if;
 if tg_op='DELETE' then return old; end if;
 new.updated_by:=auth.uid(); new.updated_at:=now(); return new;
end $$;
revoke all on function private.sponsor_workspace_guard() from public,anon,authenticated;

create or replace function public.sponsor_portal_submit_request(_type text,_title text,_details text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_record uuid; v_id uuid; v_user uuid:=auth.uid();
begin
 if v_user is null or not ('sponsor'=any(private.current_club_roles())) then raise exception 'Sponsor role required' using errcode='42501'; end if;
 v_record:=private.current_sponsor_record_id();
 if v_record is null then raise exception 'Sponsor account is not linked' using errcode='42501'; end if;
 if _type not in ('change','report','logo_update','meeting','other') then raise exception 'Invalid request type'; end if;
 if length(btrim(coalesce(_title,'')))<3 or length(_title)>200 or length(coalesce(_details,''))>4000 then raise exception 'Enter a title and keep details under 4000 characters'; end if;
 insert into private.sponsor_role_requests(sponsor_name,sponsor_record_id,requested_by,target_role,request_type,request_category,title,details,status,created_by,updated_by)
 select c.data->>'name',v_record,v_user,'sponsor_lead',_type,_type,btrim(_title),coalesce(_details,''),'submitted',v_user,v_user
 from private.club_records c where c.id=v_record returning id into v_id;
 insert into private.sponsor_portal_notifications(recipient_user_id,sponsor_record_id,request_id,notification_type,title,body)
 select u.id,v_record,v_id,'sponsor_request','New sponsor request: '||btrim(_title),
   'A linked sponsor submitted a '||_type||' request.'
 from auth.users u
 where exists(select 1 from private.role_assignments r where r.user_id=u.id and r.active and r.role_key='sponsor_lead')
 or private.is_active_platform_admin(u.id);
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data)
 values(v_user,'sponsor_role_requests',v_id,'sponsor_submitted_request',jsonb_build_object('sponsor_record_id',v_record,'request_type',_type,'title',_title));
 return v_id;
end $$;
revoke all on function public.sponsor_portal_submit_request(text,text,text) from public, anon;
grant execute on function public.sponsor_portal_submit_request(text,text,text) to authenticated;

create or replace function public.sponsor_portal_save_details(_company_name text,_contact_person text,_contact_email text,_contact_phone text,_logo_url text,_public_description text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_record uuid; v_id uuid; v_user uuid:=auth.uid();
begin
 if v_user is null or not ('sponsor'=any(private.current_club_roles())) then raise exception 'Sponsor role required' using errcode='42501'; end if;
 v_record:=private.current_sponsor_record_id();
 if v_record is null then raise exception 'Sponsor account is not linked' using errcode='42501'; end if;
 if length(btrim(coalesce(_company_name,'')))<2 or length(_company_name)>240 or length(coalesce(_public_description,''))>3000 then raise exception 'Company name and valid description are required'; end if;
 if _contact_email is not null and _contact_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid contact email'; end if;
 if _logo_url is not null and (length(_logo_url)>2000 or _logo_url !~* '^https?://') then raise exception 'Logo URL must be an HTTP or HTTPS URL under 2000 characters'; end if;
 insert into private.sponsor_profile_edits(sponsor_record_id,requested_by,company_name,contact_person,contact_email,contact_phone,logo_url,public_description,status)
 values(v_record,v_user,btrim(_company_name),nullif(btrim(_contact_person),''),nullif(btrim(_contact_email),''),nullif(btrim(_contact_phone),''),nullif(btrim(_logo_url),''),coalesce(_public_description,''),'draft')
 returning id into v_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data)
 values(v_user,'sponsor_profile_edits',v_id,'sponsor_details_saved_as_draft',jsonb_build_object('sponsor_record_id',v_record,'company_name',_company_name,'status','draft'));
 return v_id;
end $$;
revoke all on function public.sponsor_portal_save_details(text,text,text,text,text,text) from public, anon;
grant execute on function public.sponsor_portal_save_details(text,text,text,text,text,text) to authenticated;

create or replace function public.sponsor_lead_review_profile_edit(_edit_id uuid,_decision text,_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_edit private.sponsor_profile_edits%rowtype; v_admin boolean; v_record private.club_records%rowtype; v_old jsonb;
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then raise exception 'Sponsor Lead or Platform Admin required' using errcode='42501'; end if;
 if _decision not in ('approved','declined') then raise exception 'Invalid decision'; end if;
 if length(btrim(coalesce(_reason,'')))<3 then raise exception 'Review reason required'; end if;
 select * into v_edit from private.sponsor_profile_edits where id=_edit_id for update;
 if not found then raise exception 'Profile draft not found'; end if;
 select * into v_record from private.club_records where id=v_edit.sponsor_record_id for update;
 v_old:=to_jsonb(v_record);
 if _decision='approved' then
   update private.club_records set data=data || jsonb_build_object('name',v_edit.company_name,'contact_person',v_edit.contact_person,'contact_email',v_edit.contact_email,'contact_phone',v_edit.contact_phone,'logo_url',v_edit.logo_url,'details',v_edit.public_description),updated_by=auth.uid(),updated_at=now(),publication_status='approved',approved_by=auth.uid(),approved_at=now()
   where id=v_edit.sponsor_record_id;
 end if;
 update private.sponsor_profile_edits set status=_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_note=btrim(_reason),updated_at=now() where id=_edit_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_profile_edits',_edit_id,'profile_edit_'||_decision,v_old,
   jsonb_build_object('edit_id',_edit_id,'decision',_decision,'sponsor_record_id',v_edit.sponsor_record_id),btrim(_reason));
 return jsonb_build_object('ok',true,'status',_decision);
end $$;
revoke all on function public.sponsor_lead_review_profile_edit(uuid,text,text) from public, anon;
grant execute on function public.sponsor_lead_review_profile_edit(uuid,text,text) to authenticated;

create or replace function public.media_set_sponsor_shares(_table text,_record_id uuid,_sponsor_record_ids uuid[],_reason text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; v_old jsonb; v_new jsonb; v_ids uuid[]:=coalesce(_sponsor_record_ids,'{}'::uuid[]);
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r) or 'media_team'=any(r)) then raise exception 'Media Team, Chairman or admin required' using errcode='42501'; end if;
 if admin and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Admin override reason required'; end if;
 if _table='social_posts' then
   select to_jsonb(p) into v_old from public.social_posts p where p.id=_record_id for update;
   if v_old is null then raise exception 'Social post not found'; end if;
   if not admin and not ('chairman'=any(r) or (v_old->>'created_by')::uuid=auth.uid()) then raise exception 'Only the author, Media Team lead or admin may change sharing'; end if;
   if exists(select 1 from unnest(v_ids) x where not exists(select 1 from private.club_records c where c.id=x and c.record_type='sponsor' and c.publication_status='approved')) then raise exception 'Every shared sponsor must be an approved sponsor record'; end if;
   delete from private.sponsor_media_shares where media_table='social_posts' and media_record_id=_record_id;
   insert into private.sponsor_media_shares(media_table,media_record_id,sponsor_record_id,shared_by) select 'social_posts',_record_id,x,auth.uid() from unnest(v_ids) x;
   v_new:=jsonb_build_object('share_with_sponsor_ids',v_ids);
 elsif _table='fan_gallery' then
   select to_jsonb(p) into v_old from public.fan_gallery p where p.id=_record_id for update;
   if v_old is null then raise exception 'Gallery photo not found'; end if;
   if not admin and not ('chairman'=any(r) or (v_old->>'created_by')::uuid=auth.uid()) then raise exception 'Only the author, Media Team lead or admin may change sharing'; end if;
   if exists(select 1 from unnest(v_ids) x where not exists(select 1 from private.club_records c where c.id=x and c.record_type='sponsor' and c.publication_status='approved')) then raise exception 'Every shared sponsor must be an approved sponsor record'; end if;
   delete from private.sponsor_media_shares where media_table='fan_gallery' and media_record_id=_record_id;
   insert into private.sponsor_media_shares(media_table,media_record_id,sponsor_record_id,shared_by) select 'fan_gallery',_record_id,x,auth.uid() from unnest(v_ids) x;
   v_new:=jsonb_build_object('share_with_sponsor_ids',v_ids);
 else raise exception 'Unsupported media record type'; end if;
 insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
 values(auth.uid(),_record_id,_table,'sponsor_share_changed',nullif(btrim(_reason),''),admin,v_old,v_new);
 return jsonb_build_object('ok',true,'share_with_sponsor_ids',to_jsonb(v_ids));
end $$;
revoke all on function public.media_set_sponsor_shares(text,uuid,uuid[],text) from public, anon;
grant execute on function public.media_set_sponsor_shares(text,uuid,uuid[],text) to authenticated;

commit;
