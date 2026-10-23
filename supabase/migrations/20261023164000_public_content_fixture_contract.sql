-- Align fixture drafts with the existing workspace form and expose only approved public fields.
create or replace function private.valid_club_record_data(_type text, _data jsonb)
returns boolean
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_allowed text[];
  v_required text;
  v_key text;
  v_value text;
  v_date date;
begin
  if _data is null or jsonb_typeof(_data)<>'object' then return false; end if;
  case _type
    when 'player' then
      v_allowed:=array['name','position','bio','squad_number','date_of_birth','fkf_number'];
      v_required:='name';
    when 'fixture' then
      v_allowed:=array['opponent','match_date','venue','result','competition','match_type','match_status'];
      v_required:='opponent';
    when 'news' then
      v_allowed:=array['title','summary','body','category'];
      v_required:='title';
    when 'sponsor' then
      v_allowed:=array['name','support_type','details','website'];
      v_required:='name';
    when 'activity' then
      v_allowed:=array['title','date','location','details'];
      v_required:='title';
    else
      return false;
  end case;

  if not (_data ? v_required)
     or jsonb_typeof(_data->v_required)<>'string'
     or length(btrim(_data->>v_required))=0 then
    return false;
  end if;

  for v_key in select jsonb_object_keys(_data) loop
    if not (v_key=any(v_allowed)) or jsonb_typeof(_data->v_key)<>'string' then
      return false;
    end if;
    v_value:=_data->>v_key;
    if length(v_value)>3000 then return false; end if;
    if v_key='date_of_birth' and v_value<>'' then
      if v_value !~ '^\d{4}-\d{2}-\d{2}$' then return false; end if;
      begin v_date:=v_value::date; exception when others then return false; end;
    end if;
  end loop;

  if _type='fixture' then
    if coalesce(btrim(_data->>'match_date'),'')='' or
       coalesce(_data->>'match_type','') not in ('home','away') or
       coalesce(_data->>'match_status','') not in ('scheduled','completed','postponed','cancelled') then
      return false;
    end if;
    if (_data->>'match_date') !~ '^\d{4}-\d{2}-\d{2}$' then return false; end if;
    begin v_date:=(_data->>'match_date')::date; exception when others then return false; end;
  end if;

  return true;
end
$function$;

create or replace function public.get_published_club_content()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',r.id,
        'record_type',r.record_type,
        'data',
          case r.record_type
            when 'player' then jsonb_strip_nulls(jsonb_build_object(
              'name',r.data->'name','position',r.data->'position',
              'bio',r.data->'bio','squad_number',r.data->'squad_number'))
            when 'fixture' then jsonb_strip_nulls(jsonb_build_object(
              'opponent',r.data->'opponent','match_date',r.data->'match_date',
              'venue',r.data->'venue','result',r.data->'result',
              'competition',r.data->'competition','match_type',r.data->'match_type',
              'match_status',r.data->'match_status'))
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
      ) order by r.approved_at desc
    ),
    '[]'::jsonb
  )
  from private.club_records r
  where r.publication_status='approved'
    and r.record_type in ('player','fixture','news','sponsor','activity')
$function$;
