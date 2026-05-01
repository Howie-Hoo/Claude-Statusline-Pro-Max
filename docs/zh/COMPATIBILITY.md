# 兼容性

## 平台支持

| 平台 | 状态 | 备注 |
|------|------|------|
| macOS (Apple Silicon) | 完全支持 | 主要开发平台 |
| macOS (Intel) | 完全支持 | 相同 bash 3.2，相同 BSD 工具 |
| Linux (x86_64) | 完全支持 | 跨平台 `stat` 回退 |
| Windows (WSL) | 预期可用 | 需要 bash + jq |
| Windows (原生) | 不支持 | 无 bash |

## 依赖

| 依赖 | 是否必需 | 用途 |
|------|----------|------|
| bash 3.2+ | 是 | 脚本运行时 |
| jq | 是 | 解析 Claude Code JSON schema |
| git | 可选 | 分支显示（缺失时优雅省略） |
| od | 是 | 精确字符宽度计算（BSD/coreutils） |

## macOS 特殊说明

### `tr` 字节范围 Bug

macOS `tr` 不支持 `\xNN` 字节范围语法：

```bash
# macOS 上会出错 — \x80 被当作字面字符串
tr -d '\0-\x7F\x80-\xBF'

# 正确做法 — 使用 LC_ALL=C 剥离剩余法
_old_lc="$LC_ALL"; LC_ALL=C
_only_n4="${s//[^$'\xf0'$'\xf1'$'\xf2'$'\xf3'$'\xf4']/}"
n4=${#_only_n4}
LC_ALL="$_old_lc"
```

本脚本仅使用 `LC_ALL=C` 剥离剩余法。

### bash 3.2 限制

macOS 自带 bash 3.2。本脚本避免使用：

- `mapfile` / `readarray`（bash 4+）
- `declare -A`（bash 4+）
- `${var,,}` / `${var^^}`（bash 4+）
- `seq 1 0`（macOS 上会倒序输出 — 已用条件守卫）

### `stat` 格式

跨平台支持带回退：

```bash
# macOS
stat -f %m file

# Linux
stat -c %Y file
```

脚本先尝试 `stat -f %m`，回退到 `stat -c %Y`：

```bash
mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
```

## 第三方 Provider 支持

使用 Claude Code 连接第三方 Provider 时（如通过 `ANTHROPIC_BASE_URL`）：

- Schema 中通常没有 `rate_limits` 字段
- 脚本检测到后优雅省略速率显示
- 模型名显示 Provider 返回的 `display_name` 或 `id`
- 上下文窗口显示 schema 中的值（对未识别模型可能不准确）
- TIER 系统优雅降级：无 `current_usage` token 时降为 TIER 2 或 3

### 已知问题：上下文窗口大小

Claude Code 对未识别模型默认使用 200K 上下文窗口。目前没有配置项能在保留自动压缩的同时覆盖此值。详见[架构文档](ARCHITECTURE.md)。

## 字符宽度精度

| 字符类型 | 宽度 | 精度 |
|----------|------|------|
| ASCII | 1 列 | 精确 |
| CJK（中文、日文、韩文） | 2 列 | 精确 |
| Emoji（常见） | 2 列 | 精确 |
| 制表符/方块元素（`│▓░●…`） | 1 列 | 精确（N_3byte_single_width 修正） |
| 罕见 2 字节字符（Latin-1 补充） | 1 列 | 最多高估 1（安全） |
| 组合字符 | 0 列 | 未处理（状态栏场景中罕见） |

公式 `display = chars + (bytes - chars - N_4byte) / 2 - N_3byte_single_width` 对常见情况精确。罕见 2 字节字符的 ≤1 高估意味着脚本截断略多于需要——始终安全，不会溢出。

## 性能

Apple Silicon (M 系列) 上的测量值：

| 指标 | 值 |
|------|-----|
| 平均执行时间 | ~44ms |
| P95 执行时间 | ~53ms |
| 内存 | 可忽略（< 1MB） |
| 每次刷新 CPU | < 0.1% |
| Git 分支缓存命中 | ~0.1ms |

5 秒刷新间隔意味着脚本每分钟运行 12 次。每次 ~44ms，总 CPU 时间约占一个核心的 0.5%。

### 性能优化

- **零 fork 响应式循环**：所有区域变体长度在循环前预计算；`try_len` 是纯整数算术
- **全局变量模式**：`visible_len` → `_VL`，`fmt_tok` → `_FT`，`try_len` → `_TL` — 避免子 shell 开销
- **Zone 4 预计算**：`(show_dur, show_session, show_rate)` 标志的所有 8 种组合预计算

## 故障排除

### 状态栏不显示

1. 检查 `settings.json` 是否有 `statusLine` 配置
2. 检查脚本是否可执行：`chmod +x ~/.claude/statusline-command.sh`
3. 手动运行：`echo '{}' | bash ~/.claude/statusline-command.sh`
4. 重启 Claude Code

### 字符乱码

- 确保终端支持 UTF-8
- 尝试不同终端（推荐 iTerm2、Alacritty、Kitty）
- 检查 `locale` 输出是否包含 `UTF-8`

### 分支不显示

- 确保 `git` 已安装且目录是 git 仓库
- 检查 git 分支缓存：`ls /tmp/.claude-git-branch-*`

### 字符对齐错误

- 通常意味着字符宽度不匹配
- 脚本处理 ASCII + CJK + emoji + 制表符；不支持组合字符
- 如遇特定字符导致错位，请提交 issue

### 窄终端溢出

- 脚本在 4-200 列范围内测试，零溢出
- 如果看到溢出，检查终端是否报告了正确的 `COLUMNS` 值
- 运行 `stty size` 验证终端尺寸
