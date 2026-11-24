#!/usr/bin/env bash
# better-docs universal deterministic documentation check gate.
# Specification: docs/check-spec.md (diagnostics BD001–BD070, BD901–BD903).
# Prerequisites: bash (>= 4.0), POSIX awk, git (unless --no-git), sha256sum or shasum.

set -uo pipefail

ROOT="."
CONFIG_PATH=""
CI_MODE=0
BASE_REF=""
SEAL_MODE=0
PROBES_MODE=0
LIST_BUDGETS=0
NO_GIT=0

usage() {
  cat <<'EOF'
Usage: check-docs.sh [options]
  --root <dir>         Target repository root (default: .)
  --config <path>      Config file path (default: <root>/docs-check.conf)
  --ci                 CI mode: requires --base-ref (or BETTER_DOCS_BASE_REF) != HEAD
  --base-ref <ref>     Git baseline ref for append-only archive seal checks
  --seal               Verify existing seals, then append newly archived files to manifest.sha256
  --probes             Emit advisory EN/ZH lexical recall diagnostics (BD901)
  --list-budgets       Print wordcount usage for every configured budget
  --no-git             Run without git (disables --ci, tracked-scratch, and gitlink checks)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    --ci) CI_MODE=1; shift ;;
    --base-ref) BASE_REF="${2:-}"; shift 2 ;;
    --seal) SEAL_MODE=1; shift ;;
    --probes) PROBES_MODE=1; shift ;;
    --list-budgets) LIST_BUDGETS=1; shift ;;
    --no-git) NO_GIT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "check-docs.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "check-docs.sh: root directory not found: $ROOT" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd -P)"
if [[ -z "$CONFIG_PATH" ]]; then
  CONFIG_PATH="$ROOT/docs-check.conf"
fi

# Prerequisite checks
if ! command -v awk >/dev/null 2>&1; then
  echo "check-docs.sh: missing prerequisite 'awk'" >&2
  exit 2
fi
SHA_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA_CMD="shasum -a 256"
else
  echo "check-docs.sh: missing prerequisite 'sha256sum' or 'shasum'" >&2
  exit 2
fi

hash_file() {
  local f="$1"
  if [[ "$SHA_CMD" == "sha256sum" ]]; then
    sha256sum "$f" | awk '{print $1}'
  else
    shasum -a 256 "$f" | awk '{print $1}'
  fi
}

IN_GIT=0
if [[ "$NO_GIT" -eq 0 ]] && command -v git >/dev/null 2>&1; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IN_GIT=1
  fi
fi

if [[ "$CI_MODE" -eq 1 && "$IN_GIT" -eq 0 ]]; then
  echo "check-docs.sh: --ci requires a git repository" >&2
  exit 2
fi

FAILURES=0
fail() {
  local id="$1"
  local loc="$2"
  local msg="$3"
  printf '%s %s %s\n' "$id" "$loc" "$msg" >&2
  FAILURES=$((FAILURES + 1))
}

advise() {
  local id="$1"
  local loc="$2"
  local msg="$3"
  printf '%s %s %s\n' "$id" "$loc" "$msg"
}

# ---------------------------------------------------------------------------
# 1. Tracked .agents/scratch/ rejection (BD001) — runs FIRST before exclusions
# ---------------------------------------------------------------------------
if [[ "$IN_GIT" -eq 1 ]]; then
  while IFS= read -r tracked_scratch; do
    [[ -n "$tracked_scratch" ]] && fail "BD001" "$tracked_scratch" "tracked file under .agents/scratch/ is forbidden"
  done < <(git -C "$ROOT" ls-files -- .agents/scratch)
fi

# ---------------------------------------------------------------------------
# 2. Parse and validate docs-check.conf (BD002)
# ---------------------------------------------------------------------------
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "check-docs.sh: config file not found: $CONFIG_PATH" >&2
  exit 2
fi

KIT_VERSION=""
LANGUAGE_MODE="single-en"
LANGUAGE_PRIMARY="en"
FEATURE_NOTES="false"
FEATURE_EMPIRICAL_RECORDS="false"
FEATURE_ARCHIVE_SEAL="false"
FEATURE_BUDGETS="false"
NOTE_CLASSES="feature,bug-fix,architecture,simplification,process,testing"

declare -a SURFACE_RULES=()
declare -a GRANDFATHERED_NOTES=()
declare -a SUBTREES=()
declare -a SUBMODULE_OWNED=()
declare -a SUBMODULE_SHARED=()
declare -a SUBMODULE_EXTERNAL=()
declare -a BUDGETS=()
declare -a HOOKS_REQUIRED=()
declare -a HOOKS_ADVISORY=()

