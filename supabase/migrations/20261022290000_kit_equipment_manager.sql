-- Kit & Equipment Manager, including coach-safe updates and movement audit.
begin;

create table if not exists public.kit_items (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('jersey','bibs','cones','ball','goal_nets','first_aid_kit','other')),
  name text not null check (length(trim(name)) > 0),
  colour text,
  usage_type text not null default 'both' check (usage_type in ('match_day','training','both')),
  quantity_total integer not null default 0 check (quantity_total >= 0),
  quantity_usable integer not null default 0 check (quantity_usable >= 0 and quantity_usable <= quantity_total),
  quantity_damaged integer not null default 0 check (quantity_damaged >= 0),
  quantity_missing integer not null default 0 check (quantity_missing >= 0),
  status text not null default 'good' check (status in ('good','fair','needs_repair','unusable')),
  custodian_id uuid references auth.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint kit_item_quantity_breakdown_check check (quantity_usable + quantity_damaged + quantity_missing <= quantity_total)
);

create table if not exists public.first_aid_items (
  id uuid primary key default gen_random_uuid(),
  kit_item_id uuid not null references public.kit_items(id) on delete cascade,
  item_name text not null check (length(trim(item_name)) > 0),
  required_qty integer not null default 0 check (required_qty >= 0),
  current_qty integer not null default 0 check (current_qty >= 0),
  expiry_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kit_movements (
  id uuid primary key default gen_random_uuid(),
  kit_item_id uuid not null references public.kit_items(id) on delete restrict,
  action text not null check (action in ('issued','returned','lost','damaged','repaired','replaced')),
  quantity integer not null check (quantity > 0),
  from_person uuid references auth.users(id) on delete set null,
  to_person uuid references auth.users(id) on delete set null,
  fixture_id uuid references private.club_records(id) on delete set null,
  movement_date date not null default current_date,
  recorded_by uuid not null default auth.uid() references auth.users(id),
  recorded_at timestamptz not null default now(),
  notes text
);

create table if not exists public.kit_managers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  assigned_by uuid not null default auth.uid() references auth.users(id),
  assigned_at timestamptz not null default now()
);

create table if not exists public.kit_alerts (
  id uuid primary key default gen_random_uuid(),
  kit_item_id uuid references public.kit_items(id) on delete cascade,
  alert_type text not null check (alert_type in ('damaged','missing','unusable','first_aid_incomplete','first_aid_expired')),
  message text not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id)
);

create index if not exists kit_items_category_idx on public.kit_items(category);
create index if not exists kit_items_custodian_idx on public.kit_items(custodian_id);
create index if not exists kit_movements_item_date_idx on public.kit_movements(kit_item_id, movement_date desc, recorded_at desc);
create index if not exists first_aid_items_expiry_idx on public.first_aid_items(expiry_date);
create index if not exists kit_alerts_open_idx on public.kit_alerts(created_at desc) where resolved_at is null;

alter table public.kit_items enable row level security;
alter table public.first_aid_items enable row level security;
alter table public.kit_movements enable row level security;
alter table public.kit_managers enable row level security;
alter table public.kit_alerts enable row level security;
revoke all on public.kit_items, public.first_aid_items, public.kit_movements, public.kit_managers, public.kit_alerts from public, anon;
grant select, insert, update on public.kit_items, public.first_aid_items, public.kit_movements, public.kit_managers, public.kit_alerts to authenticated;
grant delete on public.kit_managers to authenticated;

create or replace function private.kit_can_manage()
returns boolean language sql stable security definer set search_path = ''
as $$
 select coalesce(private.is_active_platform_admin(auth.uid()),false)
   or coalesce(private.current_club_roles() && array['admin','chairman','secretary','team_manager']::text[],false)
   or exists(select 1 from public.kit_managers km where km.user_id=auth.uid());
$$;
create or replace function private.kit_can_read()
returns boolean language sql stable security definer set search_path = ''
as $$
 select coalesce(private.kit_can_manage(),false)
   or coalesce(private.current_club_roles() && array['coach','assistant_coach','treasurer','sponsor_lead','media_team']::text[],false)
   or exists(select 1 from public.kit_items ki where ki.custodian_id=auth.uid());
