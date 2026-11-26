---
name: doc-garden
description: "Maintain an already-bootstrapped repository's documentation health: detect code-to-doc drift, enforce wordcount budgets, run Agent Note supersession and archival sealing, distill concluded empirical studies in place, check i18n freshness, and flag kit_version drift. Use periodically, before major releases, or after large architectural/experimental milestones."
---

# Documentation Gardening and Lifecycle Maintenance (`doc-garden`)

Keep active documentation current, lean, and verified without deleting load-bearing rationale.

## Scope and guardrails

- Read `AGENTS.md`, `docs/AGENTS.md`, and `docs-check.conf` first.
- Never edit `vendor/`, `node_modules/`, `.agents/notes/archived/`, already-concluded `.agents/records/<study-id>/`, or `submodule_shared=` / `submodule_external=` paths.
- For `submodule_owned=` paths, garden, validate, commit, and verify push reachability inside the child repo first before updating parent gitlink pins.
- Never archive toward a quota or by file age; judge every note semantically by future decision value.
- Preserve any durable skill/script doc interfaces linked from `docs/AGENTS.md` (or an applicable `<subtree>/AGENTS.md`) across prose edits, note moves, consolidations, and deletions; report interface conflicts for the user or owner to resolve instead of auto-invoking companion skills or editing unapproved skill files.

## Maintenance passes

Run only the passes applicable to the features enabled in `docs-check.conf`:

### 1. Deterministic gate & kit-version check
1. Run the repo's configured check-gate command with `--probes` (adding `--list-budgets` when `feature_budgets=true`, e.g., `./scripts/check-docs.sh --probes --list-budgets`).
2. Fix any hard failures (`BD001`–`BD070`), including any accidentally tracked `.agents/scratch/` files (`BD001`).
3. Compare `kit_version` in `docs-check.conf` against `<gate-command> --version` (and the local `better-docs` kit checkout if present); report drift if a newer kit version is available.

### 2. Budget and drift audit
- For any standing doc approaching or exceeding its `budget=` ceiling (`BD010`), follow the strict order:
  1. **Relocate** content owned by a narrower tier and leave a one-line link.
  2. **Condense** prose via `prose-standard` while preserving every factual proposition.
  3. **Raise** the ceiling only when required facts genuinely need the space, with justification in the commit/PR.
- Cross-check commands, flags, file paths, and package lists in `AGENTS.md` and `docs/` against current source and tests. Update stale facts in place.
- When `docs/theory.md` is present: keep its epistemic-status header accurate, rewrite revised assumptions cleanly in place without change narration, and verify overturned hypotheses record their falsification rationale in the repo's configured evidence destination before deleting or replacing them.
- When root `ROADMAP.md` is present:
  - Use promoted `implemented/` or `concluded/` notes (when `feature_notes=true`, regardless of recency) strictly as evidence *leads*—verify each row's actual done condition before ticking `[x]`.
  - Delete checked `[x]` rows at milestone or cycle close; delete open `[ ]` rows **only** on explicit collaborator cancellation or supersession (age, a broken link, or a similar note title is never sufficient).
  - Verify linked paths resolve and bounce multi-paragraph spec bloat to `.agents/notes/proposed/` (when `feature_notes=true`) or issue threads; never add new unagreed rows without explicit collaborator authorization.
- Check `i18n-en-zh` sidecars (when enabled) for stale `source_sha256` entries (`BD060`) and sync counterparts semantically before refreshing hashes.

### 3. Agent Note supersession, consolidation, and archival (`feature_notes=true`)
Apply the three-way deletion vs. recording filter and classify each active note in scope:

- **`implemented/` — delete**: purely mechanical or trivial local edits with no lasting architectural, compatibility, or ownership rule; repair or remove inbound links.
- **`implemented/` — keep active**: rationale, rejected alternatives, negative guarantees, wire/storage semantics, ownership boundaries, security rules, or reintroduction conditions still guide future work. Update shipped paths/symbols in place if code moved.
- **`implemented/` — consolidate**: when a newer note fully supersedes an older one, absorb every unique rationale, alternative, consequence, and verification gap into the new owner, repair inbound links, and delete the old note. Keep partial supersessions active and cross-linked.
- **`implemented/` — archive**: complete substantive historical decisions unlikely to guide future changes. Move to `.agents/notes/archived/<class>/` (along with `.zh.md` and `.i18n.yaml` siblings if `language_mode=i18n-en-zh`), repair or retarget inbound links from active prose, and seal with `<gate-command> --seal` when `feature_archive_seal=true`. Never edit sealed files afterward.
- **`proposed/` — never archive**: either promote to `implemented/` (rewriting to present tense and removing `## Proposal`/`## Plan`/`## Migration plan`/`## Acceptance criteria`), promote to `concluded/` (for empirical studies), move to `rejected/` (only if it prevents a plausible, tempting mistake), or **delete outright** if discarded due to incomplete reasoning.
- **`rejected/` — prune**: keep while the losing option remains a plausible temptation OR while it is the sole preserved falsification rationale for an overturned premise in `docs/theory.md`; delete outright once obsolete and superseded.

### 4. Empirical study distillation (`feature_empirical_records=true`)
For active studies under `.agents/records/<study-id>/`:
1. Confirm raw large artifacts (checkpoints, huge logs) are stored externally and only curated summaries + provenance pointers remain in git.
2. When a study reaches a verdict or pivot, distill the takeaway into `.agents/notes/concluded/<class>/YYYY-MM-DD-<slug>.md` linking `.agents/records/<study-id>/`.
3. Change **line 3** of `.agents/records/<study-id>/README.md` (or `index.md`) to exact `Status: concluded` (freezing the study **in place** so links never break). When `language_mode=i18n-en-zh`, update its `.zh.md` counterpart and `.i18n.yaml` (`source_sha256`) **before** sealing; then run `<gate-command> --seal` when `feature_archive_seal=true`.
4. If a newer experiment overturns an earlier `concluded/` note, create a new `concluded/` note explicitly superseding and cross-linking the older one.

## Report

Summarize: checks run, hard failures fixed, budget changes, notes kept/consolidated/archived/deleted, studies distilled/sealed, and any genuinely borderline decisions for user review.
