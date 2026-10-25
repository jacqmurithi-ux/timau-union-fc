-- Minimal disposable fixture for the finance approval RPC migration.
-- This fixture is test-only and must never be run against production.
begin;

do $roles$
begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end
$roles$;

create schema if not exists auth;
create schema if not exists private;

create or replace function auth.uid()
returns uuid
language sql stable
as $uid$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$uid$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;

create or replace function private.is_active_platform_admin(_user_id uuid)
returns boolean
language sql stable
as $admin$
 select coalesce(current_setting('test.platform_admin',true),'false')='true'
$admin$;

create or replace function private.current_club_roles()
returns text[]
language sql stable
as $roles$
 select coalesce(string_to_array(nullif(current_setting('test.club_roles',true),''),','),array[]::text[])
$roles$;

create table private.club_financial_expenses (
 id uuid primary key,
 category text not null,
 description text not null,
 amount_kes numeric(12,2) not null check(amount_kes>0),
 expense_date date not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 squad_number text not null default 'N/A',
 created_by uuid not null,
 reviewed_by uuid,
 reviewed_at timestamptz,
 review_reason text,
 approved_ledger_entry_id uuid,
 updated_by uuid,
 updated_at timestamptz
);

create table private.club_financial_ledger (
 id uuid primary key default gen_random_uuid(),
 entry_type text not null,
 amount_kes numeric(12,2) not null,
 description text not null,
 source_expense_id uuid not null references private.club_financial_expenses(id),
 transaction_date date not null default current_date,
 actor_user_id uuid not null,
 approved_by uuid not null,
 created_at timestamptz not null default now()
);

create table private.club_financial_audit (
 id uuid primary key default gen_random_uuid(),
 actor_user_id uuid not null,
 expense_id uuid not null references private.club_financial_expenses(id),
 action_key text not null,
 old_data jsonb not null,
 new_data jsonb not null,
 old_status text not null,
 new_status text not null,
 is_admin_override boolean not null,
 reason text not null,
 created_at timestamptz not null default now()
);

grant usage on schema public,private to authenticated;
grant execute on function private.is_active_platform_admin(uuid),private.current_club_roles() to authenticated;

insert into private.club_financial_expenses(id,category,description,amount_kes,expense_date,status,created_by)
values
 ('20000000-0000-0000-0000-000000000001','Transport','Admin guard test',500,'2026-10-25','pending','10000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002','Refreshments','Treasurer approval test',750,'2026-10-25','pending','10000000-0000-0000-0000-000000000002'),
 ('20000000-0000-0000-0000-000000000003','Equipment','Self approval test',250,'2026-10-25','pending','10000000-0000-0000-0000-000000000003'),
 ('20000000-0000-0000-0000-000000000004','Meals','Rejection test',300,'2026-10-25','pending','10000000-0000-0000-0000-000000000004');

commit;
