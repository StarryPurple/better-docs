# Agent Notes

An Agent Note records a durable decision or proposal that affects this repository—the rationale, alternatives rejected, consequences, and verification that code and reference docs do not carry. Exact mechanical rules (`BD030`–`BD033`) are defined in [docs/check-spec.md](../../docs/check-spec.md).

## Layout and naming

Every active Agent Note path uses lowercase kebab-case (`[a-z0-9-]+`) for `{lifecycle}`, `{class}`, and `slug`: `{lifecycle}/{class}/YYYY-MM-DD-slug.md`.

- `proposed/`: reviewed proposals for unbuilt work.
- `implemented/`: shipped decisions written in present tense and kept current with shipped facts.
- `rejected/`: considered and declined proposals; keep only while the rationale prevents a plausible, tempting mistake, otherwise delete outright.
- `archived/`: frozen historical snapshots sealed in [archived/manifest.sha256](archived/manifest.sha256).

Classes are defined by `note_classes` in [docs-check.conf](../../docs-check.conf). Do not add a centralized `INDEX.md`.

## Header and required sections

First four lines of every active note (line 2 and line 4 must be blank):

```markdown
# Agent Note: <title>

Status: proposed

```

Exact line-3 `Status:` forms (`BD031`):
- `proposed/`: `Status: proposed`
- `implemented/`: `Status: implemented`
- `rejected/`: `Status: rejected — <non-whitespace reason>` (using U+2014 em-dash; trailing `— <reason>` is rejected on `proposed/` and `implemented/`)

Required `##` sections (`BD032`) and forbidden proposal-era headings in `implemented/` (`BD033`) are governed by [docs/check-spec.md](../../docs/check-spec.md).

## Supersession and deletion filter

- Every new note triggers a supersession scan over active notes. Full supersession absorbs unique rationale into the new owner and deletes or archives the superseded note; partial supersession keeps both active and cross-linked.
- Delete discarded incomplete reasoning or draft mistakes completely; never place them in `rejected/` or `archived/`.
- Mechanical or local edits do not require an Agent Note.
