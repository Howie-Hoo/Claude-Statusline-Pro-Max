# Customization

## Colors

All colors are defined at the top of `statusline-command.sh`:

```bash
RST='\033[0m'    BOLD='\033[1m'   DIM='\033[2m'
RED='\033[31m'   GRN='\033[32m'   YLW='\033[33m'
BLU='\033[34m'   MGN='\033[35m'   CYN='\033[36m'
GRY='\033[90m'
```

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
if (( pct_int >= 86 )); then
  bar_color=$RED
elif (( pct_int >= 70 )); then
  bar_color=$YLW
else
  bar_color=$GRN
fi
```

### Rate Limit Thresholds

Same three-tier system as context bar. Adjust in the rate section.

## Symbols

| Symbol | Meaning | Variable |
|--------|---------|----------|
| `●` | Thinking enabled | `think_mark` |
| `⚡` | Effort level | `effort_mark` |
| `🤖` | Agent mode | `agent_mark` |
| `│` | Zone separator | `sep` |
| `▓` | Bar filled cell | — |
| `░` | Bar empty cell | — |
| `[N]` | Vim normal mode | — |
| `[I]` | Vim insert mode | — |
| `[V]` | Vim visual mode | — |

To change a symbol, search for it in the script and replace. All symbols are inline, not variables (except the marks above).

## Responsive Level Thresholds

The script uses `try_build` with different parameter combinations. Each level is tried in order from most information (L0) to least (last-resort).

To adjust which elements appear at which width:

1. Find the responsive level section (search for `L0` through `L11`)
2. Modify the `try_build` call parameters:
   - `show_rate=1/0` — show/hide rate limits
   - `show_vim=1/0` — show/hide vim mode
   - `show_dur=1/0` — show/hide duration
3. Reorder levels by moving `try_build` calls

### Adding a New Element

1. Compute the element's string in the data extraction section
2. Add a `show_xxx` flag parameter to `try_build`
3. Add the element to the `try_build` assembly logic
4. Create responsive levels that include/exclude the element
5. Test across all terminal widths

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

To force showing the full path instead:

```bash
# Find the path computation section and change:
# From: relative path logic
# To:   p="$cwd"
```

## Duration Format

Compound format by default: `1h24m`, `2d3h`, `45s`.

To switch to simple format (total minutes only), modify the duration computation section.