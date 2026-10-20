-- Timau Union FC — Phase 2 private club workspace
-- DRAFT ONLY: review and test on Union Test before production application.
-- Public website must read only approved records via get_published_club_content().
begin;

create table private.club_records (
  id uuid primary key default gen_random_uuid(),
  record_type text not null check (record_type in ('player','fixture','news','sponsor','activity')),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  publication_status text not null default 'draft'
    check (publication_status in ('draft','approved','archived')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  constraint club_records_approval_consistency check (
    (publication_status = 'approved' and approved_by is not null and approved_at is not null)
    or publication_status <> 'approved'
  )
);
create index club_records_type_status_updated_idx
  on private.club_records(record_type, publication_status, updated_at desc);
alter table private.club_records enable row level security;
revoke all on private.club_records from public, anon, authenticated;

create table private.club_record_audit (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  record_id uuid,
  record_type text not null,
  action_key text not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table private.club_record_audit enable row level security;
revoke all on private.club_record_audit from public, anon, authenticated;

create function private.current_club_role()
returns text
language sql stable security definer
set search_path = ''
as $function$
  select ra.role_key
  from private.role_assignments ra
  join private.account_access aa on aa.user_id = ra.user_id
  join auth.users u on u.id = ra.user_id
  where ra.user_id = auth.uid()
    and ra.active
    and aa.status = 'approved'
    and u.email_confirmed_at is not null
  limit 1
$function$;
revoke all on function private.current_club_role() from public, anon, authenticated;

create function public.club_get_workspace_bundle()
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $function$
declare v_role text;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  v_role := private.current_club_role();
  if v_role is null then raise exception 'Approved active club role required'; end if;
  return jsonb_build_object(
    'role', v_role,
    'records', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'record_type',r.record_type,'data',r.data,
        'publication_status',r.publication_status,'created_at',r.created_at,
        'updated_at',r.updated_at,'approved_at',r.approved_at
      ) order by r.updated_at desc)
      from private.club_records r
      where
        (v_role in ('chairman','secretary'))
        or (r.record_type = 'player' and v_role in ('team_manager','coach'))
        or (r.record_type = 'fixture' and v_role in ('team_manager','coach'))
        or (r.record_type = 'news' and v_role = 'media_team')
        or (r.record_type = 'sponsor' and v_role = 'sponsor_lead')
        or (r.record_type = 'activity' and v_role in ('team_manager','coach'))
    ), '[]'::jsonb),
    'can_approve', v_role in ('chairman','secretary')
  );
end
$function$;
revoke all on function public.club_get_workspace_bundle() from public, anon;
grant execute on function public.club_get_workspace_bundle() to authenticated;

create function public.club_save_record(
  _record_id uuid,
  _record_type text,
  _data jsonb
) returns uuid
language plpgsql security definer
set search_path = ''
as $function$
declare v_role text; v_id uuid; v_old_status text; v_old_type text;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  if _record_type not in ('player','fixture','news','sponsor','activity')
     or jsonb_typeof(_data) <> 'object' then raise exception 'Invalid record'; end if;
  v_role := private.current_club_role();
  if v_role is null then raise exception 'Approved active club role required'; end if;
  if not (
    v_role in ('chairman','secretary')
    or (_record_type = 'player' and v_role in ('team_manager','coach'))
    or (_record_type = 'fixture' and v_role in ('team_manager','coach'))
    or (_record_type = 'news' and v_role = 'media_team')
    or (_record_type = 'sponsor' and v_role = 'sponsor_lead')
    or (_record_type = 'activity' and v_role in ('team_manager','coach'))
  ) then raise exception 'Your role cannot edit this record type'; end if;

  if _record_id is not null then
    select publication_status, record_type into v_old_status, v_old_type
    from private.club_records where id = _record_id for update;
    if not found then raise exception 'Record not found'; end if;
    if not (
      v_role in ('chairman','secretary')
      or (v_old_type = 'player' and v_role in ('team_manager','coach'))
      or (v_old_type = 'fixture' and v_role in ('team_manager','coach'))
      or (v_old_type = 'news' and v_role = 'media_team')
      or (v_old_type = 'sponsor' and v_role = 'sponsor_lead')
      or (v_old_type = 'activity' and v_role in ('team_manager','coach'))
    ) then raise exception 'Your role cannot edit this record'; end if;
    update private.club_records
       set record_type = _record_type, data = _data,
           publication_status = 'draft', approved_by = null, approved_at = null,
           updated_by = auth.uid(), updated_at = now()
     where id = _record_id;
    v_id := _record_id;
    insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason)
    values(auth.uid(),v_id,_record_type,'record_updated','Saved as draft; approval reset');
  else
    insert into private.club_records(record_type,data,created_by,updated_by)
    values(_record_type,_data,auth.uid(),auth.uid()) returning id into v_id;
    insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key)
    values(auth.uid(),v_id,_record_type,'record_created');
  end if;
  return v_id;
