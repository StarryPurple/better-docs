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

assert_fail_with() {
  local name="$1"
  local expect_id="$2"
  shift 2
  local out
  local rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne 1 ]]; then
    printf 'FAIL  %s (expected exit 1, got %d)\n%s\n' "$name" "$rc" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if [[ "$out" != *"$expect_id"* ]]; then
    printf 'FAIL  %s (expected diagnostic %s)\n%s\n' "$name" "$expect_id" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  printf 'PASS  %s (%s)\n' "$name" "$expect_id"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_pass_with() {
  local name="$1"
  local expect_str="$2"
  shift 2
  local out
  local rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL  %s (expected exit 0, got %d)\n%s\n' "$name" "$rc" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if [[ "$out" != *"$expect_str"* ]]; then
    printf 'FAIL  %s (expected output containing %s)\n%s\n' "$name" "$expect_str" "$out" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  printf 'PASS  %s (%s)\n' "$name" "$expect_str"
  PASS_COUNT=$((PASS_COUNT + 1))
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

Summary of baseline runs.
EOF

"$GATE" --root "$R1" --seal >/dev/null
commit_all "$R1" "initial valid commit"

# Second commit adding a new archived note (append-only extension)
cat > "$R1/.agents/notes/archived/architecture/2026-02-01-second.md" <<'EOF'
# Agent Note: Second archived

Status: implemented
EOF
"$GATE" --root "$R1" --seal >/dev/null
commit_all "$R1" "append second sealed archive"

assert_pass "valid_full_local" "$GATE" --root "$R1"
assert_pass "valid_full_ci_append_only" "$GATE" --root "$R1" --ci --base-ref HEAD~1

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
# Case 4: BD010 — EN + CJK token counting budget
# ---------------------------------------------------------------------------
R4="$TMP_BASE/bd010"
init_repo "$R4"
cat > "$R4/docs-check.conf" <<'EOF'
kit_version=0.1.0
feature_budgets=true
budget=README.md:5
EOF
# 2 English words + 4 CJK chars = 6 tokens > 5
printf 'Hello world 你好世界\n' > "$R4/README.md"
commit_all "$R4" "over cjk budget"
assert_fail_with "fail_bd010_cjk_budget" "BD010" "$GATE" --root "$R4"

# ---------------------------------------------------------------------------
# Case 5: BD020 & BD021 — broken links and missing anchors
# ---------------------------------------------------------------------------
R5="$TMP_BASE/bd020_bd021"
init_repo "$R5"
cat > "$R5/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
cat > "$R5/README.md" <<'EOF'
# Home

See [missing](missing.md) and [bad anchor](README.md#nonexistent).
EOF
commit_all "$R5" "broken links"
assert_fail_with "fail_bd020_broken_link" "BD020" "$GATE" --root "$R5"
assert_fail_with "fail_bd021_missing_anchor" "BD021" "$GATE" --root "$R5"

# ---------------------------------------------------------------------------
# Case 6: BD030–BD033 + grandfathered_note exemption
# ---------------------------------------------------------------------------
R6="$TMP_BASE/bd030_bd033"
init_repo "$R6"
mkdir -p "$R6/.agents/notes/implemented/architecture" "$R6/.agents/notes/implemented/unknown-class"
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

# Now add violating notes
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
commit_all "$R6" "bad notes"
assert_fail_with "fail_bd030_unknown_class" "BD030" "$GATE" --root "$R6"
assert_fail_with "fail_bd031_bad_header" "BD031" "$GATE" --root "$R6"
assert_fail_with "fail_bd032_missing_sections" "BD032" "$GATE" --root "$R6"
assert_fail_with "fail_bd033_proposal_heading" "BD033" "$GATE" --root "$R6"

# ---------------------------------------------------------------------------
# Case 7: BD040–BD043 — archive seal CI base-ref, tamper detection, symlink rejection
# ---------------------------------------------------------------------------
assert_fail_with "fail_bd040_ci_no_base" "BD040" "$GATE" --root "$R1" --ci
assert_fail_with "fail_bd040_ci_same_head" "BD040" "$GATE" --root "$R1" --ci --base-ref HEAD

R7="$TMP_BASE/bd041_tamper"
cp -a "$R1" "$R7"
printf '\ntampered line\n' >> "$R7/.agents/notes/archived/architecture/2026-01-01-old.md"
assert_fail_with "fail_bd042_digest_mismatch" "BD042" "$GATE" --root "$R7"
# Even if an attacker rewrites manifest.sha256 and commits, --ci --base-ref HEAD~1 catches BD041!
new_hash="$(sha256sum "$R7/.agents/notes/archived/architecture/2026-01-01-old.md" | awk '{print $1}')"
awk -v h="$new_hash" '$2 == ".agents/notes/archived/architecture/2026-01-01-old.md" { print h "  " $2; next } { print }' \
  "$R7/.agents/notes/archived/manifest.sha256" > "$R7/.agents/notes/archived/manifest.tmp"
mv "$R7/.agents/notes/archived/manifest.tmp" "$R7/.agents/notes/archived/manifest.sha256"
commit_all "$R7" "tamper sealed archive and rewrite manifest"
assert_fail_with "fail_bd041_append_only_violation" "BD041" "$GATE" --root "$R7" --ci --base-ref HEAD~1

ln -sf "../../README.md" "$R7/.agents/notes/archived/evil-link.md"
assert_fail_with "fail_bd043_archive_symlink" "BD043" "$GATE" --root "$R7"

# ---------------------------------------------------------------------------
# Case 8: BD050 & BD051 — hygiene and draft marker
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

# ---------------------------------------------------------------------------
# Case 9: BD060 — i18n-en-zh pairing and staleness
# ---------------------------------------------------------------------------
R9="$TMP_BASE/bd060_i18n"
init_repo "$R9"
cat > "$R9/docs-check.conf" <<'EOF'
kit_version=0.1.0
language_mode=i18n-en-zh
language_primary=en
EOF
printf '# Hello\n' > "$R9/README.md"
commit_all "$R9" "missing zh pair"
assert_fail_with "fail_bd060_missing_pair" "BD060" "$GATE" --root "$R9"

printf '# 你好\n' > "$R9/README.zh.md"
src_sha="$(sha256sum "$R9/README.md" | awk '{print $1}')"
printf 'source: README.md\ntarget: README.zh.md\nsource_sha256: %s\n' "$src_sha" > "$R9/README.i18n.yaml"
commit_all "$R9" "valid i18n pair"
assert_pass "valid_i18n_pair" "$GATE" --root "$R9"

printf '\nUpdated text.\n' >> "$R9/README.md"
commit_all "$R9" "stale i18n source"
assert_fail_with "fail_bd060_stale_sidecar" "BD060" "$GATE" --root "$R9"

# ---------------------------------------------------------------------------
# Case 10: BD070 required hook vs BD902 advisory hook + BD901 --probes
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
assert_pass_with "pass_bd901_advisory_probes" "BD901" "$GATE" --root "$R10" --probes

echo "hook_required=nonexistent_better_docs_tool" >> "$R10/docs-check.conf"
commit_all "$R10" "required missing hook"
assert_fail_with "fail_bd070_missing_required_hook" "BD070" "$GATE" --root "$R10"

# ---------------------------------------------------------------------------
# Case 11: BD903 — unlisted & uninitialized gitlink reported explicitly
# ---------------------------------------------------------------------------
R11="$TMP_BASE/bd903_submodule"
init_repo "$R11"
cat > "$R11/docs-check.conf" <<'EOF'
kit_version=0.1.0
EOF
cat > "$R11/.gitmodules" <<'EOF'
[submodule "libs/unlisted"]
	path = libs/unlisted
	url = https://example.com/unlisted.git
EOF
mkdir -p "$R11/libs/unlisted"
printf '# Root\n' > "$R11/README.md"
commit_all "$R11" "unlisted uninitialized submodule"
assert_pass_with "pass_bd903_unlisted_gitlink" "BD903" "$GATE" --root "$R11"

printf '\nConformance summary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
