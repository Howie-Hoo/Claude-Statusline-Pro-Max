# Changelog

All notable changes to Claude-Statusline-Pro-Max are documented here.

## v1.2.0 — 2026-06-01

Remove session tokens display (redundant with Zone 2 context info).

### Breaking Changes

- **Session tokens removed from Zone 4**: The `total_input_tokens`/`total_output_tokens` fields from Claude Code v2.1.132+ now reflect current context usage (not cumulative session totals), making them redundant with Zone 2's token counts. Removed to eliminate duplicate information.

### Architecture

- **Zone 4 simplified**: Duration + rate limits only (was duration + session tokens + rate limits)
- **Zone 4 variants reduced**: 4 flag combinations (was 8)
- **Responsive levels reduced**: 12 levels + 2 fallbacks (was 15 + 2)
- **try_build/try_len signature**: 7 parameters (was 8, removed `show_session`)
- **Optional element removal order**: rate limits → vim → duration → path (was rate limits → vim → session tokens → duration → path)

### Code Changes

- Removed `total_input`/`total_output` from jq parsing and default variable initialization
- Removed `session_tok`/`session_str` calculation and display logic
- Removed `_z4_no_rate`, `_z4_session_only`, `_z4_session_rate`, `_z4_empty` Zone 4 variants
- Renumbered responsive levels L10→L10, L11→L10, L12→L11 (removed old L10 "drop session tokens")
- Updated CLAUDE.md architecture documentation

## v1.1.0 — 2026-05-02

Incremental improvements: TIER signal quality, responsive coverage gaps, CJK/emoji safety, and bug fixes.

### Architecture

- **TIER signal quality system**: Context display adapts to available signal strength
  - TIER 1: full fidelity — progress bar + percentage + token counts
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
