begin;

create table if not exists public.sponsor_mockups (
 id uuid primary key default gen_random_uuid(),
 title text not null check (char_length(btrim(title)) between 2 and 120),
 package_key text not null check (package_key in ('kit','match-day','training','website-social','community','custom','match-poster','recognition-banner','proposal-cover','thank-you','equipment','community-impact')),
 description text not null default '' check (char_length(description)<=1000),
 storage_path text not null unique,
 mime_type text not null check (mime_type in ('image/png','image/jpeg','image/webp')),
 file_size bigint not null check (file_size between 1 and 10485760),
 status text not null default 'draft' check (status in ('draft','approved','archived')),
 created_by uuid not null references auth.users(id),
 updated_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 approved_by uuid references auth.users(id),
 approved_at timestamptz
);
alter table public.sponsor_mockups enable row level security;
revoke all on public.sponsor_mockups from public, anon, authenticated;
create policy sponsor_mockups_staff_select on public.sponsor_mockups for select to authenticated
 using (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()));
create policy sponsor_mockups_staff_insert on public.sponsor_mockups for insert to authenticated
 with check ((private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) and created_by=auth.uid() and status='draft');
create policy sponsor_mockups_staff_update on public.sponsor_mockups for update to authenticated
 using (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()))
 with check (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles()));
grant select,insert,update on public.sponsor_mockups to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('sponsor-mockups','sponsor-mockups',false,10485760,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['image/png','image/jpeg','image/webp'];

create or replace function private.can_access_sponsor_mockup(_name text, _operation text)
returns boolean language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then return false; end if;
 if not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles()) or 'chairman'=any(private.current_club_roles())) then return false; end if;
 if _operation='read' then return exists(select 1 from public.sponsor_mockups m where m.storage_path=_name); end if;
 if _operation='insert' then return split_part(_name,'/',1)=auth.uid()::text and not exists(select 1 from public.sponsor_mockups m where m.storage_path=_name); end if;
 if _operation='delete' then return private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'sponsor_lead'=any(private.current_club_roles()); end if;
 return false;
end $$;
revoke all on function private.can_access_sponsor_mockup(text,text) from public,anon,authenticated;
grant execute on function private.can_access_sponsor_mockup(text,text) to authenticated;
drop policy if exists sponsor_mockups_storage_read on storage.objects;
create policy sponsor_mockups_storage_read on storage.objects for select to authenticated using(bucket_id='sponsor-mockups' and private.can_access_sponsor_mockup(name,'read'));
drop policy if exists sponsor_mockups_storage_insert on storage.objects;
create policy sponsor_mockups_storage_insert on storage.objects for insert to authenticated with check(bucket_id='sponsor-mockups' and private.can_access_sponsor_mockup(name,'insert'));
drop policy if exists sponsor_mockups_storage_delete on storage.objects;
create policy sponsor_mockups_storage_delete on storage.objects for delete to authenticated using(bucket_id='sponsor-mockups' and private.can_access_sponsor_mockup(name,'delete'));

create or replace function public.sponsor_mockup_set_status(_id uuid,_status text,_reason text)
returns void language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'sponsor_lead'=any(private.current_club_roles())) then raise exception 'Sponsor Lead, Chairman or Platform Admin required' using errcode='42501'; end if;
 if _status not in ('draft','approved','archived') or char_length(btrim(coalesce(_reason,'')))<3 or char_length(_reason)>1000 then raise exception 'Valid status and reason required' using errcode='22023'; end if;
 update public.sponsor_mockups set status=_status,updated_at=now(),updated_by=auth.uid(),approved_by=case when _status='approved' then auth.uid() else null end,approved_at=case when _status='approved' then now() else null end where id=_id;
 if not found then raise exception 'Mockup not found' using errcode='P0002'; end if;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_mockups',_id,'sponsor_mockup_status_changed','{}'::jsonb,jsonb_build_object('status',_status),btrim(_reason));
end $$;
revoke all on function public.sponsor_mockup_set_status(uuid,text,text) from public,anon;
grant execute on function public.sponsor_mockup_set_status(uuid,text,text) to authenticated;
commit;
