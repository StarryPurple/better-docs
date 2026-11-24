# Advisory EN + ZH Recall Batteries

These ripgrep probes hunt Chain-of-Thought leakage, change narration, and ChatGPT-style filler. They are **advisory discovery aids**, never hard-fail definitions: every hit requires semantic judgment, and unpatterned reading of dense prose is still required to catch misses.

## Invocation rules

1. Pass `--hidden --glob '!.git/**'` so `.agents/` is searched without scanning `.git/`.
2. Place exclusions **last** so earlier globs cannot re-admit excluded paths.
3. Also exclude concluded study directories under `.agents/records/` and any `submodule_shared=` / `submodule_external=` paths.
4. Keep code-token patterns case-sensitive; pass `-i` on natural-language prose lines.

```sh
EXCLUDES=(
  --glob '!.git/**'
  --glob '!vendor/**'
  --glob '!node_modules/**'
  --glob '!.agents/notes/archived/**'
  --glob '!.agents/scratch/**'
  --glob '!**/prose-standard/references/**'
)
```

## English probes

```sh
# 1. Dead draft / session citations
rg -n --hidden '\(decision \d|\(audit [A-Z]\d|design §|plan §|design ledger|\bP-[IVX]+\b|\bW\d\b|\bT\d\b' . "${EXCLUDES[@]}"

# 2. PR / commit / stack vantage
rg -n --hidden -i '\bthis PR\b|\bthis branch\b|\bthis stack\b|\blater PRs?\b|\bprevious commits?\b|\bthis commit\b' . "${EXCLUDES[@]}"

# 3. Change narration and indexical time stamps
rg -n --hidden -i '\bused to\b|\bno longer\b|\bpreviously\b|\bthe old\b|\bwas renamed\b|\bwas moved\b|\bfor now\b|this cut' . "${EXCLUDES[@]}"

# 4. Review choreography and defensive self-justification
rg -n --hidden -i 'rejected in review|review round|reviewer confirmed|codex suggested|claude suggested|is safe because|it simply' . "${EXCLUDES[@]}"

# 5. Hype, comfort adjectives, and LLM-slop reframes
rg -n --hidden -i '\b(seamless|seamlessly|effortless|robust|powerful|delve|tapestry|testament to)\b|not just .*, it.?s|in conclusion,|it is worth noting|it is important to note' . "${EXCLUDES[@]}"
```

## Chinese probes

```sh
# 1. Change narration and review choreography in Chinese prose
rg -n --hidden '以前|不再|旧版|老版本|老的|上一?轮|评审|本版|本 PR|本次提交|之前我们|此前' . "${EXCLUDES[@]}"

# 2. ChatGPT-style defensive padding and summary filler in Chinese
rg -n --hidden '需要注意的是|值得一提的是|不仅如此|总而言之|综上所述|换句话说|本质上来说|毫不夸张|显而易见|简单来说|无缝|开箱即用|强大而灵活' . "${EXCLUDES[@]}"

# 3. Stray Chinese authoring residue in English-only docs or code comments (run on EN surfaces only)
rg -n --hidden '设计稿|评审|旧版|上一?轮|遗留|临时|待定' --glob '!*.zh.md' . "${EXCLUDES[@]}"
```

## False-positive families (judge and keep when valid)

- **Instrumental `"used to"`**: `"the token used to authenticate"` describes function, not past state.
- **Runtime old/new handover**: `"the old worker drains before the new worker binds"` describes live runtime behavior.
- **Process docs about PRs**: PR templates or git-workflow guides legitimately mention `"PR"`.
- **Protocol versions**: `/v1/completions`, `TLSv1.3` are identifiers, not draft stamps.
- **External standard sections**: `RFC 9110 §10.1.5` resolves outside the repo by design.
- **Explicit `## Alternatives considered` slots**: `"rejected"` inside a note's alternatives slot is sanctioned genre structure, not review choreography.
- **Empirical records**: dated run comparisons inside `.agents/records/<study-id>/` are sanctioned temporal evidence when `feature_empirical_records=true`.
- **Versioned release phrasing in ZH**: `本版本` in an upgrade guide refers to a real release; bare indexical `本版` in current-state docs is leakage.
