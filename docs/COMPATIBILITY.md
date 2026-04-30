# Compatibility

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | Full support | Primary development platform |
| macOS (Intel) | Full support | Same bash 3.2, same BSD utils |
| Linux (x86_64) | Expected to work | Uses POSIX-compatible commands only |
| Windows (WSL) | Expected to work | bash + jq required |
| Windows (native) | Not supported | No bash |

## Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| bash 3.2+ | Yes | Script runtime |
| jq | Yes | Parse Claude Code JSON schema |
| git | Optional | Branch display (gracefully omitted if missing) |
| od | Yes | Exact character width calculation (BSD/coreutils) |

## macOS-Specific Notes

### `tr` Byte Range Bug

macOS `tr` does NOT support `\xNN` byte range syntax:

```bash
# BROKEN on macOS — \x80 treated as literal string
tr -d '\0-\x7F\x80-\xBF'

# WORKS — use od instead
od -A n -t x1 | tr ' ' '\n' | grep -cE '^f[0-4]'
```

This script uses the `od`-based approach exclusively.

### bash 3.2 Limitations

macOS ships bash 3.2. The script avoids:

- `mapfile` / `readarray` (bash 4+)
- `declare -A` (bash 4+)
- `${var,,}` / `${var^^}` (bash 4+)
- `seq 1 0` (counts down on macOS — guarded with conditionals)

### `stat` Format

```bash
# macOS
stat -f %m file

# Linux
stat -c %Y file
```

The script uses `stat -f %m` for git branch cache timestamps.

## Third-Party Provider Support

When using Claude Code with a third-party provider (e.g., via `ANTHROPIC_BASE_URL`):

- The `rate_limits` field is typically absent from the schema
- The script detects this and omits the rate display gracefully
- Model name shows whatever `display_name` or `id` the provider returns
- Context window shows the value from the schema (may be inaccurate for unrecognized models)

### Known Issue: Context Window Size

Claude Code defaults to 200K context window for unrecognized models. There is currently no configuration to override this while keeping auto-compaction. See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

## Character Width Accuracy

| Character Type | Width | Accuracy |
|---------------|-------|----------|
| ASCII | 1 column | Exact |
| CJK (Chinese, Japanese, Korean) | 2 columns | Exact |
| Emoji (most common) | 2 columns | Exact |
| Rare 2-byte chars (Latin-1 supplement) | 1 column | Overestimates by ≤1 (safe) |
| Combining characters | 0 columns | Not handled (rare in statusline context) |

The formula `display = chars + (bytes - chars - N_4byte) / 2` is exact for the common case. The ≤1 overestimation for rare 2-byte chars means the script truncates slightly more than needed — always safe, never overflows.

## Performance

Measured on Apple Silicon (M-series):

| Metric | Value |
|--------|-------|
| Execution time | ~3-4ms |
| Memory | Negligible (sub-MB) |
| CPU per refresh | < 0.1% |
| Git branch cache hit | ~0.1ms |

The 5-second refresh interval means the script runs 12 times per minute. At 3-4ms per run, total CPU time is ~0.05% of one core.

## Troubleshooting

### Statusline not showing

1. Check `settings.json` has the `statusLine` config
2. Check the script is executable: `chmod +x ~/.claude/statusline-command.sh`
3. Run manually: `echo '{}' | bash ~/.claude/statusline-command.sh`
4. Restart Claude Code

### Garbled characters

- Ensure your terminal supports UTF-8
- Try a different terminal (iTerm2, Alacritty, Kitty recommended)
- Check `locale` output includes `UTF-8`

### Branch not showing

- Ensure `git` is installed and the directory is a git repo
- Check git branch cache: `ls /tmp/.claude-git-branch-*`

### Wrong character alignment

- This typically means a character width mismatch
- The script handles ASCII + CJK + emoji; combining characters are not supported
- File an issue with the specific character that causes misalignment