$$;
create or replace function private.kit_is_coach()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce(private.current_club_roles() && array['coach','assistant_coach']::text[],false); $$;
create or replace function private.kit_is_writer()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce(private.kit_can_manage(),false) or coalesce(private.kit_is_coach(),false); $$;

create or replace function private.kit_guard_insert()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 if not coalesce(private.kit_can_manage(),false) then raise exception 'Only kit managers and authorized officials can add kit items'; end if;
 if new.quantity_usable + new.quantity_damaged + new.quantity_missing > new.quantity_total then raise exception 'Usable + damaged + missing cannot exceed total'; end if;
 new.updated_at:=now(); new.updated_by:=auth.uid(); return new;
end; $$;
drop trigger if exists kit_items_guard_insert on public.kit_items;
create trigger kit_items_guard_insert before insert on public.kit_items for each row execute function private.kit_guard_insert();

create or replace function private.kit_guard_item_update()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_manager boolean:=coalesce(private.kit_can_manage(),false);
declare v_coach boolean:=coalesce(private.kit_is_coach(),false);
declare v_custodian boolean:=old.custodian_id=auth.uid();
declare v_action text;
declare v_qty integer;
begin
 if auth.uid() is null or not (v_manager or v_coach or v_custodian) then raise exception 'You cannot update this kit item'; end if;
 if not v_manager and v_coach then
  if new.quantity_total is distinct from old.quantity_total then raise exception 'Coaches cannot change total quantity'; end if;
  if new.custodian_id is distinct from old.custodian_id then raise exception 'Coaches cannot reassign custodians'; end if;
  if new.category is distinct from old.category or new.name is distinct from old.name or new.colour is distinct from old.colour or new.usage_type is distinct from old.usage_type or new.notes is distinct from old.notes then raise exception 'Coaches can only update status and usable/damaged/missing quantities'; end if;
 elsif not v_manager and v_custodian then
  if new.quantity_total is distinct from old.quantity_total or new.custodian_id is distinct from old.custodian_id or new.category is distinct from old.category or new.name is distinct from old.name or new.colour is distinct from old.colour or new.usage_type is distinct from old.usage_type or new.notes is distinct from old.notes then raise exception 'Custodians can only update status and quantities for assigned items'; end if;
 end if;
 if new.quantity_usable+new.quantity_damaged+new.quantity_missing>new.quantity_total then raise exception 'Usable + damaged + missing cannot exceed total'; end if;
 new.updated_at:=now(); new.updated_by:=auth.uid();
 if v_coach and coalesce(current_setting('app.kit_manual_movement',true),'false') <> 'true' then
  v_qty:=greatest(1,abs(new.quantity_missing-old.quantity_missing),abs(new.quantity_damaged-old.quantity_damaged),abs(new.quantity_usable-old.quantity_usable));
  if new.quantity_missing>old.quantity_missing then v_action:='lost';
  elsif new.quantity_damaged>old.quantity_damaged or new.status in ('needs_repair','unusable') and old.status is distinct from new.status then v_action:='damaged';
  elsif new.quantity_damaged<old.quantity_damaged or old.status in ('needs_repair','unusable') and new.status in ('good','fair') then v_action:='repaired';
  elsif new.quantity_usable<old.quantity_usable then v_action:='issued';
  elsif new.quantity_usable>old.quantity_usable then v_action:='returned';
  else v_action:='returned'; end if;
  insert into public.kit_movements(kit_item_id,action,quantity,recorded_by,notes)
  values(old.id,v_action,v_qty,auth.uid(),'Automatic audit from coach kit update.');
 end if;
 return new;
end; $$;
drop trigger if exists kit_items_guard_update on public.kit_items;
create trigger kit_items_guard_update before update on public.kit_items for each row execute function private.kit_guard_item_update();

create or replace function private.kit_guard_movement()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 if auth.uid() is null or not coalesce(private.kit_is_writer(),false) then raise exception 'You cannot record kit movements'; end if;
 new.recorded_by:=auth.uid(); new.recorded_at:=now(); return new;
