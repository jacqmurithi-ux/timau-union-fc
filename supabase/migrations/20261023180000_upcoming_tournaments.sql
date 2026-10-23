-- Upcoming tournament records for public club news. Apply to test first; do not run in production without review.
begin;

create table if not exists public.club_tournaments (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 3 and 180),
  summary text not null check (length(btrim(summary)) between 3 and 3000),
  starts_on date not null,
  ends_on date not null,
  venue text not null check (length(btrim(venue)) between 2 and 240),
  poster_url text check (poster_url is null or (length(poster_url) <= 2000 and poster_url ~* '^https?://')),
  status text not null default 'draft' check (status in ('draft','pending','approved','rejected')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  check ((status in ('approved','rejected') and reviewed_by is not null and reviewed_at is not null)
      or (status in ('draft','pending') and reviewed_by is null and reviewed_at is null))
);
create index if not exists club_tournaments_public_dates_idx
  on public.club_tournaments(status, starts_on, ends_on);

alter table public.club_tournaments enable row level security;
revoke all on public.club_tournaments from public, anon, authenticated;
grant select (id,title,summary,starts_on,ends_on,venue,poster_url,status)
  on public.club_tournaments to anon, authenticated;
create policy club_tournaments_public_approved_read
  on public.club_tournaments for select to anon, authenticated
  using (status='approved');

create table if not exists private.club_tournament_audit (
  id bigint generated always as identity primary key,
  tournament_id uuid not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  action_key text not null check (action_key in ('created','updated','submitted','approved','rejected','returned_to_draft')),
  old_status text,
  new_status text not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table private.club_tournament_audit enable row level security;
revoke all on private.club_tournament_audit from public, anon, authenticated;

create or replace function public.club_tournament_can_manage()
returns boolean language sql stable security definer set search_path=''
as $$
  select auth.uid() is not null and (
    private.is_active_platform_admin(auth.uid())
    or private.current_club_roles() && array['chairman','secretary','media_team']::text[]
  )
$$;
revoke all on function public.club_tournament_can_manage() from public, anon;
grant execute on function public.club_tournament_can_manage() to authenticated;

create or replace function public.club_tournaments_manage_list()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.club_tournament_can_manage() then
   raise exception 'Media Team, Secretary or Chairman access required' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(to_jsonb(t) order by t.starts_on desc,t.created_at desc)
   from public.club_tournaments t),'[]'::jsonb);
end $$;
revoke all on function public.club_tournaments_manage_list() from public, anon;
grant execute on function public.club_tournaments_manage_list() to authenticated;

