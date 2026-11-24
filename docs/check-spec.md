# Deterministic Check Gate Specification (`docs/check-spec.md`)

This document is the single authority for every deterministic check implemented by [gates/check-docs.sh](../gates/check-docs.sh) and any future repo-native gate engine. Every engine must pass [gates/conformance/run.sh](../gates/conformance/run.sh).

## Prerequisites and CLI contract

### Baseline prerequisites (`gates/check-docs.sh`)
- `bash` (>= 4.4)
- POSIX `awk` and standard POSIX utilities (`sed -E`, `find`, `sort`, `tr`, `tail`, `od`, `dirname`, `mkdir`)
- `git` (required unless `--no-git` is passed; missing `git` without `--no-git` exits `2`. When `git` is installed and `--root` is not inside a git worktree, git-dependent checks are skipped unless `--ci` is passed.)
- `sha256sum` or `shasum -a 256`

### CLI flags

| Flag | Behavior |
| :--- | :--- |
| `--root <dir>` | Target repository root (default: current working directory); requires an argument. |
| `--config <path>` | Path to config file (default: `<root>/docs-check.conf`); requires a non-empty argument. |
| `--ci` | CI enforcement mode: requires a git worktree and `--base-ref` (or `BETTER_DOCS_BASE_REF`) resolving to a commit distinct from `HEAD` (`BD040`). Incompatible with `--seal` and `--no-git` (exit `2`). |
| `--base-ref <ref>` | Baseline git ref for append-only archive seal checks (default outside `--ci`: `HEAD`); requires a non-empty argument (exit `2` if empty). An explicitly supplied unresolvable ref fails `BD040` and blocks `--seal` from rewriting `manifest.sha256`. |
| `--seal` | Verify all existing seals and baseline append-only integrity (`BD040`–`BD043`); if no archive seal errors occurred, rewrite `.agents/notes/archived/manifest.sha256` sorted by path (`LC_ALL=C sort -k1.67`) including newly archived files and concluded study files. Incompatible with `--ci` (exit `2`). |
| `--probes` | Also emit advisory EN/ZH lexical CoT/slop recall diagnostics (`BD901`); never changes exit code. |
| `--list-budgets` | Also print current token usage (`ok`/`OVER`/`MISS`) for every configured `budget=` entry during the check run (enforces `BD010` only when `feature_budgets=true`). |
| `--no-git` | Run without `git` (disables tracked-scratch `BD001`, baseline `BD041`, and `.gitmodules` `BD903` checks). Incompatible with `--ci` (exit `2`). |
| `--version` | Print the gate kit version (`0.1.0`) and exit `0`. |
| `-h`, `--help` | Print CLI usage and exit `0`. |

### Exit codes
- `0`: all hard-fail checks passed (advisory diagnostics, skipped advisory hooks, and advisory hook warnings do not fail the run).
- `1`: one or more hard-fail diagnostics (`BD001`–`BD070`) failed.
- `2`: invocation error (unknown CLI flag, missing option argument, incompatible flag pair `--ci --seal` or `--ci --no-git`, missing `--root` or `--config`, `--ci` outside a git worktree, or missing required prerequisite binary).

---

## Configuration grammar (`docs-check.conf`)

Line-oriented `key=value` file:
- Blank lines and lines whose first non-whitespace character is `#` are ignored.
- Inline comments (` # ...`) are stripped only when preceded by whitespace.
- Leading/trailing whitespace around keys and values is trimmed.
- Scalar keys use the last declaration; list keys (`surface_rule`, `grandfathered_note`, `subtree`, `submodule_owned`, `submodule_shared`, `submodule_external`, `budget`, `hook_required`, `hook_advisory`) reject empty values and append in declaration order.
- All key syntax, normalized repo-relative paths (no leading `/`, trailing `/`, `//`, `.`, or `..` segments), and feature dependencies are validated unconditionally (`BD002`).