end
$function$;
revoke all on function public.club_save_record(uuid,text,jsonb) from public, anon;
grant execute on function public.club_save_record(uuid,text,jsonb) to authenticated;

create function public.club_set_publication_status(
  _record_id uuid, _new_status text, _reason text
) returns boolean
language plpgsql security definer
set search_path = ''
as $function$
declare v_role text; v_type text;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  v_role := private.current_club_role();
  if v_role not in ('chairman','secretary') then raise exception 'Chairman or Secretary approval required'; end if;
  if _new_status not in ('approved','archived','draft') then raise exception 'Invalid publication status'; end if;
  if length(btrim(coalesce(_reason,''))) < 3 then raise exception 'A reason of at least 3 characters is required'; end if;
  select record_type into v_type from private.club_records where id = _record_id for update;
  if not found then raise exception 'Record not found'; end if;
  update private.club_records set
    publication_status = _new_status,
    approved_by = case when _new_status = 'approved' then auth.uid() else null end,
    approved_at = case when _new_status = 'approved' then now() else null end,
    updated_by = auth.uid(), updated_at = now()
  where id = _record_id;
  insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason)
  values(auth.uid(),_record_id,v_type,'publication_'||_new_status,btrim(_reason));
  return true;
end
$function$;
revoke all on function public.club_set_publication_status(uuid,text,text) from public, anon;
grant execute on function public.club_set_publication_status(uuid,text,text) to authenticated;

create function public.get_published_club_content()
returns jsonb
language sql stable security definer
set search_path = ''
as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,
    'record_type',r.record_type,
    'data',case r.record_type
      when 'player' then jsonb_strip_nulls(jsonb_build_object(
        'name',r.data->'name','position',r.data->'position',
        'bio',r.data->'bio','squad_number',r.data->'squad_number'))
      when 'fixture' then jsonb_strip_nulls(jsonb_build_object(
        'opponent',r.data->'opponent','match_date',r.data->'match_date',
        'venue',r.data->'venue','result',r.data->'result'))
      when 'news' then jsonb_strip_nulls(jsonb_build_object(
        'title',r.data->'title','summary',r.data->'summary',
        'body',r.data->'body','category',r.data->'category'))
      when 'sponsor' then jsonb_strip_nulls(jsonb_build_object(
        'name',r.data->'name','support_type',r.data->'support_type',
        'details',r.data->'details','website',r.data->'website'))
      when 'activity' then jsonb_strip_nulls(jsonb_build_object(
        'title',r.data->'title','date',r.data->'date',
        'location',r.data->'location','details',r.data->'details'))
    end,
    'approved_at',r.approved_at
  ) order by r.approved_at desc), '[]'::jsonb)
  from private.club_records r
  where r.publication_status = 'approved'
    and r.record_type in ('player','fixture','news','sponsor','activity')
$function$;
revoke all on function public.get_published_club_content() from public;
grant execute on function public.get_published_club_content() to anon, authenticated;

commit;
