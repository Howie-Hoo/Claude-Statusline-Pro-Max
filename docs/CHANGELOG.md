# Changelog

All notable changes to Claude-Statusline-Pro-Max are documented here.

## v1.4.0 — 2026-06-09

Linux compatibility fixes and version indicator.

### Features

- **Version indicator in Zone 3**: Shows the latest git tag (release version) next to the branch name (e.g. `main v1.3.1`). Dynamically resolved via `git describe --tags --abbrev=0` with 5-second cache. Only shown when both branch and cwd are present — disappears for non-git projects or when no tags exist.

### Bug Fixes

- **`stat` command order breaks Linux branch detection**: `stat -f %m` (macOS syntax) was tried before `stat -c %Y` (Linux syntax). On Linux, `stat -f %m` succeeds but outputs filesystem metadata instead of mtime — the `||` short-circuit never fell through to the Linux fallback. Reversed to `stat -c %Y` first, making Linux the primary path. This was the root cause of branch names not displaying on Linux.
- **`mtime` value not validated**: Even with correct `stat` order, non-numeric output from unexpected `stat` behavior would crash bash arithmetic. Added `case` glob guard (zero-fork POSIX) to guarantee `mtime` is always a valid integer before arithmetic use.
- **Empty `cwd` causes spurious branch name**: When JSON input lacked a `workspace` field, `cwd` was empty. `git -C ""` silently runs in the current working directory, returning a branch name from an unrelated repo. Added `[ -n "$cwd" ]` guard so git commands only execute when cwd is non-empty.

## v1.3.1 — 2026-06-06

Linux compatibility fix for git branch cache.

### Bug Fixes

- **`md5` command not available on Linux**: Git branch cache file name used macOS-only `md5` command; now tries `md5sum` first with fallback to `md5`, using `cut -c1-32` for consistent 32-char hash output on both platforms.

## v1.3.0 — 2026-06-05

Claude Code v2.1.163 compatibility: thinking modes, new indicators, ultracode support, and expanded metrics.

### Features

- **Adaptive thinking mark**: `◉` when `thinking.type=adaptive`, `●` for legacy `enabled` mode. Forward-compatible with upcoming Claude Code API changes.
- **Ultracode effort level**: `◆` (purple bold) when `effort.level=ultracode` (xhigh + dynamic workflow orchestration).
- **Fast mode indicator**: `⚡` in Zone 1 when fast mode is active.
- **Remote session indicator**: `🌐` in Zone 1 when connected remotely.
- **PR number display**: `#123` in Zone 3 when reviewing a pull request.
- **Lines changed metrics**: `+123` (green) / `-45` (red) in Zone 4 alongside duration.
- **Context overflow detection**: Color forced to red when `exceeds_200k_tokens=true` and usage > 85%, signaling auto-compaction is disabled at a critical threshold.

### Schema

- New jq extractions: `thinking_type`, `fast_mode`, `exceeds_200k`, `lines_added`, `lines_removed`, `remote_session`, `pr_number`
- All new fields have `// false` or `// ""` fallbacks — fully backward compatible

### Architecture

- **Zone 4 variants**: 5 pre-computed flag combinations (was 4), adding `lines_only` variant
- **try_build simplified**: Zone 4 string assembly now selects from pre-computed variants instead of rebuilding
- **n3sw character list**: Extended to 8 entries for new marks (`◉◆⚠`)

### Bug Fixes

- **`_z4_dur_only` / `_z4_dur_rate` empty when duration absent**: Fixed seed logic so lines-only display works correctly at responsive levels where duration is removed
- **`_z4_lines_only` not pre-computed**: Fixed missing variant causing overflow in lines-only scenarios at narrow widths

### Marks

