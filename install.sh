#!/usr/bin/env bash
# Idempotent skill installer for better-docs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILLS=(doc-bootstrap doc-migrate prose-standard doc-garden doc-verify)
MODE="release"
UNINSTALL=0
LINK_CLAUDE=0
LINK_CODEX=0
INSTALL_DIR="${BETTER_DOCS_HOME:-$HOME/.local/share/better-docs}"

usage() {
  cat <<'EOF'
Usage: install.sh [options]
  --mode release|dev   Link from ~/.local/share/better-docs (default) or current checkout (dev)
  --claude             Also link skills into ~/.claude/skills
  --codex              Also link skills into ~/.codex/skills
  --uninstall          Remove skill symlinks created by this kit
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || {
        echo "install.sh: --mode requires release or dev" >&2
        exit 2
      }
      MODE="$2"
      shift 2
      ;;
    --claude)
      LINK_CLAUDE=1
      shift
      ;;
    --codex)
      LINK_CODEX=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "install.sh: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  release) SRC_DIR="$INSTALL_DIR" ;;
  dev) SRC_DIR="$SCRIPT_DIR" ;;
  *)
    echo "install.sh: invalid --mode '$MODE' (expected release or dev)" >&2
    exit 2
    ;;
esac

TARGETS=("$HOME/.agents/skills")
[[ "$LINK_CLAUDE" -eq 1 ]] && TARGETS+=("$HOME/.claude/skills")
[[ "$LINK_CODEX" -eq 1 ]] && TARGETS+=("$HOME/.codex/skills")

if [[ "$UNINSTALL" -eq 1 ]]; then
  RESOLVED_SRC="$SRC_DIR"
  [[ -d "$SRC_DIR" ]] && RESOLVED_SRC="$(cd "$SRC_DIR" && pwd -P)"
  for target in "${TARGETS[@]}"; do
    for s in "${SKILLS[@]}"; do
      dest="$target/$s"
      if [[ -L "$dest" ]]; then
        link_target="$(readlink "$dest")"
        if [[ "$link_target" == "$RESOLVED_SRC/skills/$s" || "$link_target" == "$SRC_DIR/skills/$s" || "$link_target" == "$SCRIPT_DIR/skills/$s" ]]; then
          rm -f "$dest"
          printf 'removed %s\n' "$dest"
        else
          printf 'skipped %s (points to %s)\n' "$dest" "$link_target"
        fi
      fi
    done
  done
  exit 0
fi

if [[ ! -d "$SRC_DIR/skills" ]]; then
  echo "install.sh: skills directory not found at $SRC_DIR/skills" >&2
  exit 1
fi
SRC_DIR="$(cd "$SRC_DIR" && pwd -P)"

# Pre-flight: validate all source skills and destination conflicts before mutating anything.
for s in "${SKILLS[@]}"; do
  if [[ ! -f "$SRC_DIR/skills/$s/SKILL.md" ]]; then
    echo "install.sh: missing skill manifest $SRC_DIR/skills/$s/SKILL.md" >&2
    exit 1
  fi
done
for target in "${TARGETS[@]}"; do
  for s in "${SKILLS[@]}"; do
    dest="$target/$s"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      echo "install.sh: refusing to overwrite non-symlink at $dest" >&2
      exit 1
    fi
  done
done

for target in "${TARGETS[@]}"; do
  mkdir -p "$target"
  for s in "${SKILLS[@]}"; do
    src="$SRC_DIR/skills/$s"
    dest="$target/$s"
    ln -sfn "$src" "$dest"
    printf 'linked %s -> %s\n' "$dest" "$src"
  done
done
