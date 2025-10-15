# Plans & Tickets

This repository uses a lightweight, file‑based planning system mirrored from other Flora apps.

Guidelines:
- All work starts as a ticket in `docs/plans/`.
- Only implement once the ticket/spec is explicit and accepted.
- Keep tickets terse, actionable, and source‑controlled.

Directory layout:
- `docs/plans/todo/` — newly proposed tickets and backlog items.
- `docs/plans/active/` — currently in progress.
- `docs/plans/complete/` — completed tickets (optional archive).
- `_index.md` — backlog index per folder.

Ticket filename format:
- `NNNN-type-slug.md` where `type ∈ {bug,feature,task,runbook,research}`.

Required sections:
- Summary
- Problem / Context
- Scope (in/out)
- Implementation Plan (steps)
- Acceptance Criteria
- Risks & Rollback
- Owners & Timeline
- Evidence & References

Lux memory pin: Track all tickets/issues only under `docs/plans/*` across this workspace.

