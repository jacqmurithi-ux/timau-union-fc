-- Home match attendance: internal raw records, role-gated reads/writes, sponsor-safe summaries.
begin;

create table if not exists public.match_attendance (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null unique references private.club_records(id) on delete cascade,
  attendance_count integer not null check (attendance_count >= 0),
  recorded_by uuid not null references auth.users(id),
  recorded_at timestamptz not null default now(),
  notes text,
  updated_at timestamptz not null default now()
);

create index if not exists match_attendance_recorded_at_idx on public.match_attendance(recorded_at desc);
alter table public.match_attendance enable row level security;
revoke all on public.match_attendance from public, anon;
grant select, insert, update on public.match_attendance to authenticated;

drop policy if exists "attendance internal readers" on public.match_attendance;
create policy "attendance internal readers" on public.match_attendance
for select to authenticated
using (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman','treasurer','sponsor_lead','media_team','coach']::text[]
);
drop policy if exists "attendance authorized writers" on public.match_attendance;
create policy "attendance authorized writers" on public.match_attendance
for insert to authenticated
with check (
  recorded_by = auth.uid()
  and (
    private.is_active_platform_admin(auth.uid())
    or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
  )
);
drop policy if exists "attendance authorized editors" on public.match_attendance;
create policy "attendance authorized editors" on public.match_attendance
for update to authenticated
using (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
)
with check (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
);

create or replace function private.validate_home_attendance_fixture()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare fixture_data jsonb;
begin
  select c.data into fixture_data
  from private.club_records c
  where c.id = new.fixture_id and c.record_type = 'fixture';

  if fixture_data is null then
    raise exception 'Attendance must link to an existing fixture record';
  end if;

  if lower(coalesce(fixture_data->>'match_type','')) not in ('home','home match')
     and lower(coalesce(fixture_data->>'is_home','false')) not in ('true','1','yes') then
    raise exception 'Attendance can only be recorded for home fixtures';
  end if;

  if lower(coalesce(fixture_data->>'match_status', fixture_data->>'status','')) <> 'completed' then
    raise exception 'Attendance can only be recorded for completed home fixtures';
  end if;

  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.recorded_at := now();
  end if;
  return new;
end;
$$;
revoke all on function private.validate_home_attendance_fixture() from public, anon, authenticated;

drop trigger if exists validate_home_attendance_fixture on public.match_attendance;
create trigger validate_home_attendance_fixture
before insert or update on public.match_attendance
for each row execute function private.validate_home_attendance_fixture();


create or replace function private.guard_attendance_fixture_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.record_type = 'fixture'
     and exists (select 1 from public.match_attendance a where a.fixture_id = new.id)
     and (
       (lower(coalesce(new.data->>'match_type','')) not in ('home','home match')
         and lower(coalesce(new.data->>'is_home','false')) not in ('true','1','yes'))
       or lower(coalesce(new.data->>'match_status',new.data->>'status','')) <> 'completed'
     ) then
    raise exception 'A fixture with recorded attendance must remain a completed home match; remove attendance before changing its status or venue type';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_attendance_fixture_update() from public, anon, authenticated;
drop trigger if exists guard_attendance_fixture_update on private.club_records;
create trigger guard_attendance_fixture_update
before update of data, record_type on private.club_records
for each row execute function private.guard_attendance_fixture_update();

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
        'match_date',c.data->>'match_date','opponent',c.data->>'opponent',
        'competition',c.data->>'competition','attendance_count',a.attendance_count
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

commit;