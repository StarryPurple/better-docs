---
name: doc-verify
description: "Fact-check finished documentation pages, sections, or changed claims using a fresh-context subagent (or a structured human-reviewer checklist when subagent execution is unavailable) that re-runs documented commands and verifies claims against authoritative code, tests, or primary sources. Manually triggered or run as the verification gate in doc-migrate; reports findings without rewriting by default."
---

# Fresh-Context Documentation Verification (`doc-verify`)

Verify finished prose against reality from a **fresh context** so the reviewer cannot be talked into the drafting session's assumptions.

## Scope the run

1. Confirm the target: a page, specific `##` sections, or a list of changed claims. If omitted, ask.
2. Locate the target repo root, `AGENTS.md`, `docs/AGENTS.md`, and `docs-check.conf`.
3. Split large pages into bounded review units (one `##` section or claim group per reviewer).

## Execution mode

### Mode A — Fresh-context subagent (default when runtime supports subagents)

Spawn a fresh read-only subagent per unit. Because subagents do not inherit loaded skills, pass all required paths explicitly in the prompt:

```text
You are reviewing one unit of repository documentation cold. Act as both a skeptical maintainer and a strict fact-checker with the repository open. Do not edit any files.

Repo root: <ABSOLUTE_REPO_ROOT>

Read first:
1. <ABSOLUTE_REPO_ROOT>/AGENTS.md and <ABSOLUTE_REPO_ROOT>/docs/AGENTS.md (tier rules, fact-to-home map, language mode)
2. <ABSOLUTE_REPO_ROOT>/docs-check.conf
3. <TARGET_PAGE_PATH> — review only <SECTION_OR_CLAIM_LIST>; read surrounding sections for context only.

Check in strict order:
1. Facts: verify every command, flag, path, config key, default, exit code, and behavior claim against source code, tests, or primary citations. Re-run read-only terminal commands; run mutating commands only in an isolated scratch directory or verify against source/tests. Flag any claim that cannot be verified and explain why.
2. Examples: verify every code fence, config snippet, and fixture matches current syntax and passes the repo's check gate or tests.
3. Structure (fact-to-home): flag any passage that restates a topic owned by another tier/page, violates language_mode / surface_rule, or leaks unshipped plans into current-state docs.
4. Job fit: confirm the unit answers its stated lookup target directly, answer-first, with load-bearing facts on scan anchors.
5. Slop and CoT leakage: flag dead session/draft citations, change narration ("used to", "this PR", "以前", "上一轮"), review choreography, hype/comfort adjectives ("easy", "seamless", "powerful", "强大而灵活"), defensive padding ("需要注意的是", "it is important to note"), binary reframes ("not X, it's Y"), and summary endings.

Output format:
- Findings ranked most severe first (Critical / Major / Minor). For each: quote the line, name the violated rule or factual discrepancy, and give a one-line fix.
- Verified evidence list: every fact checked and exact command or file:line used.
- Unverified claims list: anything that could not be verified and why.
- Do not rewrite the page.
```

### Mode B — Human-reviewer checklist fallback (when subagents are unavailable)

If the current agent runtime cannot spawn an isolated subagent, run the exact 5-step audit above in a clean read-only pass (re-running commands and checking `file:line` references), explicitly mark the report as `self-audit (no fresh subagent available)`, and present a short human verification checklist covering any claims requiring human or external confirmation.

## Handle the report

- **Report-only by default**: present ranked findings, verified evidence, and unverified claims to the user. Apply fixes only when explicitly requested (`verify-and-fix` or inside `doc-migrate` Batch 3).
- **Re-verify factual edits only**: if a fix changes a factual claim or command, re-verify only the changed claims; wording-only fixes do not need a second pass.
- **Anti-loop stop rule**: if two verification passes do not converge, stop and escalate the unresolved conflict to the user.
