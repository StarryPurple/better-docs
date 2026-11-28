---
name: doc-migrate
description: "Execute an approved brownfield documentation migration manifest in safe, git-checkpointed batches: scaffold contracts, extract surviving rationale before touching legacy files, rebuild current-state docs from authoritative sources, verify with doc-verify, and archive or delete superseded docs last. Use only after doc-bootstrap has produced an approved migration manifest."
---

# Execute Brownfield Documentation Migration (`doc-migrate`)

Execute an approved migration manifest without losing load-bearing rationale or corrupting collaborator submodules.

## Inputs required

1. Target repository root.
2. Path to the approved migration manifest:
   - `.agents/notes/proposed/<class>/YYYY-MM-DD-doc-migration.md` (using `process` or an enabled class from `note_classes`, when `feature_notes=true`), or
   - `.agents/scratch/doc-migration.md` (untracked, when `feature_notes=false`).
3. Explicit user approval of the manifest and any `submodule_owned=` entries.

If the manifest is missing or unapproved, stop and route back to `doc-bootstrap`.

## Pre-flight checks (abort on failure)

1. **Clean working tree (exempting the manifest itself)**: run `git status --porcelain`. Ignore only the approved migration manifest file (and its `.zh.md`/`.i18n.yaml` pair if `i18n-en-zh`); if any other dirty or untracked files exist, stop and ask the user to commit or stash them into a checkpoint commit before proceeding.
2. **Stale-plan check**: compare `git rev-parse HEAD` against the manifest's `Source HEAD:` SHA. If `HEAD` moved, inspect the diff between the pinned SHA and `HEAD` and re-confirm affected manifest rows with the user before editing.
3. **Checkpoint branch**: create a dedicated migration branch (e.g., `docs/migrate-governance`) so every batch can be reviewed or rolled back cleanly.
4. **Submodule boundary check**: verify no action row targets a `submodule_shared=` or `submodule_external=` path. For any `submodule_owned=` path, verify its starting gitlink SHA matches the approved entry and run pre-flight inside that child repo independently.

## Batched execution order (extract and verify before deleting)

Commit after each batch so rollback and resume stay deterministic. Before the **first** batch that can break a manifest-recorded skill or consumer dependency (including Batch 3 in-place `REWRITE`, `SPLIT`, or `MERGE` edits that change headings or schemas), recheck that dependency: default to preserving the interface or deferring the affected row, never run blind bulk path replacement across skills, and land any explicitly approved named consumer edit in the **same checkpoint commit** as its doc change (verifying both together; where a retained old path allows staged cutover, verify the consumer against the new destination before removing the old path in Batch 4). When `language_mode=i18n-en-zh`, create matching `.zh.md` and `.i18n.yaml` files for every active `.md` file added, rewritten, or kept across Batches 1–4 (including active `.agents/notes/` and `.agents/records/` files; vendored `.agents/skills/*`, root `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md`, `*/AGENTS.md`, and `*/CLAUDE.md` are exempt from `BD060`).

### Batch 1 — Scaffold contracts, gate, and archive manifest
- Apply manifest-planned **idempotent scoped updates** to existing root `AGENTS.md` and live subtree `**/AGENTS.md` files (preserving all unrelated host commands, architecture links, non-doc contract pointers, and directory-scoped rules verbatim; later batches must not undo these Batch 1 merges); scaffold missing files or sections from templates for `AGENTS.md`, `CLAUDE.md -> AGENTS.md`, `docs/AGENTS.md` (recording any preserved architecture doc as active current-state documentation with its owner), optional `<subtree>/AGENTS.md` files (for every configured `subtree=`, satisfying `BD003`), `docs-check.conf`, `.gitignore` (ignoring `.agents/scratch/` while preserving existing ignore rules and negations, verified via `git check-ignore`), `.agents/notes/` / `.agents/records/` skeletons (if enabled), optional vendored steady-state skills under `.agents/skills/`, the check gate (`scripts/check-docs.sh` or repo-native gate), and matching configs from `gates/optional/` (`lychee.toml`, `vale.ini`, and `vale-styles/`) for any approved built-in hooks (preserving verified existing configs).
- Leave unrelated native tool configs and non-doc contracts untouched. Apply only the exact local git-hook runner or CI workflow edits explicitly approved in the manifest, preserving unrelated hook jobs and formatter-before-check ordering.
- When `feature_archive_seal=true`, initialize `.agents/notes/archived/manifest.sha256` with `<gate-command> --seal` so `BD040` passes during subsequent batches.
- Commit batch 1 (do not stage `.agents/scratch/doc-migration.md` when `feature_notes=false`).

