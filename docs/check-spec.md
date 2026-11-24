# Deterministic Check Gate Specification (`docs/check-spec.md`)

This document is the single authority for every deterministic check implemented by [gates/check-docs.sh](../gates/check-docs.sh) and any future repo-native gate engine. Every engine must pass [gates/conformance/run.sh](../gates/conformance/run.sh).

## Prerequisites and CLI contract

### Baseline prerequisites (`gates/check-docs.sh`)
- `bash` (>= 4.0)
- POSIX `awk`
- `git` (optional only when `--no-git` is passed; required for `--ci`, tracked-scratch checks, and submodule detection)
- `sha256sum` or `shasum -a 256`

### CLI flags

| Flag | Behavior |
| :--- | :--- |
| `--root <dir>` | Target repository root (default: current working directory). |
| `--config <path>` | Path to config file (default: `<root>/docs-check.conf`). |
| `--ci` | CI enforcement mode: requires `--base-ref` (or `BETTER_DOCS_BASE_REF`) resolving to a commit distinct from `HEAD`. |
| `--base-ref <ref>` | Baseline git ref for append-only archive seal checks (default outside `--ci`: `HEAD`). |
| `--seal` | Verify all existing archive seals, then append SHA-256 entries for newly archived files into `.agents/notes/archived/manifest.sha256` (and concluded study files when `feature_empirical_records=true`). |
| `--probes` | Also emit advisory EN/ZH lexical CoT/slop recall diagnostics (never changes exit code). |
| `--list-budgets` | Print current wordcount usage against every configured `budget=` entry and exit `0` if all pass, `1` if any fail. |

### Exit codes
- `0`: all required checks passed (advisory checks and `SKIPPED` hooks do not fail the run).
- `1`: one or more hard-fail diagnostic checks (`BD001`–`BD089`) failed.
- `2`: invocation error (bad CLI flags, missing config, missing required prerequisite binary).

---

## Configuration grammar (`docs-check.conf`)

Line-oriented `key=value` file:
- Blank lines and lines whose first non-whitespace character is `#` are ignored.
- Inline comments (` # ...`) are stripped only when preceded by whitespace.
- Leading/trailing whitespace around keys and values is trimmed.
- Scalar keys use the last declaration; list keys (`surface_rule`, `grandfathered_note`, `subtree`, `submodule_owned`, `submodule_shared`, `submodule_external`, `budget`, `hook_required`, `hook_advisory`) append in declaration order.

| Key | Kind | Allowed values / format | Default |
| :--- | :--- | :--- | :--- |
| `kit_version` | scalar | Semver string (`0.1.0`) | required |
| `language_mode` | scalar | `single-en`, `single-zh`, `split-by-surface`, `i18n-en-zh` | `single-en` |
| `language_primary` | scalar | `en`, `zh` | `en` |
| `surface_rule` | list | `<glob>\|<locale>\|<owner\|derived>` (first-match wins) | empty |
| `feature_notes` | bool | `true`, `false` | `false` |
| `feature_empirical_records` | bool | `true`, `false` (requires `feature_notes=true`) | `false` |
| `feature_archive_seal` | bool | `true`, `false` (requires `feature_notes=true`) | `false` |
| `feature_budgets` | bool | `true`, `false` | `false` |
| `note_classes` | csv | Comma-separated kebab-case class names | `feature,bug-fix,architecture,simplification,process,testing` |
| `grandfathered_note` | list | Exact repo-relative path to a pre-adoption note | empty |
| `subtree` | list | Repo-relative directory containing a subtree `AGENTS.md` | empty |
| `submodule_owned` | list | `<path>\|<repo_id>\|<starting_sha>\|<scope>` | empty |
| `submodule_shared` | list | Repo-relative gitlink path (read-only) | empty |
| `submodule_external` | list | Repo-relative gitlink path (read-only) | empty |
| `budget` | list | `<repo-relative-path>:<positive-int>` | empty |
| `hook_required` | list | Executable name on `PATH` (`lychee`, `vale`) | empty |
| `hook_advisory` | list | Executable name on `PATH` (`lychee`, `vale`) | empty |

---

## Scope, parsing, and counting semantics

### Tracked-file scope
- In a git repository, active Markdown files are discovered via `git ls-files --cached --others --exclude-standard -- '*.md'` (excluding `vendor/`, `node_modules/`, `.agents/notes/archived/`, and all gitlink paths unless a child is checked separately from its own root).
- Outside git, scan `*.md` with the same directory exclusions plus `.git/` and `.agents/scratch/`.
- **Default-closed gitlinks**: checking stops at every submodule boundary; uninitialized gitlinks listed in `.gitmodules` are reported as `SKIPPED (uninitialized)` and never silently treated as validated.

