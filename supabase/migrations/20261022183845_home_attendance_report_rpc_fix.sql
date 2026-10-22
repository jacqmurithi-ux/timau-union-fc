create or replace function public.home_attendance_get_report()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare roles text[] := private.current_club_roles(); adm boolean := private.is_active_platform_admin(auth.uid());
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  if not adm and not (roles && array['admin','secretary','team_manager','chairman','vice_chairman','treasurer','sponsor_lead','media_team','coach']::text[]) then
    raise exception 'Home attendance report access denied' using errcode='42501';
  end if;
  return jsonb_build_object(
    'fixtures', coalesce((
      select jsonb_agg(jsonb_build_object(
        'fixture_id', c.id, 'match_date', c.data->>'match_date',
        'opponent', c.data->>'opponent', 'competition', c.data->>'competition',
        'venue', c.data->>'venue', 'match_status', coalesce(c.data->>'match_status',c.data->>'status'),
        'attendance_count', a.attendance_count, 'notes', a.notes,
        'recorded_at', a.recorded_at, 'updated_at', a.updated_at
      ) order by nullif(c.data->>'match_date','')::date desc)
      from private.club_records c
      left join public.match_attendance a on a.fixture_id=c.id
      where c.record_type='fixture'
        and (lower(coalesce(c.data->>'match_type','')) in ('home','home match')
          or lower(coalesce(c.data->>'is_home','false')) in ('true','1','yes'))
        and lower(coalesce(c.data->>'match_status',c.data->>'status',''))='completed'
    ), '[]'::jsonb),
    'monthly', coalesce((select jsonb_agg(to_jsonb(m) order by m.month desc) from private.home_attendance_monthly m), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.home_attendance_get_report() from public, anon;
grant execute on function public.home_attendance_get_report() to authenticated;