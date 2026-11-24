# Interactive Grill Protocol

Use this protocol during `doc-bootstrap` to resolve ambiguity before writing contracts or a migration manifest.

## Core rules

1. **Detect first, propose defaults, then grill.** Never ask open-ended questions when inspection already reveals a strong default; present the detected fact and ask only where judgment or preference decides.
2. **Start with Language & i18n.** Every subsequent file and rule depends on it.
3. **Group related decisions; skip inapplicable branches.** Do not ask about submodule ownership when `.gitmodules` is absent, and do not ask about `surface_rule` when `language_mode=single-en`.
4. **Never guess destructive actions.** In brownfield repos, any legacy document that might hold unrecovered rationale, collaborator commitments, or lab conclusions requires an explicit user decision (`EXTRACT_NOTE` / `EXTRACT_RECORD` / `QUARANTINE` / `DELETE`).

## Grill sequence

### Round 1 — Project traits (conditional)
- **Language & i18n**: propose detected dominant language; confirm `single-en`, `single-zh`, `split-by-surface`, or `i18n-en-zh`.
- **Evidence & rigor**: confirm whether the repo needs strict `.agents/notes/` lifecycle (`proposed/implemented/rejected/archived`) and whether empirical/audit records (`.agents/records/` + `concluded/`) are needed.
- **Topology & skills**: if workspaces or `.gitmodules` exist, confirm subtrees, classify every gitlink (`owned` / `shared` / `external`), and confirm global vs. root-vendored steady-state skills.
- **Check gate**: confirm `bash` baseline vs. repo-native gate and any `hook_required` / `hook_advisory` tools.

### Round 2 — Brownfield ambiguities (only when legacy docs exist)
Surface only genuinely uncertain items in compact groups:
1. **Ambiguous legacy docs**: quote file path, brief summary of buried facts, and ask `EXTRACT_NOTE` vs. `QUARANTINE` vs. `DELETE`.
2. **Published URLs / external links**: ask whether any existing doc paths are published or linked externally (requiring redirects or stability).
3. **Non-code authorities**: identify who or what owns operational procedures, support commitments, or experiment baselines that source code cannot verify.

## Exit criterion

Stop grilling once every `docs-check.conf` field and every legacy doc disposition row has a clear decision. Write the draft contracts and manifest, then wait for explicit user approval before invoking `doc-migrate`.