### Batch 2 — Extract surviving rationale and falsified theory first
- Process all `EXTRACT_NOTE`, `EXTRACT_RECORD`, and manifest `FALSIFIED` theory-triage rows **before** deleting or moving any legacy source or rewriting theory.
- For `FALSIFIED` theory-triage rows, always write falsification rationale to the **exact evidence destination approved in the manifest** (never override an approved durable/external destination with repo notes, and never write `.agents/notes/concluded/` when `feature_empirical_records=false`).
- When `feature_notes=true`, write `EXTRACT_NOTE` decisions into `.agents/notes/implemented/<class>/` (present tense) or `.agents/notes/rejected/<class>/` (for plausible traps and falsified assumptions routed there by the manifest).
- For legacy notes whose original alternatives cannot be reconstructed, add their exact relative path to `grandfathered_note=` in `docs-check.conf` rather than inventing alternatives.
- For empirical/audit evidence (`feature_empirical_records=true`), write curated summaries with provenance pointers into `.agents/records/<study-id>/` and distill conclusions into `.agents/notes/concluded/<class>/`.
- Apply `prose-standard` to all newly created notes.
- Commit batch 2.

### Batch 3 — Rebuild and verify canonical docs
- Process all `REWRITE`, `SPLIT`, and `MERGE` rows.
- Treat legacy prose as a checklist of topics only—never copy AI-slop text forward.
- Ground every claim in authoritative sources:
  - Code behavior, flags, schemas, and commands → verify against source code, tests, and executed commands.
  - Non-code operational procedures, support commitments, or primary-source surveys → verify against named owners, configs, or primary citations listed in the manifest.
- When the theory tier is enabled:
  - If the manifest approves in-repo `docs/theory.md` storage, synthesize surviving working theory from approved `KEEP_THEORY` rows after Batch 2 extractions land, preserve `UNRESOLVED` claims explicitly labeled as open/unresolved, never claim unbuilt theory is shipped in code, and honor the approved `README.md`-linked vs. unlisted-in-`README.md` visibility.
  - If the manifest approves confidential external/private storage, write or hand off surviving theory to that private destination and omit any in-repo `docs/theory.md` file and public links.
- When root `ROADMAP.md` is enabled: seed it strictly from approved `Confirmed roadmap seed` rows (or leave it empty); never blindly copy legacy `TODO.md` lines.
- Apply `prose-standard` throughout.
- Run `doc-verify` (fresh-context subagent or human-reviewer checklist) on the rebuilt docs and resolve every factual finding.
- Commit batch 3.

### Batch 4 — Cutover, cleanup, and receipt (last)
- Verify every replacement doc exists and passed `doc-verify`.
- Update all inbound relative links, anchors, and any documented published-URL redirects.
- Execute `ARCHIVE` and `DELETE` rows only now (deferred `KEEP` rows stay in place with their follow-up note, or an issue / `.agents/scratch/` item when `feature_notes=false`).
- Record a compact cutover receipt (source SHA, action counts, verification summary) and finalize the migration manifest **before** running the final gate check:
  - `feature_notes=true` + `feature_archive_seal=true`: rewrite the migration note to `implemented/` grammar (`Status: implemented`, `## Decision`, `## Consequences`, removing `## Proposal`/`## Plan`/`## Migration plan`/`## Acceptance criteria`), move it (along with its `.zh.md` and `.i18n.yaml` siblings if `language_mode=i18n-en-zh`) to `.agents/notes/archived/<class>/`, and seal with `<gate-command> --seal`.
  - `feature_notes=true` + `feature_archive_seal=false`: rewrite the migration note to `implemented/` grammar (`Status: implemented`, `## Decision`, `## Consequences`, removing proposal-era headings) and move it (along with its `.zh.md` and `.i18n.yaml` siblings if `language_mode=i18n-en-zh`) to `.agents/notes/implemented/<class>/`.
  - `feature_notes=false`: delete `.agents/scratch/doc-migration.md` and include the receipt in the batch 4 commit message.
- Run the repo's configured deterministic check gate (e.g., `./scripts/check-docs.sh` or repo-native gate) and confirm exit code `0`.
- Commit batch 4.

## Recursive submodule completion order

When `submodule_owned=` repos were migrated:
1. Complete batches 1–4 and pass the gate independently inside each child repo first.
2. Verify each child repo's new commit is pushed to its remote (or explicitly notify the user that the child commit is local-only) **before** updating the parent's gitlink pin.
3. Commit the parent's updated gitlink pointers last.
