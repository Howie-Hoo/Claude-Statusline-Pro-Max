# Contributing

Contributions are welcome! Here's how to help.

## Bug Reports

Open an [issue](https://github.com/Howie-Hoo/Claude-Statusline-Pro-Max/issues) with:

1. Your platform (macOS/Linux, terminal app)
2. Terminal width when the bug occurs
3. Expected vs actual output
4. Screenshot if possible

## Pull Requests

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Test across terminal widths (80, 120, 160, 200+)
4. Test with CJK characters and emoji in paths
5. Verify no overflow: `echo '{"model":{"id":"test"}}' | bash statusline-command.sh`
6. Submit PR with description of changes

## Development

### Testing

```bash
# Basic smoke test
echo '{}' | bash statusline-command.sh

# With model info
echo '{"model":{"id":"claude-opus-4-7","display_name":"Opus 4.7"}}' | bash statusline-command.sh

# With context
echo '{"context_window":{"used_percentage":67.3,"context_window_size":200000}}' | bash statusline-command.sh

# Full schema
cat test/fixtures/full.json | bash statusline-command.sh
```

### Key Constraints

- **bash 3.2 only** — no bash 4+ features
- **macOS `tr` bug** — never use `\xNN` byte ranges in `tr`
- **No external dependencies** beyond `jq` and standard Unix tools
- **Zero overflow** — output must never exceed terminal width

## Style

- Follow existing code style in `statusline-command.sh`
- Keep the script self-contained (single file)
- Comments only for non-obvious WHY, not WHAT
