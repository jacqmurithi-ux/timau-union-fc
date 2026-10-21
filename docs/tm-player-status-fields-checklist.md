# Team Manager structured player-status fields — test checklist

- [ ] Team Manager can create/edit a Squad admin record with player name, position, age group, availability status, and fitness status.
- [ ] TM-only contact availability and notes remain restricted to TM/admin roles; Coach never receives those keys.
- [ ] Team Manager can record structured availability, fitness, return-to-training, cards, and suspension status in Discipline & welfare.
- [ ] Coach squad list shows only position, age group, availability and fitness fields from Squad admin records.
- [ ] Coach injuries/fitness panel shows only structured availability, fitness and return status; no free-text welfare notes or private case details.
- [ ] Coach discipline panel shows only cards and suspension status.
- [ ] Coach cannot create/edit TM records or access TM save RPC.
- [ ] Existing TM draft/approval lifecycle remains intact; edits return records to draft.
- [ ] Other non-TM roles retain their existing permissions.
- [ ] Verify migration on a disposable Supabase project before production application.
- [ ] Verify older records with no structured values display as unknown/blank; do not infer status from old free text.
