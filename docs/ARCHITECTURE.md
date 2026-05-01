# Architecture

## Overview

The statusline reads a JSON schema from Claude Code via stdin, extracts fields with `jq`, and renders a responsive layout using pure bash arithmetic.

```
stdin (JSON) → jq parse → zone computation → responsive assembly → stdout
```

## Zone Layout

Four zones arranged left-to-right with `│` separators:

```
Zone 1: Model    │  Zone 2: Context  │  Zone 3: Workspace  │  Zone 4: Duration
```

### Zone 1 — Model

- Model name with color coding (Opus=magenta, Sonnet=blue, Haiku=cyan, other=green)
- Thinking indicator: `●` when extended thinking is enabled
- Effort level: `⬆`/`⬆⬆`/`⬆⬆⬆` marks for high/xhigh/max
- Agent indicator: `●` prefix when agent is active
- **Family-preserving truncation**: extracts family keyword + version chain, skips "claude" prefix and date stamps
  - `claude-opus-4-7` → mid: `opus-4-7`, short: `opus`
  - `claude-3-5-sonnet-20241022` → mid: `3-5-sonnet`, short: `sonnet`
  - `claude-haiku-4-5-20251001` → mid: `haiku-4-5`, short: `haiku`

### Zone 2 — Context

**TIER signal quality system** — display adapts to available data, never shows misleading information:

| TIER | Signal | Display |
|------|--------|---------|
| 1 | Full token breakdown available (`current_usage` non-zero) | Bar + % + input/output/cache tokens |
| 2 | Percentage known, no token breakdown | Bar + % + context size |
| 3 | Only context size known | "ctx 200.0k" |
| 0 | No context data | "n/a" |

Rationale: `total_input_tokens`/`total_output_tokens` are cumulative across the entire session including compacted turns. They always overestimate current context occupancy, and the overestimate grows with session length. Showing them as a percentage or bar is misleading. When no real signal exists, showing only the context size is honest and stable.

- 10-cell progress bar `▓░` with color thresholds:
  - Green: 0-69%
  - Yellow: 70-85%
  - Red: 86-100%+
- Bar clamped to [0,100] for display; percentage shows real value (can exceed 100%)
- Three truncation levels: bar+%+tokens → %+tokens → % only

### Zone 3 — Workspace

- Path derived from `project_dir` (official Claude Code field), not raw `cwd`
- Project name + relative path when inside a project
- `path_mid` truncation: project name capped at 20 chars (consistent with root case)
- Git branch: schema fields first (`wt_branch`, `git_worktree`, `worktree_name`), then `git` command with 5s cache
- Branch gets `│` prefix when path is empty (visual distinction from context zone)
- Vim mode indicator: `🔄` INSERT, `👁` VISUAL

### Zone 4 — Duration

- Compound format: `1h24m`, `2d3h`, `45s` (sub-second suppressed)
- Session tokens: cumulative input + output across entire session (secondary stat)
- Rate limits: `5h:42% 7d:15%` with color thresholds:
  - Green: ≤59%
  - Yellow: 60-84%
  - Red: ≥85%
- Rate limits gracefully omitted for third-party providers (no `rate_limits` field)

## Responsive Levels

15 levels (L0-L7 + L2a/L2b/L3a + L8-L12) + fallback + emergency + last-resort:

### Core truncation (L0-L7)

Progressive truncation of model name, path, branch, and context detail:

| Level | Model | Path | Branch | Context | Optional |
|-------|-------|------|--------|---------|----------|
| L0 | full | full | full | bar+%+tok | all |
| L1 | full | mid | full | bar+%+tok | all |
| L2 | full | mid | full | %+tok | all |
| L2a | full | mid | full | % only | all |
| L2b | full | mid | short | % only | all |
| L3 | full | short | full | %+tok | all |
| L3a | full | short | short | %+tok | all |
| L4 | mid | short | full | %+tok | all |
| L5 | mid | short | short | %+tok | all |
| L6 | short | short | short | %+tok | all |
| L7 | short | short | short | % only | all |

L2a/L2b/L3a were added to close a 64-char coverage gap between L2 and L3 that wasted space at 80-100 column terminals.

