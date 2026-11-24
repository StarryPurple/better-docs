---
name: doc-bootstrap
description: "Audit a repository or project plan, grill the user across five discovery topics (starting with language and i18n), and produce tailored documentation contracts (AGENTS.md, docs/AGENTS.md, docs-check.conf) plus a brownfield migration manifest when legacy docs exist. Use when initializing documentation governance on a greenfield project, structuring a multi-session exploration or knowledge repo, or preparing a messy brownfield repository for migration."
---

# Bootstrap Documentation Governance (`doc-bootstrap`)

Inspect the target repository (or project plan), resolve project-trait choices with the user, and produce thin, declarative repository contracts—never regenerating universal prose or migration skills inside the target repo.

Read [references/discovery-checklist.md](references/discovery-checklist.md) for the five discovery topics and capability mapping, and [references/grill-protocol.md](references/grill-protocol.md) for the interactive grill rules.

## Mode detection

Classify the target into one of three starting states before proposing files:

1. **Inception / exploration (empty folder or idea only in the developer's head)**:
   - If the folder is empty or not yet a git repo, do not fail inspection; offer two paths:
     - **Disposable exploration**: keep rough brainstorming in untracked scratch (runtime scratch dir or `.gitignore`d `.agents/scratch/`) and defer bootstrapping until a direction converges.
     - **Seed from an idea**: offer to run `git init` (if missing), run the conditional 5-topic grill, scaffold minimal contracts plus an honest 3-line `README.md` stub, and interview the developer to write the first concrete `.agents/notes/proposed/<class>/YYYY-MM-DD-<slug>.md` (only when `feature_notes=true`; or `.agents/records/<study-id>/README.md` when `feature_empirical_records=true`; otherwise keep rough plans in `.agents/scratch/`). Never put unbuilt ideas into standing `docs/`.
2. **Greenfield (converged plan, little or no code)**:
   - Never place unimplemented designs or target architecture skeletons inside standing `docs/`.
   - With `feature_notes=true`, place unimplemented specs and architecture plans in `.agents/notes/proposed/<class>/`; keep `docs/` and `README.md` strictly to what exists at `HEAD`, linking to active `proposed/` notes.
   - With `feature_notes=false`, keep unimplemented plans in untracked `.agents/scratch/` until code exists.
3. **Brownfield (existing repo with legacy docs or clutter)**:
   - Run **read-only first**. Make zero destructive edits and do not overwrite existing repository contracts during bootstrap—leave contract scaffolding to `doc-migrate` Batch 1 so the working tree stays clean for pre-flight checks.
   - Present proposed contract drafts and write a reviewable **migration manifest** for `doc-migrate`.

## Workflow

### 1. Read-only inspection

Inspect the target root without modifying files:

1. Check git state (`git rev-parse --is-inside-work-tree`, `git status --short`, current `HEAD` SHA if commits exist, `.gitmodules`, tracked `.agents/scratch/`). Treat a non-git or empty directory cleanly as **Inception** mode.
2. Inventory existing Markdown files, `AGENTS.md`, `CLAUDE.md`, package/workspace manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`), and existing doc-check scripts.
3. Detect default-closed gitlinks (`.gitmodules` and recursive child `.gitmodules`). Do not descend into any submodule until the user classifies it as `owned`.
4. In brownfield mode, run the advisory EN/ZH recall probes from `prose-standard` (`references/recall-batteries.md`) to surface CoT leakage, change narration, and duplicate docs.

### 2. Conditional discovery grill

Follow [references/grill-protocol.md](references/grill-protocol.md):

1. Present detected signals and proposed defaults.
2. **Ask Language & i18n first** (`single-en`, `single-zh`, `split-by-surface`, `i18n-en-zh`).
3. Grill across the remaining discovery topics, skipping follow-ups that do not apply:
   - Epistemic / evidence needs (`feature_notes`, `feature_empirical_records`, note classes)
   - Structure & ownership (`subtree=`, `submodule_owned/shared/external=`, global vs. vendored steady-state skills)
   - Governance rigor (`feature_budgets`, `feature_archive_seal`)
   - Check-gate runtime (`better-docs` kit's `gates/check-docs.sh` baseline vs. a repo-native gate conforming to `docs/check-spec.md`, plus `hook_required` / `hook_advisory`)
4. In brownfield mode, also grill the user on every **ambiguous legacy doc** (hidden rationale, uncertain keep vs. archive vs. delete), any **published URL / redirect constraint**, and every **submodule collaborator boundary**.

### 3. Assemble per-repo contracts

Compile approved answers using the composable building blocks in the `better-docs` kit's `templates/` directory (following the instantiation rules in `templates/README.md`):

- `AGENTS.md` (with `CLAUDE.md -> AGENTS.md` symlink): repo layout, commands, hard standing orders, explicit triggers pointing to `docs/AGENTS.md` and steady-state skills, plus a **Submodule Ownership Table** when submodules exist.
- `docs/AGENTS.md`: `Tier | Job | Does NOT belong there` table, writing rules, fact-to-home map, `split-by-surface` path ownership (if applicable), and budget policy (if `feature_budgets=true`).
- Optional `<subtree>/AGENTS.md` files for every configured `subtree=` directory (required by `BD003`).
- `docs-check.conf`: pinned `kit_version`, language settings, enabled features, `note_classes` (if overriding defaults), `grandfathered_note=` inventory, `subtree=` / `submodule_*=`, `budget=` ceilings (only for existing files when `feature_budgets=true`), and hooks.
- `.gitignore`: ensure `.agents/scratch/` is ignored.
- Optional `.agents/notes/` and `.agents/records/` skeletons (only when enabled).
- Optional vendored steady-state skills (`prose-standard`, `doc-garden`, `doc-verify`) placed *once* at repo/superproject root (`.agents/skills/`) if collaborators need self-contained skills (exempt from `BD060` under `i18n-en-zh`). Never copy `doc-bootstrap` or `doc-migrate` into target repos.

**Write boundary by mode:**
- **Inception / Greenfield**: write the assembled contracts to disk, copy the gate script (e.g. `scripts/check-docs.sh`), initialize `.agents/notes/archived/manifest.sha256` with `<gate-command> --seal` whenever `feature_archive_seal=true`, and verify the gate exits `0`.
- **Brownfield**: present the proposed contracts in the review summary (do not write them over the repo yet; `doc-migrate` Batch 1 writes and commits them on the migration branch).

### 4. Output brownfield migration manifest (brownfield only)

Write only the migration manifest without deleting or rewriting legacy files:

- Destination:
  - `.agents/notes/proposed/<class>/YYYY-MM-DD-doc-migration.md` (using `process` or an enabled class from `note_classes`) when `feature_notes=true`.
  - `.agents/scratch/doc-migration.md` (untracked; confirm `.agents/scratch/` is already gitignored before writing, or use the agent runtime scratch directory) when `feature_notes=false`.
- Required contents:
  1. Pinned source commit SHA (`Source HEAD: <sha>`) and `Working-tree status:` note.
  2. Target tier map and any `submodule_owned=` approvals (full recursive path, repo identity, starting gitlink SHA, approved scope).
  3. Disposition table covering every legacy doc in scope:

```markdown
| Legacy Path | Action | Destination | Owner / Evidence | Redirect / Compat | Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- |
```

Allowed `Action` values: `KEEP`, `REWRITE`, `SPLIT`, `MERGE`, `EXTRACT_NOTE` *(requires `feature_notes=true`)*, `EXTRACT_RECORD` *(requires `feature_empirical_records=true`)*, `ARCHIVE` *(requires `feature_notes=true`; moves into `.agents/notes/archived/`)*, `DELETE`. For uncertain legacy docs the user wants to defer, use `KEEP` plus a follow-up item in a `proposed/` note (or an issue / `.agents/scratch/` item when `feature_notes=false`).

### 5. Stop for approval

Present the drafted contracts (and migration manifest for brownfield) and stop. Do not run destructive brownfield cleanup until the user approves the manifest and invokes `doc-migrate`.
