# Claude Statusline Pro Max

[中文文档](README.zh-CN.md)

A responsive, information-dense statusline for [Claude Code](https://claude.ai/code) CLI. Pure bash script — zero dependencies beyond `jq`.

![preview](docs/preview.svg)

## Features

- **4-zone layout**: Model | Context | Workspace | Duration — adapts to any terminal width
- **TIER signal quality**: Context display fidelity adapts to available data
- **Family-preserving model names**: `opus-4-7`, `3-5-sonnet`, `haiku-4-5` — never lose identity
- **CJK & emoji safe**: Display-width-aware truncation at every level, including emergency fallback
- **Zero overflow guarantee**: 15 responsive levels + fallbacks, tested across 4–200 columns
- **~44ms per refresh**: Zero-fork responsive loop with pre-computed zone lengths

## Quick Start

```bash
# Install
cp statusline-command.sh ~/.claude/statusline-command.sh

# Add to ~/.claude/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
```

## The 4 Zones

```
Opus 4.8 ◉ ◆ ⚡ │ ▓▓▓▓▓▓░░░░ 67% 130.0k/200.0k │ my-app/src/components main #42 │ 1h24m +123 -45 5h:35% 7d:12%
└───── Model ─────┘ └──────── Context ───────────┘ └────── Workspace ─────────┘ └────── Duration ───────┘
```

| Zone | Content | Color Logic |
|------|---------|-------------|
| **Model** | Name + thinking/effort/fast/remote/agent marks | Opus=magenta, Sonnet=blue, Haiku=cyan |
| **Context** | Progress bar + % + token counts | Green <70%, Yellow 70-85%, Red >85% |
| **Workspace** | Project + relative path + git branch + vim + PR | — |
| **Duration** | Elapsed time + lines changed + rate limits | Rate: Green ≤59%, Yellow 60-84%, Red ≥85% |

## Context TIER System

The context zone adapts to signal quality — never shows misleading data:

| TIER | Signal | Display |
|------|--------|---------|
| 1 | Full token breakdown available | Bar + % + used/total tokens |
| 2 | Percentage known, no token breakdown | Bar + % + context size |
| 3 | Only context size known | "ctx 200.0k" |
| 0 | No context data | "n/a" |

## Responsive Behavior

At narrow terminals, content truncates progressively:

1. Rate limits drop first
2. Then vim mode, duration
3. Then path shortens (full → mid → short)
4. Then context simplifies (full → mid → short)
5. Then model name shortens (full → mid → short/family)
6. Emergency: model family keyword only

## Marks

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
| @name | Agent active (first 8 chars) | Zone 1 |
| #N | PR number | Zone 3 |
| [N] | Vim: NORMAL | Zone 3 |
| [I] | Vim: INSERT | Zone 3 |
| [V] | Vim: VISUAL | Zone 3 |
| [V-L] | Vim: VISUAL LINE | Zone 3 |
| +N/-N | Lines added/removed | Zone 4 |

## Configuration

All configuration is via `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
```

`refreshInterval` controls how often the statusline updates (in seconds). Recommended: 3–5.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — Internal design and data flow
- [Customization](docs/CUSTOMIZATION.md) — Theming and visual tweaks
- [Compatibility](docs/COMPATIBILITY.md) — Platform and terminal support
- [Changelog](docs/CHANGELOG.md) — Release history

## Requirements

- Bash 3.2+ (macOS default)
- `jq` (JSON parsing)
- Standard Unix tools (`git`, `stat`, `sed`, `grep`)

## License

MIT