end; $$;
drop trigger if exists kit_movements_guard on public.kit_movements;
create trigger kit_movements_guard before insert on public.kit_movements for each row execute function private.kit_guard_movement();

create or replace function private.kit_guard_first_aid_update()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 if coalesce(private.kit_is_coach(),false) and not coalesce(private.kit_can_manage(),false) then
  if new.kit_item_id is distinct from old.kit_item_id or new.item_name is distinct from old.item_name or new.required_qty is distinct from old.required_qty or new.expiry_date is distinct from old.expiry_date then raise exception 'Coaches may only record first aid quantities used'; end if;
  if new.current_qty>old.current_qty then raise exception 'Coaches cannot increase first aid stock'; end if;
  if new.current_qty<old.current_qty then
   insert into public.kit_movements(kit_item_id,action,quantity,recorded_by,notes)
   values(old.kit_item_id,'issued',old.current_qty-new.current_qty,auth.uid(),'First aid supplies used: '||old.item_name||'.');
  end if;
 end if;
 new.updated_at:=now(); return new;
end; $$;
drop trigger if exists first_aid_items_guard_update on public.first_aid_items;
create trigger first_aid_items_guard_update before update on public.first_aid_items for each row execute function private.kit_guard_first_aid_update();

drop policy if exists kit_items_read on public.kit_items;
create policy kit_items_read on public.kit_items for select to authenticated using (private.kit_can_read());
drop policy if exists kit_items_insert on public.kit_items;
create policy kit_items_insert on public.kit_items for insert to authenticated with check (private.kit_can_manage());
drop policy if exists kit_items_update on public.kit_items;
create policy kit_items_update on public.kit_items for update to authenticated using (private.kit_can_manage() or private.kit_is_coach() or custodian_id=auth.uid()) with check (private.kit_can_manage() or private.kit_is_coach() or custodian_id=auth.uid());
drop policy if exists kit_items_no_delete on public.kit_items;
create policy kit_items_no_delete on public.kit_items for delete to authenticated using(false);

drop policy if exists first_aid_items_read on public.first_aid_items;
create policy first_aid_items_read on public.first_aid_items for select to authenticated using(private.kit_can_read());
drop policy if exists first_aid_items_insert on public.first_aid_items;
create policy first_aid_items_insert on public.first_aid_items for insert to authenticated with check(private.kit_can_manage() and exists(select 1 from public.kit_items k where k.id=kit_item_id and k.category='first_aid_kit'));
drop policy if exists first_aid_items_update on public.first_aid_items;
create policy first_aid_items_update on public.first_aid_items for update to authenticated using(private.kit_can_manage() or private.kit_is_coach()) with check(private.kit_can_manage() or private.kit_is_coach());
drop policy if exists first_aid_items_no_delete on public.first_aid_items;
create policy first_aid_items_no_delete on public.first_aid_items for delete to authenticated using(false);

drop policy if exists kit_movements_read on public.kit_movements;
create policy kit_movements_read on public.kit_movements for select to authenticated using(private.kit_can_read());
drop policy if exists kit_movements_insert on public.kit_movements;
create policy kit_movements_insert on public.kit_movements for insert to authenticated with check(private.kit_is_writer() and recorded_by=auth.uid());
drop policy if exists kit_movements_no_update on public.kit_movements;
create policy kit_movements_no_update on public.kit_movements for update to authenticated using(false);
drop policy if exists kit_movements_no_delete on public.kit_movements;
create policy kit_movements_no_delete on public.kit_movements for delete to authenticated using(false);

drop policy if exists kit_managers_read on public.kit_managers;
create policy kit_managers_read on public.kit_managers for select to authenticated using(private.kit_can_read());
drop policy if exists kit_managers_insert on public.kit_managers;
create policy kit_managers_insert on public.kit_managers for insert to authenticated with check((coalesce(private.is_active_platform_admin(auth.uid()),false) or coalesce(private.current_club_roles() && array['admin','chairman']::text[],false)) and assigned_by=auth.uid());
drop policy if exists kit_managers_delete on public.kit_managers;
create policy kit_managers_delete on public.kit_managers for delete to authenticated using(coalesce(private.is_active_platform_admin(auth.uid()),false) or coalesce(private.current_club_roles() && array['admin','chairman']::text[],false));
drop policy if exists kit_managers_no_update on public.kit_managers;
create policy kit_managers_no_update on public.kit_managers for update to authenticated using(false);

