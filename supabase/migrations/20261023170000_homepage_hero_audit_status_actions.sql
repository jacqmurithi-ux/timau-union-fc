-- Extend the hero audit action allowlist for explicit draft/publish transitions.
alter table private.homepage_hero_audit
  drop constraint if exists homepage_hero_audit_action_key_check;

alter table private.homepage_hero_audit
  add constraint homepage_hero_audit_action_key_check
  check (action_key = any (array[
    'created',
    'updated',
    'removed',
    'expired',
    'image_replaced',
    'reordered',
    'created_as_draft',
    'updated_as_draft',
    'approved_and_published',
    'returned_to_draft'
  ]::text[]));