### Optional element removal (L8-L12)

Drop optional elements by priority (least critical first):

| Level | Rate | Vim | Session | Duration | Path |
|-------|------|-----|---------|----------|------|
| L8 | removed | kept | kept | kept | kept |
| L9 | removed | removed | kept | kept | kept |
| L10 | removed | removed | removed | kept | kept |
| L11 | removed | removed | removed | removed | kept |
| L12 | removed | removed | removed | removed | removed |

### Emergency levels

- **Fallback**: model + context % (no path, no branch)
- **Emergency**: model name only (with color)
- **Last resort**: truncate by display width (CJK/emoji safe) — `visible_len`-driven loop removes one character at a time until output fits

## try_build / try_len Functions

The `try_build(m, p, b, c, show_rate, show_vim, show_dur, show_session)` function assembles a candidate string with optional element flags:

- `show_rate=1`: include rate limits zone
- `show_vim=1`: include vim mode indicator
- `show_dur=1`: include duration
- `show_session=1`: include session tokens

`try_len` computes the visible length using pre-computed zone lengths (pure arithmetic, zero forks). Each responsive level calls `try_len` first, then checks `_TL <= term_cols`. First fit wins, calls `try_build`, exits immediately.

### Zero-fork responsive loop

All zone variant lengths are pre-computed before the responsive loop. The loop itself uses only `try_len` (pure integer arithmetic) — no `visible_len` calls inside the loop. This eliminates 6-7 forks per level × 15 levels.

### Zone 4 pre-computation

All 8 combinations of `(show_dur, show_session, show_rate)` flags are pre-computed as `_z4_*` variants with their visible lengths stored as `lz4_*`. The `try_len` function selects the correct variant using a flag-matching cascade.

## Visible Length Calculation

Exact formula for ASCII + CJK + emoji:

```
display = chars + (bytes - chars - N_4byte) / 2 - N_3byte_single_width
```

Where:
- `chars` = `${#s}` (bash string length = character count)
- `bytes` = `${#s}` under `LC_ALL=C` (byte count)
- `N_4byte` = count of UTF-8 leading bytes F0-F4 (emoji and rare CJK), each occupies 2 display columns but 4 bytes
- `N_3byte_single_width` = count of known 3-byte 1-column chars (`│▓░●…`)

The base formula `chars + (bytes - chars - N_4byte) / 2` treats all 3-byte chars as 2-column CJK. Subtracting `N_3byte_single_width` corrects the overcount for box-drawing, block-element, and punctuation chars that are actually 1-column.

Implementation uses `LC_ALL=C` strip-rest approach for N_4byte counting (avoiding macOS `tr` which does not support `\xNN` byte range syntax). N_3byte_single_width is counted by removing each known char and measuring the difference.

This formula is exact for ASCII + CJK + emoji + common box-drawing chars. It overestimates by at most 1 column for rare 2-byte chars (Latin-1 supplement), which is safe — truncates more, not less.

## Input Schema

The script reads JSON from stdin. Key fields:

```json
{
  "model": { "id": "...", "display_name": "..." },
  "context_window": {
    "used_percentage": 67.3,
    "context_window_size": 200000,
    "current_usage": { "input_tokens": 50000, "output_tokens": 3000, ... }
  },
  "workspace": { "current_dir": "...", "project_dir": "..." },
  "worktree": { "branch": "..." },
  "cost": { "total_duration_ms": 5040000 },
  "effort": { "level": "high" },
  "thinking": { "enabled": true },
  "rate_limits": { "five_hour": { "used_percentage": 42 }, ... },
  "vim": { "mode": "NORMAL" }
}
```

All fields have fallback defaults — the script never crashes on missing or malformed input.

## Safety Guarantees

- **Zero overflow**: output never exceeds terminal width (verified across 4-200 columns)
- **Single-line invariant**: all newlines in input values are sanitized to spaces
- **printf '%s'**: color variables use actual ESC bytes (`$'\033'[0m`), not `printf "%b"` interpretable sequences
- **HOME prefix**: `$HOME/` requires trailing slash or exact match (prevents `/home/user2` false match)
