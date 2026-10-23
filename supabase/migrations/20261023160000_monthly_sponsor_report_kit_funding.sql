-- Monthly sponsor report and kit funding metadata.
-- Review and test in a non-production project before applying to production.

alter table public.kit_items
  add column if not exists funded_by_sponsor_id uuid references private.club_records(id) on delete set null,
  add column if not exists funding_amount numeric(12,2),
  add column if not exists date_acquired date,
  add column if not exists acquisition_type text;

alter table public.kit_items
  drop constraint if exists kit_items_funding_amount_nonnegative,
  add constraint kit_items_funding_amount_nonnegative
    check (funding_amount is null or funding_amount >= 0),
  drop constraint if exists kit_items_acquisition_type_valid,
  add constraint kit_items_acquisition_type_valid
    check (acquisition_type is null or acquisition_type in ('purchased','donated','sponsor-funded','other'));

create or replace function private.validate_kit_sponsor_funding()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_type text;
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_allowed boolean := coalesce(private.is_active_platform_admin(auth.uid()), false)
    or v_roles && array['admin','chairman','treasurer','secretary']::text[]
    or exists (select 1 from public.kit_managers km where km.user_id = auth.uid());
begin
  if auth.uid() is null then
    raise exception 'Authentication required to change kit funding';
  end if;
  if tg_op = 'INSERT' then
    if (new.funded_by_sponsor_id is not null or new.funding_amount is not null or new.acquisition_type = 'sponsor-funded') and not v_allowed then
      raise exception 'Only Admin, Chairman, Treasurer, Secretary or kit managers can set sponsor funding';
    end if;
  elsif (new.funded_by_sponsor_id is distinct from old.funded_by_sponsor_id
      or new.funding_amount is distinct from old.funding_amount
      or new.date_acquired is distinct from old.date_acquired
      or new.acquisition_type is distinct from old.acquisition_type)
      and not v_allowed then
    raise exception 'Only Admin, Chairman, Treasurer, Secretary or kit managers can set sponsor funding';
  end if;
  if new.acquisition_type = 'sponsor-funded' and new.funded_by_sponsor_id is null then
    raise exception 'Sponsor-funded kit must identify the sponsor';
  end if;
  if new.funded_by_sponsor_id is not null then
    select record_type into v_type
      from private.club_records
      where id = new.funded_by_sponsor_id;
    if v_type is distinct from 'sponsor' then
      raise exception 'funded_by_sponsor_id must reference a sponsor record';
    end if;
    if new.acquisition_type is null then
      new.acquisition_type := 'sponsor-funded';
    end if;
  end if;
  if new.funding_amount is not null and new.funding_amount < 0 then
    raise exception 'funding_amount cannot be negative';
  end if;
  return new;
end;
$$;

drop trigger if exists kit_items_validate_sponsor_funding on public.kit_items;
comment on column public.kit_items.funded_by_sponsor_id is 'Sponsor record in private.club_records (record_type=sponsor); nullable for existing or non-sponsored kit.';
comment on column public.kit_items.funding_amount is 'Optional recorded funding value in KES; only authorized officials or kit managers may change it.';
comment on column public.kit_items.date_acquired is 'Date the item was acquired; nullable for existing inventory.';
comment on column public.kit_items.acquisition_type is 'How the item was acquired; nullable for existing inventory.';

create trigger kit_items_validate_sponsor_funding
before insert or update of funded_by_sponsor_id, funding_amount, date_acquired, acquisition_type
on public.kit_items
for each row execute function private.validate_kit_sponsor_funding();

