---
name: doc-bootstrap
description: "Audit a repository or project plan, evaluate whether documentation governance adds value (or recommend skipping), grill on project traits, and produce tailored documentation contracts (AGENTS.md, docs/AGENTS.md, docs-check.conf) plus a brownfield migration manifest when legacy docs exist. Use when initializing documentation governance on a multi-session or growing repository; skip for single-README tools or disposable scripts."
---

# Bootstrap Documentation Governance (`doc-bootstrap`)

Inspect the target repository (or project plan), resolve project-trait choices with the user, and produce thin, declarative repository contracts—never regenerating universal prose or migration skills inside the target repo.

Read [references/discovery-checklist.md](references/discovery-checklist.md) for the five discovery topics and capability mapping, and [references/grill-protocol.md](references/grill-protocol.md) for the interactive grill rules.

## Mode detection

Classify the target into one of three starting states before proposing files:

1. **Inception / exploration (empty folder or idea only in the developer's head)**:
   - If the folder is empty or not yet a git repo, do not fail inspection; offer two paths:
     - **Disposable exploration**: keep rough brainstorming in untracked scratch (runtime scratch dir or `.gitignore`d `.agents/scratch/`) and defer bootstrapping until a direction converges.
     - **Seed from an idea**: offer to run `git init` (if missing), run the conditional 5-topic grill, scaffold minimal contracts plus an honest 3-line `README.md` stub (plus opt-in `docs/theory.md` populated from the theory grill and/or root `ROADMAP.md` seeded with confirmed near-term tasks or left empty when selected), and interview the developer to write the first concrete `.agents/notes/proposed/<class>/YYYY-MM-DD-<slug>.md` (only when `feature_notes=true`; or `.agents/records/<study-id>/README.md` when `feature_empirical_records=true`; otherwise keep rough plans in `.agents/scratch/`). Never put unbuilt feature specs into current-state `docs/`.
2. **Greenfield (converged plan, little or no code)**:
   - Never place unimplemented feature specs or target code-architecture skeletons inside current-state `docs/` (the opt-in `docs/theory.md` working formulation and root `ROADMAP.md` agreed-task board are explicitly declared non-current-state tiers when enabled).
   - With `feature_notes=true`, place unagreed or unimplemented feature/architecture proposals in `.agents/notes/proposed/<class>/`; keep `README.md` and current-state `docs/` strictly to what exists at `HEAD`, linking to active `proposed/` notes (and optionally `docs/theory.md` with a working-formulation notice if `README.md` visibility was chosen).
   - With `feature_notes=false`, keep unimplemented plans in untracked `.agents/scratch/` until code exists.
3. **Brownfield (existing repo with legacy docs or clutter)**:
   - Run **read-only first**. Make zero destructive edits and do not overwrite existing repository contracts during bootstrap—leave contract scaffolding to `doc-migrate` Batch 1 so the working tree stays clean for pre-flight checks.
   - Present proposed contract drafts and write a reviewable **migration manifest** for `doc-migrate`.

## Workflow

### 1. Read-only inspection

Inspect the target root without modifying files:

1. Check git state (`git rev-parse --is-inside-work-tree`, `git status --short`, current `HEAD` SHA if commits exist, `.gitmodules`, tracked `.agents/scratch/`). Treat a non-git or empty directory cleanly as **Inception** mode.
2. Inventory existing Markdown files, `AGENTS.md`, `CLAUDE.md`, live subtree `**/AGENTS.md` files (excluding templates, fixtures, generated/vendored trees, and paths behind gitlinks), existing architecture or non-doc contracts, package/workspace manifests, native tool configs (`.editorconfig`, `.gitattributes`, formatter/linter/hook/CI configs), existing doc-check scripts, and repo-local skill/instruction entry points (`.agents/skills/*/SKILL.md`, `.claude/skills/`, `.cursor/rules/`, `.github/copilot-instructions.md` — skipping symlinks and stopping at gitlinks). For brownfield repos, read relevant in-repo `references/`, `scripts/`, or configs linked from those skills and treat literal path grep hits strictly as leads to identify doc paths, headings, or schemas that existing consumers depend on.
3. Detect default-closed gitlinks (`.gitmodules` and recursive child `.gitmodules`), third-party/generated doc directories (candidates for `exclude=`), and any existing repo check entrypoints (`Makefile`, `justfile`, `package.json`, `AGENTS.md`). Do not descend into any submodule until the user classifies it as `owned`.
4. In brownfield mode, run the advisory EN/ZH recall probes from `prose-standard` (`references/recall-batteries.md`) to surface CoT leakage, change narration, and duplicate docs.

### 1b. Step 0 — Applicability gate (Apply vs. Skip)

Before grilling or scaffolding, judge whether adding `better-docs` brings net value over existing repo tooling:

- **Recommend `Skip`**: if a single `README.md` covers the repository, the folder is a disposable script/prototype, or an equivalent maintained documentation gate already covers the repo's needs. State the reason clearly and **stop without writing files** unless the user explicitly chooses to proceed.
- **Recommend `Apply`**: propose a concrete preset (**Lean** for lightweight link/hygiene + `AGENTS.md`/`docs/AGENTS.md`; **Strict** for multi-session repos needing notes, budgets, or archive seals) and proceed to discovery.

### 2. Conditional discovery grill

Follow [references/grill-protocol.md](references/grill-protocol.md):

1. Present detected signals and a **complete ready-to-apply default proposal** (fast path). If the repo is straightforward and the user accepts the proposal, proceed directly without multi-round interrogation; grill only where judgment, ambiguity, or destructive brownfield actions apply.
2. **Confirm Language & i18n first** (`single-en`, `single-zh`, `split-by-surface`, `i18n-en-zh`).
3. Grill across the remaining discovery topics, skipping follow-ups that do not apply:
   - Epistemic, theory, and planning needs (`feature_notes`, `feature_empirical_records`, note classes, opt-in `docs/theory.md` with problem/domain/notation/assumptions/failure criteria/evidence destination/visibility-or-confidentiality, opt-in root `ROADMAP.md` with confirmed seed rows and done conditions)
   - Structure & ownership (approve `exclude=` for third-party/generated Markdown, approve `subtree=` entries while preserving live subtree `**/AGENTS.md` rules, confirm `submodule_owned/shared/external=`, global vs. vendored steady-state skills)
   - Governance rigor (`feature_budgets`, `feature_archive_seal`)
   - Check-gate runtime (`better-docs` kit's `gates/check-docs.sh` baseline vs. a repo-native gate conforming to `docs/check-spec.md`, approved `hook_required` / `hook_advisory` tools and their config provisioning, plus separate approvals for an idempotent local git-hook runner entry and any CI workflow update per [references/discovery-checklist.md](references/discovery-checklist.md))
4. In brownfield mode, also grill the user on every **ambiguous legacy doc** (hidden rationale, uncertain keep vs. archive vs. delete), **mixed legacy theory/assumptions** (surviving vs. falsified vs. shipped vs. unresolved at section/claim level when `docs/theory.md` is enabled), **legacy TODOs** (unconfirmed candidates requiring fresh collaborator agreement before entering `ROADMAP.md`), **existing host-repo merges** (idempotent updates to root/subtree `AGENTS.md` and preserving any active architecture doc), **confirmed skill/consumer doc dependencies** (including known out-of-scope or global skill consumers whose required paths/headings conflict with planned moves or rewrites), any **published URL / redirect constraint**, and every **submodule collaborator boundary**.

### 3. Assemble per-repo contracts

Compile approved answers using the composable building blocks in the `better-docs` kit's `templates/` directory (following the instantiation rules in `templates/README.md`). Treat templates as scaffolding for missing files or sections—when an existing root `AGENTS.md` or live subtree `**/AGENTS.md` already holds host instructions, perform an **idempotent scoped update** preserving all unrelated sections verbatim:

- `AGENTS.md` (with `CLAUDE.md -> AGENTS.md` symlink; if a regular `CLAUDE.md` with unique instructions already exists, merge its unique rules into `AGENTS.md` before symlinking): repo layout, commands, hard standing orders (including the human-editable / agent-authorized `ROADMAP.md` rule and `docs/theory.md` pointer when enabled), explicit triggers pointing to `docs/AGENTS.md` and steady-state skills, plus a **Submodule Ownership Table** when submodules exist. Preserve all unrelated host commands, architecture links, and non-doc contract pointers verbatim; keep gitignored paths in inline code rather than Markdown links, and do not add skill-interface inventories here.
- `docs/AGENTS.md`: `Tier | Job | Does NOT belong there` table (single canonical home for `docs/theory.md` revision rules and `ROADMAP.md` format/pruning rules when enabled; classify any existing architecture doc as active current-state documentation preserving its owner), writing rules, fact-to-home map, `split-by-surface` path ownership (if applicable), budget policy (if `feature_budgets=true`), and—only when future `doc-garden` or `doc-verify` runs must honor a durable skill/script doc interface—a **one-line scoped pointer** (here or in the applicable `<subtree>/AGENTS.md`) linking to the authoritative skill, script, or schema (keep exact rules at that owner; never copy schemas into a separate registry).
- Optional `<subtree>/AGENTS.md` files for every approved `subtree=` directory (required by `BD003`); preserve existing live subtree conventions via idempotent scoped update instead of replacing them from templates.
- `docs-check.conf`: pinned `kit_version`, language settings, enabled features, `note_classes` (if overriding defaults), `grandfathered_note=` inventory, `exclude=` paths/prefixes for third-party or generated docs, `subtree=` / `submodule_*=`, `budget=` ceilings (only for existing files when `feature_budgets=true`, sizing `budget=AGENTS.md:...` on the merged file with modest headroom—or proposing relocation of excess detail to a linked contract rather than dropping host orders), and only approved `hook_required=` / `hook_advisory=` entries.
- `.gitignore`: ensure `.agents/scratch/` is ignored without clobbering existing ignore rules or negations (verify with `git check-ignore`).
- Optional `.agents/notes/` and `.agents/records/` skeletons (only when enabled).
- Optional `docs/theory.md` (populated from the theory grill; omitted from a public git repo if confidential) and root `ROADMAP.md` (seeded with confirmed tasks or left empty) when selected during discovery.
- Optional vendored steady-state skills (`prose-standard`, `doc-garden`, `doc-verify`) placed *once* at repo/superproject root (`.agents/skills/`) if collaborators need self-contained skills (exempt from `BD060` under `i18n-en-zh`). Never copy `doc-bootstrap` or `doc-migrate` into target repos.

**Write boundary by mode:**
- **Inception / Greenfield**: write new contracts and apply approved idempotent updates (root/subtree `AGENTS.md`, plus separately approved local git-hook runner or CI workflow edits) without mutating unrelated native tool configs; copy the gate script (e.g. `scripts/check-docs.sh`) plus matching configs from `gates/optional/` (`lychee.toml`, `vale.ini`, and `vale-styles/`) for any approved built-in hooks (or preserve verified existing configs); under `i18n-en-zh`, provision any missing `.zh.md` and `.i18n.yaml` companions for newly scaffolded non-exempt docs and retained active docs; initialize `.agents/notes/archived/manifest.sha256` with `<gate-command> --seal` whenever `feature_archive_seal=true`; and verify both the doc gate and the host repo's documented verification entrypoint (or report uncovered checks if none exists) exit `0`.
- **Brownfield**: present the proposed contracts and scoped merges in the review summary (do not write them over the repo or edit hook/CI configs yet; `doc-migrate` Batch 1 applies and commits them on the migration branch).

### 4. Output brownfield migration manifest (brownfield only)

Write only the migration manifest without deleting or rewriting legacy files:

- Destination:
  - `.agents/notes/proposed/<class>/YYYY-MM-DD-doc-migration.md` (using `process` or an enabled class from `note_classes`) when `feature_notes=true`.
  - `.agents/scratch/doc-migration.md` (untracked; confirm `.agents/scratch/` is already gitignored before writing, or use the agent runtime scratch directory) when `feature_notes=false`.
- Required contents:
  1. Pinned source commit SHA (`Source HEAD: <sha>`) and `Working-tree status:` note.
  2. Target tier map, planned Batch 1 scoped `AGENTS.md` / hook / CI updates, and any `submodule_owned=` approvals (full recursive path, repo identity, starting gitlink SHA, approved scope). Keep non-doc native configs and hook/CI files outside the legacy-doc disposition table. Root and live subtree `AGENTS.md` updates are owned by Batch 1 (do not schedule conflicting edits in Batches 2–4); list any retained active architecture doc in the disposition table as `KEEP` unless an owner-approved change is explicitly named.
  3. Disposition table covering every legacy doc in scope:

```markdown
| Legacy Path | Action | Destination | Owner / Evidence | Redirect / Compat | Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- |
```

Allowed `Action` values: `KEEP`, `REWRITE`, `SPLIT`, `MERGE`, `EXTRACT_NOTE` *(requires `feature_notes=true`)*, `EXTRACT_RECORD` *(requires `feature_empirical_records=true`)*, `ARCHIVE` *(requires `feature_notes=true`; moves into `.agents/notes/archived/`)*, `DELETE`. For uncertain legacy docs the user wants to defer, use `KEEP` plus a follow-up item in a `proposed/` note (or an issue / `.agents/scratch/` item when `feature_notes=false`). For any row affecting a confirmed repo-local or external skill/consumer interface, record the consumer and evidence location, required path or structure, and approved disposition (defaulting to preserve or defer; explicit approval is required for any named consumer edit).

  4. Optional **Theory & assumption triage** section (when the theory tier is enabled): pin the approved theory storage/visibility (`docs/theory.md` `README.md`-linked vs. unlisted in `README.md`, or confidential external/private storage), the approved falsification evidence destination, and section/claim-level rows (`Source file + heading | Class (KEEP_THEORY / FALSIFIED / SHIPPED_CODE / UNRESOLVED) | Destination | Evidence`).
  5. Optional **Confirmed roadmap seed** section (when `ROADMAP.md` is enabled): list only collaborator-confirmed agreed rows and their done conditions (never auto-copy stale legacy `TODO.md` bullets).

### 5. Stop for approval

Present the drafted contracts (and migration manifest for brownfield) and stop. Do not run destructive brownfield cleanup until the user approves the manifest and invokes `doc-migrate`.
