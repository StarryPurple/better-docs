# AGENTS.md — Documentation Standard

This file defines document tiers, writing rules, and wordcount budgets for `better-docs`. Use [prose-standard](../skills/prose-standard/SKILL.md) for sentence-level coverage and anti-slop rules, [doc-garden](../skills/doc-garden/SKILL.md) for maintenance and archival, and [doc-verify](../skills/doc-verify/SKILL.md) for fresh-context fact-checking.

## Tier taxonomy: one home per fact

Every fact belongs in one canonical tier; elsewhere, link to it.

| Tier | Job | Does NOT belong there |
| :--- | :--- | :--- |
| Root `AGENTS.md` | Always-loaded standing orders, repo map, and commands (1–3 lines per rule, linking owners) | Worked examples, multi-step procedures, prose restated from linked docs |
| `docs/AGENTS.md` | Document tier boundaries, writing rules, and budget policy | Gate parsing internals (→ `docs/check-spec.md`), skill workflows (→ `skills/`) |
| `README.md` | Newcomer entry point: what the repo ships, install, quick start, layout map | Exhaustive spec contracts (→ `docs/check-spec.md`), decision history (→ `.agents/notes/`) |
| `docs/check-spec.md` | Authoritative deterministic gate specification: config grammar, parsing rules, diagnostic IDs, exit codes | Editorial style advice (→ `skills/prose-standard/`), migration runbooks (→ `skills/doc-migrate/`) |
| `skills/<name>/SKILL.md` | Portable, reusable workflows and calibration references | Repo-specific paths, project history, hardcoded repo configs |
| `templates/` | Composable starter files instantiated by `doc-bootstrap` | Narrative rationale (→ `.agents/notes/`) |
| `.agents/notes/` | Durable decision records (`proposed/`, `implemented/`, `rejected/`, `archived/`) | Ephemeral review dumps (→ `.agents/scratch/`), current reference specs (→ `docs/`) |
| `.agents/scratch/` *(gitignored)* | Ephemeral session scratch, raw LLM reviews, temporary brainstorms | Anything committed to git (`BD001` rejects tracked files here) |

## Writing rules

- **Current state only**: state what exists at `HEAD`. Keep change history in git commits and durable decision rationale in `.agents/notes/`.
- **Retrieval surface first**: answer first, inventory then expand, path before concept, one job per slot.
- **Preserve complete propositions**: keep actor, timing, modality, negative guarantees, ownership, and failure modes when condensing.
- **No CoT leakage**: delete dead draft citations, PR/session vantage, review choreography, and hype adjectives. Keep every reference resolvable at `HEAD`.
- **Single-language primary**: all authored docs in this repo are English (`language_mode=single-en`), except bilingual calibration examples inside `skills/prose-standard/references/`.
- **File hygiene**: UTF-8, LF line endings, no trailing whitespace, exactly one trailing newline.

## Wordcount budgets

`docs-check.conf` pins wordcount ceilings for standing docs (`AGENTS.md`, `docs/AGENTS.md`, `README.md`). When `./gates/check-docs.sh` fails on `BD010`:

1. **Relocate** content owned by a narrower tier and leave a one-line link.
2. **Condense** prose while preserving every factual proposition.
3. **Raise** the ceiling in `docs-check.conf` only when required facts genuinely need the space, and justify the diff in the commit/PR.
