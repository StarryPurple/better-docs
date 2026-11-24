---
name: prose-standard
description: "Write, audit, restore, or trim technical documentation, Agent Notes, code comments, and bilingual (EN/ZH) prose using retrieval-surface structure, complete-proposition preservation, and Chain-of-Thought leakage removal. Use whenever drafting, editing, or reviewing docs, READMEs, notes, comments, or bilingual surfaces."
---

# Prose Standard and Anti-Slop Discipline (`prose-standard`)

Write enough to preserve the exact contract, then remove reasoning transcripts, repetition, hype, and defensive filler. Read [references/recall-batteries.md](references/recall-batteries.md) for advisory EN/ZH probe patterns and [references/examples.md](references/examples.md) for before/after calibration.

## Scope and exclusions

- Require an explicit target scope (files or directories); do not silently audit the whole repository unless requested.
- Never edit or audit `vendor/`, `node_modules/`, `.agents/notes/archived/`, concluded `.agents/records/<study-id>/`, or `submodule_shared=` / `submodule_external=` paths.
- Audit tasks report findings without editing; write/fix tasks apply clear changes.

## Six structural rules (retrieval surface first)

1. **Retrieval surface, not an essay**: open every section with the answer, command, or inventory; put context and rationale after.
2. **One job per slot**: one fact per sentence; list intros only announce the list; one lookup target per section.
3. **Inventory, then expand**: list every item in one line first, then expand each in its own unit below.
4. **Place first, meaning second**: name files, paths, flags, and commands before glossing their concept.
5. **One canonical home per fact**: state each fact in its owning tier (`docs/AGENTS.md`) and link everywhere else.
6. **Scan anchors for load-bearing facts**: place commands, options, constraints, and failure modes on code fences, `**Term**: fact` bullets, numbered bold lead-ins, tables, or file trees—never buried mid-paragraph.

## Complete-proposition preservation

Trimming is never word-count golf. Before deleting or shortening any passage, list its factual propositions and preserve every relevant:

- actor and concrete action;
- condition, timing, and ordering;
- modality (`must`, `may`, `never`);
- negative guarantee and exception;
- ownership, side effect, failure mode, and consequence.

Delete adjectives, wind-up, and narration only when every load-bearing clause survives.

## The One Test for Chain-of-Thought leakage

Ask of every passage: **could a reader at `HEAD`, with no access to any chat transcript, PR thread, or uncommitted draft, resolve every reference and verify every claim?**

If no, restate the surviving facts from the repository's vantage at `HEAD` and delete the transcript around it.

### Eight leakage classes (EN + ZH)

1. **Dead session/draft citations**: `(decision 7)`, `(audit C2)`, `design §4.7`, phase labels (`T4`, `P-I`), `设计稿 §3`. Cite a committed owner by path, or delete the citation and keep the standalone fact.
2. **PR/branch vantage**: `"this PR adds"`, `"in a later PR"`, `"previous commit"`, `"本 PR"`, `"上一次提交"`. State the current mechanism; deferrals go to `TODO` or an issue reference.
3. **Change narration on current-state surfaces**: `"used to"`, `"no longer"`, `"previously"`, `"the old X"`, `"以前"`, `"不再"`, `"旧版"`, `"本版"`. State present behavior; express regression pins as present-tense counterfactuals (`"without X, Y happens"`).
4. **Review choreography**: `"rejected in review"`, `"Codex suggested"`, `"round 2"`, `"评审通过"`, `"上一轮评审"`. Keep only the surviving decision or caveat as plain fact.
5. **Defensive reviewer justification**: `"this cast is safe because it simply..."`, `"需要注意的是..."`, `"值得一提的是..."`. State the concrete invariant, or delete if code shows it.
6. **Derivation and control-flow narration**: `"first we X, then we Y"`, test walkthroughs, proofs of obvious branches. Keep only non-obvious invariants or contracts.
7. **Hedges and hype/comfort adjectives**: `"probably fine"`, `"should suffice"`, `"easy"`, `"simple"`, `"just"`, `"powerful"`, `"seamless"`, `"robust"`, `"简单来说"`, `"非常强大"`, `"总而言之"`. Replace with observable behavior, concrete limits, or a `TODO`.
8. **Unintended mixed-language residue**: untranslated authoring fragments leaking into a single-language surface (e.g., stray Chinese notes in an English doc, or vice versa), except explicit code identifiers and declared bilingual glosses.

### What is NOT leakage (do not over-delete)

- Committed issue/PR citations inside `.agents/notes/` or postmortems.
- Linter/checker suppression reasons (`eslint-disable ... -- reason`, empty-catch reasons).
- Present-tense counterfactual regression pins (`"without lock X, concurrent writers corrupt Y"`).
- Measured bounds and provenance (`"(measured: 512 nests ≈ 0.15s)"`, commit SHAs, run IDs).
- Runtime old/new state transitions (`"the old connection drains before the new one accepts"`).
- External standard citations (`RFC 9110 §10.1.5`).
- Instrumental `"used to"` (`"the key used to sign tokens"`).

## Language-mode rules

- `single-en`: direct, active technical English; no binary contrasts (`"not X, it's Y"`), no summary endings.
- `single-zh`: direct, active technical Chinese; keep exact English code symbols, CLI flags, and file paths verbatim; ban ChatGPT-style Chinese padding (`"需要注意的是"`, `"值得一提的是"`, `"不仅如此"`, `"总而言之"`, `"本质上来说"`).
- `split-by-surface`: honor `surface_rule=` in `docs-check.conf` (first match wins, fallback to `language_primary`); do not duplicate canonical facts across languages—link the owning surface.
- `i18n-en-zh`: keep both `.md` and `.zh.md` natural and idiomatic in their respective languages; update `.i18n.yaml` `source_sha256` only when semantic content is genuinely synchronized.

## Workflow

1. Read `AGENTS.md`, `docs/AGENTS.md`, and `docs-check.conf` to confirm language mode and excluded paths.
2. Run advisory recall probes (`./gates/check-docs.sh --probes` or [references/recall-batteries.md](references/recall-batteries.md)), then inspect the densest prose without a pattern in hand.
3. Judge each hit semantically: classify as `keep`, `trim`, `restate`, `add`, or `relocate`.
4. Edit owner files before derivative files; run the repo's check gate afterward.
