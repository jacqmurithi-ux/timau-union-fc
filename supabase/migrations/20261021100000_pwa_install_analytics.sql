-- REVIEW DRAFT: apply to Union Test only after security review.
begin;
create table if not exists private.analytics_events (
  id bigint generated always as identity primary key,
  event_type text not null check (event_type in ('install','install_prompt_shown','install_prompt_accepted','app_open')),
  visitor_id uuid not null,
  source text not null check (source in ('home','app','unknown')),
  created_at timestamptz not null default now()
);
create index if not exists analytics_events_type_created_idx on private.analytics_events(event_type, created_at desc);
create index if not exists analytics_events_visitor_type_created_idx on private.analytics_events(visitor_id,event_type,created_at desc);
create unique index if not exists analytics_events_one_install_per_visitor on private.analytics_events(visitor_id) where event_type='install';
alter table private.analytics_events enable row level security;
revoke all on private.analytics_events from public, anon, authenticated;
revoke all on sequence private.analytics_events_id_seq from public, anon, authenticated;

create or replace function public.record_event(_event_type text,_visitor_id uuid,_source text default 'unknown')
returns boolean language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if _event_type not in ('install','install_prompt_shown','install_prompt_accepted','app_open') then
   raise exception 'Invalid event type' using errcode='22023';
 end if;
 if _visitor_id is null then raise exception 'visitor_id required' using errcode='22023'; end if;
 if _source not in ('home','app','unknown') then raise exception 'Invalid source' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(_visitor_id::text,0));
 if _event_type='install' and exists(select 1 from private.analytics_events where visitor_id=_visitor_id and event_type='install') then return true; end if;
 select count(*) into v_count from private.analytics_events where visitor_id=_visitor_id and created_at>now()-interval '1 minute';
 if v_count>=20 then raise exception 'Event rate limit exceeded' using errcode='54000'; end if;
 insert into private.analytics_events(event_type,visitor_id,source) values(_event_type,_visitor_id,_source)
 on conflict (visitor_id) where event_type='install' do nothing;
 return true;
end; $$;
revoke all on function public.record_event(text,uuid,text) from public;
grant execute on function public.record_event(text,uuid,text) to anon,authenticated;

create or replace function public.install_report()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_today date := (now() at time zone 'Africa/Nairobi')::date; v_result jsonb;
begin
 if auth.uid() is null or not private.is_active_platform_admin(auth.uid()) then
   raise exception 'Platform Admin access required' using errcode='42501';
 end if;
 with daily as (
  select d::date install_date,count(e.id) filter(where e.event_type='install')::integer installs
  from generate_series(v_today-29,v_today,interval '1 day') d
  left join private.analytics_events e on e.event_type='install'
   and (e.created_at at time zone 'Africa/Nairobi')::date=d::date
  group by d::date
 ), series as (
  select install_date,installs,sum(installs) over(order by install_date)::integer cumulative_30d from daily
 ), totals as (
  select count(*) filter(where event_type='install')::integer total_installs,
   count(*) filter(where event_type='install' and (created_at at time zone 'Africa/Nairobi')::date=v_today)::integer installs_today,
   count(*) filter(where event_type='install' and created_at>=now()-interval '7 days')::integer installs_7d,
   count(*) filter(where event_type='install' and created_at>=now()-interval '30 days')::integer installs_30d,
   count(distinct visitor_id) filter(where event_type='app_open' and created_at>=now()-interval '30 days')::integer active_installs_30d,
   count(*) filter(where event_type='install_prompt_shown' and created_at>=now()-interval '30 days')::integer prompts_shown_30d,
   count(*) filter(where event_type='install_prompt_accepted' and created_at>=now()-interval '30 days')::integer prompts_accepted_30d
  from private.analytics_events
 )
 select jsonb_build_object(
  'total_installs',total_installs,'installs_today',installs_today,'installs_7d',installs_7d,'installs_30d',installs_30d,
  'active_installs_30d',active_installs_30d,'prompts_shown_30d',prompts_shown_30d,'prompts_accepted_30d',prompts_accepted_30d,
  'acceptance_rate_30d',case when prompts_shown_30d=0 then 0 else round(100.0*prompts_accepted_30d/prompts_shown_30d,1) end,
  'daily',coalesce((select jsonb_agg(jsonb_build_object('date',to_char(install_date,'YYYY-MM-DD'),'installs',installs,'cumulative_30d',cumulative_30d) order by install_date) from series),'[]'::jsonb)
 ) into v_result from totals;
 return v_result;
end; $$;
revoke all on function public.install_report() from public,anon;
grant execute on function public.install_report() to authenticated;
commit;
