# 兼容性

## 平台支持

| 平台 | 状态 | 备注 |
|------|------|------|
| macOS (Apple Silicon) | 完全支持 | 主要开发平台 |
| macOS (Intel) | 完全支持 | 相同 bash 3.2，相同 BSD 工具 |
| Linux (x86_64) | 预期可用 | 仅使用 POSIX 兼容命令 |
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

# 正确做法 — 使用 od
od -A n -t x1 | tr ' ' '\n' | grep -cE '^f[0-4]'
```

本脚本仅使用基于 `od` 的方法。

### bash 3.2 限制

macOS 自带 bash 3.2。本脚本避免使用：

- `mapfile` / `readarray`（bash 4+）
- `declare -A`（bash 4+）
- `${var,,}` / `${var^^}`（bash 4+）
- `seq 1 0`（macOS 上会倒序输出 — 已用条件守卫）

### `stat` 格式

```bash
# macOS
stat -f %m file

# Linux
stat -c %Y file
```

脚本使用 `stat -f %m` 获取 git 分支缓存时间戳。

## 第三方 Provider 支持

使用 Claude Code 连接第三方 Provider 时（如通过 `ANTHROPIC_BASE_URL`）：

- Schema 中通常没有 `rate_limits` 字段
- 脚本检测到后优雅省略速率显示
- 模型名显示 Provider 返回的 `display_name` 或 `id`
- 上下文窗口显示 schema 中的值（对未识别模型可能不准确）

### 已知问题：上下文窗口大小

Claude Code 对未识别模型默认使用 200K 上下文窗口。目前没有配置项能在保留自动压缩的同时覆盖此值。详见[架构文档](ARCHITECTURE.md)。

## 字符宽度精度

| 字符类型 | 宽度 | 精度 |
|----------|------|------|
| ASCII | 1 列 | 精确 |
| CJK（中文、日文、韩文） | 2 列 | 精确 |
| Emoji（常见） | 2 列 | 精确 |
| 罕见 2 字节字符（Latin-1 补充） | 1 列 | 最多高估 1（安全） |
| 组合字符 | 0 列 | 未处理（状态栏场景中罕见） |

公式 `display = chars + (bytes - chars - N_4byte) / 2` 对常见情况精确。罕见 2 字节字符的 ≤1 高估意味着脚本截断略多于需要——始终安全，不会溢出。

## 性能

Apple Silicon (M 系列) 上的测量值：

| 指标 | 值 |
|------|-----|
| 执行时间 | ~3-4ms |
| 内存 | 可忽略（< 1MB） |
| 每次刷新 CPU | < 0.1% |
| Git 分支缓存命中 | ~0.1ms |

5 秒刷新间隔意味着脚本每分钟运行 12 次。每次 3-4ms，总 CPU 时间约占一个核心的 0.05%。

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
- 脚本处理 ASCII + CJK + emoji；不支持组合字符
- 如遇特定字符导致错位，请提交 issue
