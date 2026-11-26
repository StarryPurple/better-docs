# Interactive Grill Protocol

Use this protocol during `doc-bootstrap` to resolve ambiguity before writing contracts or a migration manifest.

## Core rules

1. **Detect first, propose defaults, then grill.** Never ask open-ended questions when inspection already reveals a strong default; present the detected fact and ask only where judgment or preference decides.
2. **Start with Language & i18n.** Every subsequent file and rule depends on it.
3. **Group related decisions; skip inapplicable branches.** Do not ask about submodule ownership when `.gitmodules` is absent, and do not ask about `surface_rule` when `language_mode=single-en`.
4. **Never guess destructive actions.** In brownfield repos, any legacy document that might hold unrecovered rationale, collaborator commitments, or lab conclusions requires an explicit user decision (`EXTRACT_NOTE` / `EXTRACT_RECORD` / `ARCHIVE` / `KEEP` / `DELETE`).

## Grill sequence

### Round 1 — Project traits (conditional)
- **Language & i18n**: propose detected dominant language; confirm `single-en`, `single-zh`, `split-by-surface`, or `i18n-en-zh`.
- **Evidence, theory & planning**: confirm whether the repo needs strict `.agents/notes/` lifecycle (`proposed/implemented/rejected/archived`), empirical/audit records (`.agents/records/` + `concluded/`), an opt-in living `docs/theory.md`, or an opt-in root `ROADMAP.md`.
  - If `docs/theory.md` is opted in: grill for problem, domain, core notation, assumptions with falsification criteria, evidence owner and valid falsification destination (matching enabled features), and visibility (`README.md`-linked vs. unlisted in `README.md` for public repos, or private/external storage if confidential).
  - If `ROADMAP.md` is opted in: confirm collaborator-editable / agent-authorized rules and each initial agreed seed row with its done condition (an empty board is valid).
- **Topology & skills**: if workspaces or `.gitmodules` exist, confirm subtrees, classify every gitlink (`owned` / `shared` / `external`), and confirm global vs. root-vendored steady-state skills.
- **Check gate**: confirm `bash` baseline vs. repo-native gate, any approved `hook_required` / `hook_advisory` tools, and whether to copy `gates/optional/` configs or preserve existing repo configs.

### Round 2 — Brownfield ambiguities (only when legacy docs exist)
Surface only genuinely uncertain items in compact groups:
1. **Ambiguous legacy docs**: quote file path, brief summary of buried facts, and ask `EXTRACT_NOTE` / `EXTRACT_RECORD` vs. `ARCHIVE` vs. `KEEP` vs. `DELETE`.
2. **Mixed legacy theory & TODOs** (when `docs/theory.md` or `ROADMAP.md` is enabled): separate surviving working theory, falsified assumptions, shipped behavior, and unresolved claims at section/claim level; treat legacy `TODO.md` entries as unconfirmed candidates requiring fresh collaborator agreement before entering the roadmap seed.
3. **Existing skill / consumer dependencies**: present confirmed repo-local skill/script dependencies (and ask about known global or out-of-scope consumers) whose required doc paths, headings, or schemas conflict with planned rewrites or moves; confirm whether to preserve the interface, defer the row, or approve a named consumer edit.
4. **Published URLs / external links**: ask whether any existing doc paths are published or linked externally (requiring redirects or stability).
5. **Non-code authorities**: identify who or what owns operational procedures, support commitments, proofs, or experiment baselines that source code cannot verify.

## Exit criterion

Stop grilling only once every `docs-check.conf` field, every approved hook's config provisioning, every enabled theory/roadmap content and confidentiality decision, and every legacy doc disposition row (including optional theory triage and roadmap seed) has a clear decision. Write the draft contracts and manifest, then wait for explicit user approval before invoking `doc-migrate`.