drop policy if exists kit_alerts_read on public.kit_alerts;
create policy kit_alerts_read on public.kit_alerts for select to authenticated using(private.kit_can_read());
drop policy if exists kit_alerts_insert on public.kit_alerts;
create policy kit_alerts_insert on public.kit_alerts for insert to authenticated with check(private.kit_is_writer());
drop policy if exists kit_alerts_update on public.kit_alerts;
create policy kit_alerts_update on public.kit_alerts for update to authenticated using(private.kit_can_manage()) with check(private.kit_can_manage());
drop policy if exists kit_alerts_no_delete on public.kit_alerts;
create policy kit_alerts_no_delete on public.kit_alerts for delete to authenticated using(false);

create or replace function public.kit_get_fixtures()
returns table(fixture_id uuid,opponent text,match_date text,match_type text,match_status text)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not coalesce(private.kit_can_read(),false) then raise exception 'Not authorized'; end if;
 return query select c.id,coalesce(c.data->>'opponent','Fixture'),coalesce(c.data->>'match_date',''),coalesce(c.data->>'match_type',c.data->>'is_home',''),coalesce(c.data->>'match_status',c.data->>'status','')
 from private.club_records c where c.record_type='fixture' and lower(coalesce(c.data->>'match_type',c.data->>'is_home','')) in ('home','true','yes')
 order by c.data->>'match_date' desc;
end; $$;
revoke all on function public.kit_get_fixtures() from public,anon;
grant execute on function public.kit_get_fixtures() to authenticated;

create or replace function public.kit_get_people()
returns table(user_id uuid,display_name text,roles text[],is_kit_manager boolean)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not coalesce(private.kit_can_read(),false) then raise exception 'Not authorized'; end if;
 return query select p.user_id,coalesce(nullif(p.display_name,''),'Club member'),coalesce(array_agg(distinct ra.role_key) filter(where ra.role_key is not null and ra.active),array[]::text[]),
 exists(select 1 from public.kit_managers km where km.user_id=p.user_id)
 from private.user_profiles p left join private.role_assignments ra on ra.user_id=p.user_id
 group by p.user_id,p.display_name order by p.display_name;
end; $$;
revoke all on function public.kit_get_people() from public,anon;
grant execute on function public.kit_get_people() to authenticated;

create or replace function private.kit_notify_attention()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if tg_table_name='kit_movements' and new.action in ('lost','damaged') then
  insert into public.kit_alerts(kit_item_id,alert_type,message) values(new.kit_item_id,case when new.action='lost' then 'missing' else 'damaged' end,case when new.action='lost' then 'Kit reported lost ('||new.quantity||').' else 'Kit reported damaged ('||new.quantity||').' end);
 elsif tg_table_name='kit_items' then
  if new.status='unusable' then insert into public.kit_alerts(kit_item_id,alert_type,message) values(new.id,'unusable','Item marked unusable: '||new.name||'.'); end if;
  if new.quantity_missing>0 then insert into public.kit_alerts(kit_item_id,alert_type,message) values(new.id,'missing','Missing quantity reported for '||new.name||': '||new.quantity_missing||'.'); end if;
 elsif tg_table_name='first_aid_items' then
  if new.current_qty<new.required_qty then insert into public.kit_alerts(kit_item_id,alert_type,message) values(new.kit_item_id,'first_aid_incomplete','First aid item below required quantity: '||new.item_name||'.'); end if;
  if new.expiry_date is not null and new.expiry_date<current_date then insert into public.kit_alerts(kit_item_id,alert_type,message) values(new.kit_item_id,'first_aid_expired','Expired first aid item: '||new.item_name||'.'); end if;
 end if;
 return new;
