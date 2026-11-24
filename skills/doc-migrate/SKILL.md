---
name: doc-migrate
description: "Execute an approved brownfield documentation migration manifest in safe, git-checkpointed batches: scaffold contracts, extract surviving rationale before touching legacy files, rebuild current-state docs from authoritative sources, verify with doc-verify, and quarantine or delete superseded docs last. Use only after doc-bootstrap has produced an approved migration manifest."
---

# Execute Brownfield Documentation Migration (`doc-migrate`)

Execute an approved migration manifest without losing load-bearing rationale or corrupting collaborator submodules.

## Inputs required

1. Target repository root.
2. Path to the approved migration manifest:
   - `.agents/notes/proposed/process/YYYY-MM-DD-doc-migration.md` (when `feature_notes=true`), or
   - `.agents/scratch/doc-migration.md` (when `feature_notes=false`).
3. Explicit user approval of the manifest and any `submodule_owned=` entries.

If the manifest is missing or unapproved, stop and route back to `doc-bootstrap`.

## Pre-flight checks (abort on failure)

1. **Clean working tree**: run `git status --porcelain`. If dirty or untracked files exist, stop and ask the user to commit or stash them into a checkpoint commit before proceeding.
2. **Stale-plan check**: compare `git rev-parse HEAD` against the manifest's `Source HEAD:` SHA. If `HEAD` moved, inspect the diff between the pinned SHA and `HEAD` and re-confirm affected manifest rows with the user before editing.
3. **Checkpoint branch**: create a dedicated migration branch (e.g., `docs/migrate-governance`) so every batch can be reviewed or rolled back cleanly.
4. **Submodule boundary check**: verify no action row targets a `submodule_shared=` or `submodule_external=` path. For any `submodule_owned=` path, verify its starting gitlink SHA matches the approved entry and run pre-flight inside that child repo independently.

## Batched execution order (extract and verify before deleting)

Commit after each batch so rollback and resume stay deterministic.

### Batch 1 — Scaffold contracts and gate
- Write `AGENTS.md`, `CLAUDE.md -> AGENTS.md`, `docs/AGENTS.md`, `docs-check.conf`, `.gitignore` (ignoring `.agents/scratch/`), `.agents/notes/` / `.agents/records/` skeletons (if enabled), and the check gate (`scripts/check-docs.sh` or repo-native gate).
- Commit batch 1.

### Batch 2 — Extract surviving rationale first (when `feature_notes=true`)
- Process all `EXTRACT_NOTE` and `EXTRACT_RECORD` rows **before** deleting or moving any legacy source.
- Write extracted decisions into `.agents/notes/implemented/<class>/` (present tense) or `.agents/notes/rejected/<class>/` (only for plausible, tempting traps).
- For legacy notes whose original alternatives cannot be reconstructed, add their exact relative path to `grandfathered_note=` in `docs-check.conf` rather than inventing alternatives.
- For empirical/audit evidence (`feature_empirical_records=true`), write curated summaries with provenance pointers into `.agents/records/<study-id>/` and distill conclusions into `.agents/notes/concluded/<class>/`.
- Apply `prose-standard` to all newly created notes.
- Commit batch 2.

### Batch 3 — Rebuild and verify canonical current-state docs
- Process all `REWRITE`, `SPLIT`, and `MERGE` rows.
- Treat legacy prose as a checklist of topics only—never copy AI-slop text forward.
- Ground every claim in authoritative sources:
  - Code behavior, flags, schemas, and commands → verify against source code, tests, and executed commands.
  - Non-code operational procedures, support commitments, or primary-source surveys → verify against named owners, configs, or primary citations listed in the manifest.
- Apply `prose-standard` throughout.
- Run `doc-verify` (fresh-context subagent or human-reviewer checklist) on the rebuilt docs and resolve every factual finding.
- Commit batch 3.

### Batch 4 — Cutover, cleanup, and receipt (last)
- Verify every replacement doc exists and passed `doc-verify`.
- Update all inbound relative links, anchors, and any documented published-URL redirects.
- Execute `QUARANTINE`, `ARCHIVE`, and `DELETE` rows only now.
- Run the deterministic check gate (`./scripts/check-docs.sh` or `gates/check-docs.sh`) and confirm exit code `0`.
- Record a compact cutover receipt (source SHA, action counts, gate output):
  - `feature_notes=true` + `feature_archive_seal=true`: promote the migration note to `implemented/`, then archive it under `.agents/notes/archived/process/` and run `--seal`.
  - `feature_notes=true` + `feature_archive_seal=false`: promote the migration note to `.agents/notes/implemented/process/`.
  - `feature_notes=false`: delete `.agents/scratch/doc-migration.md` and include the receipt in the batch 4 commit message.
- Commit batch 4.

## Recursive submodule completion order

When `submodule_owned=` repos were migrated:
1. Complete batches 1–4 and pass the gate independently inside each child repo first.
2. Verify each child repo's new commit is pushed to its remote (or explicitly notify the user that the child commit is local-only) **before** updating the parent's gitlink pin.
3. Commit the parent's updated gitlink pointers last.
