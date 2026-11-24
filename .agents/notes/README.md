# Agent Notes

An Agent Note records a durable decision or proposal that affects this repository—the rationale, alternatives rejected, consequences, and verification that code and reference docs do not carry.

## Layout and naming

Every active Agent Note encodes two axes in its path: `{lifecycle}/{class}/YYYY-MM-DD-topic.md`.

- `proposed/`: reviewed proposals for unbuilt work.
- `implemented/`: shipped decisions written in present tense and kept current with shipped facts.
- `rejected/`: considered and declined proposals; keep only while the rationale prevents a plausible, tempting mistake, otherwise delete outright.
- `archived/`: frozen historical snapshots sealed in [archived/manifest.sha256](archived/manifest.sha256).

Classes are defined by `note_classes` in [docs-check.conf](../../docs-check.conf). Do not add a centralized `INDEX.md`.

## Header and required sections

First four lines of every active note:

```markdown
# Agent Note: <title>

Status: <proposed | implemented | rejected — one-line reason>

```

Required `##` sections:

- `proposed/`: `## Problem`, `## Proposal`, `## Alternatives considered`, `## Acceptance criteria`, `## Risks`
- `implemented/`: `## Problem`, `## Decision`, `## Alternatives considered`, `## Consequences` (bans `## Proposal`, `## Plan`, `## Migration plan`, `## Acceptance criteria`)
- `rejected/`: `## Problem`, `## Proposal`, `## Alternatives considered`

## Supersession and deletion filter

- Every new note triggers a supersession scan over active notes. Full supersession absorbs unique rationale into the new owner and deletes or archives the superseded note; partial supersession keeps both active and cross-linked.
- Delete discarded incomplete reasoning or draft mistakes completely; never place them in `rejected/` or `archived/`.
- Mechanical or local edits do not require an Agent Note.