end; $$;
drop trigger if exists kit_movement_attention_alert on public.kit_movements;
create trigger kit_movement_attention_alert after insert on public.kit_movements for each row execute function private.kit_notify_attention();
drop trigger if exists kit_item_attention_alert on public.kit_items;
create trigger kit_item_attention_alert after insert or update on public.kit_items for each row execute function private.kit_notify_attention();
drop trigger if exists kit_first_aid_attention_alert on public.first_aid_items;
create trigger kit_first_aid_attention_alert after insert or update on public.first_aid_items for each row execute function private.kit_notify_attention();


create or replace function public.kit_record_movement(
 p_kit_item_id uuid, p_action text, p_quantity integer,
 p_from_person uuid default null, p_to_person uuid default null,
 p_fixture_id uuid default null, p_movement_date date default current_date, p_notes text default null
)
returns uuid language plpgsql security definer set search_path=''
as $kit$
declare v_item public.kit_items%rowtype;
declare v_id uuid;
declare v_coach boolean:=coalesce(private.kit_is_coach(),false);
declare v_manager boolean:=coalesce(private.kit_can_manage(),false);
begin
 if auth.uid() is null or not coalesce(private.kit_is_writer(),false) then raise exception 'You cannot record kit movements'; end if;
 if p_quantity is null or p_quantity<1 then raise exception 'Quantity must be a positive whole number'; end if;
 if p_action not in ('issued','returned','lost','damaged','repaired','replaced') then raise exception 'Invalid movement action'; end if;
 select * into v_item from public.kit_items where id=p_kit_item_id for update;
 if not found then raise exception 'Kit item not found'; end if;
 if p_action in ('issued','lost','damaged') and v_item.quantity_usable<p_quantity then raise exception 'Not enough usable quantity'; end if;
 if p_action='returned' and v_item.quantity_usable+p_quantity+v_item.quantity_damaged+v_item.quantity_missing>v_item.quantity_total then raise exception 'Return quantity exceeds available total'; end if;
 if p_action='lost' and v_item.quantity_missing+p_quantity+v_item.quantity_damaged+v_item.quantity_usable-p_quantity>v_item.quantity_total then raise exception 'Missing quantity exceeds total'; end if;
 if p_action='damaged' and v_item.quantity_damaged+p_quantity+v_item.quantity_missing+v_item.quantity_usable-p_quantity>v_item.quantity_total then raise exception 'Damaged quantity exceeds total'; end if;
 perform set_config('app.kit_manual_movement','true',true);
 insert into public.kit_movements(kit_item_id,action,quantity,from_person,to_person,fixture_id,movement_date,recorded_by,notes)
 values(p_kit_item_id,p_action,p_quantity,p_from_person,p_to_person,p_fixture_id,coalesce(p_movement_date,current_date),auth.uid(),p_notes)
 returning id into v_id;
 if p_action='issued' then
  update public.kit_items set quantity_usable=quantity_usable-p_quantity,updated_by=auth.uid() where id=p_kit_item_id;
 elsif p_action='returned' then
  update public.kit_items set quantity_usable=quantity_usable+p_quantity,updated_by=auth.uid() where id=p_kit_item_id;
 elsif p_action='lost' then
  update public.kit_items set quantity_usable=quantity_usable-p_quantity,quantity_missing=quantity_missing+p_quantity,updated_by=auth.uid() where id=p_kit_item_id;
 elsif p_action='damaged' then
  update public.kit_items set quantity_usable=quantity_usable-p_quantity,quantity_damaged=quantity_damaged+p_quantity,status='needs_repair',updated_by=auth.uid() where id=p_kit_item_id;
 elsif p_action='repaired' then
  if v_item.quantity_damaged<p_quantity then raise exception 'Repair quantity exceeds damaged stock'; end if;
  update public.kit_items set quantity_damaged=quantity_damaged-p_quantity,quantity_usable=quantity_usable+p_quantity,status=case when status='needs_repair' then 'fair' else status end,updated_by=auth.uid() where id=p_kit_item_id;
 end if;
 return v_id;
end; $kit$;
revoke all on function public.kit_record_movement(uuid,text,integer,uuid,uuid,uuid,date,text) from public,anon;
grant execute on function public.kit_record_movement(uuid,text,integer,uuid,uuid,uuid,date,text) to authenticated;


commit;
