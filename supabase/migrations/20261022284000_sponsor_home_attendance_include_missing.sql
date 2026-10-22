-- Include the latest five completed home fixtures even when attendance is still missing.
-- Null attendance stays null; the sponsor UI must not display it as zero.
create or replace function public.sponsor_home_attendance_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare sponsor_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  if not ('sponsor'=any(private.current_club_roles())) then
    raise exception 'Sponsor account required' using errcode='42501';
  end if;
  sponsor_id := private.current_sponsor_record_id();
  if sponsor_id is null then raise exception 'Approved sponsor link required' using errcode='42501'; end if;
  return jsonb_build_object(
    'month_average', (
      select round(avg(a.attendance_count)::numeric,1)
      from public.match_attendance a
      join private.club_records c on c.id=a.fixture_id
      where c.record_type='fixture'
        and (lower(coalesce(c.data->>'match_type','')) in ('home','home match')
          or lower(coalesce(c.data->>'is_home','false')) in ('true','1','yes'))
        and lower(coalesce(c.data->>'match_status',c.data->>'status',''))='completed'
        and date_trunc('month', nullif(c.data->>'match_date','')::date)=date_trunc('month', current_date)
    ),
    'season_average', (
      select round(avg(a.attendance_count)::numeric,1)
      from public.match_attendance a
      join private.club_records c on c.id=a.fixture_id
      where c.record_type='fixture'
        and (lower(coalesce(c.data->>'match_type','')) in ('home','home match')
          or lower(coalesce(c.data->>'is_home','false')) in ('true','1','yes'))
        and lower(coalesce(c.data->>'match_status',c.data->>'status',''))='completed'
        and date_part('year', nullif(c.data->>'match_date','')::date)=date_part('year', current_date)
    ),
    'last_five', coalesce((
      select jsonb_agg(jsonb_build_object(
        'match_date',c.data->>'match_date',
        'opponent',c.data->>'opponent',
        'competition',c.data->>'competition',
        'attendance_count',a.attendance_count
      ) order by nullif(c.data->>'match_date','')::date desc)
      from (
        select c.id,c.data from private.club_records c
        where c.record_type='fixture'
          and (lower(coalesce(c.data->>'match_type','')) in ('home','home match')
            or lower(coalesce(c.data->>'is_home','false')) in ('true','1','yes'))
          and lower(coalesce(c.data->>'match_status',c.data->>'status',''))='completed'
        order by nullif(c.data->>'match_date','')::date desc
        limit 5
      ) c left join public.match_attendance a on a.fixture_id=c.id
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.sponsor_home_attendance_summary() from public, anon;
grant execute on function public.sponsor_home_attendance_summary() to authenticated;