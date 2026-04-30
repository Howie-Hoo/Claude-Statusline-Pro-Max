# Claude-Statusline-Pro-Max

A responsive, information-dense statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

<p align="center">
<img width="800" alt="statusline preview" src="docs/preview.svg" />
</p>

## What It Shows

| Zone | Content | Example |
|------|---------|---------|
| Model | Name + thinking/effort/agent marks | `Opus 4.7 ✦ ⚡ 🤖` |
| Path | Working directory (truncated) | `~/projects/app` |
| Branch | Git branch with cache | `main` |
| Context | Usage bar + percentage | `▓▓▓▓░░ 67%` |
| Rate | Token rate (when available) | `42t/s` |
| Vim | Vim mode indicator | `NORMAL` |
| Duration | Session duration | `1h24m` |

## Key Features

- **12-level responsive layout** — gracefully adapts from wide terminals to narrow panes
- **Exact CJK/emoji width** — `od`-based formula handles Chinese, Japanese, Korean, and emoji correctly
- **Third-party provider support** — works with custom model endpoints (no `rate_limits` field? no problem)
- **5s git branch cache** — avoids forking `git` on every refresh
- **Compound duration** — `1h24m`, `2d3h`, not `84m` or `5040s`
- **Zero dependencies** — pure bash, only `jq` for Claude Code schema parsing

## Quick Start

```bash
# Clone
git clone https://github.com/Howie-Hoo/Claude-Statusline-Pro-Max.git
cd Claude-Statusline-Pro-Max

# Install
bash install.sh

# Or install with auto-config
bash install.sh --write-config

# Restart Claude Code
```

### Manual Install

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
```

## Documentation

| Document | Content |
|----------|---------|
| [Architecture](docs/ARCHITECTURE.md) | Zone layout, responsive levels, width calculation |
| [Customization](docs/CUSTOMIZATION.md) | Colors, symbols, thresholds, adding new elements |
| [Compatibility](docs/COMPATIBILITY.md) | Platform notes, known issues, third-party providers |
| [Changelog](docs/CHANGELOG.md) | Version history |

## Requirements

- Claude Code CLI
- bash 3.2+ (macOS default)
- `jq` (for parsing Claude Code schema)
- Git (optional, for branch display)

## Performance

~3-4ms per refresh on Apple Silicon. No perceptible lag at 5s interval.

## License

[MIT](LICENSE)