### Fenced-code stripping
- A line starting with optional indentation (up to 3 spaces) followed by three or more backticks (`` ``` ``) or tildes (`~~~`) toggles fence state until a matching closing fence of at least the same length.
- All heading extraction, link extraction, and mechanical prose checks ignore lines inside fenced code blocks.

### Token counting unit (`feature_budgets=true`)
- Designed for bilingual EN + ZH consistency:
  - Every non-CJK whitespace-delimited token counts as `1`.
  - Every CJK Unified Ideograph (`U+4E00`–`U+9FFF`, `U+3400`–`U+4DBF`, `U+F900`–`U+FAFF`) counts as `1`, even without spaces.
- Implementation in `awk`: count each CJK character as 1 token (replacing CJK runs with spaces before counting remaining whitespace-delimited tokens) so pure English matches `wc -w` exactly and pure Chinese matches character count.

### ATX heading and anchor normalization
- Extracted headings are ATX headings (`^#{1,6} `) outside fenced code blocks.
- GitHub-style slug normalization: lowercase ASCII, strip inline Markdown formatting (`` ` ``, `*`, `_`), drop punctuation except ASCII letters/digits, CJK characters, spaces, and `-`, replace spaces with `-`, and disambiguate duplicate slugs with `-1`, `-2`, ...

### Inline Markdown link extraction
- Matches `[label](target)` outside fenced code blocks and inline code spans (`` `...` ``).
- Ignores external schemes (`http://`, `https://`, `mailto:`, `tel:`, `data:`, `file://`) and pure placeholder targets (`<...>`).
- Strips optional title (`"..."`) and splits `path#anchor`.
- Resolves `path` relative to the containing file's directory (or repo root if starting with `/`); rejects paths escaping `<root>`.
- When `#anchor` is present and the target is a `.md` file, verifies the normalized anchor exists in the target file.

### Raw-byte SHA-256 sealing (`feature_archive_seal=true`)
- Manifest path: `.agents/notes/archived/manifest.sha256`.
- Format: sorted lines of `<64-lowercase-hex-sha256>  <repo-relative-path>` (two spaces, standard `sha256sum` format).
- Sealed scope:
  - All regular files under `.agents/notes/archived/` except `AGENTS.md` and `manifest.sha256`.
  - When `feature_empirical_records=true`, all regular files inside any `.agents/records/<study-id>/` directory whose `README.md` (or `index.md`) carries `Status: concluded`.
- Symlinks inside sealed scope are rejected (`BD043`).
- Raw file bytes are hashed directly (no CRLF/LF rewriting).

---

## Diagnostic catalog

Every hard failure prints `<ID> <path>[:<line>] <message>`.

### Hard-fail diagnostics (exit `1`)

| ID | Category | Condition |
| :--- | :--- | :--- |
| `BD001` | Tracked scratch | Any file under `.agents/scratch/` is tracked by git (`git ls-files .agents/scratch/`). |
| `BD002` | Config | Unknown key, malformed value, or violated dependency (`feature_empirical_records=true` or `feature_archive_seal=true` while `feature_notes=false`). |
| `BD003` | Subtree | Configured `subtree=` directory lacks an `AGENTS.md` file. |
| `BD010` | Budget | Budgeted file missing or token count exceeds configured `budget=` ceiling. |
| `BD020` | Link | Relative Markdown link target file does not exist or escapes repository root. |
| `BD021` | Anchor | Relative Markdown `#anchor` fragment does not match any ATX heading in target `.md` file. |
| `BD030` | Note tree | Active note path does not match `.agents/notes/{proposed,implemented,concluded,rejected}/{class}/YYYY-MM-DD-slug.md`, uses an unknown class, or uses `concluded/` while `feature_empirical_records=false`. |
| `BD031` | Note header | Line 1–4 header violates `# Agent Note: <title>` / blank / `Status: <lifecycle-grammar>` / blank, or repeats `Status:` in body. |
| `BD032` | Note sections | Missing required `##` sections (`proposed`: Problem, Proposal, Alternatives considered, Acceptance criteria, Risks; `implemented`: Problem, Decision, Alternatives considered, Consequences; `concluded`: Hypothesis / Question, Evidence, Conclusion, Direction impact, Alternatives considered; `rejected`: Problem, Proposal, Alternatives considered). Notes listed in `grandfathered_note=` are exempt from `## Alternatives considered`. |
| `BD033` | Note spec-speak | `implemented/` note contains a proposal-era heading (`## Proposal`, `## Plan`, `## Migration plan`, `## Acceptance criteria`). |
| `BD040` | Archive seal | Missing `manifest.sha256` or `--ci` invoked without a valid `--base-ref` distinct from `HEAD`. |
| `BD041` | Archive seal | Baseline manifest entry from `--base-ref` was modified or removed (append-only violation). |
| `BD042` | Archive seal | Sealed file digest mismatches `manifest.sha256`, or a sealed file is missing from `manifest.sha256`, or a manifest entry has no file on disk. |
| `BD043` | Archive seal | Symlink or non-normalized path found under sealed archive/record directories. |
| `BD050` | Hygiene | Trailing whitespace or missing trailing EOF newline in active Markdown file. |
| `BD051` | Draft marker | Unresolved internal draft marker (`(decision N)`, `(audit XN)`) in parsed prose outside fenced code blocks and inline code spans. |
| `BD060` | i18n pairing | In `i18n-en-zh`, an authored `.md` file lacks its `.zh.md` counterpart or `.i18n.yaml` sidecar, or `.i18n.yaml` `source_sha256` does not match the current source file digest. |
| `BD070` | Required hook | Tool listed in `hook_required=` is not installed on `PATH` or exited non-zero. |

### Advisory diagnostics (exit `0`, emitted with `--probes` or advisory hooks)

| ID | Category | Condition |
| :--- | :--- | :--- |
| `BD901` | Lexical probe | Advisory EN/ZH CoT-leakage or slop pattern match (`used to`, `this PR`, `previously`, `以前`, `不再`, `上一轮`, `评审`, etc.) for semantic review. |
| `BD902` | Advisory hook | Tool listed in `hook_advisory=` is not installed (`SKIPPED (not installed)`) or reported warnings. |
| `BD903` | Submodule | Gitlink in `.gitmodules` is uninitialized (`SKIPPED (uninitialized)`) or unlisted (`SKIPPED (unlisted gitlink)`). |