line_no=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  # Strip CR if present
  line="${raw_line%$'\r'}"
  # Skip blank or full-line comment
  if [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi
  # Strip inline comment preceded by whitespace
  line="$(printf '%s' "$line" | sed -E 's/[[:space:]]+#.*$//')"
  # Trim leading/trailing whitespace
  line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  if [[ "$line" != *=* ]]; then
    fail "BD002" "docs-check.conf:$line_no" "malformed config line (expected key=value)"
    continue
  fi
  key="${line%%=*}"
  val="${line#*=}"
  key="$(printf '%s' "$key" | sed -E 's/[[:space:]]+$//')"
  val="$(printf '%s' "$val" | sed -E 's/^[[:space:]]+//')"

  case "$key" in
    kit_version) KIT_VERSION="$val" ;;
    language_mode) LANGUAGE_MODE="$val" ;;
    language_primary) LANGUAGE_PRIMARY="$val" ;;
    surface_rule) SURFACE_RULES+=("$val") ;;
    feature_notes) FEATURE_NOTES="$val" ;;
    feature_empirical_records) FEATURE_EMPIRICAL_RECORDS="$val" ;;
    feature_archive_seal) FEATURE_ARCHIVE_SEAL="$val" ;;
    feature_budgets) FEATURE_BUDGETS="$val" ;;
    note_classes) NOTE_CLASSES="$val" ;;
    grandfathered_note) GRANDFATHERED_NOTES+=("$val") ;;
    subtree) SUBTREES+=("$val") ;;
    submodule_owned) SUBMODULE_OWNED+=("$val") ;;
    submodule_shared) SUBMODULE_SHARED+=("$val") ;;
    submodule_external) SUBMODULE_EXTERNAL+=("$val") ;;
    budget) BUDGETS+=("$val") ;;
    hook_required) HOOKS_REQUIRED+=("$val") ;;
    hook_advisory) HOOKS_ADVISORY+=("$val") ;;
    *) fail "BD002" "docs-check.conf:$line_no" "unknown config key '$key'" ;;
  esac
done < "$CONFIG_PATH"

is_bool() { [[ "$1" == "true" || "$1" == "false" ]]; }

[[ -z "$KIT_VERSION" ]] && fail "BD002" "docs-check.conf" "missing required key 'kit_version'"
case "$LANGUAGE_MODE" in
  single-en|single-zh|split-by-surface|i18n-en-zh) ;;
  *) fail "BD002" "docs-check.conf" "invalid language_mode '$LANGUAGE_MODE'" ;;
esac
case "$LANGUAGE_PRIMARY" in
  en|zh) ;;
  *) fail "BD002" "docs-check.conf" "invalid language_primary '$LANGUAGE_PRIMARY'" ;;
esac
is_bool "$FEATURE_NOTES" || fail "BD002" "docs-check.conf" "feature_notes must be true or false"
is_bool "$FEATURE_EMPIRICAL_RECORDS" || fail "BD002" "docs-check.conf" "feature_empirical_records must be true or false"
is_bool "$FEATURE_ARCHIVE_SEAL" || fail "BD002" "docs-check.conf" "feature_archive_seal must be true or false"
is_bool "$FEATURE_BUDGETS" || fail "BD002" "docs-check.conf" "feature_budgets must be true or false"

if [[ "$FEATURE_EMPIRICAL_RECORDS" == "true" && "$FEATURE_NOTES" != "true" ]]; then
  fail "BD002" "docs-check.conf" "feature_empirical_records=true requires feature_notes=true"
fi
if [[ "$FEATURE_ARCHIVE_SEAL" == "true" && "$FEATURE_NOTES" != "true" ]]; then
  fail "BD002" "docs-check.conf" "feature_archive_seal=true requires feature_notes=true"
fi

for sr in "${SURFACE_RULES[@]}"; do
  if [[ ! "$sr" =~ ^[^|]+\|(en|zh)\|(owner|derived)$ ]]; then
    fail "BD002" "docs-check.conf" "invalid surface_rule '$sr' (expected <glob>|<en|zh>|<owner|derived>)"
  fi
done

for sub_dir in "${SUBTREES[@]}"; do
  if [[ ! -f "$ROOT/$sub_dir/AGENTS.md" ]]; then
    fail "BD003" "$sub_dir/AGENTS.md" "configured subtree is missing AGENTS.md"
  fi
done

# ---------------------------------------------------------------------------
# 3. Submodule discovery and default-closed gitlink tracking (BD903)
# ---------------------------------------------------------------------------
declare -A GITLINK_PATHS=()
declare -A DECLARED_SUBMODULES=()

for entry in "${SUBMODULE_OWNED[@]}"; do
  sub_p="${entry%%|*}"
  DECLARED_SUBMODULES["$sub_p"]="owned"
done
for entry in "${SUBMODULE_SHARED[@]}"; do
  DECLARED_SUBMODULES["$entry"]="shared"
done
for entry in "${SUBMODULE_EXTERNAL[@]}"; do
  DECLARED_SUBMODULES["$entry"]="external"
done