create or replace function public.club_tournament_save(
 _id uuid, _title text, _summary text, _starts_on date, _ends_on date,
 _venue text, _poster_url text, _submit boolean default false
) returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.club_tournaments%rowtype; v_id uuid; v_old_status text;
begin
 if auth.uid() is null or not public.club_tournament_can_manage() then
  raise exception 'Media Team, Secretary or Chairman access required' using errcode='42501';
 end if;
 if length(btrim(coalesce(_title,''))) not between 3 and 180
    or length(btrim(coalesce(_summary,''))) not between 3 and 3000
    or length(btrim(coalesce(_venue,''))) not between 2 and 240
    or _starts_on is null or _ends_on is null or _ends_on < _starts_on
    or (_poster_url is not null and (length(_poster_url)>2000 or _poster_url !~* '^https?://')) then
   raise exception 'Check tournament title, summary, dates, venue and poster URL';
 end if;
 if _id is null then
   insert into public.club_tournaments(title,summary,starts_on,ends_on,venue,poster_url,status,created_by,updated_by)
   values(btrim(_title),btrim(_summary),_starts_on,_ends_on,btrim(_venue),nullif(btrim(_poster_url),''),case when _submit then 'pending' else 'draft' end,auth.uid(),auth.uid())
   returning id into v_id;
   insert into private.club_tournament_audit(tournament_id,actor_user_id,action_key,new_status)
   values(v_id,auth.uid(),case when _submit then 'submitted' else 'created' end,case when _submit then 'pending' else 'draft' end);
 else
   select * into v from public.club_tournaments where id=_id for update;
   if not found then raise exception 'Tournament not found'; end if;
   if v.created_by<>auth.uid() and not ('chairman'=any(private.current_club_roles()) or private.is_active_platform_admin(auth.uid())) then
     raise exception 'Only the creator or Chairman may edit this tournament' using errcode='42501';
   end if;
   if v.status='approved' then raise exception 'Approved tournament cannot be edited; return it to draft first'; end if;
   v_old_status:=v.status;
   update public.club_tournaments set title=btrim(_title),summary=btrim(_summary),starts_on=_starts_on,ends_on=_ends_on,venue=btrim(_venue),poster_url=nullif(btrim(_poster_url),''),status=case when _submit then 'pending' else 'draft' end,reviewed_by=null,reviewed_at=null,review_reason=null,updated_by=auth.uid(),updated_at=now() where id=_id returning id into v_id;
   insert into private.club_tournament_audit(tournament_id,actor_user_id,action_key,old_status,new_status)
   values(v_id,auth.uid(),case when _submit then 'submitted' else 'updated' end,v_old_status,case when _submit then 'pending' else 'draft' end);
 end if;
 return v_id;
end $$;
revoke all on function public.club_tournament_save(uuid,text,text,date,date,text,text,boolean) from public, anon;
grant execute on function public.club_tournament_save(uuid,text,text,date,date,text,text,boolean) to authenticated;

create or replace function public.club_tournament_review(_id uuid,_decision text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare v public.club_tournaments%rowtype;
begin
 if auth.uid() is null or not ('chairman'=any(private.current_club_roles())) then
  raise exception 'Chairman approval required' using errcode='42501';
 end if;
 if _decision is null or _decision not in ('approved','rejected') or length(btrim(coalesce(_reason,''))) not between 3 and 1000 then
  raise exception 'Choose approve/reject and provide a reason of 3–1000 characters';
 end if;
 select * into v from public.club_tournaments where id=_id for update;
 if not found then raise exception 'Tournament not found'; end if;
 if v.status<>'pending' then raise exception 'Only submitted tournaments can be reviewed'; end if;
 if v.created_by=auth.uid() then raise exception 'You cannot approve your own tournament'; end if;
 update public.club_tournaments set status=_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=btrim(_reason),updated_by=auth.uid(),updated_at=now() where id=_id;
 insert into private.club_tournament_audit(tournament_id,actor_user_id,action_key,old_status,new_status,reason)
 values(_id,auth.uid(),_decision,v.status,_decision,btrim(_reason));
 return true;
end $$;
revoke all on function public.club_tournament_review(uuid,text,text) from public, anon;
grant execute on function public.club_tournament_review(uuid,text,text) to authenticated;

create or replace function public.club_tournaments_public_list()
returns jsonb language sql stable security definer set search_path=''
as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',t.id,'title',t.title,'summary',t.summary,'starts_on',t.starts_on,
   'ends_on',t.ends_on,'venue',t.venue,'poster_url',t.poster_url
 ) order by t.starts_on,t.title),'[]'::jsonb)
 from public.club_tournaments t
 where t.status='approved' and t.ends_on >= current_date
$$;
revoke all on function public.club_tournaments_public_list() from public;
grant execute on function public.club_tournaments_public_list() to anon, authenticated;

create or replace function public.club_tournament_my_access()
returns jsonb language plpgsql stable security definer set search_path=''
as $
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 return jsonb_build_object(
   'roles',to_jsonb(private.current_club_roles()),
   'is_platform_admin',private.is_active_platform_admin(auth.uid())
 );
end $;
revoke all on function public.club_tournament_my_access() from public, anon;
grant execute on function public.club_tournament_my_access() to authenticated;

commit;
