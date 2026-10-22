-- Enforce accepted proposal immutability at the database boundary and protect
-- proposal version numbering against duplicate concurrent writes.
-- Candidate migration only; do not apply to production without explicit approval.
begin;

-- The save RPC locks the parent proposal before allocating the next version.
-- This unique index is the final integrity guard if another write path is added.
create unique index if not exists sponsor_proposal_versions_proposal_version_uq
  on private.sponsor_proposal_versions (proposal_id, version_no);

create or replace function private.sponsor_proposal_immutable_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'accepted' then
      raise exception 'Accepted proposals are immutable';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.status = 'accepted' then
    raise exception 'Accepted proposals are immutable';
  end if;

  return new;
end
$$;

revoke all on function private.sponsor_proposal_immutable_guard() from public, anon, authenticated;

drop trigger if exists sponsor_proposals_immutable_guard on private.sponsor_proposals;
create trigger sponsor_proposals_immutable_guard
before update or delete on private.sponsor_proposals
for each row execute function private.sponsor_proposal_immutable_guard();

create or replace function private.sponsor_proposal_version_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  proposal_id_to_check uuid;
  proposal_status text;
begin
  if tg_op = 'DELETE' then
    proposal_id_to_check := old.proposal_id;
  else
    proposal_id_to_check := new.proposal_id;
  end if;

  if tg_op = 'UPDATE' and old.proposal_id is distinct from new.proposal_id then
    raise exception 'Proposal version cannot be moved to another proposal';
  end if;

  -- Lock the parent row to serialize version changes against acceptance.
  select p.status into proposal_status
  from private.sponsor_proposals p
  where p.id = proposal_id_to_check
  for update;

  if proposal_status is null then
    raise exception 'Proposal not found for version';
  end if;

  if proposal_status = 'accepted' then
    raise exception 'Versions of accepted proposals are immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;

revoke all on function private.sponsor_proposal_version_guard() from public, anon, authenticated;

drop trigger if exists sponsor_proposal_versions_immutable_guard on private.sponsor_proposal_versions;
create trigger sponsor_proposal_versions_immutable_guard
before insert or update or delete on private.sponsor_proposal_versions
for each row execute function private.sponsor_proposal_version_guard();

commit;
