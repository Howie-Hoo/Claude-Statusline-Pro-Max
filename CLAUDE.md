# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A responsive, information-dense statusline for Claude Code CLI. Pure bash script that reads JSON from stdin, parses it with `jq`, and renders a 4-zone layout that adapts to terminal width across 13 responsive levels + fallbacks.

## Testing

```bash
# Smoke test (empty input)
echo '{}' | bash statusline-command.sh

# With model info
echo '{"model":{"id":"claude-opus-4-7","display_name":"Opus 4.7"}}' | bash statusline-command.sh

# With context window (TIER 1 — full fidelity)
echo '{"model":{"id":"claude-opus-4-7","display_name":"Opus 4.7"},"context_window":{"used_percentage":67.3,"context_window_size":200000,"current_usage":{"input_tokens":80000,"output_tokens":50000}}}' | bash statusline-command.sh

# TIER 2 — percentage + bar, no token counts
echo '{"model":{"id":"claude-sonnet-4-6","display_name":"Sonnet 4.6"},"context_window":{"used_percentage":42.5,"context_window_size":200000}}' | bash statusline-command.sh

# Verify no overflow at specific width
COLUMNS=80 bash statusline-command.sh <<< '{}'
```

## Critical Constraints

- **bash 3.2 only** — no `mapfile`, `declare -A`, `${var,,}`, or other bash 4+ features
- **macOS `tr` bug** — never use `\xNN` byte ranges in `tr`; use `od -A n -t x1` or LC_ALL=C strip-rest instead
- **No external dependencies** beyond `jq` and standard Unix tools
- **Zero overflow** — output must never exceed terminal width
- **Single-line invariant** — output must never contain newlines; all string values are sanitized after eval
- **Single-file script** — everything lives in `statusline-command.sh`

## Architecture

```
stdin (JSON) → jq parse → eval + sanitize → zone computation → responsive assembly → stdout
```

Four zones separated by `│`:
1. **Model** — family-preserving name truncation + thinking/effort/agent marks, color-coded by family (Opus=magenta, Sonnet=blue, Haiku=cyan)
2. **Context** — TIER-based display with progress bar, color thresholds at 70%/86%
3. **Workspace** — project name + relative path + git branch + vim mode
4. **Duration** — compound format (`1h24m`) + session tokens + rate limits

### Context TIER System

| TIER | Signal | Display |
|------|--------|---------|
| 1 | current_usage tokens non-zero | bar + % + token counts |
| 2 | used_pct > 0 but no current_usage | bar + % + size (no token counts) |
| 3 | only ctx_size known | "ctx 200.0k" |
| 0 | no data | "n/a" |

### Responsive System

`try_build(m, p, b, c, show_rate, show_vim, show_dur, show_session)` assembles a candidate string. `try_len` computes width via pure arithmetic using pre-computed zone lengths (zero-fork). 15 levels (L0-L12 + L2a/L2b/L3a) + 2 fallbacks + emergency try progressively truncated parameters; first fit wins and exits. Content truncation order: path → context → model → branch. Optional element removal: rate limits → vim → session tokens → duration → path. Emergency fallback truncates by display width (not char count) to handle CJK/emoji.

### Visible Length

Formula: `display = chars + (bytes - chars - N_4byte) / 2 - N_3byte_single_width` where N_4byte counts UTF-8 leading bytes F0-F4 via LC_ALL=C strip-rest, and N_3byte_single_width corrects for known 3-byte 1-col chars (│▓░●…). Exact for ASCII+CJK+emoji.

### Global Variable Pattern

`visible_len` sets `_VL`, `fmt_tok` sets `_FT`, `try_len` sets `_TL` — eliminates subshell forks in the hot path.

### Color Variables

Actual ESC bytes via `$'\033'[0m` syntax (not literal `\033` strings). All output uses `printf '%s'` (not `printf "%b"`) to prevent backslash interpretation in user data.

### Git Branch Cache

5-second cache at `/tmp/.claude-git-branch-$(md5_of_cwd)` with atomic write. Schema fields (`wt_branch`, `git_worktree`, `worktree_name`) take priority over the git command. Cross-platform `stat` for mtime (macOS + Linux).

### Rate Limit Thresholds

Green ≤59%, Yellow 60-84%, Red ≥85%.

## Bilingual Docs

English docs in `docs/`, Chinese translations in `docs/zh/`. Both READMEs (`README.md`, `README.zh-CN.md`) must stay in sync.
