-- Restrict attendance table privileges and keep audit fields server-managed.
begin;
revoke all on table public.match_attendance from public, anon, authenticated;
grant select, insert, update on table public.match_attendance to authenticated;

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
  else
    new.id := old.id;
    new.fixture_id := old.fixture_id;
    new.recorded_by := old.recorded_by;
    new.recorded_at := old.recorded_at;
  end if;
  return new;
end;
$$;
revoke all on function private.validate_home_attendance_fixture() from public, anon, authenticated;
drop trigger if exists validate_home_attendance_fixture on public.match_attendance;
create trigger validate_home_attendance_fixture
before insert or update on public.match_attendance
for each row execute function private.validate_home_attendance_fixture();
commit;