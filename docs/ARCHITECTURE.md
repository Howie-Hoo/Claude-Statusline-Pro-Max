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
- Thinking indicator: green `●` when extended thinking is enabled
- Effort level: `l`/`m`/`h`/`x`/`M` suffix
- Agent name: `@agent` prefix (truncated to 8 chars)
- Three truncation levels: full name → mid (12 chars) → short (6 chars)

### Zone 2 — Context

- 10-cell progress bar `▓░` with color thresholds:
  - Green: 0-69%
  - Yellow: 70-85%
  - Red: 86-100%+
- Token counts formatted as `12.4k/200k`
- Bar clamped to [0,100] for display; percentage shows real value (can exceed 100%)
- Three truncation levels: bar+%+tokens → %+tokens → % only

### Zone 3 — Workspace

- Path derived from `project_dir` (official Claude Code field), not raw `cwd`
- Project name + relative path when inside a project
- Git branch: schema fields first (`wt_branch`, `git_worktree`, `worktree_name`), then `git` command with 5s cache
- Branch gets `│` prefix when path is empty (visual distinction from context zone)
- Vim mode indicator: `[N]`/`[I]`/`[V]`/`[V-L]`

### Zone 4 — Duration

- Compound format: `1h24m`, `2d3h`, `45s` (sub-second suppressed)
- Rate limits: `5h:42% 7d:15%` with color thresholds (same as context)
- Rate limits gracefully omitted for third-party providers (no `rate_limits` field)

## Responsive Levels

12 levels (L0-L11) + fallback + emergency + last-resort:

### Core truncation (L0-L7)

Progressive truncation of model name, path, branch, and context detail:

| Level | Model | Path | Branch | Context | Optional |
|-------|-------|------|--------|---------|----------|
| L0 | full | full | full | bar+%+tok | all |
| L1 | full | mid | full | bar+%+tok | all |
| L2 | full | mid | full | %+tok | all |
| L3 | full | short | full | %+tok | all |
| L4 | mid | short | full | %+tok | all |
| L5 | mid | short | short | %+tok | all |
| L6 | short | short | short | %+tok | all |
| L7 | short | short | short | % only | all |

### Optional element removal (L8-L11)

Drop optional elements by priority (least critical first):

| Level | Rate | Vim | Duration | Path |
|-------|------|-----|----------|------|
| L8 | removed | kept | kept | kept |
| L9 | removed | removed | kept | kept |
| L10 | removed | removed | removed | kept |
| L11 | removed | removed | removed | removed |

### Emergency levels

- **Fallback**: model + context % (no path, no branch)
- **Emergency**: model name only
- **Last resort**: first N chars of model name (no color, no ellipsis)

## try_build Function

The `try_build(m, p, b, c, show_rate, show_vim, show_dur)` function assembles a candidate string with optional element flags:

- `show_rate=1`: include rate limits zone
- `show_vim=1`: include vim mode indicator
- `show_dur=1`: include duration zone

Each responsive level calls `try_build` with different parameters, then checks `visible_len(candidate) <= term_cols`. First fit wins, exits immediately.

## Visible Length Calculation

Exact formula for ASCII + CJK + emoji on macOS:

```
display = chars + (bytes - chars - N_4byte) / 2
```

Where:
- `chars` = `${#s}` (bash string length = character count)
- `bytes` = `wc -c` output (byte count)
- `N_4byte` = count of UTF-8 leading bytes F0-F4 (emoji and rare CJK)

Implementation uses `od -A n -t x1` to count 4-byte leading bytes, avoiding macOS `tr` which does not support `\xNN` byte range syntax.

This formula is exact for ASCII + CJK + emoji. It overestimates by at most 1 column for rare 2-byte chars (Latin-1 supplement), which is safe — truncates more, not less.

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