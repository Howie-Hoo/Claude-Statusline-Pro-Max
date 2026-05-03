# Customization

## Colors

All colors are defined at the top of `statusline-command.sh` using actual ESC bytes:

```bash
RST=$'\033'[0m;  BOLD=$'\033'[1m;  DIM=$'\033'[2m
RED=$'\033'[31m; GRN=$'\033'[32m; YLW=$'\033'[33m
BLU=$'\033'[34m; MGN=$'\033'[35m; CYN=$'\033'[36m; GRY=$'\033'[90m
```

Note: Color variables use `$'\033'[...m` syntax (actual ESC bytes), not `'\033[...m'` strings. This ensures `printf '%s'` works correctly without backslash interpretation.

### Model Color Mapping

```bash
# In the model section, colors are assigned by model family:
Opus   → MGN (magenta)
Sonnet → BLU (blue)
Haiku  → CYN (cyan)
Other  → GRN (green)
```

To change a model color, find the `case` block in the model section and change the color variable.

### Context Bar Thresholds

```bash
# Green:  0-69%
# Yellow: 70-85%
# Red:    86%+
```

Adjust the threshold values in the context bar rendering section:

```bash
if [ "$pct_int" -gt 85 ]; then
  ctx_color=$RED
elif [ "$pct_int" -gt 69 ]; then
  ctx_color=$YLW
else
  ctx_color=$GRN
fi
```

### Rate Limit Thresholds

```bash
# Green:  ≤59%
# Yellow: 60-84%
# Red:    ≥85%
```

Adjust in the rate section:

```bash
if [ "$r5h_int" -gt 84 ]; then r5h_color=$RED
elif [ "$r5h_int" -gt 59 ]; then r5h_color=$YLW
else r5h_color=$GRN
fi
```

## Marks

| Mark | Meaning | Variable |
|------|---------|----------|
| `●` | Thinking enabled | `think_mark` |
| `@name` | Agent active (first 8 chars) | `agent_mark` |
| `h` | Effort: high | `effort_mark` |
| `x` | Effort: xhigh | `effort_mark` |
| `M` | Effort: max | `effort_mark` |
| `[N]` | Vim: NORMAL | `vim_mark` |
| `[I]` | Vim: INSERT | `vim_mark` |
| `[V]` | Vim: VISUAL | `vim_mark` |
| `[V-L]` | Vim: VISUAL LINE | `vim_mark` |
| `│` | Zone separator | `sep` |
| `▓` | Bar filled cell | — |
| `░` | Bar empty cell | — |

To change a mark, search for it in the script and replace.

## Responsive Level Thresholds

The script uses `try_build`/`try_len` with different parameter combinations. Each level is tried in order from most information (L0) to least (last-resort).

To adjust which elements appear at which width:

1. Find the responsive level section (search for `L0` through `L12`)
2. Modify the `try_build`/`try_len` call parameters:
   - `show_rate=1/0` — show/hide rate limits
   - `show_vim=1/0` — show/hide vim mode
   - `show_dur=1/0` — show/hide duration
   - `show_session=1/0` — show/hide session tokens
3. Reorder levels by moving `try_build`/`try_len` call pairs

### Adding a New Element

1. Compute the element's string in the data extraction section
2. Add a `show_xxx` flag parameter to `try_build` and `try_len`
3. Add the element to the `try_build` assembly logic
4. Add length computation to `try_len`
5. Pre-compute all Zone 4 flag combinations
6. Create responsive levels that include/exclude the element
7. Test across all terminal widths (4-200 columns)

## Git Branch Cache

Branch is cached for 5 seconds at `/tmp/.claude-git-branch-$(md5_of_cwd)`:

```bash
# To change cache duration, modify:
if [ $(( now - cache_time )) -gt 5 ]; then
```

Change `5` to your preferred seconds. Set to `0` to disable caching.

## Refresh Interval

Configured in `settings.json`, not in the script:

```json
{
  "statusLine": {
    "refreshInterval": 5
  }
}
```

Lower values = more responsive but more CPU. 3-5 seconds is recommended.

## Path Display

The script uses `project_dir` from the Claude Code schema (not raw `cwd`). When inside a project, it shows the project name + relative path.

- `path_mid` truncation: project name capped at 20 chars
- `path_short` truncation: project name capped at 15 chars
- HOME prefix requires trailing slash or exact match (prevents false matches)

To force showing the full path instead:

```bash
# Find the path computation section and change:
# From: relative path logic
# To:   p="$cwd"
```

## Duration Format

Compound format by default: `1h24m`, `2d3h`, `45s`.

Session tokens are displayed as a secondary stat in Zone 4 alongside duration, formatted with `fmt_tok` (e.g., `80.0k`).

## Context TIER System

The context zone adapts to signal quality. To change TIER behavior:

1. Find the `ctx_tier` computation section
2. Adjust the conditions for each TIER
3. Modify the display format for each TIER's `ctx_full`/`ctx_mid`/`ctx_short`