| Key | Kind | Allowed values / format | Default |
| :--- | :--- | :--- | :--- |
| `kit_version` | scalar | Semver string (`0.1.0` or `0.1.0-alpha.1`) | required |
| `language_mode` | scalar | `single-en`, `single-zh`, `split-by-surface`, `i18n-en-zh` | `single-en` |
| `language_primary` | scalar | `en`, `zh` (validated metadata in v1; unmatched fallback for `split-by-surface`) | `en` |
| `surface_rule` | list | `<glob>\|<en\|zh>\|<owner\|derived>` (validated metadata in v1; first-match wins for skills) | empty |
| `feature_notes` | bool | `true`, `false` | `false` |
| `feature_empirical_records` | bool | `true`, `false` (requires `feature_notes=true`) | `false` |
| `feature_archive_seal` | bool | `true`, `false` (requires `feature_notes=true`) | `false` |
| `feature_budgets` | bool | `true`, `false` | `false` |
| `note_classes` | csv | Non-empty comma-separated lowercase kebab-case class names (`[a-z0-9-]+`; no leading/trailing comma) | `feature,bug-fix,architecture,simplification,process,testing` |
| `grandfathered_note` | list | Exact normalized repo-relative path to a pre-adoption note | empty |
| `subtree` | list | Normalized repo-relative directory containing a subtree `AGENTS.md` | empty |
| `submodule_owned` | list | `<path>\|<repo_id>\|<starting_sha>\|<scope>` (`<path>` normalized repo-relative) | empty |
| `submodule_shared` | list | Normalized repo-relative gitlink path (read-only) | empty |
| `submodule_external` | list | Normalized repo-relative gitlink path (read-only) | empty |
| `budget` | list | `<normalized-repo-relative-path>:<positive-int>` | empty |
| `hook_required` | list | Executable name on `PATH`. `lychee` runs as `lychee --no-progress --offline --root-dir <root> [--config <cfg>] <root>` (auto-discovering `.lychee.toml`, `lychee.toml`, or `gates/optional/lychee.toml` under `<root>`). `vale` runs as `vale --config <cfg> <root>` (auto-discovering `.vale.ini`, `vale.ini`, or `gates/optional/vale.ini` under `<root>`); missing config fails `BD070` for required hooks or skips (`BD902`) for advisory hooks. Other tools run as `<tool> <root>`. | empty |
| `hook_advisory` | list | Executable name on `PATH` (same invocation and config-discovery contract as `hook_required`) | empty |

---

## Scope, parsing, and counting semantics

### Tracked-file scope
- In a git worktree (confirmed via `git rev-parse --is-inside-work-tree == true`, unless `--no-git`), active Markdown files are discovered via `git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.md'` so non-ASCII/CJK filenames are preserved verbatim.
- Outside git or with `--no-git`, scan `*.md` via `find`.
- Both modes skip symlinks and exclude `vendor/`, `node_modules/`, `.git/`, `.agents/scratch/`, `.agents/notes/archived/`, and all declared submodule paths (and, in git mode, `.gitmodules` gitlink paths).
- **Default-closed gitlinks**: checking stops at every submodule boundary; in git mode, any gitlink in `.gitmodules` that is unlisted or uninitialized emits `BD903` unconditionally.

