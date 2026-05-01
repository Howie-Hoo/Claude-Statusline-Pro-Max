# 架构

## 概述

状态栏通过 stdin 读取 Claude Code 的 JSON schema，用 `jq` 提取字段，纯 bash 算术渲染响应式布局。

```
stdin (JSON) → jq 解析 → 区域计算 → 响应式组装 → stdout
```

## 区域布局

四个区域从左到右排列，用 `│` 分隔：

```
区域 1: 模型    │  区域 2: 上下文  │  区域 3: 工作区  │  区域 4: 时长
```

### 区域 1 — 模型

- 模型名称带颜色编码（Opus=品红, Sonnet=蓝, Haiku=青, 其他=绿）
- 思考指示器：扩展思考启用时显示 `●`
- 努力等级：`⬆`/`⬆⬆`/`⬆⬆⬆` 标记（high/xhigh/max）
- 代理指示器：代理活跃时显示 `●` 前缀
- **家族保留截断**：提取家族关键词 + 版本链，跳过 "claude" 前缀和日期戳
  - `claude-opus-4-7` → 中等: `opus-4-7`, 短名: `opus`
  - `claude-3-5-sonnet-20241022` → 中等: `3-5-sonnet`, 短名: `sonnet`
  - `claude-haiku-4-5-20251001` → 中等: `haiku-4-5`, 短名: `haiku`

### 区域 2 — 上下文

**TIER 信号质量系统** — 显示精度随可用数据自动调整，永不显示误导性信息：

| TIER | 信号 | 显示 |
|------|------|------|
| 1 | 完整 token 分解可用（`current_usage` 非零） | 条 + % + input/output/cache token |
| 2 | 百分比已知，无 token 分解 | 条 + % + 上下文大小 |
| 3 | 仅上下文大小已知 | "ctx 200.0k" |
| 0 | 无上下文数据 | "n/a" |

原理：`total_input_tokens`/`total_output_tokens` 是整个会话（包括压缩轮次）的累计值。它们总是高估当前上下文占用，且高估量随会话长度增长。将它们显示为百分比或进度条是误导性的。当没有真实信号时，仅显示上下文大小是诚实且稳定的。

- 10 格进度条 `▓░`，带颜色阈值：
  - 绿色：0-69%
  - 黄色：70-85%
  - 红色：86-100%+
- 进度条显示值 clamp 到 [0,100]；百分比显示真实值（可超过 100%）
- 三级截断：条+%+token → %+token → 仅 %

### 区域 3 — 工作区

- 路径取自 `project_dir`（Claude Code 官方字段），非原始 `cwd`
- 在项目内时显示项目名 + 相对路径
- `path_mid` 截断：项目名上限 20 字符（与根目录情况一致）
- Git 分支：优先用 schema 字段（`wt_branch`、`git_worktree`、`worktree_name`），回退到 `git` 命令 + 5 秒缓存
- 路径为空时分支加 `│` 前缀（视觉区分）
- Vim 模式指示器：`🔄` INSERT，`👁` VISUAL

### 区域 4 — 时长

- 复合格式：`1h24m`、`2d3h`、`45s`（亚秒级不显示）
- 会话 token：整个会话的累计 input + output（次要统计）
- 速率限制：`5h:42% 7d:15%`，带颜色阈值：
  - 绿色：≤59%
  - 黄色：60-84%
  - 红色：≥85%
- 第三方 Provider 无 `rate_limits` 字段时优雅省略

## 响应级别

15 级（L0-L7 + L2a/L2b/L3a + L8-L12）+ 回退 + 紧急 + 最后手段：

### 核心截断（L0-L7）

渐进截断模型名、路径、分支和上下文详情：

| 级别 | 模型 | 路径 | 分支 | 上下文 | 可选元素 |
|------|------|------|------|--------|----------|
| L0 | 全名 | 完整 | 完整 | 条+%+token | 全部 |
| L1 | 全名 | 中等 | 完整 | 条+%+token | 全部 |
| L2 | 全名 | 中等 | 完整 | %+token | 全部 |
| L2a | 全名 | 中等 | 完整 | 仅 % | 全部 |
| L2b | 全名 | 中等 | 短名 | 仅 % | 全部 |
| L3 | 全名 | 短名 | 完整 | %+token | 全部 |
| L3a | 全名 | 短名 | 短名 | %+token | 全部 |
| L4 | 中等 | 短名 | 完整 | %+token | 全部 |
| L5 | 中等 | 短名 | 短名 | %+token | 全部 |
| L6 | 短名 | 短名 | 短名 | %+token | 全部 |
| L7 | 短名 | 短名 | 短名 | 仅 % | 全部 |

