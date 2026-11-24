# better-docs

Portable documentation governance for AI-assisted repositories: a fixed five-skill kit, composable per-repo contracts, and a deterministic check gate.

## What this repo ships

- **`skills/`**: Five cross-agent skills (`.agents/skills/` standard) for bootstrapping, brownfield migration, EN/ZH anti-slop prose, ongoing gardening, and fresh-context verification.
- **`templates/`**: Composable building blocks assembled per repo (`AGENTS.md`, `docs/AGENTS.md`, `docs-check.conf`, `.agents/notes/`, `.agents/records/`, i18n, monorepo subtrees, recursive submodules).
- **`gates/`**: Universal bash check gate ([check-docs.sh](gates/check-docs.sh)) conforming to [docs/check-spec.md](docs/check-spec.md), plus a shared conformance suite ([gates/conformance/run.sh](gates/conformance/run.sh)) and optional linter configs.

## Quick start

1. **Clone once to a machine-local directory** (HTTPS or SSH):

```sh
# HTTPS
git clone https://github.com/StarryPurple/better-docs.git "$HOME/.local/share/better-docs"

# or SSH
git clone git@github.com:StarryPurple/better-docs.git "$HOME/.local/share/better-docs"
```

2. **Link the five skills globally**, then open a new agent session:

```sh
KIT="$HOME/.local/share/better-docs"
mkdir -p "$HOME/.agents/skills"
for s in doc-bootstrap doc-migrate prose-standard doc-garden doc-verify; do
  ln -sfn "$KIT/skills/$s" "$HOME/.agents/skills/$s"
done

# Optional: if your agent runtime scans a separate global skills root (e.g., Antigravity uses "$HOME/.gemini/config/skills"), symlink into that directory as well.
```

3. **Use inside a target repository**:
   - Open an agent session in `/path/to/target-repo` and ask it to run `doc-bootstrap` (pointing to `$HOME/.local/share/better-docs` for templates and `gates/check-docs.sh`).
   - Answer the 5-topic grill (language/i18n first, then evidence, topology, rigor, and gate runtime/hooks).
   - For brownfield repos, review the generated migration manifest, then run `doc-migrate`.
   - Copy `$HOME/.local/share/better-docs/gates/check-docs.sh` to `scripts/check-docs.sh` in the target repo (so the target repo works standalone) and run:

```sh
./scripts/check-docs.sh
```

## Verify this repo

Run from the root of your `better-docs` checkout:

```sh
./gates/check-docs.sh
./gates/conformance/run.sh
```

## Uninstall

```sh
# Remove global skill symlinks and local kit checkout
for s in doc-bootstrap doc-migrate prose-standard doc-garden doc-verify; do
  rm -f "$HOME/.agents/skills/$s"
done
rm -rf "$HOME/.local/share/better-docs"
```

If you added optional symlinks in another runtime-specific global root, remove those as well. To remove `better-docs` from a specific target repo, delete its `docs-check.conf`, `scripts/check-docs.sh`, and any vendored `.agents/skills/{prose-standard,doc-garden,doc-verify}` folders; keep or edit `AGENTS.md`, `docs/`, and `.agents/notes/` as ordinary Markdown.

## Layout

```text
better-docs/
├── AGENTS.md                 # Standing orders (CLAUDE.md symlinks here)
├── docs-check.conf           # Gate configuration for this repository
├── docs/
│   ├── AGENTS.md             # Tier taxonomy, writing rules, wordcount budgets
│   └── check-spec.md         # Deterministic gate spec (BD001–BD070, BD901–BD903)
├── skills/                   # Portable Agent Skills (doc-bootstrap, doc-migrate, prose-standard, doc-garden, doc-verify)
├── templates/                # Composable repo contract templates
├── gates/                    # check-docs.sh + conformance suite (conformance/run.sh) + optional linter configs
└── .agents/notes/            # Dogfooded decision records for this repository
```
