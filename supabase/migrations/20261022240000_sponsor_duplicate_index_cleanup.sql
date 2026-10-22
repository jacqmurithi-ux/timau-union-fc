-- Remove redundant unique index: the UNIQUE constraint already enforces
-- (proposal_id, version_no), so keeping a second identical index wastes writes.
begin;
drop index if exists private.sponsor_proposal_versions_proposal_version_uq;
commit;