### Fenced-code and inline-code stripping
- A line starting with up to 3 spaces followed by three or more backticks (`` ``` ``) or tildes (`~~~`) opens a fenced code block (per CommonMark, a backtick fence opens only when the remainder of the line contains no backtick) and stays open until a matching closing fence of at least the same length followed only by optional whitespace.
- Inline code spans are stripped left-to-right using CommonMark backtick-run matching (a maximal run of `k` backticks closes only at the next exact run of `k` backticks), replacing each matched code span with a non-empty placeholder so `[broken](missing.md)` inside code spans is ignored while code-labeled links such as `` [`foo.md`](foo.md) `` remain checked.
- Heading extraction, inline link extraction, Agent Note section/status scanning (`BD031`–`BD033`), draft-marker checks (`BD051`), and lexical probes (`BD901`) ignore lines inside fenced code blocks.
- File-level whitespace and EOF newline hygiene (`BD050`) applies to every line in active Markdown files, including lines inside code fences.

### Token counting unit (`feature_budgets=true`)
- Every non-CJK whitespace-delimited token counts as `1`.
- Every CJK Unified Ideograph (`U+4E00`–`U+9FFF`, `U+3400`–`U+4DBF`, `U+F900`–`U+FAFF`) counts as `1`, even without spaces (consecutive non-ideograph punctuation without spaces counts as `1` non-CJK token).

### ATX heading and anchor normalization
- Extracted headings are ATX headings matching `^#{1,6}[ \t]+` outside fenced code blocks, with optional trailing `#` runs stripped and inline Markdown links `[text](url)` unwrapped to `text`.
- Slug normalization: lowercase ASCII, strip inline formatting (`` ` ``, `*`, `_`), retain only ASCII `[a-z0-9 -]` and UTF-8 CJK Unified Ideographs (dropping ASCII and non-ASCII punctuation such as `—` or `。`), trim outer spaces, replace each space with `-`, and disambiguate duplicate slugs with `-1`, `-2`, ...

### Inline Markdown link extraction
- Scans inline `[label](target)` and `![alt](target)` links outside fenced code blocks after CommonMark inline-code stripping, supporting empty alt text (`![](img.png)`), nested image-in-link constructs (`[![alt](img.png)](dest.md)`), and balanced parentheses inside targets or titles (`docs/foo_(bar).md`).
- Ignores empty targets, bare `#`, external schemes (`http://`, `https://`, `mailto:`, `tel:`, `data:`, `file://`), angle-bracket targets starting with `<`, and template targets containing `{{`.
- Strips optional double- or single-quoted titles (`"..."`, `'...'`) and splits `path#anchor`.
- Resolves `path` relative to the containing file's directory (or repo root if starting with `/`); rejects paths escaping `<root>` (`BD020`) and checks existence via `-e` (files or directories).
- When `#anchor` is present and the target is a `.md` file, verifies the ASCII-lowercased anchor exists in the target file's extracted slugs (`BD021`).

### Raw-byte SHA-256 sealing (`feature_archive_seal=true`)
- Manifest path: `.agents/notes/archived/manifest.sha256`.
- Format: unique lines of `<64-lowercase-hex-sha256>  <repo-relative-path>` (two literal spaces, standard `sha256sum` format), written sorted by path starting at byte offset 67 (`LC_ALL=C sort -k1.67`) by `--seal`.
- Sealed scope:
  - All regular files under `.agents/notes/archived/` except `.agents/notes/archived/AGENTS.md` and `.agents/notes/archived/manifest.sha256`.
  - When `feature_empirical_records=true`, all regular files inside any `.agents/records/<study-id>/` directory whose `README.md` (or `index.md` if `README.md` is absent) has exact `Status: concluded` on line 3.
- Symlinks anywhere under `.agents/notes/archived/` or `.agents/records/` (including the directories themselves, `AGENTS.md`, `manifest.sha256`, and study files) and non-normalized paths in `manifest.sha256` are rejected (`BD043`).
- Raw file bytes are hashed via stdin (`sha256sum < file` or `shasum -a 256 < file`, no CRLF/LF rewriting).

### `i18n-en-zh` pairing format (`BD060`)
- Applies to active `.md` files except `*.zh.md`, `AGENTS.md`, `CLAUDE.md`, `*/AGENTS.md`, `*/CLAUDE.md`, and `.agents/skills/*`.
- Each in-scope source `<stem>.md` (including active `.agents/notes/` and `.agents/records/` files) requires `<stem>.zh.md` and `<stem>.i18n.yaml` containing an unquoted `source_sha256: <64-hex>` line (trailing whitespace and `#` inline comments ignored) matching the raw-byte SHA-256 digest of `<stem>.md`.

---

## Diagnostic catalog

Hard failures (`BD001`–`BD070`) print `<ID> <loc> <message>` to **stderr** (where `<loc>` is `<path>[:<line>]` or `<tool>` for `BD070`). Advisory diagnostics (`BD901`–`BD903`) print to **stdout**.

### Hard-fail diagnostics (exit `1`)

| ID | Category | Condition |
| :--- | :--- | :--- |
| `BD001` | Tracked scratch | Any file under `.agents/scratch/` is tracked by git (`git -c core.quotePath=false ls-files -- .agents/scratch`). |
| `BD002` | Config | Missing required `kit_version`, unknown key, empty list value, malformed value/path, or violated feature dependency (`feature_empirical_records=true` or `feature_archive_seal=true` while `feature_notes=false`). |
| `BD003` | Subtree | Configured `subtree=` directory lacks an `AGENTS.md` file. |
| `BD010` | Budget | When `feature_budgets=true`, budgeted file is missing or token count exceeds configured `budget=` ceiling. |
| `BD020` | Link | Relative Markdown link target does not exist (`-e`) or escapes repository root. |
| `BD021` | Anchor | Relative Markdown `#anchor` fragment does not match any normalized ATX heading in target `.md` file. |
| `BD030` | Note tree | Active note under `.agents/notes/` (excluding `README.md`, `README.zh.md`, `AGENTS.md`, `*/AGENTS.md`, and `*.zh.md` under `i18n-en-zh`) does not match `{proposed,implemented,concluded,rejected}/{class}/YYYY-MM-DD-slug.md` (lowercase kebab-case), uses an unknown class, or uses `concluded/` while `feature_empirical_records=false`. |
| `BD031` | Note header | Line 1–4 header violates `# Agent Note: <title>` / blank / exact lifecycle status (`Status: proposed`, `Status: implemented`, `Status: concluded`, or `Status: rejected — <non-whitespace reason>` using U+2014 em-dash) / blank (file must have at least 4 lines), or repeats `Status:` outside fenced code. |
| `BD032` | Note sections | Missing required `##` sections (`proposed`: Problem, Proposal, Alternatives considered, Acceptance criteria, Risks; `implemented`: Problem, Decision, Alternatives considered, Consequences; `concluded`: Hypothesis / Question, Evidence, Conclusion, Direction impact, Alternatives considered; `rejected`: Problem, Proposal, Alternatives considered). Notes listed in `grandfathered_note=` are exempt from `## Alternatives considered`. |
| `BD033` | Note spec-speak | `implemented/` note contains a proposal-era heading (`## Proposal`, `## Plan`, `## Migration plan`, `## Acceptance criteria`). |
| `BD040` | Archive seal / CI | Missing `manifest.sha256` (outside `--seal`), `--ci` invoked without a valid `--base-ref` / `BETTER_DOCS_BASE_REF` distinct from `HEAD`, or an explicitly supplied `--base-ref` cannot resolve to a commit. |
| `BD041` | Archive seal | Baseline manifest entry from `--base-ref` was modified or removed (append-only violation). |
| `BD042` | Archive seal | Malformed or duplicate manifest line, sealed file digest mismatch against `manifest.sha256`, sealed file missing from `manifest.sha256` (outside `--seal`), or manifest entry missing on disk. |
| `BD043` | Archive seal | Symlink anywhere in `.agents/notes/archived/` or `.agents/records/` (including directories, `AGENTS.md`, `manifest.sha256`), or non-normalized path in `manifest.sha256`. |
| `BD050` | Hygiene | Trailing whitespace on any line, or missing trailing EOF newline in a non-empty active Markdown file. |
| `BD051` | Draft marker | Unresolved internal draft marker (`(decision N)`, `(audit XN)`) in prose outside fenced code blocks and inline code spans. |
| `BD060` | i18n pairing | Under `i18n-en-zh`, an in-scope `.md` file lacks `.zh.md` or `.i18n.yaml`, or `.i18n.yaml` lacks or mismatches `source_sha256`. |
| `BD070` | Required hook | Executable listed in `hook_required=` is missing from `PATH`, lacks a repo config (`vale`), or exited non-zero. |

### Advisory diagnostics (exit `0`)

| ID | Category | Condition |
| :--- | :--- | :--- |
| `BD901` | Lexical probe | Emitted with `--probes` on active `.md` files (excluding `skills/prose-standard/references/*`, `.agents/skills/prose-standard/references/*`, and concluded `.agents/records/<study-id>/*`) matching EN (`used to`, `this pr`, `previously`, `no longer`, `in conclusion`, `it is worth noting`, `it is important to note`, `seamless`, `seamlessly`, `effortless`) and/or ZH (`以前`, `不再`, `旧版`, `上一轮`, `评审`, `需要注意的是`, `值得一提的是`, `不仅如此`, `总而言之`, `综上所述`) probes outside fences and inline code (both EN and ZH are checked independently on every line). |
| `BD902` | Advisory hook | Executable listed in `hook_advisory=` is missing (`SKIPPED (not installed)`), lacks a repo config (`vale`: `SKIPPED (no vale config found)`), or exited non-zero (`advisory hook '<tool>' reported warnings`). |
| `BD903` | Submodule | Emitted in git mode whenever `.gitmodules` contains an unlisted gitlink (`SKIPPED (unlisted gitlink; default-closed)`) or uninitialized gitlink (`SKIPPED (uninitialized)`). |
