-- Defense-in-depth: enforce the three-active-slide cap for every insert/update path.
begin;
create or replace function private.enforce_homepage_hero_active_limit()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('homepage_hero_slides_max_three'));
  if new.ends_at is null or new.ends_at > now() then
    select count(*) into v_count
    from public.homepage_hero_slides s
    where (s.ends_at is null or s.ends_at > now())
      and s.id is distinct from new.id;
    if v_count >= 3 then
      raise exception 'Maximum of 3 active homepage hero slides';
    end if;
  end if;
  return new;
end
$$;
revoke all on function private.enforce_homepage_hero_active_limit() from public, anon, authenticated;
drop trigger if exists homepage_hero_active_limit on public.homepage_hero_slides;
create trigger homepage_hero_active_limit
before insert or update of ends_at on public.homepage_hero_slides
for each row execute function private.enforce_homepage_hero_active_limit();
commit;
