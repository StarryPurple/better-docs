#!/usr/bin/env bash
# Shared conformance test suite for better-docs deterministic gate engines.
# Usage: ./gates/conformance/run.sh [path-to-gate-executable]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GATE="${1:-$REPO_ROOT/gates/check-docs.sh}"

if [[ ! -x "$GATE" ]]; then
  echo "conformance: gate executable not found or not executable: $GATE" >&2
  exit 2
fi

hash_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum < "$f" | awk '{print $1}'
  else
    shasum -a 256 < "$f" | awk '{print $1}'
  fi
}

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "conformance@better-docs.local"
  git -C "$dir" config user.name "Conformance"
}

commit_all() {
  local dir="$1"
  local msg="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg"
}

assert_pass() {
  local name="$1"
  shift
  local out
  if out="$("$@" 2>&1)"; then
    printf 'PASS  %s\n' "$name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  %s (expected exit 0)\n%s\n' "$name" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Hard-fail diagnostics must appear on stderr with exit code 1.
assert_fail_with() {
  local name="$1"
  local expect_id="$2"
  shift 2
  local stdout_f="$TMP_BASE/_stdout"
  local stderr_f="$TMP_BASE/_stderr"
  local rc=0
  "$@" >"$stdout_f" 2>"$stderr_f" || rc=$?
  local err
  err="$(cat "$stderr_f")"
  if [[ "$rc" -ne 1 ]]; then
    printf 'FAIL  %s (expected exit 1, got %d)\nstdout:\n%s\nstderr:\n%s\n' "$name" "$rc" "$(cat "$stdout_f")" "$err" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if [[ "$err" != *"$expect_id"* ]]; then
    printf 'FAIL  %s (expected stderr containing %s)\nstderr:\n%s\n' "$name" "$expect_id" "$err" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  printf 'PASS  %s (%s)\n' "$name" "$expect_id"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# Advisory diagnostics must appear on stdout with exit code 0.
assert_pass_with() {
  local name="$1"
  local expect_str="$2"
  shift 2
  local stdout_f="$TMP_BASE/_stdout"
  local stderr_f="$TMP_BASE/_stderr"
  local rc=0
  "$@" >"$stdout_f" 2>"$stderr_f" || rc=$?
  local out
  out="$(cat "$stdout_f")"
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL  %s (expected exit 0, got %d)\nstdout:\n%s\nstderr:\n%s\n' "$name" "$rc" "$out" "$(cat "$stderr_f")" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if [[ "$out" != *"$expect_str"* ]]; then
    printf 'FAIL  %s (expected stdout containing %s)\nstdout:\n%s\n' "$name" "$expect_str" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  printf 'PASS  %s (%s)\n' "$name" "$expect_str"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_exit2() {
  local name="$1"
  shift
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    printf 'PASS  %s (exit 2)\n' "$name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  %s (expected exit 2, got %d)\n' "$name" "$rc" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---------------------------------------------------------------------------
# Case 1: Full valid repo (notes, empirical records, archive seal, budgets, links, --ci)
# ---------------------------------------------------------------------------
R1="$TMP_BASE/valid_full"
init_repo "$R1"
mkdir -p "$R1/docs" "$R1/.agents/notes/proposed/feature" "$R1/.agents/notes/implemented/architecture" \
  "$R1/.agents/notes/concluded/experiment" "$R1/.agents/notes/rejected/process" \
  "$R1/.agents/notes/archived/architecture" "$R1/.agents/records/2026-11-baseline"

cat > "$R1/docs-check.conf" <<'EOF'
kit_version=0.1.0
language_mode=single-en
language_primary=en
feature_notes=true
feature_empirical_records=true
feature_archive_seal=true
feature_budgets=true
note_classes=feature,architecture,experiment,process
budget=README.md:50
EOF

cat > "$R1/README.md" <<'EOF'
# Demo

See [guide](docs/guide.md#usage-steps) and `(decision 9)` inside inline code.

```markdown
[ignored-broken](does-not-exist.md)
(decision 7)
```
EOF

cat > "$R1/docs/guide.md" <<'EOF'
# Guide

## Usage steps

Run the tool.
EOF

cat > "$R1/.agents/notes/proposed/feature/2026-11-01-plan.md" <<'EOF'
# Agent Note: Add cache

Status: proposed

## Problem

Cold builds are slow.

## Proposal

Add a local cache.

## Alternatives considered

- **No cache**: too slow.

## Acceptance criteria

- Repeat build completes under 5s.

## Risks

- Cache invalidation bugs.
EOF

cat > "$R1/.agents/notes/implemented/architecture/2026-11-02-core.md" <<'EOF'
# Agent Note: Core layout

Status: implemented

## Problem

Modules lacked clear boundaries.

## Decision

Split core and CLI into separate packages.

## Alternatives considered

- **Monolith**: circular imports.

## Consequences

- Clean dependency direction.
EOF

cat > "$R1/.agents/notes/concluded/experiment/2026-11-03-lr.md" <<'EOF'
# Agent Note: Learning rate sweep

Status: concluded

## Hypothesis / Question

Does lr=3e-4 improve convergence?

## Evidence

- See [2026-11-baseline](../../../records/2026-11-baseline/README.md).

## Conclusion

lr=1e-4 is more stable.

## Direction impact

- Keep lr=1e-4 as baseline.

## Alternatives considered

- **Cosine warmup only**: still diverged at lr=3e-4.
EOF

cat > "$R1/.agents/notes/rejected/process/2026-11-04-index.md" <<'EOF'
# Agent Note: Central index

Status: rejected — causes merge conflicts on every PR

## Problem

Finding notes takes a directory listing.

## Proposal

Maintain INDEX.md.

## Alternatives considered

- **Path-encoded tree**: zero merge contention.
EOF

cat > "$R1/.agents/notes/archived/AGENTS.md" <<'EOF'
# Archived
EOF

cat > "$R1/.agents/notes/archived/architecture/2026-01-01-old.md" <<'EOF'
# Agent Note: Old architecture

Status: implemented
EOF

cat > "$R1/.agents/records/2026-11-baseline/README.md" <<'EOF'
# Study: 2026-11-baseline

Status: concluded

Summary of baseline runs; we used to try lr=3e-4, 以前失败。
EOF

"$GATE" --root "$R1" --seal >/dev/null
commit_all "$R1" "initial valid commit"

cat > "$R1/.agents/notes/archived/architecture/2026-02-01-second.md" <<'EOF'
# Agent Note: Second archived

Status: implemented
EOF
"$GATE" --root "$R1" --seal >/dev/null
commit_all "$R1" "append second sealed archive"

assert_pass "valid_full_local" "$GATE" --root "$R1"
assert_pass "valid_full_ci_append_only" "$GATE" --root "$R1" --ci --base-ref HEAD~1
assert_pass "valid_concluded_record_excluded_from_probes" bash -c 'out="$("'"$GATE"'" --root "'"$R1"'" --probes)"; [[ "$out" != *"BD901"* ]]'

# ---------------------------------------------------------------------------
# Case 2: BD001 — tracked .agents/scratch/
# ---------------------------------------------------------------------------
R2="$TMP_BASE/bd001"
init_repo "$R2"
cat > "$R2/.gitignore" <<'EOF'
.agents/scratch/
EOF
cat > "$R2/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
mkdir -p "$R2/.agents/scratch"
echo "raw review dump" > "$R2/.agents/scratch/codex_review.md"
git -C "$R2" add .gitignore docs-check.conf
git -C "$R2" add -f .agents/scratch/codex_review.md
git -C "$R2" commit -q -m "track scratch"
assert_fail_with "fail_bd001_tracked_scratch" "BD001" "$GATE" --root "$R2"

# ---------------------------------------------------------------------------
# Case 3: BD002 & BD003 — invalid config dependency + missing subtree AGENTS.md
# ---------------------------------------------------------------------------
R3="$TMP_BASE/bd002_bd003"
init_repo "$R3"
cat > "$R3/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=false
feature_empirical_records=true
unknown_key=1
subtree=packages/core
EOF
commit_all "$R3" "bad config"
assert_fail_with "fail_bd002_config_dep" "BD002" "$GATE" --root "$R3"
assert_fail_with "fail_bd003_subtree" "BD003" "$GATE" --root "$R3"

# ---------------------------------------------------------------------------
# Case 4: BD010 — EN + CJK token counting budget + --list-budgets when disabled
# ---------------------------------------------------------------------------
R4="$TMP_BASE/bd010"
init_repo "$R4"
cat > "$R4/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_budgets=true
budget=README.md:5
EOF
printf 'Hello world 你好世界\n' > "$R4/README.md"
commit_all "$R4" "over cjk budget"
assert_fail_with "fail_bd010_cjk_budget" "BD010" "$GATE" --root "$R4"

cat > "$R4/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_budgets=false
budget=README.md:5
EOF
assert_pass_with "pass_list_budgets_when_feature_disabled" "OVER" "$GATE" --root "$R4" --list-budgets

# ---------------------------------------------------------------------------
# Case 5: BD020 & BD021 — broken links, missing anchors, nested image-in-link, parens, CJK filenames
# ---------------------------------------------------------------------------
R5="$TMP_BASE/bd020_bd021"
init_repo "$R5"
mkdir -p "$R5/docs"
cat > "$R5/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
printf '# Target\n' > "$R5/docs/foo_(bar).md"
printf 'png' > "$R5/docs/ok.png"
cat > "$R5/README.md" <<'EOF'
# Home

See [missing](missing.md), [bad anchor](README.md#nonexistent), [ok-parens](docs/foo_(bar).md "v (1)"), [![alt](docs/ok.png)](nested-missing.md), and ![](empty-alt-missing.png).
EOF
printf '# 中文文档\n\nSee [broken-in-cjk-file](nope-cjk.md).\n' > "$R5/docs/设计.md"
commit_all "$R5" "broken links and cjk filename"
assert_fail_with "fail_bd020_broken_link" "missing.md" "$GATE" --root "$R5"
assert_fail_with "fail_bd021_missing_anchor" "BD021" "$GATE" --root "$R5"
assert_fail_with "fail_bd020_nested_image_link" "nested-missing.md" "$GATE" --root "$R5"
assert_fail_with "fail_bd020_empty_alt_image" "empty-alt-missing.png" "$GATE" --root "$R5"
assert_fail_with "fail_bd020_cjk_filename" "nope-cjk.md" "$GATE" --root "$R5"

# Verify balanced parens link itself passes when valid
cat > "$R5/README.md" <<'EOF'
# Home

See [ok-parens](docs/foo_(bar).md "v (1)"), [![alt](docs/ok.png)](docs/foo_(bar).md), and \[escaped](not-a-link.md).
EOF
rm -f "$R5/docs/设计.md"
commit_all "$R5" "valid parens and nested image link"
assert_pass "pass_parens_and_nested_image_link" "$GATE" --root "$R5"

# ---------------------------------------------------------------------------
# Case 6: BD030–BD033 + grandfathered_note + 3-line & whitespace-only rejected note
# ---------------------------------------------------------------------------
R6="$TMP_BASE/bd030_bd033"
init_repo "$R6"
mkdir -p "$R6/.agents/notes/implemented/architecture" "$R6/.agents/notes/implemented/unknown-class" "$R6/.agents/notes/rejected/architecture"
cat > "$R6/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
note_classes=architecture
grandfathered_note=.agents/notes/implemented/architecture/2025-01-01-legacy.md
EOF

cat > "$R6/.agents/notes/implemented/architecture/2025-01-01-legacy.md" <<'EOF'
# Agent Note: Legacy decision

Status: implemented

## Problem

Old system.

## Decision

Shipped new system.

## Consequences

- Works.
EOF
commit_all "$R6" "valid grandfathered note"
assert_pass "valid_grandfathered_note" "$GATE" --root "$R6"

cat > "$R6/.agents/notes/implemented/unknown-class/2026-11-01-bad.md" <<'EOF'
# Bad Title

Status: proposed

## Problem

X

## Plan

Y
EOF
cat > "$R6/.agents/notes/implemented/architecture/2026-11-02-specspeak.md" <<'EOF'
# Agent Note: Spec speak

Status: implemented

## Problem

X

## Decision

Y

## Plan

Z

## Alternatives considered

- A

## Consequences

- B
EOF
printf '# Agent Note: Blank reason\n\nStatus: rejected —   \n' > "$R6/.agents/notes/rejected/architecture/2026-11-03-short.md"
commit_all "$R6" "bad notes"
assert_fail_with "fail_bd030_unknown_class" "BD030" "$GATE" --root "$R6"
assert_fail_with "fail_bd031_bad_header" "BD031" "$GATE" --root "$R6"
assert_fail_with "fail_bd031_short_rejected_reason" "2026-11-03-short.md" "$GATE" --root "$R6"
assert_fail_with "fail_bd032_missing_sections" "BD032" "$GATE" --root "$R6"
assert_fail_with "fail_bd033_proposal_heading" "BD033" "$GATE" --root "$R6"

# ---------------------------------------------------------------------------
# Case 7: BD040–BD043 — archive seal CI base-ref, tamper, symlinked manifest/index, spaces sort
# ---------------------------------------------------------------------------
assert_fail_with "fail_bd040_ci_no_base" "BD040" "$GATE" --root "$R1" --ci
assert_fail_with "fail_bd040_ci_same_head" "BD040" "$GATE" --root "$R1" --ci --base-ref HEAD
assert_fail_with "fail_bd040_explicit_bad_base_ref" "BD040" "$GATE" --root "$R1" --base-ref nonexistent_ref_xyz

R7="$TMP_BASE/bd041_tamper"
cp -a "$R1" "$R7"
printf '\ntampered line\n' >> "$R7/.agents/notes/archived/architecture/2026-01-01-old.md"
assert_fail_with "fail_bd042_digest_mismatch" "BD042" "$GATE" --root "$R7"
new_hash="$(hash_file "$R7/.agents/notes/archived/architecture/2026-01-01-old.md")"
awk -v h="$new_hash" '$2 == ".agents/notes/archived/architecture/2026-01-01-old.md" { print h "  " $2; next } { print }' \
  "$R7/.agents/notes/archived/manifest.sha256" > "$R7/.agents/notes/archived/manifest.tmp"
mv "$R7/.agents/notes/archived/manifest.tmp" "$R7/.agents/notes/archived/manifest.sha256"
commit_all "$R7" "tamper sealed archive and rewrite manifest"
assert_fail_with "fail_bd041_append_only_violation" "BD041" "$GATE" --root "$R7" --ci --base-ref HEAD~1

ln -sf "../../README.md" "$R7/.agents/notes/archived/evil-link.md"
assert_fail_with "fail_bd043_archive_symlink" "BD043" "$GATE" --root "$R7"

# Symlinked manifest.sha256 must fail BD043 and --seal must NOT write through it
R7S="$TMP_BASE/bd043_manifest_symlink"
cp -a "$R1" "$R7S"
printf 'CANARY\n' > "$R7S/canary.txt"
rm -f "$R7S/.agents/notes/archived/manifest.sha256"
ln -s "../../../canary.txt" "$R7S/.agents/notes/archived/manifest.sha256"
assert_fail_with "fail_bd043_manifest_symlink" "BD043" "$GATE" --root "$R7S" --seal
if [[ "$(cat "$R7S/canary.txt")" == "CANARY" ]]; then
  printf 'PASS  seal_did_not_clobber_symlink_target\n'; PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  seal_did_not_clobber_symlink_target\n' >&2; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Symlinked index.md in non-concluded study must still trigger BD043
R7I="$TMP_BASE/bd043_index_symlink"
cp -a "$R1" "$R7I"
mkdir -p "$R7I/.agents/records/2026-11-s2"
ln -s "../../../README.md" "$R7I/.agents/records/2026-11-s2/index.md"
assert_fail_with "fail_bd043_records_index_symlink" "BD043" "$GATE" --root "$R7I"

# Manifest sorting with spaces in paths uses byte offset 67 (LC_ALL=C sort -k1.67)
R7P="$TMP_BASE/manifest_spaces_sort"
init_repo "$R7P"
mkdir -p "$R7P/.agents/notes/archived/dir a"
cat > "$R7P/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_archive_seal=true
EOF
printf 'z-body\n' > "$R7P/.agents/notes/archived/dir a/z.md"
printf 'a-body\n' > "$R7P/.agents/notes/archived/dir a/a.md"
"$GATE" --root "$R7P" --seal >/dev/null
first_path="$(head -n 1 "$R7P/.agents/notes/archived/manifest.sha256" | cut -c67-)"
if [[ "$first_path" == ".agents/notes/archived/dir a/a.md" ]]; then
  printf 'PASS  manifest_spaces_path_sort\n'; PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  manifest_spaces_path_sort (got %s)\n' "$first_path" >&2; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Duplicate manifest entry fails BD042
dup_line="$(head -n 1 "$R7P/.agents/notes/archived/manifest.sha256")"
printf '%s\n' "$dup_line" >> "$R7P/.agents/notes/archived/manifest.sha256"
assert_fail_with "fail_bd042_duplicate_manifest_entry" "BD042" "$GATE" --root "$R7P"

# ---------------------------------------------------------------------------
# Case 8: BD050 & BD051 + CommonMark triple-backtick inline span & inline-fence traps
# ---------------------------------------------------------------------------
R8="$TMP_BASE/bd050_bd051"
init_repo "$R8"
cat > "$R8/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
printf '# Title   \n\nSee (decision 4) here.' > "$R8/README.md"
commit_all "$R8" "hygiene violations"
assert_fail_with "fail_bd050_hygiene" "BD050" "$GATE" --root "$R8"
assert_fail_with "fail_bd051_draft_marker" "BD051" "$GATE" --root "$R8"

R8C="$TMP_BASE/commonmark_spans"
init_repo "$R8C"
cat > "$R8C/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
cat > "$R8C/README.md" <<'EOF'
# Spans

See (`` ``` ``) and [caught-after-triple](missing-triple.md) or (`~~~`) here.

```inline-code``` is not a fence.
[caught-after-inline-fence](missing-after-inline.md)
EOF
commit_all "$R8C" "commonmark inline span edge cases"
assert_fail_with "fail_bd020_after_triple_backtick_span" "missing-triple.md" "$GATE" --root "$R8C"
assert_fail_with "fail_bd020_after_inline_3backtick_line" "missing-after-inline.md" "$GATE" --root "$R8C"

# ---------------------------------------------------------------------------
# Case 9: BD060 — i18n-en-zh pairing, comments/whitespace, vendored .agents/skills/ exemption
# ---------------------------------------------------------------------------
R9="$TMP_BASE/bd060_i18n"
init_repo "$R9"
mkdir -p "$R9/.agents/skills/prose-standard"
cat > "$R9/docs-check.conf" <<'EOF'
kit_version=0.1.0
language_mode=i18n-en-zh
language_primary=en
EOF
printf '# Hello\n' > "$R9/README.md"
printf '# Roadmap\n\n- [ ] Implement parser — @alice\n  实现解析器\n' > "$R9/ROADMAP.md"
printf '# Vendored skill\n' > "$R9/.agents/skills/prose-standard/SKILL.md"
commit_all "$R9" "missing zh pair"
assert_fail_with "fail_bd060_missing_pair" "BD060" "$GATE" --root "$R9"

printf '# 你好\n' > "$R9/README.zh.md"
src_sha="$(hash_file "$R9/README.md")"
printf 'source: README.md\ntarget: README.zh.md\nsource_sha256: %s   # synced\n' "$src_sha" > "$R9/README.i18n.yaml"
commit_all "$R9" "valid i18n pair with vendored skill, root ROADMAP, and comment"
assert_pass "valid_i18n_pair_and_exemptions" "$GATE" --root "$R9"

mkdir -p "$R9/docs"
printf '# Nested roadmap\n' > "$R9/docs/ROADMAP.md"
commit_all "$R9" "nested ROADMAP is not exempt from BD060"
assert_fail_with "fail_bd060_nested_roadmap_not_exempt" "BD060 docs/ROADMAP.md" "$GATE" --root "$R9"
rm -f "$R9/docs/ROADMAP.md"
commit_all "$R9" "remove nested ROADMAP"

printf '# Roadmap\n\n- [x] Implement parser — @alice\n  实现解析器\n' > "$R9/ROADMAP.md"
commit_all "$R9" "checkbox-only edit on root ROADMAP"
assert_pass "pass_roadmap_checkbox_edit_no_sidecar" "$GATE" --root "$R9"

# Reject symlinked or gitignored .zh.md and .i18n.yaml
R9B="$TMP_BASE/bd060_symlink_ignored"
init_repo "$R9B"
cat > "$R9B/docs-check.conf" <<'EOF'
kit_version=0.1.0
language_mode=i18n-en-zh
language_primary=en
EOF
printf '# Guide\n' > "$R9B/README.md"
ln -s README.md "$R9B/README.zh.md"
src_sha="$(hash_file "$R9B/README.md")"
printf 'source: README.md\ntarget: README.zh.md\nsource_sha256: %s\n' "$src_sha" > "$R9B/README.i18n.yaml"
commit_all "$R9B" "symlinked zh counterpart"
assert_fail_with "fail_bd060_symlink_zh" "BD060 README.md" "$GATE" --root "$R9B"

rm -f "$R9B/README.zh.md"
printf '# 指南\n' > "$R9B/README.zh.md"
mv "$R9B/README.i18n.yaml" "$R9B/real.yaml"
ln -s real.yaml "$R9B/README.i18n.yaml"
commit_all "$R9B" "symlinked sidecar"
assert_fail_with "fail_bd060_symlink_sidecar" "BD060 README.md" "$GATE" --root "$R9B"

rm -f "$R9B/README.i18n.yaml"
mv "$R9B/real.yaml" "$R9B/README.i18n.yaml"
# Ignored .zh.md alone (sidecar tracked)
git -C "$R9B" rm -q --cached README.zh.md
printf 'README.zh.md\n' > "$R9B/.gitignore"
commit_all "$R9B" "ignore zh only"
assert_fail_with "fail_bd060_gitignored_zh_only" "excluded or gitignored" "$GATE" --root "$R9B"

# Ignored .i18n.yaml alone (.zh.md tracked)
printf '' > "$R9B/.gitignore"
git -C "$R9B" add README.zh.md
git -C "$R9B" rm -q --cached README.i18n.yaml
printf 'README.i18n.yaml\n' > "$R9B/.gitignore"
commit_all "$R9B" "ignore sidecar only"
assert_fail_with "fail_bd060_gitignored_sidecar_only" "i18n sidecar 'README.i18n.yaml' is gitignored" "$GATE" --root "$R9B"

# Wildcard sidecar Guide[1].i18n.yaml ignored beside visible Guide1.i18n.yaml
printf '' > "$R9B/.gitignore"
git -C "$R9B" add README.i18n.yaml
printf '# Bracket guide\n' > "$R9B/Guide[1].md"
printf '# 括号指南\n' > "$R9B/Guide[1].zh.md"
g_sha="$(hash_file "$R9B/Guide[1].md")"
printf 'source: Guide[1].md\ntarget: Guide[1].zh.md\nsource_sha256: %s\n' "$g_sha" > "$R9B/Guide[1].i18n.yaml"
printf 'source: Guide1.md\ntarget: Guide1.zh.md\nsource_sha256: %s\n' "$g_sha" > "$R9B/Guide1.i18n.yaml"
printf 'Guide\\[1\\].i18n.yaml\n' > "$R9B/.gitignore"
commit_all "$R9B" "ignored wildcard sidecar beside visible sibling"
assert_fail_with "fail_bd060_ignored_wildcard_sidecar" "Guide[1].i18n.yaml" "$GATE" --root "$R9B"

printf '\nUpdated text.\n' >> "$R9/README.md"
commit_all "$R9" "stale i18n source"
assert_fail_with "fail_bd060_stale_sidecar" "BD060" "$GATE" --root "$R9"

# ---------------------------------------------------------------------------
# Case 10: BD070 required hook vs BD902 advisory hook + BD901 EN and ZH on same line
# ---------------------------------------------------------------------------
R10="$TMP_BASE/bd070_bd901_bd902"
init_repo "$R10"
cat > "$R10/docs-check.conf" <<'EOF'
kit_version=0.1.0
hook_advisory=nonexistent_better_docs_tool
EOF
printf '# Notes\n\nWe used to do X, 以前如此。\n' > "$R10/README.md"
commit_all "$R10" "advisory hook and probes"
assert_pass_with "pass_bd902_advisory_skipped" "BD902" "$GATE" --root "$R10"
assert_pass_with "pass_bd901_en_probe" "used to" "$GATE" --root "$R10" --probes
assert_pass_with "pass_bd901_zh_probe_same_line" "以前" "$GATE" --root "$R10" --probes

echo "hook_required=nonexistent_better_docs_tool" >> "$R10/docs-check.conf"
commit_all "$R10" "required missing hook"
assert_fail_with "fail_bd070_missing_required_hook" "BD070" "$GATE" --root "$R10"

# ---------------------------------------------------------------------------
# Case 11: BD903 — unlisted & uninitialized gitlink (including submodule name with space)
# ---------------------------------------------------------------------------
R11="$TMP_BASE/bd903_submodule"
init_repo "$R11"
cat > "$R11/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
cat > "$R11/.gitmodules" <<'EOF'
[submodule "my lib"]
	path = libs/unlisted
	url = https://example.com/unlisted.git
EOF
mkdir -p "$R11/libs/unlisted"
printf '# Root\n' > "$R11/README.md"
commit_all "$R11" "unlisted uninitialized submodule"
assert_pass_with "pass_bd903_unlisted_gitlink" "libs/unlisted SKIPPED (unlisted gitlink; default-closed)" "$GATE" --root "$R11"

# ---------------------------------------------------------------------------
# Case 12: CLI flags, exit 2 guards, unconditional config, --ci without seal, anchors, hooks
# ---------------------------------------------------------------------------
assert_pass_with "pass_help_flag" "Usage:" "$GATE" --help
assert_pass_with "pass_version_flag" "0.1.0" "$GATE" --version
assert_pass "pass_no_git_flag" "$GATE" --root "$R11" --no-git

assert_exit2 "exit2_unknown_flag" "$GATE" --unknown-flag
assert_exit2 "exit2_missing_root_arg" "$GATE" --root
assert_exit2 "exit2_missing_config_arg" "$GATE" --config
assert_exit2 "exit2_missing_base_ref_arg" "$GATE" --base-ref
assert_exit2 "exit2_empty_base_ref" "$GATE" --root "$R1" --base-ref ""
assert_exit2 "exit2_empty_config" "$GATE" --root "$R11" --config ""
assert_exit2 "exit2_ci_with_seal" "$GATE" --root "$R1" --ci --seal --base-ref HEAD~1
assert_exit2 "exit2_ci_with_no_git" "$GATE" --root "$R1" --ci --no-git

assert_fail_with "fail_bd040_ci_without_seal" "BD040" "$GATE" --root "$R11" --ci
assert_pass "pass_env_base_ref" env BETTER_DOCS_BASE_REF=HEAD~1 "$GATE" --root "$R1" --ci

# Unconditional config validation: semver, trailing comma, empty list values, root escape
R12="$TMP_BASE/unconditional_cfg"
init_repo "$R12"
cat > "$R12/docs-check.conf" <<'EOF'
kit_version=not-semver
feature_notes=true
feature_budgets=false
budget=../../etc/passwd:100
note_classes=feature,
grandfathered_note=
submodule_owned=only-two|fields
submodule_shared=libs/trailing/
EOF
printf '# OK\n' > "$R12/README.md"
commit_all "$R12" "invalid unconditional config"
assert_fail_with "fail_bd002_unconditional_fields" "BD002" "$GATE" --root "$R12"

# --list-budgets runs full checks + code-labeled links + (audit A1)
R13="$TMP_BASE/list_budgets_probes"
init_repo "$R13"
cat > "$R13/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_budgets=true
budget=README.md:50
EOF
printf '# Home\n\nSee [broken](nope.md) and [`code-broken`](nope2.md) and `(audit A1)` vs (audit A1).\n' > "$R13/README.md"
commit_all "$R13" "code-labeled link and list-budgets"
assert_fail_with "fail_list_budgets_runs_all_checks" "BD020" "$GATE" --root "$R13" --list-budgets
assert_fail_with "fail_code_labeled_link_bd020" "nope2.md" "$GATE" --root "$R13"
assert_fail_with "fail_audit_marker_bd051" "BD051" "$GATE" --root "$R13"

# CJK + non-ASCII punctuation anchor normalization & duplicate anchors + root-escape link
R14="$TMP_BASE/anchors_and_escape"
init_repo "$R14"
cat > "$R14/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
cat > "$R14/README.md" <<'EOF'
# Guide

See [cjk-emdash](#中文--标题), [cjk-plain](#中文-标题), [dup](#item-1), [first](#item), and `` [`ignored`](missing.md) ``.

## 中文 — 标题。

## 中文 标题。

## Item

## Item
EOF
commit_all "$R14" "valid cjk and duplicate anchors"
assert_pass "pass_cjk_and_duplicate_anchors" "$GATE" --root "$R14"

printf '\nSee [escape](../../etc/passwd).\n' >> "$R14/README.md"
commit_all "$R14" "root escape link"
assert_fail_with "fail_bd020_root_escape" "BD020" "$GATE" --root "$R14"

# --seal refuses to overwrite manifest.sha256 on BD043 symlink error
R15="$TMP_BASE/seal_refuses_on_error"
cp -a "$R1" "$R15"
before_manifest="$(cat "$R15/.agents/notes/archived/manifest.sha256")"
ln -sf "../../README.md" "$R15/.agents/notes/archived/bad-link.md"
assert_fail_with "fail_seal_refuses_with_symlink" "BD043" "$GATE" --root "$R15" --seal
after_manifest="$(cat "$R15/.agents/notes/archived/manifest.sha256")"
if [[ "$before_manifest" == "$after_manifest" ]]; then
  printf 'PASS  seal_did_not_overwrite_manifest\n'; PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  seal_did_not_overwrite_manifest\n' >&2; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --seal refuses to overwrite manifest.sha256 on BD040 bad --base-ref
R15B="$TMP_BASE/seal_refuses_bad_base_ref"
cp -a "$R1" "$R15B"
printf '# Agent Note: New\n\nStatus: implemented\n' > "$R15B/.agents/notes/archived/architecture/2026-03-01-new.md"
before_b_manifest="$(cat "$R15B/.agents/notes/archived/manifest.sha256")"
assert_fail_with "fail_seal_refuses_bad_base_ref" "BD040" "$GATE" --root "$R15B" --seal --base-ref nonexistent_ref_xyz
after_b_manifest="$(cat "$R15B/.agents/notes/archived/manifest.sha256")"
if [[ "$before_b_manifest" == "$after_b_manifest" ]]; then
  printf 'PASS  seal_did_not_overwrite_on_bad_base_ref\n'; PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  seal_did_not_overwrite_on_bad_base_ref\n' >&2; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Non-link square brackets enclosing a link emit exactly one BD020 (no duplicate emission)
R15C="$TMP_BASE/non_link_bracket_single_emit"
init_repo "$R15C"
cat > "$R15C/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
printf '# Note\n\nText [see [guide](missing-once.md)] here.\n' > "$R15C/README.md"
commit_all "$R15C" "bracketed link"
dup_err="$("$GATE" --root "$R15C" 2>&1 >/dev/null || true)"
dup_cnt="$(printf '%s\n' "$dup_err" | grep -c 'missing-once.md' || true)"
if [[ "$dup_cnt" -eq 1 ]]; then
  printf 'PASS  non_link_bracket_no_duplicate_bd020\n'; PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  non_link_bracket_no_duplicate_bd020 (got %s matches)\n%s\n' "$dup_cnt" "$dup_err" >&2; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Symlinked study directory under .agents/records/ triggers BD043
R16="$TMP_BASE/records_symlink"
cp -a "$R1" "$R16"
ln -s "../../docs" "$R16/.agents/records/2026-11-evil"
assert_fail_with "fail_bd043_records_symlink" "BD043" "$GATE" --root "$R16"

# Secondary branches: concluded disabled, duplicate Status, double-slash manifest
R17="$TMP_BASE/secondary_branches"
init_repo "$R17"
mkdir -p "$R17/.agents/notes/concluded/architecture" "$R17/.agents/notes/implemented/architecture" "$R17/.agents/notes/archived"
cat > "$R17/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_empirical_records=false
feature_archive_seal=true
note_classes=architecture
EOF
printf '# Agent Note: Bad\n\nStatus: concluded\n\n## Hypothesis / Question\n\nQ\n\n## Evidence\n\nE\n\n## Conclusion\n\nC\n\n## Direction impact\n\nD\n\n## Alternatives considered\n\nA\n' > "$R17/.agents/notes/concluded/architecture/2026-11-01-c.md"
printf '# Agent Note: Dup status\n\nStatus: implemented\n\nStatus: implemented\n\n## Problem\n\nP\n\n## Decision\n\nD\n\n## Alternatives considered\n\nA\n\n## Consequences\n\nC\n' > "$R17/.agents/notes/implemented/architecture/2026-11-01-s.md"
printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  .agents/notes/archived//bad.md\n' > "$R17/.agents/notes/archived/manifest.sha256"
commit_all "$R17" "secondary diagnostic branches"
assert_fail_with "fail_bd030_concluded_disabled" "BD030" "$GATE" --root "$R17"
assert_fail_with "fail_bd031_duplicate_status" "BD031" "$GATE" --root "$R17"
assert_fail_with "fail_bd043_double_slash_manifest" "BD043" "$GATE" --root "$R17"

# Installed hooks: BD902 warning vs BD070 failure
R18="$TMP_BASE/installed_hooks"
init_repo "$R18"
cat > "$R18/docs-check.conf" <<'EOF'
kit_version=0.1.0
hook_advisory=false
EOF
printf '# Clean\n' > "$R18/README.md"
commit_all "$R18" "installed advisory warning hook"
assert_pass_with "pass_bd902_advisory_warning" "reported warnings" "$GATE" --root "$R18"

echo "hook_required=false" >> "$R18/docs-check.conf"
commit_all "$R18" "installed required failing hook"
assert_fail_with "fail_bd070_installed_hook_failed" "BD070" "$GATE" --root "$R18"

# ---------------------------------------------------------------------------
# Case 13: Live template instantiation test (Lean + Strict + Empirical)
# ---------------------------------------------------------------------------
R19="$TMP_BASE/template_instantiation"
init_repo "$R19"
mkdir -p "$R19/docs" "$R19/.agents/notes/proposed/process" "$R19/.agents/notes/implemented/architecture" \
  "$R19/.agents/notes/concluded/architecture" "$R19/.agents/notes/rejected/architecture" \
  "$R19/.agents/records/2026-11-study"
sed -e 's/{{LANGUAGE_MODE}}/single-en/g' \
    -e 's/{{LANGUAGE_PRIMARY}}/en/g' \
    -e 's/{{FEATURE_NOTES}}/true/g' \
    -e 's/{{FEATURE_EMPIRICAL_RECORDS}}/true/g' \
    -e 's/{{FEATURE_ARCHIVE_SEAL}}/true/g' \
    -e 's/{{FEATURE_BUDGETS}}/false/g' \
    "$REPO_ROOT/templates/core/docs-check.conf.tmpl" > "$R19/docs-check.conf"
sed -e 's/{{TITLE}}/Migration/g' \
    -e 's/{{SOURCE_HEAD_SHA}}/deadbeef/g' \
    -e 's/{{WORKING_TREE_STATUS}}/clean/g' \
    -e 's/{{LANGUAGE_MODE}}/single-en/g' \
    -e 's/{{FEATURE_NOTES}}/true/g' \
    -e 's/{{FEATURE_EMPIRICAL_RECORDS}}/true/g' \
    -e 's/{{FEATURE_ARCHIVE_SEAL}}/true/g' \
    -e 's/{{FEATURE_BUDGETS}}/false/g' \
    -e 's/{{OWNED_SUBMODULES_OR_NONE}}/none/g' \
    -e 's/{{TARGET_TIER_MAP}}/Root + docs/g' \
    -e 's/{{LEGACY_PATH}}/OLD.md/g' \
    -e 's/{{REWRITE\\|SPLIT\\|MERGE\\|EXTRACT_NOTE\\|EXTRACT_RECORD\\|ARCHIVE\\|DELETE\\|KEEP}}/DELETE/g' \
    -e 's/{{DEST_PATH_OR_DASH}}/-/g' \
    -e 's/{{CODE_OR_OWNER}}/code/g' \
    -e 's/{{REDIRECT_OR_NONE}}/none/g' \
    -e 's/{{CONCISE_REASON}}/obsolete/g' \
    -e '/{{OPTIONAL_/d' \
    "$REPO_ROOT/templates/notes/migration-manifest.md.tmpl" > "$R19/.agents/notes/proposed/process/2026-11-24-doc-migration.md"
sed -e 's/{{TITLE}}/Sample/g' -e 's/{{PROBLEM_STATEMENT}}/P/g' -e 's/{{SHIPPED_REALITY_IN_PRESENT_TENSE}}/D/g' \
    -e 's/{{ALTERNATIVE_1}}/A/g' -e 's/{{WHY_IT_LOST}}/L/g' -e 's/{{WHAT_THE_TRADEOFF_BOUGHT_AND_COST}}/C/g' \
    "$REPO_ROOT/templates/notes/implemented.md.tmpl" > "$R19/.agents/notes/implemented/architecture/2026-11-24-sample.md"
sed -e 's/{{TITLE}}/Finding/g' -e 's/{{QUESTION_OR_HYPOTHESIS_TESTED}}/H/g' -e 's/{{STUDY_ID}}/2026-11-study/g' \
    -e 's/{{COMMIT_SHA}}/abc1234/g' -e 's/{{CONFIG_REF}}/cfg/g' -e 's/{{COLLABORATOR_OR_NONE}}/none/g' \
    -e 's/{{CONCISE_OBSERVED_OUTCOME_AND_UNCERTAINTY}}/ok/g' -e 's/{{DISTILLED_VERDICT_IN_PRESENT_TENSE}}/V/g' \
    -e 's/{{CONCRETE_CHANGE_TO_NEXT_WORK_OR_PIPELINE}}/Next/g' -e 's/{{ALTERNATIVE_EXPLANATION_OR_PATH}}/Alt/g' \
    -e 's/{{WHY_REJECTED_OR_DEFERRED}}/Why/g' \
    "$REPO_ROOT/templates/notes/concluded.md.tmpl" > "$R19/.agents/notes/concluded/architecture/2026-11-24-finding.md"
sed -e 's/{{TITLE}}/Trap/g' -e 's/{{ONE_LINE_VERDICT}}/too slow/g' -e 's/{{PROBLEM_STATEMENT}}/P/g' \
    -e 's/{{ORIGINAL_PROPOSAL_FROZEN}}/Prop/g' -e 's/{{CHOSEN_PATH_OR_REASON}}/Fast/g' \
    -e 's/{{WHY_THIS_PROPOSAL_LOST_AND_REMAINS_A_TEMPTING_TRAP}}/Slow/g' \
    "$REPO_ROOT/templates/notes/rejected.md.tmpl" > "$R19/.agents/notes/rejected/architecture/2026-11-24-trap.md"
sed -e 's/{{STUDY_ID}}/2026-11-study/g' -e 's/{{STUDY_TITLE}}/Baseline/g' -e 's/{{START_YYYY_MM_DD}}/2026-11-24/g' \
    -e 's/{{COMMIT_SHA}}/abc1234/g' -e 's/{{EXTERNAL_STORAGE_URI_OR_PATH}}/s3/g' \
    -e 's/{{PERMISSION_CLEARANCE_AND_EXPIRY_POLICY}}/cleared/g' -e 's/{{RUN_YYYY_MM_DD}}/2026-11-24/g' \
    -e 's/{{RUN_ID}}/r1/g' -e 's/{{CONFIG_OR_SHA}}/c1/g' -e 's/{{METRIC_OR_FINDING}}/0.9/g' \
    -e 's/{{LIMITS_OR_ADVICE}}/none/g' -e 's/{{DOCS_CHECK_COMMAND}}/.\/scripts\/check-docs.sh/g' \
    "$REPO_ROOT/templates/notes/record-study-README.md.tmpl" > "$R19/.agents/records/2026-11-study/README.md"
printf '# Docs AGENTS\n' > "$R19/docs/AGENTS.md"
sed -e 's/{{PROBLEM_STATEMENT_AND_DOMAIN}}/Objective/g' -e 's/{{SYMBOL}}/x/g' \
    -e 's/{{DEFINITION}}/State/g' -e 's/{{CONSTRAINTS}}/finite/g' \
    -e 's/{{ASSUMPTION_NAME}}/Bound/g' -e 's/{{ASSUMPTION_STATEMENT}}/Bounded/g' \
    -e 's/{{FALSIFICATION_CRITERION}}/Diverges/g' \
    -e 's/{{HYPOTHESIS_NAME}}/Monotone/g' -e 's/{{TESTABLE_HYPOTHESIS}}/Decreases loss/g' \
    -e 's/{{MECHANISM_DECOMPOSITION_DERIVATIONS_AND_INVARIANTS}}/Two-stage solver/g' \
    -e 's/{{THEORY_EVIDENCE_OWNER}}/Alice/g' \
    -e 's/{{THEORY_EVIDENCE_DESTINATION}}/.agents\/notes\/concluded\/ and .agents\/records\//g' \
    "$REPO_ROOT/templates/research/theory.md.tmpl" > "$R19/docs/theory.md"
sed -e 's/{{PROJECT_NAME}}/Demo/g' \
    -e 's/{{OPTIONAL_ACTIVE_TASKS}}/- [ ] Build solver — @alice — [note](.agents\/notes\/proposed\/process\/2026-11-24-doc-migration.md)/g' \
    -e 's/{{OPTIONAL_UP_NEXT_TASKS}}/- [ ] Run benchmark/g' \
    "$REPO_ROOT/templates/planning/ROADMAP.md.tmpl" > "$R19/ROADMAP.md"
"$GATE" --root "$R19" --seal >/dev/null
commit_all "$R19" "instantiated templates"
assert_pass "pass_live_template_instantiation" "$GATE" --root "$R19"
if ! grep -rn '{{' "$R19" --exclude-dir=.git >/dev/null 2>&1; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_live_template_no_leftover_placeholders"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "pass_live_template_no_leftover_placeholders"
fi

# Lean bilingual scaffold with core contracts, theory + pair, and ownerless bilingual ROADMAP
R19B="$TMP_BASE/lean_bilingual_scaffold"
init_repo "$R19B"
mkdir -p "$R19B/docs"
sed -e 's/{{LANGUAGE_MODE}}/i18n-en-zh/g' -e 's/{{LANGUAGE_PRIMARY}}/en/g' \
    -e 's/{{FEATURE_NOTES}}/false/g' -e 's/{{FEATURE_EMPIRICAL_RECORDS}}/false/g' \
    -e 's/{{FEATURE_ARCHIVE_SEAL}}/false/g' -e 's/{{FEATURE_BUDGETS}}/false/g' \
    "$REPO_ROOT/templates/core/docs-check.conf.tmpl" > "$R19B/docs-check.conf"
sed -e 's/{{PROJECT_ONE_LINE_SUMMARY}}/Lean demo./g' -e 's/{{REPO_LAYOUT_TREE}}/docs\//g' \
    -e 's/{{BUILD_AND_TEST_COMMANDS}}/true/g' -e 's/{{DOCS_CHECK_COMMAND}}/.\/scripts\/check-docs.sh/g' \
    -e 's/{{OPTIONAL_THEORY_RULE}}/- **Theoretical architecture**: read [docs\/theory.md](docs\/theory.md) before changing model assumptions./g' \
    -e 's/{{OPTIONAL_ROADMAP_RULE}}/- **Short-term roadmap**: [ROADMAP.md](ROADMAP.md) holds agreed tasks only; agents require explicit authorization to add rows./g' \
    -e '/{{OPTIONAL_/d' \
    "$REPO_ROOT/templates/core/AGENTS.md.tmpl" > "$R19B/AGENTS.md"
sed -e 's/{{PROJECT_NAME}}/LeanDemo/g' -e 's/{{DELIVERABLE_AUTHORITY}}/code and tests/g' \
    -e 's/{{NON_CODE_AUTHORITIES}}/proofs/g' -e 's/{{LANGUAGE_MODE}}/i18n-en-zh/g' \
    -e 's/{{LANGUAGE_PRIMARY}}/en/g' \
    -e 's/{{OPTIONAL_THEORY_TIER_ROW}}/| `docs\/theory.md` | Living theoretical formulation | Shipped code status |/g' \
    -e 's/{{OPTIONAL_ROADMAP_TIER_ROW}}/| `ROADMAP.md` | Agreed near-term tasks | Unagreed proposals |/g' \
    -e '/{{OPTIONAL_/d' \
    "$REPO_ROOT/templates/core/docs-AGENTS.md.tmpl" > "$R19B/docs/AGENTS.md"
printf '\n' >> "$R19B/docs/AGENTS.md"
cat "$REPO_ROOT/templates/i18n/i18n-en-zh.md.tmpl" >> "$R19B/docs/AGENTS.md"
sed -e 's/{{PROBLEM_STATEMENT_AND_DOMAIN}}/Lean objective/g' -e 's/{{SYMBOL}}/y/g' \
    -e 's/{{DEFINITION}}/Output/g' -e 's/{{CONSTRAINTS}}/real/g' \
    -e 's/{{ASSUMPTION_NAME}}/Convex/g' -e 's/{{ASSUMPTION_STATEMENT}}/Convex loss/g' \
    -e 's/{{FALSIFICATION_CRITERION}}/Non-convex counterexample/g' \
    -e 's/{{HYPOTHESIS_NAME}}/Convergent/g' -e 's/{{TESTABLE_HYPOTHESIS}}/Converges/g' \
    -e 's/{{MECHANISM_DECOMPOSITION_DERIVATIONS_AND_INVARIANTS}}/Single-stage/g' \
    -e 's/{{THEORY_EVIDENCE_OWNER}}/Bob/g' \
    -e 's/{{THEORY_EVIDENCE_DESTINATION}}/issue tracker and git commits/g' \
    "$REPO_ROOT/templates/research/theory.md.tmpl" > "$R19B/docs/theory.md"
printf '# 理论架构\n' > "$R19B/docs/theory.zh.md"
th_sha="$(hash_file "$R19B/docs/theory.md")"
printf 'source: docs/theory.md\ntarget: docs/theory.zh.md\nsource_sha256: %s\n' "$th_sha" > "$R19B/docs/theory.i18n.yaml"
sed -e 's/{{PROJECT_NAME}}/LeanDemo/g' \
    -e 's/{{OPTIONAL_ACTIVE_TASKS}}/- [ ] Verify bound\n  验证上界/g' \
    -e '/{{OPTIONAL_UP_NEXT_TASKS}}/d' \
    "$REPO_ROOT/templates/planning/ROADMAP.md.tmpl" > "$R19B/ROADMAP.md"
commit_all "$R19B" "lean bilingual scaffold"
assert_pass "pass_lean_bilingual_scaffold" "$GATE" --root "$R19B"
if ! grep -rn '{{' "$R19B" --exclude-dir=.git >/dev/null 2>&1; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_lean_bilingual_no_leftover_placeholders"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "pass_lean_bilingual_no_leftover_placeholders"
fi

# ---------------------------------------------------------------------------
# Case 14: lychee / vale hook config discovery, file filtering, warnings, CWD
# ---------------------------------------------------------------------------
MOCK_BIN="$TMP_BASE/mock_bin"
mkdir -p "$MOCK_BIN"
MOCK_LOG="$TMP_BASE/mock_hooks.log"
cat > "$MOCK_BIN/lychee" <<'EOF'
#!/usr/bin/env bash
printf 'lychee:%s|%s\n' "$(pwd -P)" "$*" >> "$MOCK_HOOK_LOG"
exit "${MOCK_LYCHEE_RC:-0}"
EOF
cat > "$MOCK_BIN/vale" <<'EOF'
#!/usr/bin/env bash
printf 'vale:%s|%s\n' "$(pwd -P)" "$*" >> "$MOCK_HOOK_LOG"
if [[ -n "${MOCK_VALE_OUT:-}" ]]; then
  printf '%s\n' "$MOCK_VALE_OUT"
fi
exit "${MOCK_VALE_RC:-0}"
EOF
chmod +x "$MOCK_BIN/lychee" "$MOCK_BIN/vale"

R20="$TMP_BASE/hook_config_discovery"
init_repo "$R20"
cat > "$R20/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_empirical_records=true
submodule_external=libs/ext
hook_advisory=lychee
hook_advisory=vale
EOF
mkdir -p "$R20/libs/ext" "$R20/.agents/records/2026-11-done"
printf '# Clean\n' > "$R20/README.md"
printf '# Study\n\nStatus: concluded\n\nSeamless old text.\n' > "$R20/.agents/records/2026-11-done/README.md"
# Create a real initialized child git repository registered as a 160000 gitlink
init_repo "$R20/libs/ext"
printf '# External broken\n\n[broken](nope.md)\n' > "$R20/libs/ext/bad.md"
commit_all "$R20/libs/ext" "external child broken doc"
EXT_SHA="$(git -C "$R20/libs/ext" rev-parse HEAD)"
cat > "$R20/.gitmodules" <<'EOF'
[submodule "ext"]
	path = libs/ext
	url = https://example.com/ext.git
EOF
git -C "$R20" add docs-check.conf README.md .agents/records/2026-11-done/README.md .gitmodules
git -C "$R20" update-index --add --cacheinfo 160000,"$EXT_SHA",libs/ext
git -C "$R20" commit -q -m "hook config discovery base with real gitlink"

# Run from outside R20 (/tmp) to prove CWD isolation and active-file filtering
: > "$MOCK_LOG"
assert_pass_with "pass_vale_advisory_no_config_skipped" "SKIPPED (no vale config found)" \
  bash -c 'cd /tmp && PATH="'"$MOCK_BIN"':$PATH" MOCK_HOOK_LOG="'"$MOCK_LOG"'" "'"$GATE"'" --root "'"$R20"'"'
if grep -Fq "lychee:$R20|--no-progress --offline --root-dir $R20 " "$MOCK_LOG" \
  && grep -Fq "$R20/README.md" "$MOCK_LOG" \
  && ! grep -Fq "libs/ext/bad.md" "$MOCK_LOG" \
  && ! grep -Fq "vale:" "$MOCK_LOG"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_lychee_cwd_isolated_and_filtered"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s (log=%s)\n' "pass_lychee_cwd_isolated_and_filtered" "$(cat "$MOCK_LOG")"
fi

cat > "$R20/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_empirical_records=true
submodule_external=libs/ext
hook_required=vale
EOF
assert_fail_with "fail_bd070_vale_required_no_config" "has no config" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20"

# Config discovery precedence: gates/optional < plain root < root dotfile
mkdir -p "$R20/gates/optional"
printf 'offline = true\n' > "$R20/gates/optional/lychee.toml"
printf 'MinAlertLevel = warning\n' > "$R20/gates/optional/vale.ini"
cat > "$R20/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_empirical_records=true
submodule_external=libs/ext
hook_required=lychee
hook_required=vale
EOF
: > "$MOCK_LOG"
assert_pass "pass_hooks_discover_gates_optional" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20"
if grep -Fq "lychee:$R20|--no-progress --offline --root-dir $R20 --config $R20/gates/optional/lychee.toml " "$MOCK_LOG" \
  && grep -Fq "vale:$R20|--config $R20/gates/optional/vale.ini --output=line $R20/README.md" "$MOCK_LOG" \
  && ! grep -Fq "2026-11-done" <(grep "^vale:" "$MOCK_LOG") \
  && ! grep -Fq "libs/ext/bad.md" "$MOCK_LOG"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_hooks_optional_config_and_vale_excludes"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s (log=%s)\n' "pass_hooks_optional_config_and_vale_excludes" "$(cat "$MOCK_LOG")"
fi

# Vale exit 126 with valid config reports execution failure, not missing config
assert_fail_with "fail_bd070_vale_exit_126_not_missing_config" "required hook 'vale' failed" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" MOCK_VALE_RC=126 "$GATE" --root "$R20"

# Vale warning-only (exit 0 + --output=line) surfaces BD902 even when vale is required
assert_pass_with "pass_vale_warning_surfaced_as_bd902" "BD902 vale README.md:3:9:BetterDocs.SlopEN:warn" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" MOCK_VALE_OUT="$R20/README.md:3:9:BetterDocs.SlopEN:warn" "$GATE" --root "$R20"

# Plain root lychee.toml / vale.ini beat gates/optional/*
printf 'offline = true\n' > "$R20/lychee.toml"
printf 'MinAlertLevel = warning\n' > "$R20/vale.ini"
: > "$MOCK_LOG"
assert_pass "pass_hooks_prefer_plain_root_over_optional" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20"
if grep -Fq -- "--config $R20/lychee.toml" "$MOCK_LOG" \
  && grep -Fq -- "--config $R20/vale.ini" "$MOCK_LOG"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_hooks_plain_root_precedence"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s (log=%s)\n' "pass_hooks_plain_root_precedence" "$(cat "$MOCK_LOG")"
fi

# Root dotfiles .lychee.toml / .vale.ini beat plain root
printf 'offline = true\n' > "$R20/.lychee.toml"
printf 'MinAlertLevel = warning\n' > "$R20/.vale.ini"
: > "$MOCK_LOG"
assert_pass "pass_hooks_prefer_root_dotfiles" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20"
if grep -Fq -- "--config $R20/.lychee.toml" "$MOCK_LOG" \
  && grep -Fq -- "--config $R20/.vale.ini" "$MOCK_LOG"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_hooks_root_dotfile_precedence"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s (log=%s)\n' "pass_hooks_root_dotfile_precedence" "$(cat "$MOCK_LOG")"
fi

# Empty Vale-eligible set (only concluded record exists): checks prerequisites first, then skips execution
R20E="$TMP_BASE/hook_empty_vale_set"
init_repo "$R20E"
mkdir -p "$R20E/.agents/records/2026-11-done"
cat > "$R20E/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_empirical_records=true
hook_required=vale
EOF
printf '# Study\n\nStatus: concluded\n\nSeamless old text.\n' > "$R20E/.agents/records/2026-11-done/README.md"
commit_all "$R20E" "concluded record only"
assert_fail_with "fail_bd070_empty_vale_set_still_checks_config" "has no config" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20E"
printf 'MinAlertLevel = warning\n' > "$R20E/.vale.ini"
: > "$MOCK_LOG"
assert_pass "pass_empty_vale_set_skips_execution" \
  env PATH="$MOCK_BIN:$PATH" MOCK_HOOK_LOG="$MOCK_LOG" "$GATE" --root "$R20E"
if ! grep -Fq "vale:" "$MOCK_LOG"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "pass_empty_vale_set_did_not_invoke_vale"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s (log=%s)\n' "pass_empty_vale_set_did_not_invoke_vale" "$(cat "$MOCK_LOG")"
fi

# Real lychee literal-path regression (glob metacharacters in filename)
if command -v lychee >/dev/null 2>&1; then
  R20L="$TMP_BASE/lychee_glob_literal"
  init_repo "$R20L"
  cat > "$R20L/docs-check.conf" <<'EOF'
kit_version=0.1.0
hook_required=lychee
EOF
  printf 'Guide1.md\n' > "$R20L/.gitignore"
  printf '# Clean bracket file\n' > "$R20L/Guide[1].md"
  printf '# Ignored broken sibling\n\n[broken](missing.md)\n' > "$R20L/Guide1.md"
  commit_all "$R20L" "clean bracket file beside ignored broken sibling"
  assert_pass "pass_real_lychee_literal_bracket_clean" "$GATE" --root "$R20L"
  printf '# Broken bracket file\n\n[broken](missing.md)\n' > "$R20L/Guide[1].md"
  printf '# Ignored clean sibling\n' > "$R20L/Guide1.md"
  assert_fail_with "fail_real_lychee_literal_bracket_broken" "BD070 lychee" "$GATE" --root "$R20L"
fi

# ---------------------------------------------------------------------------
# Case 15: --seal atomic write failure, non-regular manifest, staging exclusion
# ---------------------------------------------------------------------------
R21="$TMP_BASE/seal_write_failure"
init_repo "$R21"
mkdir -p "$R21/.agents/notes/archived/architecture" "$R21/.agents/notes/archived/.manifest.sha256.tmp.example"
cat > "$R21/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_archive_seal=true
EOF
printf '# Archived\n' > "$R21/.agents/notes/archived/architecture/2026-01-01-a.md"
printf '# Nested report\n' > "$R21/.agents/notes/archived/.manifest.sha256.tmp.example/report.md"
printf 'stale staging\n' > "$R21/.agents/notes/archived/.manifest.sha256.tmp.stale"
"$GATE" --root "$R21" --seal >/dev/null
commit_all "$R21" "initial sealed archive"
if ! grep -Fq ".manifest.sha256.tmp.stale" "$R21/.agents/notes/archived/manifest.sha256" \
  && grep -Fq ".agents/notes/archived/.manifest.sha256.tmp.example/report.md" "$R21/.agents/notes/archived/manifest.sha256"; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "seal_ignores_direct_staging_tmp_and_seals_nested_dir"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "seal_ignores_direct_staging_tmp_and_seals_nested_dir"
fi
ORIG_MANIFEST="$(cat "$R21/.agents/notes/archived/manifest.sha256")"
printf '# Archived B\n' > "$R21/.agents/notes/archived/architecture/2026-01-02-b.md"
chmod 555 "$R21/.agents/notes/archived"
assert_fail_with "fail_seal_unwritable_dir_bd040" "BD040" "$GATE" --root "$R21" --seal
chmod 755 "$R21/.agents/notes/archived"
if [[ "$(cat "$R21/.agents/notes/archived/manifest.sha256")" == "$ORIG_MANIFEST" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "seal_write_failure_preserved_prior_manifest"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "seal_write_failure_preserved_prior_manifest"
fi

# Directory at manifest.sha256 must fail BD043 and stay empty
R21D="$TMP_BASE/seal_manifest_dir"
init_repo "$R21D"
mkdir -p "$R21D/.agents/notes/archived/manifest.sha256" "$R21D/.agents/notes/archived/architecture"
cat > "$R21D/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_archive_seal=true
EOF
printf '# Archived\n' > "$R21D/.agents/notes/archived/architecture/2026-01-01-a.md"
assert_fail_with "fail_seal_directory_manifest_bd043" "BD043" "$GATE" --root "$R21D" --seal
if [[ -z "$(ls -A "$R21D/.agents/notes/archived/manifest.sha256")" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "seal_did_not_write_into_manifest_directory"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "seal_did_not_write_into_manifest_directory"
fi

# Directory introduced at manifest.sha256 at mv replacement time (post-validation TOCTOU)
R21R="$TMP_BASE/seal_manifest_dir_race"
init_repo "$R21R"
mkdir -p "$R21R/.agents/notes/archived/architecture" "$TMP_BASE/race_bin"
cat > "$R21R/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_notes=true
feature_archive_seal=true
EOF
printf '# Archived\n' > "$R21R/.agents/notes/archived/architecture/2026-01-01-a.md"
REAL_MV="$(command -v mv)"
cat > "$TMP_BASE/race_bin/mv" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ "\$arg" == "--help" ]]; then
    exec "$REAL_MV" "\$@"
  fi
done
mkdir -p "$R21R/.agents/notes/archived/manifest.sha256"
exec "$REAL_MV" "\$@"
EOF
chmod +x "$TMP_BASE/race_bin/mv"
assert_fail_with "fail_seal_post_validation_dir_race_bd040" "BD040" \
  env PATH="$TMP_BASE/race_bin:$PATH" "$GATE" --root "$R21R" --seal
if [[ -z "$(ls -A "$R21R/.agents/notes/archived/manifest.sha256")" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "seal_race_did_not_write_into_manifest_directory"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "seal_race_did_not_write_into_manifest_directory"
fi

printf '\nConformance summary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
