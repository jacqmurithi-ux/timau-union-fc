-- Candidate only: separate club-record editing eligibility from approval/publication.
-- Review and test in a non-production project before applying. Never run directly in production.
-- For rollback-only validation, execute this file and its paired test in one outer transaction,
-- then issue ROLLBACK from the test harness; this file intentionally has no COMMIT.

create or replace function private.role_can_approve_record(_roles text[], _type text)
returns boolean
language sql
immutable
set search_path to ''
as $function$
  select coalesce(
    'chairman'=any(coalesce(_roles,array[]::text[]))
    or (
      not ('team_manager'=any(coalesce(_roles,array[]::text[])))
      and (
        'secretary'=any(coalesce(_roles,array[]::text[]))
        or (_type='news' and 'media_team'=any(coalesce(_roles,array[]::text[])))
        or (_type='sponsor' and 'sponsor_lead'=any(coalesce(_roles,array[]::text[])))
      )
    )
    -- Preserve the existing Team Manager approval path; Coach is intentionally
    -- not included because Coach's shared-record access is not publication authority.
    or (_type in ('player','fixture','activity')
        and 'team_manager'=any(coalesce(_roles,array[]::text[]))),
    false
  );
$function$;

revoke all on function private.role_can_approve_record(text[],text) from public, anon, authenticated;

create or replace function public.club_set_publication_status(
  _record_id uuid, _new_status text, _reason text
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_is_admin boolean;
  v_roles text[];
  v_type text;
  v_data jsonb;
  v_updated timestamptz;
  match_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  v_is_admin:=private.is_active_platform_admin(auth.uid());
  v_roles:=private.current_club_roles();

  if _new_status not in('approved','archived','draft') then
    raise exception 'Invalid publication status';
  end if;
  if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then
    raise exception 'Reason of 3 to 1000 characters required';
  end if;

  select record_type,data,updated_at
    into v_type,v_data,v_updated
    from private.club_records where id=_record_id for update;
  if not found then raise exception 'Record not found'; end if;

  if not v_is_admin and not private.role_can_approve_record(v_roles,v_type) then
    raise exception 'Your role cannot approve or change publication status for this record type';
  end if;

  if _new_status='approved' and v_type='player' then
    select p.id into match_id
    from private.club_records p
    where p.record_type='player'
      and p.id<>_record_id
      and p.publication_status<>'archived'
      and private.secretary_edit_distance(
        coalesce(v_data->>'name',''),coalesce(p.data->>'name','')
      ) <= greatest(1,ceil(length(coalesce(v_data->>'name',''))*0.22)::int)
      and length(coalesce(p.data->>'name',''))>1
      and not exists(
        select 1 from private.tm_record_audit a
        where a.record_id=_record_id
          and a.action_key='player_duplicate_marked_not_duplicate'
          and a.old_data->>'matched_record_id'=p.id::text
          and a.created_at>=v_updated
      )
    order by p.created_at desc limit 1;

    if match_id is not null then
      raise exception 'Likely duplicate player detected (record %). Review matching records and merge, mark not duplicate with a reason, or cancel before approval.',match_id
        using errcode='23514';
    end if;
  end if;

  update private.club_records
  set publication_status=_new_status,
      approved_by=case when _new_status='approved' then auth.uid() else null end,
      approved_at=case when _new_status='approved' then now() else null end,
      updated_by=auth.uid(),updated_at=now()
  where id=_record_id;

  insert into private.club_record_audit(
    actor_user_id,record_id,record_type,action_key,reason
  ) values(
    auth.uid(),_record_id,v_type,'publication_'||_new_status,btrim(_reason)
  );
  return true;
end
$function$;

-- Record visibility continues to use the existing management predicate.
-- Only the can_approve flag switches to the separate approval predicate.
create or replace function public.club_get_workspace_bundle()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  r text[];
  adm boolean;
  chair boolean;
  tm boolean;
  welfare boolean;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  chair:='chairman'=any(r);
  tm:='team_manager'=any(r);
  welfare:='player_welfare'=any(r);

  if not adm and coalesce(array_length(r,1),0)=0 then
    raise exception 'Approved active club role required';
  end if;

  if not adm and 'sponsor'=any(r) then
    return jsonb_build_object(
      'roles',to_jsonb(r),'is_platform_admin',false,'can_approve',false,
      'records','[]'::jsonb,'tm_records','[]'::jsonb
    );
  end if;

  return jsonb_build_object(
    'roles',to_jsonb(r),
    'is_platform_admin',adm,
    'can_approve',adm or (
      private.role_can_approve_record(r,'player')
      or private.role_can_approve_record(r,'fixture')
      or private.role_can_approve_record(r,'activity')
      or private.role_can_approve_record(r,'news')
      or private.role_can_approve_record(r,'sponsor')
    ),
    'records',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',c.id,'record_type',c.record_type,'data',c.data,
        'publication_status',c.publication_status,'created_at',c.created_at,
        'updated_at',c.updated_at,'approved_at',c.approved_at,
        'can_approve',adm or private.role_can_approve_record(r,c.record_type)
      ))
      from private.club_records c
      where adm or chair or (
        private.role_can_manage_record(r,c.record_type)
        and private.can_manage_club_record(r,false,c.created_by)
      )
    ),'[]'::jsonb),
    'tm_records',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',t.id,'record_type','tm_'||t.section_key,
        'section_key',t.section_key,'data',t.data,
        'publication_status',t.publication_status,'created_at',t.created_at,
        'updated_at',t.updated_at,'approved_at',t.approved_at,
        'can_approve',adm or chair or tm
      ))
      from private.tm_records t
      where adm or chair or tm
        or (welfare and t.section_key='discipline_welfare')
        or ('treasurer'=any(r)
          and t.section_key='transport_logistics'
          and lower(coalesce(t.data->>'treasurer_submission','')) like 'submitted%')
    ),'[]'::jsonb)
  );
end
$function$;

-- Keep existing RPC grants unchanged; only authorization checks and UI affordance
-- metadata are separated.
