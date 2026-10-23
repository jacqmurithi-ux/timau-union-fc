create table if not exists private.monthly_sponsor_reports (
  month_start date primary key check (extract(day from month_start) = 1),
  report_data jsonb not null default '{}'::jsonb,
  highlights text[] not null default array[]::text[],
  status text not null default 'draft' check (status in ('draft','approved','published')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  published_by uuid references auth.users(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(report_data) = 'object'),
  check (cardinality(highlights) <= 3)
);

alter table private.monthly_sponsor_reports enable row level security;
revoke all on private.monthly_sponsor_reports from anon, authenticated;

create table if not exists private.monthly_sponsor_report_audit (
  id bigint generated always as identity primary key,
  month_start date not null references private.monthly_sponsor_reports(month_start) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action_key text not null check (action_key in ('draft_saved','approved','published')),
  old_status text check (old_status is null or old_status in ('draft','approved','published')),
  new_status text not null check (new_status in ('draft','approved','published')),
  old_report_data jsonb,
  new_report_data jsonb not null,
  created_at timestamptz not null default now(),
  check (old_report_data is null or jsonb_typeof(old_report_data) = 'object'),
  check (jsonb_typeof(new_report_data) = 'object')
);

alter table private.monthly_sponsor_report_audit enable row level security;
revoke all on private.monthly_sponsor_report_audit from anon, authenticated;

create or replace function public.monthly_sponsor_report_get(_month date)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_report private.monthly_sponsor_reports%rowtype;
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_admin boolean := coalesce(private.is_active_platform_admin(auth.uid()), false);
  v_sponsor_id uuid;
  v_sponsor_link_count integer;
  v_sponsor boolean;
  v_data jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if _month is null or extract(day from _month) <> 1 then raise exception 'Month must be the first day of a month'; end if;
  select count(distinct sul.sponsor_record_id), (array_agg(distinct sul.sponsor_record_id))[1]
    into v_sponsor_link_count, v_sponsor_id
    from private.sponsor_user_links sul
    where sul.user_id = auth.uid() and sul.active and sul.unlinked_at is null;
  if v_sponsor_link_count > 1 then
    raise exception 'More than one active sponsor link is assigned to this account';
  end if;
  v_sponsor := v_sponsor_id is not null and 'sponsor' = any(v_roles) and not v_admin
    and not (v_roles && array['admin','chairman','treasurer','secretary','media_team','sponsor_lead','team_manager','coach']::text[]);
  if not v_sponsor and not (v_admin or v_roles && array['admin','chairman','treasurer','secretary','media_team']::text[]) then
    raise exception 'Not authorized to view monthly sponsor reports';
  end if;

  select * into v_report from private.monthly_sponsor_reports where month_start = _month;
  if not found then
    if v_sponsor then
      return jsonb_build_object('month_start',_month,'status','unpublished','report',jsonb_build_object(
        'summary',jsonb_build_object(),
        'social',jsonb_build_object(),
        'results',jsonb_build_object(),
        'highlights',jsonb_build_array(),
        'sponsor_posts',jsonb_build_array()
      ));
    end if;
    return jsonb_build_object('month_start',_month,'status','draft','report',jsonb_build_object(),'highlights',jsonb_build_array());
  end if;
  if v_sponsor and v_report.status <> 'published' then
    return jsonb_build_object('month_start',_month,'status','unpublished','report',jsonb_build_object(
      'summary',jsonb_build_object(),'social',jsonb_build_object(),'results',jsonb_build_object(),
      'highlights',jsonb_build_array(),'sponsor_posts',jsonb_build_array()
    ));
  end if;

  if v_sponsor then
    v_data := jsonb_build_object(
      'summary', jsonb_build_object(
        'matches', coalesce(v_report.report_data#>'{summary,matches}','0'::jsonb),
        'attendance_total', coalesce(v_report.report_data#>'{summary,attendance_total}','0'::jsonb),
        'attendance_average', coalesce(v_report.report_data#>'{summary,attendance_average}','0'::jsonb),
        'attendance_highest', coalesce(v_report.report_data#>'{summary,attendance_highest}','0'::jsonb),
        'attendance_lowest', coalesce(v_report.report_data#>'{summary,attendance_lowest}','0'::jsonb)
      ),
      'social', jsonb_build_object(
        'posts', coalesce(v_report.report_data#>'{social,posts}','0'::jsonb),
        'sponsor_tagged_posts', coalesce(v_report.report_data#>'{social,sponsor_tagged_posts}','0'::jsonb),
        'views', coalesce(v_report.report_data#>'{social,views}','0'::jsonb),
        'likes', coalesce(v_report.report_data#>'{social,likes}','0'::jsonb),
        'engagement_rate', coalesce(v_report.report_data#>'{social,engagement_rate}','0'::jsonb),
        'followers_gained', coalesce(v_report.report_data#>'{social,followers_gained}','0'::jsonb)
      ),
      'results', jsonb_build_object(
        'matches_played', coalesce(v_report.report_data#>'{results,matches_played}','0'::jsonb),
        'league_position', coalesce(v_report.report_data#>'{results,league_position}','null'::jsonb),
        'results', coalesce((select jsonb_agg(jsonb_build_object(
          'date',x->'date','opponent',x->'opponent','result',x->'result'
        )) from jsonb_array_elements(coalesce(v_report.report_data#>'{results,results}','[]'::jsonb)) x),'[]'::jsonb)
      ),
      'highlights', to_jsonb(v_report.highlights),
      'sponsor_posts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'sponsor_id',x->'sponsor_id','title',x->'title','platform',x->'platform',
          'views',x->'views','likes',x->'likes','date',x->'date'
        ))
        from jsonb_array_elements(coalesce(v_report.report_data->'sponsor_posts','[]'::jsonb)) x
        where x->>'sponsor_id' = v_sponsor_id::text
      ), '[]'::jsonb)
    );
    return jsonb_build_object('month_start',v_report.month_start,'status',v_report.status,'report',v_data);
  end if;

  return jsonb_build_object(
    'month_start',v_report.month_start,'status',v_report.status,
    'report',v_report.report_data,'highlights',to_jsonb(v_report.highlights),
    'approved_at',v_report.approved_at,'published_at',v_report.published_at
  );
end;
$$;

create or replace function public.monthly_sponsor_report_save(
  _month date,
  _report_data jsonb,
  _highlights text[]
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_admin boolean := coalesce(private.is_active_platform_admin(auth.uid()), false);
  v_old private.monthly_sponsor_reports%rowtype;
  v_highlights text[];
  v_old_exists boolean := false;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if _month is null or extract(day from _month) <> 1 then raise exception 'Month must be the first day of a month'; end if;
  if not (v_admin or v_roles && array['admin','chairman','treasurer','secretary','media_team']::text[]) then
    raise exception 'Not authorized to edit monthly sponsor reports';
  end if;
  if _report_data is null or jsonb_typeof(_report_data) <> 'object' then raise exception 'Report data must be a JSON object'; end if;
  if exists (select 1 from jsonb_object_keys(_report_data) as keys(key) where key not in ('summary','social','results','sponsor_posts')) then
    raise exception 'Report data contains unsupported fields';
  end if;
  if not (_report_data ?& array['summary','social','results','sponsor_posts'])
     or jsonb_typeof(_report_data->'summary') <> 'object'
     or jsonb_typeof(_report_data->'social') <> 'object'
     or jsonb_typeof(_report_data->'results') <> 'object'
     or jsonb_typeof(_report_data->'sponsor_posts') <> 'array'
     or jsonb_typeof(_report_data#>'{results,results}') <> 'array' then
    raise exception 'Report sections have an invalid structure';
  end if;
  if exists (
    select 1 from (
      select value from jsonb_each(_report_data->'summary')
      union all
      select value from jsonb_each(_report_data->'social')
    ) metrics
    where jsonb_typeof(value)='number' and (value::text)::numeric < 0
  ) then
    raise exception 'Report metrics cannot be negative';
  end if;
  if _month > date_trunc('month', current_date)::date then raise exception 'Future-month reports cannot be saved'; end if;
  select * into v_old from private.monthly_sponsor_reports where month_start = _month for update;
  v_old_exists := found;
  if v_old_exists and v_old.status <> 'draft' then raise exception 'Only draft reports can be edited'; end if;
  v_highlights := coalesce(_highlights,array[]::text[]);
  if not (v_admin or v_roles && array['admin','chairman','media_team']::text[]) then
    v_highlights := coalesce(v_old.highlights,array[]::text[]);
  end if;
  if cardinality(v_highlights) > 3 then raise exception 'Enter no more than three highlights'; end if;
  if exists(select 1 from unnest(v_highlights) as h(value) where value is null or length(btrim(value)) = 0) then raise exception 'Highlights cannot be blank'; end if;
  if exists(select 1 from unnest(v_highlights) as h(value) where length(btrim(value)) > 500) then raise exception 'Each highlight must be 500 characters or fewer'; end if;
  insert into private.monthly_sponsor_reports(month_start,report_data,highlights,status,created_by,updated_by)
  values(_month,_report_data,v_highlights,'draft',auth.uid(),auth.uid())
  on conflict(month_start) do update set report_data=excluded.report_data,highlights=excluded.highlights,
    updated_by=auth.uid(),updated_at=now();
  insert into private.monthly_sponsor_report_audit(
    month_start,actor_user_id,action_key,old_status,new_status,old_report_data,new_report_data
  ) values (
    _month,auth.uid(),'draft_saved',case when v_old_exists then v_old.status else null end,
    'draft',case when v_old_exists then v_old.report_data else null end,_report_data
  );
  return jsonb_build_object('month_start',_month,'status','draft');
end;
$$;

create or replace function public.monthly_sponsor_report_set_status(_month date, _status text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_admin boolean := coalesce(private.is_active_platform_admin(auth.uid()), false);
  v_old private.monthly_sponsor_reports%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if _month is null or extract(day from _month) <> 1 then raise exception 'Month must be the first day of a month'; end if;
  if _month > date_trunc('month', current_date)::date then raise exception 'Future-month reports cannot be approved or published'; end if;
  if _status is null or _status not in ('approved','published') then raise exception 'Only approval or publication transitions are supported'; end if;
  if not (v_admin or 'admin'=any(v_roles) or 'chairman'=any(v_roles)) then
    raise exception 'Only Admin or Chairman can approve or publish reports';
  end if;
  select * into v_old from private.monthly_sponsor_reports where month_start=_month for update;
  if not found then raise exception 'Save the report draft first'; end if;
  if _status='approved' and v_old.status<>'draft' then raise exception 'Only a draft can be approved'; end if;
  if _status='published' and v_old.status<>'approved' then raise exception 'Approve the report before publishing'; end if;
  if _status='published' and cardinality(v_old.highlights) <> 3 then raise exception 'Enter all three monthly highlights before publishing'; end if;
  if _status='approved' then
    update private.monthly_sponsor_reports set status='approved',approved_by=auth.uid(),approved_at=now(),updated_by=auth.uid(),updated_at=now() where month_start=_month;
  else
    update private.monthly_sponsor_reports set status='published',published_by=auth.uid(),published_at=now(),updated_by=auth.uid(),updated_at=now() where month_start=_month;
  end if;
  insert into private.monthly_sponsor_report_audit(
    month_start,actor_user_id,action_key,old_status,new_status,old_report_data,new_report_data
  ) values (_month,auth.uid(),_status,v_old.status,_status,v_old.report_data,v_old.report_data);
  return jsonb_build_object('month_start',_month,'status',_status);
end;
$;

revoke all on function public.monthly_sponsor_report_get(date) from public, anon;
revoke all on function public.monthly_sponsor_report_save(date,jsonb,text[]) from public, anon;
revoke all on function public.monthly_sponsor_report_set_status(date,text) from public, anon;
grant execute on function public.monthly_sponsor_report_get(date) to authenticated;
grant execute on function public.monthly_sponsor_report_save(date,jsonb,text[]) to authenticated;
grant execute on function public.monthly_sponsor_report_set_status(date,text) to authenticated;