L2a/L2b/L3a 用于填补 L2 和 L3 之间 64 字符的覆盖间隙，避免 80-100 列终端的空间浪费。

### 可选元素移除（L8-L12）

按优先级移除可选元素（最不关键优先）：

| 级别 | 速率 | Vim | 会话 token | 时长 | 路径 |
|------|------|-----|-----------|------|------|
| L8 | 移除 | 保留 | 保留 | 保留 | 保留 |
| L9 | 移除 | 移除 | 保留 | 保留 | 保留 |
| L10 | 移除 | 移除 | 移除 | 保留 | 保留 |
| L11 | 移除 | 移除 | 移除 | 移除 | 保留 |
| L12 | 移除 | 移除 | 移除 | 移除 | 移除 |

### 紧急级别

- **回退**：模型 + 上下文 %（无路径、无分支）
- **紧急**：仅模型名（带颜色）
- **最后手段**：按显示宽度截断（CJK/emoji 安全）— `visible_len` 驱动的循环逐字符移除直到输出适配

## try_build / try_len 函数

`try_build(m, p, b, c, show_rate, show_vim, show_dur, show_session)` 函数用可选元素标志组装候选字符串：

- `show_rate=1`：包含速率限制区域
- `show_vim=1`：包含 Vim 模式指示器
- `show_dur=1`：包含时长
- `show_session=1`：包含会话 token

`try_len` 使用预计算的区域长度计算可见长度（纯算术，零 fork）。每个响应级别先调用 `try_len`，然后检查 `_TL <= term_cols`。第一个符合的即调用 `try_build` 并立即退出。

### 零 fork 响应式循环

所有区域变体长度在循环前预计算。循环本身仅使用 `try_len`（纯整数算术）— 循环内无 `visible_len` 调用。这消除了每级 6-7 次 fork × 15 级的开销。

### Zone 4 预计算

`(show_dur, show_session, show_rate)` 标志的所有 8 种组合预计算为 `_z4_*` 变体，其可见长度存储为 `lz4_*`。`try_len` 函数通过标志匹配级联选择正确的变体。

## 可见长度计算

ASCII + CJK + emoji 的精确公式：

```
display = chars + (bytes - chars - N_4byte) / 2 - N_3byte_single_width
```

其中：
- `chars` = `${#s}`（bash 字符串长度 = 字符数）
- `bytes` = `LC_ALL=C` 下 `${#s}`（字节数）
- `N_4byte` = UTF-8 前导字节 F0-F4 的数量（emoji 和罕见 CJK），每个占 2 显示列但 4 字节
- `N_3byte_single_width` = 已知 3 字节 1 列字符的数量（`│▓░●…`）

基础公式 `chars + (bytes - chars - N_4byte) / 2` 将所有 3 字节字符视为 2 列 CJK。减去 `N_3byte_single_width` 修正了实际上是 1 列的制表符、方块元素和标点字符的过度计算。

N_4byte 使用 `LC_ALL=C` 剥离剩余法计数（避免 macOS `tr` 不支持 `\xNN` 字节范围语法的问题）。N_3byte_single_width 通过移除每个已知字符并测量差值来计数。

此公式对 ASCII + CJK + emoji + 常见制表符精确。对罕见 2 字节字符（Latin-1 补充）最多高估 1 列，这是安全的——截断更多而非更少。

## 输入 Schema

脚本从 stdin 读取 JSON。关键字段：

```json
{
  "model": { "id": "...", "display_name": "..." },
  "context_window": {
    "used_percentage": 67.3,
    "context_window_size": 200000,
    "current_usage": { "input_tokens": 50000, "output_tokens": 3000, ... }
  },
  "workspace": { "current_dir": "...", "project_dir": "..." },
  "worktree": { "branch": "..." },
  "cost": { "total_duration_ms": 5040000 },
  "effort": { "level": "high" },
  "thinking": { "enabled": true },
  "rate_limits": { "five_hour": { "used_percentage": 42 }, ... },
  "vim": { "mode": "NORMAL" }
}
```

所有字段都有回退默认值——脚本不会因缺失或格式错误的输入而崩溃。

## 安全保证

- **零溢出**：输出永远不会超过终端宽度（4-200 列全测试验证）
- **单行不变量**：输入值中的所有换行符都被替换为空格
- **printf '%s'**：颜色变量使用实际 ESC 字节（`$'\033'[0m`），非 `printf "%b"` 可解释序列
- **HOME 前缀**：`$HOME/` 要求尾部斜杠或精确匹配（防止 `/home/user2` 误匹配）
