# Composable Templates

`doc-bootstrap` assembles target-repository contracts from these `.tmpl` building blocks based on the user's five discovery topics. Template files use `{{PLACEHOLDER}}` tokens and `.tmpl` extensions so they are instantiated into target repositories rather than parsed as live documentation here.

## Instantiation rules

- Delete the entire line for any omitted `{{OPTIONAL_*}}` placeholder (never leave blank lines inside Markdown tables, tight bullet lists, or trailing blank lines at EOF).
- Leave one blank line before an injected `###` or `##` section (such as `{{OPTIONAL_I18N_RULES}}` or `{{OPTIONAL_SUBMODULES_SECTION}}`).
- Uncomment `budget=` lines in `docs-check.conf` only for files that exist when `feature_budgets=true`, and uncomment `note_classes=` only when overriding the gate's default class set.

## Inventory

- **`core/`**:
  - `AGENTS.md.tmpl`: Root standing orders, layout, commands, and skill triggers.
  - `docs-AGENTS.md.tmpl`: Tier taxonomy (`Tier | Job | Does NOT belong there`), writing rules, and optional budget policy.
  - `docs-check.conf.tmpl`: Line-oriented gate configuration.
- **`i18n/`**:
  - `split-by-surface.md.tmpl`: Path-level language ownership section for `docs/AGENTS.md`.
  - `i18n-en-zh.md.tmpl`: Mirrored EN/ZH pairing contract and `.i18n.yaml` sidecar layout.
- **`notes/`**:
  - `proposed.md.tmpl`: Proposal skeleton (`.agents/notes/proposed/<class>/`).
  - `implemented.md.tmpl`: Shipped decision skeleton (`.agents/notes/implemented/<class>/`).
  - `concluded.md.tmpl`: Empirical/audit conclusion skeleton (`.agents/notes/concluded/<class>/`).
  - `rejected.md.tmpl`: Rejected tempting-trap skeleton (`.agents/notes/rejected/<class>/`).
  - `record-study-README.md.tmpl`: Bounded study index (`.agents/records/<study-id>/README.md`).
  - `migration-manifest.md.tmpl`: Brownfield migration manifest with a legacy-doc disposition table.
- **`topology/`**:
  - `subtree-AGENTS.md.tmpl`: Localized subtree instructions for monorepos.
  - `submodules-ownership.md.tmpl`: Submodule Ownership Table and child-first commit policy for recursive submodules.