create or replace function public.kit_set_sponsor_funding(
  _kit_item_id uuid,
  _funded_by_sponsor_id uuid,
  _funding_amount numeric,
  _date_acquired date,
  _acquisition_type text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_allowed boolean := coalesce(private.is_active_platform_admin(auth.uid()), false)
    or v_roles && array['admin','chairman','treasurer','secretary']::text[]
    or exists (select 1 from public.kit_managers km where km.user_id = auth.uid());
  v_type text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not v_allowed then raise exception 'Not authorized to change kit funding'; end if;
  if _funding_amount is not null and _funding_amount < 0 then raise exception 'Funding amount cannot be negative'; end if;
  if _acquisition_type is not null and _acquisition_type not in ('purchased','donated','sponsor-funded','other') then
    raise exception 'Invalid acquisition type';
  end if;
  if _acquisition_type = 'sponsor-funded' and _funded_by_sponsor_id is null then
    raise exception 'Sponsor-funded kit must identify the sponsor';
  end if;
  if _funded_by_sponsor_id is not null then
    select record_type into v_type from private.club_records where id = _funded_by_sponsor_id;
    if v_type is distinct from 'sponsor' then raise exception 'Funding sponsor must be a sponsor record'; end if;
  end if;
  update public.kit_items
     set funded_by_sponsor_id = _funded_by_sponsor_id,
         funding_amount = _funding_amount,
         date_acquired = _date_acquired,
         acquisition_type = case when _funded_by_sponsor_id is not null and _acquisition_type is null then 'sponsor-funded' else _acquisition_type end,
         updated_by = auth.uid(),
         updated_at = now()
   where id = _kit_item_id;
  if not found then raise exception 'Kit item not found'; end if;
  return jsonb_build_object('ok',true,'kit_item_id',_kit_item_id);
end;
$$;

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
revoke all on function private.validate_kit_sponsor_funding() from public, anon, authenticated;

create or replace function public.monthly_sponsor_report_get(_month date)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
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
  select count(distinct sul.sponsor_record_id), min(sul.sponsor_record_id)
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
        'kit_needs',jsonb_build_array(),
        'kit_funded_by_sponsor',jsonb_build_array(),
        'sponsor_posts',jsonb_build_array()
      ));
    end if;
    return jsonb_build_object('month_start',_month,'status','draft','report',jsonb_build_object(),'highlights',jsonb_build_array());
  end if;
  if v_sponsor and v_report.status <> 'published' then
    return jsonb_build_object('month_start',_month,'status','unpublished','report',jsonb_build_object(
      'summary',jsonb_build_object(),'social',jsonb_build_object(),'results',jsonb_build_object(),
      'highlights',jsonb_build_array(),'kit_needs',jsonb_build_array(),
      'kit_funded_by_sponsor',jsonb_build_array(),'sponsor_posts',jsonb_build_array()
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
      'kit_needs', coalesce((select jsonb_agg(jsonb_build_object(
        'name',x->'name','quantity_usable',x->'quantity_usable',
        'quantity_total',x->'quantity_total','quantity_damaged',x->'quantity_damaged',
        'quantity_missing',x->'quantity_missing'
      )) from jsonb_array_elements(coalesce(v_report.report_data->'kit_needs','[]'::jsonb)) x),'[]'::jsonb),
      'kit_month_added', coalesce(v_report.report_data->'kit_month_added','null'::jsonb),
      'kit_total_stock', coalesce(v_report.report_data->'kit_total_stock','null'::jsonb),
      'kit_usable_units', coalesce(v_report.report_data->'kit_usable_units','null'::jsonb),
      'kit_damaged_units', coalesce(v_report.report_data->'kit_damaged_units','null'::jsonb),
      'kit_missing_units', coalesce(v_report.report_data->'kit_missing_units','null'::jsonb),
      'first_aid_status', coalesce(v_report.report_data->'first_aid_status','null'::jsonb),
      'kit_funded_by_sponsor', coalesce((
        select jsonb_agg(jsonb_build_object(
          'sponsor_id',x->'sponsor_id','item',x->'item','colour',x->'colour',
          'quantity',x->'quantity','amount',x->'amount','date',x->'date',
          'condition',x->'condition','month',x->'month'
        ))
        from jsonb_array_elements(coalesce(v_report.report_data->'kit_funded_by_sponsor','[]'::jsonb)) x
        where x->>'sponsor_id' = v_sponsor_id::text
      ), '[]'::jsonb),
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
set search_path = pg_catalog, public, private
as $$
declare
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_admin boolean := coalesce(private.is_active_platform_admin(auth.uid()), false);
  v_old private.monthly_sponsor_reports%rowtype;
  v_highlights text[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if _month is null or extract(day from _month) <> 1 then raise exception 'Month must be the first day of a month'; end if;
  if not (v_admin or v_roles && array['admin','chairman','treasurer','secretary','media_team']::text[]) then
    raise exception 'Not authorized to edit monthly sponsor reports';
  end if;
  if _report_data is null or jsonb_typeof(_report_data) <> 'object' then raise exception 'Report data must be a JSON object'; end if;
  if exists (select 1 from jsonb_object_keys(_report_data) as keys(key) where key not in ('summary','social','results','kit_needs','kit_funded_by_sponsor','sponsor_posts','kit_month_added','kit_total_stock','kit_usable_units','kit_damaged_units','kit_missing_units','first_aid_status')) then
    raise exception 'Report data contains unsupported fields';
  end if;
  select * into v_old from private.monthly_sponsor_reports where month_start = _month for update;
  if found and v_old.status <> 'draft' then raise exception 'Only draft reports can be edited'; end if;
  v_highlights := coalesce(_highlights,array[]::text[]);
  if not (v_admin or v_roles && array['admin','chairman','media_team']::text[]) then
    v_highlights := coalesce(v_old.highlights,array[]::text[]);
  end if;
  if cardinality(v_highlights) > 3 then raise exception 'Enter no more than three highlights'; end if;
  if exists(select 1 from unnest(v_highlights) as h(value) where length(btrim(value)) = 0) then raise exception 'Highlights cannot be blank'; end if;
  if exists(select 1 from unnest(v_highlights) as h(value) where length(btrim(value)) > 500) then raise exception 'Each highlight must be 500 characters or fewer'; end if;
  insert into private.monthly_sponsor_reports(month_start,report_data,highlights,status,created_by,updated_by)
  values(_month,_report_data,v_highlights,'draft',auth.uid(),auth.uid())
  on conflict(month_start) do update set report_data=excluded.report_data,highlights=excluded.highlights,
    updated_by=auth.uid(),updated_at=now();
  return jsonb_build_object('month_start',_month,'status','draft');
end;
$$;

create or replace function public.monthly_sponsor_report_set_status(_month date, _status text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_roles text[] := coalesce(private.current_club_roles(), array[]::text[]);
  v_admin boolean := coalesce(private.is_active_platform_admin(auth.uid()), false);
  v_old private.monthly_sponsor_reports%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
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
  return jsonb_build_object('month_start',_month,'status',_status);
end;
$$;

revoke all on function public.kit_set_sponsor_funding(uuid,uuid,numeric,date,text) from public, anon;
grant execute on function public.kit_set_sponsor_funding(uuid,uuid,numeric,date,text) to authenticated;
revoke all on function public.monthly_sponsor_report_get(date) from public, anon;
revoke all on function public.monthly_sponsor_report_save(date,jsonb,text[]) from public, anon;
revoke all on function public.monthly_sponsor_report_set_status(date,text) from public, anon;
grant execute on function public.monthly_sponsor_report_get(date) to authenticated;
grant execute on function public.monthly_sponsor_report_save(date,jsonb,text[]) to authenticated;
grant execute on function public.monthly_sponsor_report_set_status(date,text) to authenticated;
