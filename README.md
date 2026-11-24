# better-docs

Portable documentation governance for AI-assisted repositories: a fixed five-skill kit, composable per-repo contracts, and a deterministic check gate.

## What this repo ships

- **`skills/`**: Five cross-agent skills (`.agents/skills/` standard) for bootstrapping, brownfield migration, EN/ZH anti-slop prose, ongoing gardening, and fresh-context verification.
- **`templates/`**: Composable building blocks assembled per repo (`AGENTS.md`, `docs/AGENTS.md`, `docs-check.conf`, `.agents/notes/`, `.agents/records/`, i18n, monorepo subtrees, recursive submodules).
- **`gates/`**: Universal bash check gate ([check-docs.sh](gates/check-docs.sh)) conforming to [docs/check-spec.md](docs/check-spec.md), plus a shared conformance suite ([gates/conformance/](gates/conformance/run.sh)) and optional linter configs.

## Quick start

1. **Install the skills globally** (symlink or copy into `~/.agents/skills/`):

```sh
mkdir -p ~/.agents/skills
for s in doc-bootstrap doc-migrate prose-standard doc-garden doc-verify; do
  ln -sfn "$(pwd)/skills/$s" "$HOME/.agents/skills/$s"
done
```

2. **Bootstrap a repository**: invoke `doc-bootstrap` in any greenfield or brownfield repo. It grills you on language/i18n, evidence needs, topology, rigor, and gate hooks, then drafts `AGENTS.md`, `docs/AGENTS.md`, `docs-check.conf`, and (for brownfield) a migration manifest.
3. **Run the deterministic gate**:

```sh
./gates/check-docs.sh --root /path/to/repo
```

4. **Verify this repo and the conformance suite**:

```sh
./gates/check-docs.sh
./gates/conformance/run.sh
```

## Layout

```text
better-docs/
├── AGENTS.md                 # Standing orders (CLAUDE.md symlinks here)
├── docs-check.conf           # Gate configuration for this repository
├── docs/
│   ├── AGENTS.md             # Tier taxonomy, writing rules, wordcount budgets
│   └── check-spec.md         # Deterministic gate specification (BD001–BD099)
├── skills/                   # Portable Agent Skills
│   ├── doc-bootstrap/        # Discovery grill, scaffold, brownfield manifest
│   ├── doc-migrate/          # Batched brownfield executor
│   ├── prose-standard/       # EN + ZH anti-slop and CoT-leakage standard
│   ├── doc-garden/           # Drift, budgets, note supersession, sealing
│   └── doc-verify/           # Fresh-context subagent / checklist verifier
├── templates/                # Composable repo contract templates
├── gates/                    # check-docs.sh + conformance fixtures + optional hooks
└── .agents/notes/            # Dogfooded decision records for this repository
```