if [[ -f "$ROOT/.gitmodules" ]] && command -v git >/dev/null 2>&1; then
  while IFS= read -r gm_line; do
    sub_p="${gm_line#* }"
    [[ -z "$sub_p" ]] && continue
    GITLINK_PATHS["$sub_p"]=1
    if [[ -z "${DECLARED_SUBMODULES[$sub_p]:-}" ]]; then
      advise "BD903" "$sub_p" "SKIPPED (unlisted gitlink; default-closed)"
    fi
    if [[ ! -e "$ROOT/$sub_p/.git" ]]; then
      advise "BD903" "$sub_p" "SKIPPED (uninitialized)"
    fi
  done < <(git config --file "$ROOT/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
fi

is_excluded_path() {
  local p="$1"
  case "$p" in
    vendor/*|node_modules/*|.git/*|.agents/scratch/*|.agents/notes/archived/*) return 0 ;;
  esac
  for gp in "${!GITLINK_PATHS[@]}"; do
    if [[ "$p" == "$gp" || "$p" == "$gp/"* ]]; then
      return 0
    fi
  done
  for gp in "${!DECLARED_SUBMODULES[@]}"; do
    if [[ "$p" == "$gp" || "$p" == "$gp/"* ]]; then
      return 0
    fi
  done
  return 1
}

# Collect active Markdown files (sorted)
declare -a ACTIVE_MD_FILES=()
if [[ "$IN_GIT" -eq 1 ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ ! -f "$ROOT/$f" || -L "$ROOT/$f" ]] && continue
    is_excluded_path "$f" && continue
    ACTIVE_MD_FILES+=("$f")
  done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard -- '*.md' | LC_ALL=C sort -u)
else
  while IFS= read -r f; do
    f="${f#./}"
    [[ -z "$f" ]] && continue
    [[ -L "$ROOT/$f" ]] && continue
    is_excluded_path "$f" && continue
    ACTIVE_MD_FILES+=("$f")
  done < <(cd "$ROOT" && find . -type f -name '*.md' | LC_ALL=C sort)
fi

# ---------------------------------------------------------------------------
# 4. Token counter (EN whitespace tokens + 1 per CJK Unified Ideograph)
# ---------------------------------------------------------------------------
count_tokens() {
  local file="$1"
  LC_ALL=C awk '
    BEGIN {
      for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i
      tokens = 0
    }
    {
      s = $0
      n = length(s)
      i = 1
      in_word = 0
      while (i <= n) {
        c = substr(s, i, 1)
        b1 = ord[c]
        if (b1 >= 224 && b1 <= 239 && i + 2 <= n) {
          b2 = ord[substr(s, i + 1, 1)]
          b3 = ord[substr(s, i + 2, 1)]
          cp = (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128)
          if ((cp >= 19968 && cp <= 40959) || (cp >= 13312 && cp <= 19903) || (cp >= 63744 && cp <= 64255)) {
            tokens++
            in_word = 0
            i += 3
            continue
          }
          if (!in_word) { tokens++; in_word = 1 }
          i += 3
          continue
        }
        if (c == " " || c == "\t" || c == "\r") {
          in_word = 0
        } else {
          if (!in_word) { tokens++; in_word = 1 }
        }
        i++
      }
    }
    END { print tokens + 0 }
  ' "$file"
}

# ---------------------------------------------------------------------------
# 5. Wordcount budgets (BD010)
# ---------------------------------------------------------------------------
if [[ "$FEATURE_BUDGETS" == "true" || "$LIST_BUDGETS" -eq 1 ]]; then
  budget_failed=0
  for b in "${BUDGETS[@]}"; do
    if [[ ! "$b" =~ ^[^:]+:[1-9][0-9]*$ ]]; then
      fail "BD002" "docs-check.conf" "invalid budget entry '$b' (expected <path>:<positive-int>)"
      budget_failed=1
      continue
    fi
    b_path="${b%:*}"
    b_max="${b##*:}"
    if [[ ! -f "$ROOT/$b_path" ]]; then
      [[ "$LIST_BUDGETS" -eq 1 ]] && printf 'MISS  %6s / %-6s %s\n' "-" "$b_max" "$b_path"
      fail "BD010" "$b_path" "budgeted file does not exist"
      budget_failed=1
      continue
    fi
    b_actual="$(count_tokens "$ROOT/$b_path")"
    if [[ "$LIST_BUDGETS" -eq 1 ]]; then
      status_lbl="ok  "
      (( b_actual > b_max )) && status_lbl="OVER"
      printf '%s  %6d / %-6d %s\n' "$status_lbl" "$b_actual" "$b_max" "$b_path"
    fi
    if (( b_actual > b_max )); then
      fail "BD010" "$b_path" "$b_actual tokens exceeds ceiling of $b_max (relocate, condense, or justify raise)"
      budget_failed=1
    fi
  done
  if [[ "$LIST_BUDGETS" -eq 1 && "$PROBES_MODE" -eq 0 ]]; then
    exit "$budget_failed"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Heading anchor index & relative Markdown link checks (BD020, BD021)
# ---------------------------------------------------------------------------
extract_anchors() {
  local file="$1"
  LC_ALL=C awk '
    BEGIN { in_fence = 0; fence_char = ""; fence_len = 0 }
    {
      line = $0
      sub(/\r$/, "", line)
      if (match(line, /^[ ]{0,3}(`{3,}|~{3,})/)) {
        m = substr(line, RSTART, RLENGTH)
        sub(/^[ ]+/, "", m)
        fc = substr(m, 1, 1)
        fl = length(m)
        if (!in_fence) {
          in_fence = 1; fence_char = fc; fence_len = fl; next
        } else if (fc == fence_char && fl >= fence_len && line ~ /^[ ]{0,3}(`{3,}|~{3,})[[:space:]]*$/) {
          in_fence = 0; next
        }
      }
      if (in_fence) next
      if (line ~ /^#{1,6}[ \t]+/) {
        h = line
        sub(/^#{1,6}[ \t]+/, "", h)
        sub(/[ \t]+#+[ \t]*$/, "", h)
        # Strip inline markdown links [text](url) -> text
        while (match(h, /\[[^\]]*\]\([^)]*\)/)) {
          seg = substr(h, RSTART, RLENGTH)
          sub(/^\[/, "", seg)
          sub(/\]\([^)]*\)$/, "", seg)
          h = substr(h, 1, RSTART - 1) seg substr(h, RSTART + RLENGTH)
        }
        gsub(/[`*_]/, "", h)
        h = tolower(h)
        # Keep ASCII a-z 0-9 space hyphen and non-ASCII bytes (>= 0x80)
        out = ""
        n = length(h)
        for (i = 1; i <= n; i++) {
          ch = substr(h, i, 1)
          if (ch ~ /[a-z0-9 -]/ || ch >= "\200") out = out ch
        }
        gsub(/^[ ]+|[ ]+$/, "", out)
        gsub(/ /, "-", out)
        if (out == "") next
        cnt = seen[out] + 0
        seen[out] = cnt + 1
        if (cnt == 0) print out
        else print out "-" cnt
      }
    }
  ' "$file"
}

declare -A ANCHOR_CACHE=()
has_anchor() {
  local target_file="$1"
  local want="$2"
  if [[ -z "${ANCHOR_CACHE[$target_file]+x}" ]]; then
    ANCHOR_CACHE["$target_file"]=$'\n'"$(extract_anchors "$target_file")"$'\n'
  fi
  [[ "${ANCHOR_CACHE[$target_file]}" == *$'\n'"$want"$'\n'* ]]
}

normalize_rel_path() {
  local base_dir="$1"
  local rel="$2"
  local combined
  if [[ "$rel" == /* ]]; then
    combined="${rel#/}"
  elif [[ -n "$base_dir" && "$base_dir" != "." ]]; then
    combined="$base_dir/$rel"
  else
    combined="$rel"
  fi
  awk -v p="$combined" '
    BEGIN {
      n = split(p, parts, "/")
      depth = 0
      for (i = 1; i <= n; i++) {
        seg = parts[i]
        if (seg == "" || seg == ".") continue
        if (seg == "..") {
          if (depth == 0) { print "__ESCAPE__"; exit }
          depth--
        } else {
          stack[++depth] = seg
        }
      }
      out = ""
      for (i = 1; i <= depth; i++) {
        out = (i == 1 ? stack[i] : out "/" stack[i])
      }
      print out
    }
  '
}

for rel_file in "${ACTIVE_MD_FILES[@]}"; do
  abs_file="$ROOT/$rel_file"
  file_dir="$(dirname "$rel_file")"
  while IFS=$'\t' read -r lno raw_target; do
    [[ -z "$raw_target" ]] && continue
    # Strip optional title ("..." or '...') and surrounding whitespace
    target="$(printf '%s' "$raw_target" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+("[^"]*"|'\''[^'\'']*'\'')[[:space:]]*$//; s/[[:space:]]+$//')"
    # Ignore external schemes, angle-bracket placeholders, and template tokens
    case "$target" in
      ""|"#"|http://*|https://*|mailto:*|tel:*|data:*|file://*|"<"*|*"{{") continue ;;
    esac
    if [[ "$target" == *"{{"* ]]; then continue; fi

    link_path="${target%%#*}"
    link_anchor=""
    if [[ "$target" == *#* ]]; then
      link_anchor="${target#*#}"
    fi

    resolved=""
    if [[ -z "$link_path" ]]; then
      resolved="$rel_file"
    else
      resolved="$(normalize_rel_path "$file_dir" "$link_path")"
      if [[ "$resolved" == "__ESCAPE__" ]]; then
        fail "BD020" "$rel_file:$lno" "link '$target' escapes repository root"
        continue
      fi
    fi

    if [[ ! -e "$ROOT/$resolved" ]]; then
      fail "BD020" "$rel_file:$lno" "broken relative link '$target' (missing '$resolved')"
      continue
    fi

    if [[ -n "$link_anchor" && -f "$ROOT/$resolved" && "$resolved" == *.md ]]; then
      norm_anchor="$(printf '%s' "$link_anchor" | tr '[:upper:]' '[:lower:]')"
      if ! has_anchor "$ROOT/$resolved" "$norm_anchor"; then
        fail "BD021" "$rel_file:$lno" "missing anchor '#$link_anchor' in '$resolved'"
      fi
    fi
  done < <(LC_ALL=C awk '
    BEGIN { in_fence = 0; fence_char = ""; fence_len = 0 }
    {
      line = $0
      sub(/\r$/, "", line)
      if (match(line, /^[ ]{0,3}(`{3,}|~{3,})/)) {
        m = substr(line, RSTART, RLENGTH)
        sub(/^[ ]+/, "", m)
        fc = substr(m, 1, 1)
        fl = length(m)
        if (!in_fence) {
          in_fence = 1; fence_char = fc; fence_len = fl; next
        } else if (fc == fence_char && fl >= fence_len && line ~ /^[ ]{0,3}(`{3,}|~{3,})[[:space:]]*$/) {
          in_fence = 0; next
        }
      }
      if (in_fence) next
      # Remove inline code spans `...`
      s = line
      while (match(s, /`[^`]*`/)) {
        s = substr(s, 1, RSTART - 1) substr(s, RSTART + RLENGTH)
      }
      while (match(s, /\[[^][]+\]\([^)]+\)/)) {
        seg = substr(s, RSTART, RLENGTH)
        rest = substr(s, RSTART + RLENGTH)
        sub(/^\[[^][]+\]\(/, "", seg)
        sub(/\)$/, "", seg)
        printf "%d\t%s\n", NR, seg
        s = rest
      }
    }
  ' "$abs_file")
done

# ---------------------------------------------------------------------------
# 7. Agent Note tree and format checks (BD030–BD033)
# ---------------------------------------------------------------------------
if [[ "$FEATURE_NOTES" == "true" ]]; then
  declare -A ALLOWED_CLASSES=()
  IFS=',' read -ra _cls_arr <<< "$NOTE_CLASSES"
  for c in "${_cls_arr[@]}"; do
    c="$(printf '%s' "$c" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -n "$c" ]] && ALLOWED_CLASSES["$c"]=1
  done

  declare -A GRANDFATHER_SET=()
  for gf in "${GRANDFATHERED_NOTES[@]}"; do
    GRANDFATHER_SET["$gf"]=1
  done

  for rel_file in "${ACTIVE_MD_FILES[@]}"; do
    [[ "$rel_file" != .agents/notes/* ]] && continue
    # Skip index/governance files and Chinese mirror counterparts
    case "$rel_file" in
      .agents/notes/README.md|.agents/notes/README.zh.md|.agents/notes/AGENTS.md|.agents/notes/*/AGENTS.md) continue ;;
    esac
    if [[ "$LANGUAGE_MODE" == "i18n-en-zh" && "$rel_file" == *.zh.md ]]; then
      continue
    fi

    sub="${rel_file#.agents/notes/}"
    if [[ ! "$sub" =~ ^(proposed|implemented|concluded|rejected)/([a-z0-9-]+)/([0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+)\.md$ ]]; then
      fail "BD030" "$rel_file" "note path must match .agents/notes/{proposed,implemented,concluded,rejected}/{class}/YYYY-MM-DD-slug.md"
      continue
    fi
    lifecycle="${BASH_REMATCH[1]}"
    nclass="${BASH_REMATCH[2]}"
    if [[ "$lifecycle" == "concluded" && "$FEATURE_EMPIRICAL_RECORDS" != "true" ]]; then
      fail "BD030" "$rel_file" "concluded/ lifecycle requires feature_empirical_records=true"
    fi
    if [[ -z "${ALLOWED_CLASSES[$nclass]:-}" ]]; then
      fail "BD030" "$rel_file" "unknown note class '$nclass' (allowed: $NOTE_CLASSES)"
    fi

    is_gf=0
    [[ -n "${GRANDFATHER_SET[$rel_file]:-}" ]] && is_gf=1

    while IFS=$'\t' read -r diag_id diag_msg; do
      [[ -n "$diag_id" ]] && fail "$diag_id" "$rel_file" "$diag_msg"
    done < <(LC_ALL=C awk -v lifecycle="$lifecycle" -v is_gf="$is_gf" '
      BEGIN { in_fence = 0; status_hits = 0; h2_count = 0 }
      {
        line = $0
        sub(/\r$/, "", line)
        lines[NR] = line
        if (match(line, /^[ ]{0,3}(`{3,}|~{3,})/)) {
          m = substr(line, RSTART, RLENGTH)
          sub(/^[ ]+/, "", m)
          fc = substr(m, 1, 1); fl = length(m)
          if (!in_fence) { in_fence = 1; fence_char = fc; fence_len = fl; next }
          else if (fc == fence_char && fl >= fence_len && line ~ /^[ ]{0,3}(`{3,}|~{3,})[[:space:]]*$/) { in_fence = 0; next }
        }
        if (in_fence) next
        if (line ~ /^Status:/) status_hits++
        if (line ~ /^## /) {
          h = line
          sub(/[[:space:]]+$/, "", h)
          h2[++h2_count] = h
          has_h2[h] = 1
        }
      }
      END {
        if (lines[1] !~ /^# Agent Note: [^[:space:]]/) {
          printf "BD031\tline 1 must be `# Agent Note: <title>`\n"
        }
        if (lines[2] != "") {
          printf "BD031\tline 2 must be blank\n"
        }
        status_ok = 0
        if (lifecycle == "proposed" && lines[3] == "Status: proposed") status_ok = 1
        if (lifecycle == "implemented" && lines[3] == "Status: implemented") status_ok = 1
        if (lifecycle == "concluded" && lines[3] == "Status: concluded") status_ok = 1
        if (lifecycle == "rejected" && lines[3] ~ /^Status: rejected — .+/) status_ok = 1
        if (!status_ok) {
          printf "BD031\tline 3 does not match %s status grammar\n", lifecycle
        }
        if (lines[4] != "") {
          printf "BD031\tline 4 must be blank\n"
        }
        if (status_hits > 1) {
          printf "BD031\tmultiple Status: lines found outside fenced code\n"
        }

        if (lifecycle == "concluded") {
          req_n = split("## Hypothesis / Question|## Evidence|## Conclusion|## Direction impact", req, "|")
        } else if (lifecycle == "proposed") {
          req_n = split("## Problem|## Proposal|## Acceptance criteria|## Risks", req, "|")
        } else if (lifecycle == "implemented") {
          req_n = split("## Problem|## Decision|## Consequences", req, "|")
        } else {
          req_n = split("## Problem|## Proposal", req, "|")
        }

        for (i = 1; i <= req_n; i++) {
          if (!has_h2[req[i]]) {
            printf "BD032\tmissing required section `%s`\n", req[i]
          }
        }
        if (!is_gf && !has_h2["## Alternatives considered"]) {
          printf "BD032\tmissing required section `## Alternatives considered`\n"
        }

        if (lifecycle == "implemented") {
          for (i = 1; i <= h2_count; i++) {
            low = tolower(h2[i])
            if (low ~ /^## (proposal|plan|migration plan|acceptance criteria)($| )/) {
              printf "BD033\tproposal-era heading `%s` is forbidden in implemented/\n", h2[i]
            }
          }
        }
      }
    ' "$ROOT/$rel_file")
  done
fi

# ---------------------------------------------------------------------------
# 8. Append-only frozen archive seal (BD040–BD043)
# ---------------------------------------------------------------------------
if [[ "$FEATURE_ARCHIVE_SEAL" == "true" ]]; then
  ARCHIVE_DIR="$ROOT/.agents/notes/archived"
  MANIFEST_REL=".agents/notes/archived/manifest.sha256"
  MANIFEST_ABS="$ROOT/$MANIFEST_REL"

  # Determine baseline ref
  EFFECTIVE_BASE_REF="$BASE_REF"
  if [[ -z "$EFFECTIVE_BASE_REF" && -n "${BETTER_DOCS_BASE_REF:-}" ]]; then
    EFFECTIVE_BASE_REF="$BETTER_DOCS_BASE_REF"
  fi

  BASE_COMMIT=""
  if [[ "$CI_MODE" -eq 1 ]]; then
    if [[ -z "$EFFECTIVE_BASE_REF" ]]; then
      fail "BD040" "$MANIFEST_REL" "--ci requires --base-ref or BETTER_DOCS_BASE_REF"
    else
      head_sha="$(git -C "$ROOT" rev-parse --verify HEAD 2>/dev/null || true)"
      base_sha="$(git -C "$ROOT" rev-parse --verify "${EFFECTIVE_BASE_REF}^{commit}" 2>/dev/null || true)"
      if [[ -z "$base_sha" ]]; then
        fail "BD040" "$MANIFEST_REL" "cannot resolve --base-ref '$EFFECTIVE_BASE_REF' to a commit"
      elif [[ "$base_sha" == "$head_sha" ]]; then
        fail "BD040" "$MANIFEST_REL" "--ci --base-ref must be distinct from HEAD"
      else
        BASE_COMMIT="$base_sha"
      fi
    fi
  elif [[ "$IN_GIT" -eq 1 ]]; then
    [[ -z "$EFFECTIVE_BASE_REF" ]] && EFFECTIVE_BASE_REF="HEAD"
    BASE_COMMIT="$(git -C "$ROOT" rev-parse --verify "${EFFECTIVE_BASE_REF}^{commit}" 2>/dev/null || true)"
  fi

  # Collect current sealed files on disk and reject symlinks (BD043)
  declare -A DISK_SEALED=()
  if [[ -d "$ARCHIVE_DIR" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      rel="${entry#$ROOT/}"
      [[ "$rel" == ".agents/notes/archived/AGENTS.md" || "$rel" == "$MANIFEST_REL" ]] && continue
      if [[ -L "$entry" ]]; then
        fail "BD043" "$rel" "symlinks are forbidden inside sealed archive scope"
        continue
      fi
      [[ -f "$entry" ]] && DISK_SEALED["$rel"]="$(hash_file "$entry")"
    done < <(find "$ARCHIVE_DIR" -mindepth 1 \( -type f -o -type l \) | LC_ALL=C sort)
  fi

  if [[ "$FEATURE_EMPIRICAL_RECORDS" == "true" && -d "$ROOT/.agents/records" ]]; then
    for study_dir in "$ROOT/.agents/records"/*; do
      [[ ! -d "$study_dir" ]] && continue
      study_readme=""
      [[ -f "$study_dir/README.md" ]] && study_readme="$study_dir/README.md"
      [[ -z "$study_readme" && -f "$study_dir/index.md" ]] && study_readme="$study_dir/index.md"
      [[ -z "$study_readme" ]] && continue
      line3="$(sed -n '3p' "$study_readme" | tr -d '\r')"
      if [[ "$line3" == "Status: concluded" ]]; then
        while IFS= read -r entry; do
          [[ -z "$entry" ]] && continue
          rel="${entry#$ROOT/}"
          if [[ -L "$entry" ]]; then
            fail "BD043" "$rel" "symlinks are forbidden inside concluded study scope"
            continue
          fi
          [[ -f "$entry" ]] && DISK_SEALED["$rel"]="$(hash_file "$entry")"
        done < <(find "$study_dir" -mindepth 1 \( -type f -o -type l \) | LC_ALL=C sort)
      fi
    done
  fi

  # Parse current manifest.sha256
  declare -A CUR_MANIFEST=()
  if [[ -f "$MANIFEST_ABS" ]]; then
    mlno=0
    while IFS= read -r mline || [[ -n "$mline" ]]; do
      mlno=$((mlno + 1))
      mline="${mline%$'\r'}"
      [[ -z "$mline" ]] && continue
      if [[ ! "$mline" =~ ^([0-9a-f]{64})[[:space:]][[:space:]](.+)$ ]]; then
        fail "BD042" "$MANIFEST_REL:$mlno" "malformed manifest line"
        continue
      fi
      mhash="${BASH_REMATCH[1]}"
      mpath="${BASH_REMATCH[2]}"
      if [[ "$mpath" == /* || "$mpath" == *../* || "$mpath" == */.. || "$mpath" == *./* ]]; then
        fail "BD043" "$MANIFEST_REL:$mlno" "non-normalized path '$mpath'"
        continue
      fi
      CUR_MANIFEST["$mpath"]="$mhash"
    done < "$MANIFEST_ABS"
  elif [[ "$SEAL_MODE" -eq 0 ]]; then
    fail "BD040" "$MANIFEST_REL" "missing archive manifest (run --seal to initialize)"
  fi

  # Verify append-only extension relative to baseline commit (BD041)
  if [[ -n "$BASE_COMMIT" ]]; then
    if git -C "$ROOT" cat-file -e "${BASE_COMMIT}:${MANIFEST_REL}" 2>/dev/null; then
      while IFS= read -r bline || [[ -n "$bline" ]]; do
        bline="${bline%$'\r'}"
        [[ -z "$bline" ]] && continue
        if [[ "$bline" =~ ^([0-9a-f]{64})[[:space:]][[:space:]](.+)$ ]]; then
          bhash="${BASH_REMATCH[1]}"
          bpath="${BASH_REMATCH[2]}"
          if [[ -z "${CUR_MANIFEST[$bpath]:-}" ]]; then
            fail "BD041" "$bpath" "sealed entry from baseline ($BASE_COMMIT) was removed"
          elif [[ "${CUR_MANIFEST[$bpath]}" != "$bhash" ]]; then
            fail "BD041" "$bpath" "sealed digest from baseline ($BASE_COMMIT) was modified"
          fi
        fi
      done < <(git -C "$ROOT" show "${BASE_COMMIT}:${MANIFEST_REL}")
    fi
  fi

  # Verify existing manifest entries match disk
  seal_pre_failures="$FAILURES"
  for mpath in "${!CUR_MANIFEST[@]}"; do
    if [[ -z "${DISK_SEALED[$mpath]:-}" ]]; then
      fail "BD042" "$mpath" "manifest entry has no corresponding sealed file on disk"
    elif [[ "${DISK_SEALED[$mpath]}" != "${CUR_MANIFEST[$mpath]}" ]]; then
      fail "BD042" "$mpath" "sealed file digest mismatch (expected ${CUR_MANIFEST[$mpath]}, got ${DISK_SEALED[$mpath]})"
    fi
  done

  if [[ "$SEAL_MODE" -eq 1 ]]; then
    if [[ "$FAILURES" -eq "$seal_pre_failures" ]]; then
      mkdir -p "$ARCHIVE_DIR"
      {
        for sp in "${!DISK_SEALED[@]}"; do
          printf '%s  %s\n' "${DISK_SEALED[$sp]}" "$sp"
        done
      } | LC_ALL=C sort -k2,2 > "$MANIFEST_ABS"
    fi
  else
    for sp in "${!DISK_SEALED[@]}"; do
      if [[ -z "${CUR_MANIFEST[$sp]:-}" ]]; then
        fail "BD042" "$sp" "sealed file is missing from $MANIFEST_REL (run --seal)"
      fi
    done
  fi
fi

# ---------------------------------------------------------------------------
# 9. Mechanical prose hygiene (BD050) and draft markers (BD051)
# ---------------------------------------------------------------------------
for rel_file in "${ACTIVE_MD_FILES[@]}"; do
  abs_file="$ROOT/$rel_file"
  # EOF trailing newline check (non-empty files)
  if [[ -s "$abs_file" ]]; then
    last_byte="$(tail -c 1 "$abs_file" | od -An -tx1 | tr -d ' \n')"
    if [[ "$last_byte" != "0a" ]]; then
      fail "BD050" "$rel_file" "missing trailing newline at EOF"
    fi
  fi

  while IFS=$'\t' read -r diag_id lno diag_msg; do
    [[ -n "$diag_id" ]] && fail "$diag_id" "$rel_file:$lno" "$diag_msg"
  done < <(LC_ALL=C awk '
    BEGIN { in_fence = 0; fence_char = ""; fence_len = 0 }
    {
      raw = $0
      sub(/\r$/, "", raw)
      if (raw ~ /[ \t]+$/) {
        printf "BD050\t%d\ttrailing whitespace\n", NR
      }
      if (match(raw, /^[ ]{0,3}(`{3,}|~{3,})/)) {
        m = substr(raw, RSTART, RLENGTH)
        sub(/^[ ]+/, "", m)
        fc = substr(m, 1, 1); fl = length(m)
        if (!in_fence) { in_fence = 1; fence_char = fc; fence_len = fl; next }
        else if (fc == fence_char && fl >= fence_len && raw ~ /^[ ]{0,3}(`{3,}|~{3,})[[:space:]]*$/) { in_fence = 0; next }
      }
      if (in_fence) next
      s = raw
      while (match(s, /`[^`]*`/)) {
        s = substr(s, 1, RSTART - 1) substr(s, RSTART + RLENGTH)
      }
      if (s ~ /\(decision [0-9]+\)|\(audit [A-Z][0-9]+\)/) {
        printf "BD051\t%d\tunresolved internal draft marker in prose\n", NR
      }
    }
  ' "$abs_file")
done

# ---------------------------------------------------------------------------
# 10. i18n-en-zh pairing check (BD060)
# ---------------------------------------------------------------------------
if [[ "$LANGUAGE_MODE" == "i18n-en-zh" ]]; then
  for rel_file in "${ACTIVE_MD_FILES[@]}"; do
    case "$rel_file" in
      *.zh.md|AGENTS.md|CLAUDE.md|*/AGENTS.md|*/CLAUDE.md) continue ;;
    esac
    stem="${rel_file%.md}"
    zh_rel="${stem}.zh.md"
    sidecar_rel="${stem}.i18n.yaml"
    if [[ ! -f "$ROOT/$zh_rel" ]]; then
      fail "BD060" "$rel_file" "missing Chinese counterpart '$zh_rel'"
    fi
    if [[ ! -f "$ROOT/$sidecar_rel" ]]; then
      fail "BD060" "$rel_file" "missing i18n sidecar '$sidecar_rel'"
      continue
    fi
    recorded_sha="$(awk -F':[[:space:]]*' '$1 == "source_sha256" { gsub(/\r$/, "", $2); print $2; exit }' "$ROOT/$sidecar_rel")"
    actual_sha="$(hash_file "$ROOT/$rel_file")"
    if [[ -z "$recorded_sha" ]]; then
      fail "BD060" "$sidecar_rel" "missing source_sha256 field"
    elif [[ "$recorded_sha" != "$actual_sha" ]]; then
      fail "BD060" "$sidecar_rel" "stale translation sidecar (source_sha256=$recorded_sha, actual=$actual_sha)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 11. Advisory EN/ZH lexical CoT/slop probes (--probes -> BD901)
# ---------------------------------------------------------------------------
if [[ "$PROBES_MODE" -eq 1 ]]; then
  for rel_file in "${ACTIVE_MD_FILES[@]}"; do
    case "$rel_file" in
      skills/prose-standard/references/*|.agents/skills/prose-standard/references/*) continue ;;
    esac
    while IFS=$'\t' read -r lno hit; do
      [[ -n "$lno" ]] && advise "BD901" "$rel_file:$lno" "advisory probe match: $hit"
    done < <(awk '
      BEGIN { in_fence = 0; fence_char = ""; fence_len = 0 }
      {
        raw = $0
        sub(/\r$/, "", raw)
        if (match(raw, /^[ ]{0,3}(`{3,}|~{3,})/)) {
          m = substr(raw, RSTART, RLENGTH)
          sub(/^[ ]+/, "", m)
          fc = substr(m, 1, 1); fl = length(m)
          if (!in_fence) { in_fence = 1; fence_char = fc; fence_len = fl; next }
          else if (fc == fence_char && fl >= fence_len && raw ~ /^[ ]{0,3}(`{3,}|~{3,})[[:space:]]*$/) { in_fence = 0; next }
        }
        if (in_fence) next
        s = raw
        while (match(s, /`[^`]*`/)) {
          s = substr(s, 1, RSTART - 1) substr(s, RSTART + RLENGTH)
        }
        low = tolower(s)
        if (match(low, /(^|[^a-z])(used to|this pr|previously|no longer|in conclusion|it is worth noting|it is important to note|seamless|seamlessly|effortless)([^a-z]|$)/)) {
          printf "%d\t%s\n", NR, substr(low, RSTART, RLENGTH)
        } else if (match(s, /(以前|不再|旧版|上一轮|评审|需要注意的是|值得一提的是|不仅如此|总而言之|综上所述)/)) {
          printf "%d\t%s\n", NR, substr(s, RSTART, RLENGTH)
        }
      }
    ' "$ROOT/$rel_file")
  done
fi

# ---------------------------------------------------------------------------
# 12. External hooks: required (BD070) vs advisory (BD902)
# ---------------------------------------------------------------------------
run_hook() {
  local tool="$1"
  case "$tool" in
    lychee) lychee --no-progress --offline "$ROOT" >/dev/null 2>&1 ;;
    vale) vale "$ROOT" >/dev/null 2>&1 ;;
    *) "$tool" "$ROOT" >/dev/null 2>&1 ;;
  esac
}

for h in "${HOOKS_REQUIRED[@]}"; do
  if ! command -v "$h" >/dev/null 2>&1; then
    fail "BD070" "$h" "required hook '$h' is not installed on PATH"
  elif ! run_hook "$h"; then
    fail "BD070" "$h" "required hook '$h' failed"
  fi
done

for h in "${HOOKS_ADVISORY[@]}"; do
  if ! command -v "$h" >/dev/null 2>&1; then
    advise "BD902" "$h" "SKIPPED (not installed)"
  elif ! run_hook "$h"; then
    advise "BD902" "$h" "advisory hook '$h' reported warnings"
  fi
done

if [[ "$FAILURES" -gt 0 ]]; then
  printf 'check-docs: FAILED (%d violation(s))\n' "$FAILURES" >&2
  exit 1
fi

printf 'check-docs: OK (%d active markdown file(s) checked)\n' "${#ACTIVE_MD_FILES[@]}"
exit 0
