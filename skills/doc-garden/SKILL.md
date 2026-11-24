---
name: doc-garden
description: "Maintain an already-bootstrapped repository's documentation health: detect code-to-doc drift, enforce wordcount budgets, run Agent Note supersession and archival sealing, distill concluded empirical studies in place, check i18n freshness, and flag kit_version drift. Use periodically, before major releases, or after large architectural/experimental milestones."
---

# Documentation Gardening and Lifecycle Maintenance (`doc-garden`)

Keep active documentation current, lean, and verified without deleting load-bearing rationale.

## Scope and guardrails

- Read `AGENTS.md`, `docs/AGENTS.md`, and `docs-check.conf` first.
- Never edit `vendor/`, `node_modules/`, `.agents/notes/archived/`, already-concluded `.agents/records/<study-id>/`, or `submodule_shared=` / `submodule_external=` paths.
- Never archive toward a quota or by file age; judge every note semantically by future decision value.

## Maintenance passes

Run only the passes applicable to the features enabled in `docs-check.conf`:

### 1. Deterministic gate & kit-version check
1. Run `./gates/check-docs.sh --probes --list-budgets` (or the repo's configured gate command).
2. Fix any hard failures (`BD001`–`BD070`), including any accidentally tracked `.agents/scratch/` files (`BD001`).
3. Compare `kit_version` in `docs-check.conf` against the installed/vendored `better-docs` version; report drift if a newer kit version is available.

### 2. Budget and drift audit
- For any standing doc approaching or exceeding its `budget=` ceiling (`BD010`), follow the strict order:
  1. **Relocate** content owned by a narrower tier and leave a one-line link.
  2. **Condense** prose via `prose-standard` while preserving every factual proposition.
  3. **Raise** the ceiling only when required facts genuinely need the space, with justification in the commit/PR.
- Cross-check commands, flags, file paths, and package lists in `AGENTS.md` and `docs/` against current source and tests. Update stale facts in place.
- Check `i18n-en-zh` sidecars (when enabled) for stale `source_sha256` entries (`BD060`) and sync counterparts semantically before refreshing hashes.

### 3. Agent Note supersession, consolidation, and archival (`feature_notes=true`)
Apply the three-way deletion vs. recording filter and classify each active note in scope:

- **`implemented/` — delete**: purely mechanical or trivial local edits with no lasting architectural, compatibility, or ownership rule; repair or remove inbound links.
- **`implemented/` — keep active**: rationale, rejected alternatives, negative guarantees, wire/storage semantics, ownership boundaries, security rules, or reintroduction conditions still guide future work. Update shipped paths/symbols in place if code moved.
- **`implemented/` — consolidate**: when a newer note fully supersedes an older one, absorb every unique rationale, alternative, consequence, and verification gap into the new owner, repair inbound links, and delete the old note. Keep partial supersessions active and cross-linked.
- **`implemented/` — archive**: complete substantive historical decisions unlikely to guide future changes. Move to `.agents/notes/archived/<class>/`, repair or retarget inbound links from active prose, and seal with `--seal` when `feature_archive_seal=true`. Never edit sealed files afterward.
- **`proposed/` — never archive**: either promote to `implemented/` (rewriting to present tense and removing `## Proposal`/`## Plan`/`## Acceptance criteria`), promote to `concluded/` (for empirical studies), move to `rejected/` (only if it prevents a plausible, tempting mistake), or **delete outright** if discarded due to incomplete reasoning.
- **`rejected/` — prune**: keep only while the losing option remains a plausible temptation; delete outright once obsolete.

### 4. Empirical study distillation (`feature_empirical_records=true`)
For active studies under `.agents/records/<study-id>/`:
1. Confirm raw large artifacts (checkpoints, huge logs) are stored externally and only curated summaries + provenance pointers remain in git.
2. When a study reaches a verdict or pivot, distill the takeaway into `.agents/notes/concluded/<class>/YYYY-MM-DD-<topic>.md` linking `.agents/records/<study-id>/`.
3. Mark `Status: concluded` in `.agents/records/<study-id>/README.md` (freezing the study **in place** so links never break) and seal with `--seal` when `feature_archive_seal=true`.
4. If a newer experiment overturns an earlier `concluded/` note, create a new `concluded/` note explicitly superseding and cross-linking the older one.

## Report

Summarize: checks run, hard failures fixed, budget changes, notes kept/consolidated/archived/deleted, studies distilled/sealed, and any genuinely borderline decisions for user review.