| Mark | Meaning | Zone |
|------|---------|------|
| ◉ | Adaptive thinking | Zone 1 |
| ● | Legacy thinking enabled | Zone 1 |
| ◆ | Ultracode (xhigh + workflow) | Zone 1 |
| x | Effort: xhigh | Zone 1 |
| h | Effort: high | Zone 1 |
| M | Effort: max | Zone 1 |
| ⚡ | Fast mode active | Zone 1 |
| 🌐 | Remote session active | Zone 1 |
| @name | Agent active | Zone 1 |
| #N | PR number | Zone 3 |
| [N]/[I]/[V]/[V-L] | Vim mode | Zone 3 |
| +N/-N | Lines added/removed | Zone 4 |

## v1.2.0 — 2026-06-01

Incremental improvements: TIER signal quality, responsive coverage gaps, CJK/emoji safety, and bug fixes.

### Architecture

- **TIER signal quality system**: Context display adapts to available signal strength
  - TIER 1: full fidelity — progress bar + percentage + used/total tokens
  - TIER 2: bar + percentage + size (no token breakdown)
  - TIER 3: size only ("ctx 200.0k")
  - TIER 0: no data ("n/a")
- **Family-preserving model name truncation**: Extracts family keyword + version chain, skips "claude" prefix and date stamps
  - `claude-opus-4-7` → mid: `opus-4-7`, short: `opus`
  - `claude-3-5-sonnet-20241022` → mid: `3-5-sonnet`, short: `sonnet`
  - `claude-haiku-4-5-20251001` → mid: `haiku-4-5`, short: `haiku`
- **15 responsive levels + 2 fallbacks + emergency** (was 12+2): Progressive truncation with no gaps
- **Zero-fork responsive loop**: Pre-computed zone lengths, pure arithmetic in hot path
- **8 Zone4 flag combinations**: All (show_dur, show_session, show_rate) permutations pre-computed

### Bug Fixes

- **Emergency fallback overflow with CJK/emoji**: Was truncating by char count; now uses `visible_len`-driven loop
- **Responsive coverage gap**: L2→L3 jumped 64 chars (103→39); added L2a/L2b/L3a intermediate levels
- **path_mid not truncating project_name**: 72-char project name went untruncated; now capped at 20 chars (consistent with root case)
- **Rate limit thresholds too aggressive**: Changed from 50/80 to 60/85 (Green ≤59%, Yellow 60-84%, Red ≥85%)
- **printf "%b" backslash interpretation**: Model names/branches/paths with `\n` could break single-line guarantee; changed to `printf '%s'` with actual ESC bytes
- **n4 counting returned 0 in UTF-8 locale**: Bash glob on whole characters never matched `\xf0`; fixed with LC_ALL=C strip-rest approach
- **HOME prefix matching**: `$HOME*` could match `/home/user2`; now requires `$HOME/` or exact match
- **Variable leak in visible_len**: `_old_lc`, `_only_n4`, `_t` leaked to global scope; now declared `local`
- **Newline injection after eval**: String values containing newlines after `jq @sh` + `eval` broke single-line invariant; added sanitization
- **stat command macOS-only**: Added Linux fallback (`stat -c %Y`)

### Performance

- Subshell elimination: `visible_len` → `_VL`, `fmt_tok` → `_FT`, `try_len` → `_TL` globals
- ~44ms average per invocation (5s refresh interval)

### Testing

- 432 test cases across 19 scenarios × 24 terminal widths
- Python ground-truth verification using `unicodedata.east_asian_width`
- CJK, emoji, and mixed content: zero overflow at all widths
- Extreme narrow terminals (4-10 cols): zero overflow

## v1.0.0 — 2026-04-29

Initial release.

- 4-zone layout: Model | Context | Workspace | Duration
- 12 responsive levels + 2 fallbacks
- Color-coded model families (Opus=magenta, Sonnet=blue, Haiku=cyan)
- Context progress bar with color thresholds at 70%/86%
- Git branch cache (5-second TTL)
- Thinking/effort/agent marks (● h/x/M)
- Vim mode indicator
- Duration compound format (1h24m)
- Rate limit display
