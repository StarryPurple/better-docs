# Calibration Examples (English and Chinese)

Each pair shows a bad passage and its proposition-preserving rewrite.

## English examples

### 1. Change narration → present-tense contract + counterfactual
- **Bad**: `Previously, the parser used to silently ignore unknown keys, which caused bugs in v1. In this PR we changed it to throw an error instead.`
- **Good**: `The parser rejects unknown keys with BD002. Without strict key rejection, misspelled feature flags silently fall back to defaults.`

### 2. Defensive padding & hype → concrete fact
- **Bad**: `It is important to note that this powerful and seamless tool makes it easy to validate your docs. In conclusion, simply run it before pushing.`
- **Good**: `Run ./gates/check-docs.sh before pushing. It exits 1 on broken local links, budget overruns, or malformed Agent Notes.`

### 3. Dead session citation → standalone invariant
- **Bad**: `Clamp concurrency to 4 (see decision 3 from audit B2; reviewer confirmed this is safe for now).`
- **Good**: `Clamp concurrency to 4; higher values exceed the SQLite write-lock timeout under default busy_timeout=5000ms.`

### 4. Binary slop reframe → literal statement
- **Bad**: `AGENTS.md is not just a static guide—it's a living compass that empowers your agents.`
- **Good**: `AGENTS.md holds always-loaded commands, repo boundaries, and links to deeper owning docs.`

## Chinese examples

### 5. Chinese ChatGPT-style padding → direct technical Chinese
- **Bad**: `需要注意的是，这是一个非常强大且无缝的文档检查工具。值得一提的是，它不仅能检查链接，还能确保笔记格式正确。总而言之，建议大家在提交前运行。`
- **Good**: `提交前运行 ./gates/check-docs.sh。脚本检查本地链接、字数预算和 Agent Note 格式，发现违规返回退出码 1。`

### 6. Chinese change narration → current state + rationale link
- **Bad**: `以前我们把所有实验日志都直接写在 README 里，上一轮评审后决定不再这么做，改为放到新目录中。`
- **Good**: `实验阶段性记录存放在 .agents/records/<study-id>/，README.md 仅保留当前可复现主线与最佳基线。决策依据见 [2026-11-24-records-boundary.md](.agents/notes/implemented/process/2026-11-24-records-boundary.md)。`

### 7. Overcorrection trap (DO NOT drop load-bearing clauses)
- **Original**: `Never run --seal before updating inbound links to the archived note; once sealed, the archive gate rejects any edit to the file.`
- **Bad trim (loses ordering & consequence)**: `Update inbound links and run --seal.`
- **Good trim**: `Update inbound links before running --seal; sealed files are immutable and fail BD042 on subsequent edits.`
