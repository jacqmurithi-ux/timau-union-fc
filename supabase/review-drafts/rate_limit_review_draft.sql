-- Timau Union FC Phase 1 server-side rate-limit hardening — REVIEW DRAFT ONLY.
-- This is a separate additive migration draft. Apply only to disposable Union Test after review.
-- Never apply to production without separate explicit approval.

begin;

create table private.api_rate_limit_counters (
  actor_user_id uuid not null,
  bucket_key text not null check (bucket_key in ('invite', 'activation', 'admin_mutation')),
  window_started_at timestamptz not null,
  hit_count integer not null check (hit_count >= 1),
  primary key (actor_user_id, bucket_key)
);

alter table private.api_rate_limit_counters enable row level security;
create policy api_rate_limit_deny_all on private.api_rate_limit_counters for all to public using (false) with check (false);
revoke all on table private.api_rate_limit_counters from public, anon, authenticated, service_role;

create or replace function public.club_admin_consume_rate_limit(_actor uuid, _bucket text)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_limit integer;
  v_window interval;
  v_count integer;
begin
  if _actor is null then
    raise exception using errcode='22023', message='invalid_rate_limit_actor';
  end if;

  case _bucket
    when 'invite' then
      v_limit := 5;
      v_window := interval '1 hour';
    when 'activation' then
      v_limit := 10;
      v_window := interval '1 minute';
    when 'admin_mutation' then
      v_limit := 60;
      v_window := interval '1 minute';
    else
      raise exception using errcode='22023', message='invalid_rate_limit_bucket';
  end case;

  insert into private.api_rate_limit_counters(actor_user_id, bucket_key, window_started_at, hit_count)
  values (_actor, _bucket, clock_timestamp(), 1)
  on conflict (actor_user_id, bucket_key) do update
  set window_started_at = case
        when private.api_rate_limit_counters.window_started_at <= clock_timestamp() - v_window
        then clock_timestamp()
        else private.api_rate_limit_counters.window_started_at
      end,
      hit_count = case
        when private.api_rate_limit_counters.window_started_at <= clock_timestamp() - v_window
        then 1
        else private.api_rate_limit_counters.hit_count + 1
      end
  returning hit_count into v_count;

  return v_count <= v_limit;
end
$$;

revoke all on function public.club_admin_consume_rate_limit(uuid,text) from public, anon, authenticated;
grant execute on function public.club_admin_consume_rate_limit(uuid,text) to service_role;

commit;
