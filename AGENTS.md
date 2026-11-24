# AGENTS.md

`better-docs` is a cross-agent documentation governance kit: five portable skills, composable repo templates, and a deterministic check gate. Follow [docs/AGENTS.md](docs/AGENTS.md) for documentation placement, style, and budgets.

## Repository layout

```text
skills/       Five portable Agent Skills (.agents/skills/ standard)
templates/    Composable building blocks instantiated by doc-bootstrap
gates/        Universal bash gate (check-docs.sh), conformance fixtures, optional hooks
docs/         Standing governance contract (docs/AGENTS.md) and gate spec (docs/check-spec.md)
.agents/      Dogfooded Agent Notes (.agents/notes/); .agents/scratch/ is gitignored and never tracked
```

## Commands

```sh
./gates/check-docs.sh                      # Run deterministic doc checks on this repo
./gates/check-docs.sh --probes             # Run checks plus advisory EN/ZH slop probes
./gates/conformance/run.sh                 # Run valid/invalid conformance fixtures for check-docs.sh
./gates/check-docs.sh --ci --base-ref HEAD~1  # CI mode (requires explicit base ref != HEAD)
```

## Standing rules

- **Skills follow the open Agent Skills format**: one level under `skills/<name>/SKILL.md` with YAML frontmatter (`name`, quoted `description`). Keep `skills/` project-agnostic; repo-specific facts stay in `AGENTS.md` and `docs/`.
- **Check-gate parity**: `docs/check-spec.md` is the single authority for every diagnostic ID (`BD001`–`BD099`), parsing rule, and exit code. Any gate change updates [docs/check-spec.md](docs/check-spec.md) and [gates/conformance/run.sh](gates/conformance/run.sh) in the same commit.
- **No alien runtimes in the baseline gate**: `gates/check-docs.sh` uses only `bash`, POSIX `awk`, `git`, and `sha256sum` (or `shasum`). Additional repo-native gate engines live in `gates/` only if they pass `gates/conformance/run.sh`.
- **Dogfood every rule**: apply [prose-standard](skills/prose-standard/SKILL.md) to all authored Markdown and comments. Never commit `.agents/scratch/` files. Keep `CLAUDE.md` symlinked to `AGENTS.md` and edit `AGENTS.md` directly.
- **Notes and archival**: create Agent Notes under `.agents/notes/` only for lasting design rationale not carried by specs or code; follow [.agents/notes/README.md](.agents/notes/README.md). Archived notes under `.agents/notes/archived/` are frozen and sealed in `manifest.sha256`.
- **Verify before finishing**: run `./gates/check-docs.sh` and `./gates/conformance/run.sh` after changes, and report only checks actually executed.
