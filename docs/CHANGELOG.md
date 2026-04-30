# Changelog

All notable changes to Claude-Statusline-Pro-Max.

## [1.0.0] - 2025-04-30

### Added

- 12-level responsive layout (L0-L11) with fallback + emergency + last-resort
- 4-zone layout: Model, Context, Workspace, Duration
- Exact CJK/emoji display width calculation via `od`-based formula
- Third-party provider support (graceful handling of missing `rate_limits`)
- 5-second git branch cache with `stat -f %m` timestamps
- Compound duration format (`1h24m`, `2d3h`)
- Context bar with 3-tier color thresholds (green/yellow/red)
- Vim mode indicator (`[N]`/`[I]`/`[V]`/`[V-L]`)
- Thinking indicator, effort level, agent name marks
- `try_build` function with `show_rate`/`show_vim`/`show_dur` flags
- Branch `│` prefix when path is empty (visual distinction)
- macOS bash 3.2 compatibility (no bash 4+ features)
- Zero-overflow guarantee across all terminal widths (542 test cases)
