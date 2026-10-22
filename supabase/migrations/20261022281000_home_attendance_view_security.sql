begin;
drop view if exists public.home_attendance_monthly;
create or replace view private.home_attendance_monthly with (security_invoker = true) as
with completed_home as (
  select c.id, nullif(c.data->>'match_date','')::date as match_date
  from private.club_records c
  where c.record_type = 'fixture'
    and (lower(coalesce(c.data->>'match_type','')) in ('home','home match')
      or lower(coalesce(c.data->>'is_home','false')) in ('true','1','yes'))
    and lower(coalesce(c.data->>'match_status', c.data->>'status','')) = 'completed'
    and nullif(c.data->>'match_date','') is not null
), monthly_matches as (
  select date_trunc('month', match_date)::date as month, count(*)::integer as matches_played
  from completed_home
  group by 1
), monthly_attendance as (
  select date_trunc('month', h.match_date)::date as month,
         count(*)::integer as matches_with_attendance,
         coalesce(sum(a.attendance_count),0)::bigint as total_attendance,
         round(avg(a.attendance_count)::numeric,1) as average_attendance_per_match,
         max(a.attendance_count)::integer as highest_attendance,
         min(a.attendance_count)::integer as lowest_attendance
  from completed_home h
  join public.match_attendance a on a.fixture_id = h.id
  group by 1
)
select m.month, m.matches_played,
       coalesce(a.matches_with_attendance,0)::integer as matches_with_attendance,
       coalesce(a.total_attendance,0)::bigint as total_attendance,
       a.average_attendance_per_match,
       a.highest_attendance, a.lowest_attendance
from monthly_matches m left join monthly_attendance a using (month);
revoke all on private.home_attendance_monthly from public, anon, authenticated;
commit;