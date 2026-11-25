# Discovery Checklist and Capability Mapping

`doc-bootstrap` walks five discovery topics conditionally and compiles the answers into `docs-check.conf`. Always ask Topic 1 first.

## Topic 1: Language and i18n (ask first)

| Choice | Config values | When to pick |
| :--- | :--- | :--- |
| English only | `language_mode=single-en`, `language_primary=en` | International repos or English-first teams. |
| Chinese only | `language_mode=single-zh`, `language_primary=zh` | Chinese prose with exact English code identifiers. |
| Split by surface | `language_mode=split-by-surface`, `language_primary=<en\|zh>`, `surface_rule=<glob>\|<en\|zh>\|<owner\|derived>` | Readers prefer Chinese for guides/notes while keeping API specs, contracts, or code comments in English. Rules match top-to-bottom (first match wins); unmatched paths fall back to `language_primary`. |
| Mirrored EN/ZH | `language_mode=i18n-en-zh`, `language_primary=en` | Public or bilingual team repos maintaining `.md` + `.zh.md` + `.i18n.yaml` pairs gated on existence and `source_sha256` freshness. |

## Topic 2: Epistemic and evidence needs

| Question | Config impact |
| :--- | :--- |
| Are direction changes driven primarily by engineering contracts/deduction, or also by empirical experiments, training runs, audits, and collaborator findings? | Deductive only: `feature_notes=true`, `feature_empirical_records=false`, `note_classes=feature,bug-fix,architecture,simplification,process,testing`. Empirical or hybrid (including research/audit-as-deliverable repos): add `feature_empirical_records=true` and expand `note_classes` (e.g., add `hypothesis,experiment,pipeline` or `audit`). |
| Is the repo's deliverable application code, or curated specs/surveys/skills? | Record the verification authority in `docs/AGENTS.md`: code + tests for code repos; primary sources, citations, or conformance fixtures for knowledge/spec repos. |
| Does the project need a living theoretical architecture (`docs/theory.md`) separate from shipped code docs (e.g., research or paper-bound work)? | Opt-in `docs/theory.md` from `templates/research/theory.md.tmpl`. Grill for problem, domain, notation, assumptions, failure criteria, and evidence owner. Choose a falsification destination valid under enabled features (`.agents/notes/concluded/` + `.agents/records/` requires both `feature_notes=true` and `feature_empirical_records=true`; `.agents/notes/rejected/` or `implemented/` requires `feature_notes=true`; otherwise bind a named durable destination). For public repos, choose `README.md`-linked (with working-formulation notice) vs. **unlisted in README**; if confidential, resolve private/external storage before committing or linking it. |
| Does the team want a committed short-term roadmap (`ROADMAP.md` at repo root) for agreed near-term tasks and `@owner` assignment? | Opt-in root `ROADMAP.md` from `templates/planning/ROADMAP.md.tmpl`. Any human collaborator may edit it directly; AI agents require explicit collaborator authorization to add, reword, or reassign rows (and may tick `[x]` on a uniquely matched assigned row after verifying its done condition). Confirm each concrete seed row and its done condition (an empty board is valid); unagreed proposals stay in `.agents/notes/proposed/` or issues. Exempt from `BD060` under `i18n-en-zh` (formatting rules live in the generated `docs/AGENTS.md`). |

## Topic 3: Repository structure and ownership

- **Monorepo subtrees**: list directories with subtree `AGENTS.md` files via `subtree=<dir>`. Composable with submodules.
- **Recursive git submodules**: default-closed at every gitlink. Classify each submodule explicitly:
  - `submodule_owned=<path>|<repo_id>|<starting_sha>|<scope>`: owned by the user/team; validated and committed child-first before bumping parent gitlink pins.
  - `submodule_shared=<path>`: collaborator-shared; read-only to automated migration/gardening.
  - `submodule_external=<path>`: third-party/upstream; read-only.
- **Steady-state skill placement**: global (`~/.agents/skills/`) by default; optionally vendored *once* at repo/superproject root (`.agents/skills/`) when collaborators need self-contained skills. Repo-local `.agents/skills/` overrides global `~/.agents/skills/`.

## Topic 4: Governance rigor

- **Lean**: `feature_notes=false`, `feature_empirical_records=false`, `feature_archive_seal=false`, `feature_budgets=false`. Keeps only root `AGENTS.md`, `docs/AGENTS.md`, and link/hygiene checks. Upgradeable later.
- **Strict**: `feature_notes=true`, `feature_budgets=true`, `feature_archive_seal=true` (recommended for high-churn agentic codebases, monorepos, and empirical research repos).

## Topic 5: Check-gate runtime and hooks

- **Baseline**: copy the `better-docs` kit's `gates/check-docs.sh` to `scripts/check-docs.sh` (universal `bash` baseline; works in any repo).
- **Repo-native gate** (optional): when the repo already runs a scriptable toolchain (`ts/mjs`, `python`, `rust` `xtask`, `go`), only adopt a repo-native engine if it implements the `better-docs` kit's `docs/check-spec.md` and passes `gates/conformance/run.sh`.
- **External hooks**: enable only hooks explicitly approved during discovery, split into `hook_required=` (fails `BD070` if missing/erroring) and `hook_advisory=` (prints `BD902` only). For approved `lychee` or `vale` hooks, copy the matching config from `gates/optional/` (`lychee.toml`, `vale.ini`, and `vale-styles/`) into the target repo or preserve a verified existing config.
