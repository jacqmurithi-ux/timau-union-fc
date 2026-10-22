-- Fix the shared alert trigger: branch on table name before touching table-specific NEW fields.
create or replace function private.kit_notify_attention()
returns trigger
language plpgsql
security definer
set search_path=''
as $kit_alert$
begin
 if tg_table_name='kit_movements' then
  if new.action in ('lost','damaged') then
   insert into public.kit_alerts(kit_item_id,alert_type,message)
   values(new.kit_item_id,
     case when new.action='lost' then 'missing' else 'damaged' end,
     case when new.action='lost' then 'Kit reported lost ('||new.quantity||').' else 'Kit reported damaged ('||new.quantity||').' end);
  end if;
 elsif tg_table_name='kit_items' then
  if new.status='unusable' and not exists(
    select 1 from public.kit_alerts a where a.kit_item_id=new.id and a.alert_type='unusable' and a.resolved_at is null
  ) then
   insert into public.kit_alerts(kit_item_id,alert_type,message)
   values(new.id,'unusable','Item marked unusable: '||new.name||'.');
  end if;
  if new.quantity_missing>0 and not exists(
    select 1 from public.kit_alerts a where a.kit_item_id=new.id and a.alert_type='missing' and a.resolved_at is null
  ) then
   insert into public.kit_alerts(kit_item_id,alert_type,message)
   values(new.id,'missing','Missing quantity reported for '||new.name||': '||new.quantity_missing||'.');
  end if;
 elsif tg_table_name='first_aid_items' then
  if new.current_qty<new.required_qty and not exists(
    select 1 from public.kit_alerts a where a.kit_item_id=new.kit_item_id and a.alert_type='first_aid_incomplete'
      and a.message like '%'||new.item_name||'%' and a.resolved_at is null
  ) then
   insert into public.kit_alerts(kit_item_id,alert_type,message)
   values(new.kit_item_id,'first_aid_incomplete','First aid item below required quantity: '||new.item_name||'.');
  end if;
  if new.expiry_date is not null and new.expiry_date<current_date and not exists(
    select 1 from public.kit_alerts a where a.kit_item_id=new.kit_item_id and a.alert_type='first_aid_expired'
      and a.message like '%'||new.item_name||'%' and a.resolved_at is null
  ) then
   insert into public.kit_alerts(kit_item_id,alert_type,message)
   values(new.kit_item_id,'first_aid_expired','Expired first aid item: '||new.item_name||'.');
  end if;
 end if;
 return new;
end;
$kit_alert$;
