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
- 思考指示器：扩展思考启用时显示绿色 `●`
- 努力等级：`l`/`m`/`h`/`x`/`M` 后缀
- 代理名称：`@agent` 前缀（截断到 8 字符）
- 三级截断：全名 → 中等（12 字符）→ 短名（6 字符）

### 区域 2 — 上下文

- 10 格进度条 `▓░`，带颜色阈值：
  - 绿色：0-69%
  - 黄色：70-85%
  - 红色：86-100%+
- Token 数量格式化为 `12.4k/200k`
- 进度条显示值 clamp 到 [0,100]；百分比显示真实值（可超过 100%）
- 三级截断：条+%+token → %+token → 仅 %

### 区域 3 — 工作区

- 路径取自 `project_dir`（Claude Code 官方字段），非原始 `cwd`
- 在项目内时显示项目名 + 相对路径
- Git 分支：优先用 schema 字段（`wt_branch`、`git_worktree`、`worktree_name`），回退到 `git` 命令 + 5 秒缓存
- 路径为空时分支加 `│` 前缀（视觉区分）
- Vim 模式指示器：`[N]`/`[I]`/`[V]`/`[V-L]`

### 区域 4 — 时长

- 复合格式：`1h24m`、`2d3h`、`45s`（亚秒级不显示）
- 速率限制：`5h:42% 7d:15%`，带颜色阈值（同上下文）
- 第三方 Provider 无 `rate_limits` 字段时优雅省略

## 响应级别

12 级（L0-L11）+ 回退 + 紧急 + 最后手段：

### 核心截断（L0-L7）

渐进截断模型名、路径、分支和上下文详情：

| 级别 | 模型 | 路径 | 分支 | 上下文 | 可选元素 |
|------|------|------|------|--------|----------|
| L0 | 全名 | 完整 | 完整 | 条+%+token | 全部 |
| L1 | 全名 | 中等 | 完整 | 条+%+token | 全部 |
| L2 | 全名 | 中等 | 完整 | %+token | 全部 |
| L3 | 全名 | 短名 | 完整 | %+token | 全部 |
| L4 | 中等 | 短名 | 完整 | %+token | 全部 |
| L5 | 中等 | 短名 | 短名 | %+token | 全部 |
| L6 | 短名 | 短名 | 短名 | %+token | 全部 |
| L7 | 短名 | 短名 | 短名 | 仅 % | 全部 |

### 可选元素移除（L8-L11）

按优先级移除可选元素（最不关键优先）：

| 级别 | 速率 | Vim | 时长 | 路径 |
|------|------|-----|------|------|
| L8 | 移除 | 保留 | 保留 | 保留 |
| L9 | 移除 | 移除 | 保留 | 保留 |
| L10 | 移除 | 移除 | 移除 | 保留 |
| L11 | 移除 | 移除 | 移除 | 移除 |

### 紧急级别

- **回退**：模型 + 上下文 %（无路径、无分支）
- **紧急**：仅模型名
- **最后手段**：模型名前 N 字符（无颜色、无省略号）

## try_build 函数

`try_build(m, p, b, c, show_rate, show_vim, show_dur)` 函数用可选元素标志组装候选字符串：

- `show_rate=1`：包含速率限制区域
- `show_vim=1`：包含 Vim 模式指示器
- `show_dur=1`：包含时长区域

每个响应级别用不同参数调用 `try_build`，然后检查 `visible_len(candidate) <= term_cols`。第一个符合的即返回，立即退出。

## 可见长度计算

macOS 上 ASCII + CJK + emoji 的精确公式：

```
display = chars + (bytes - chars - N_4byte) / 2
```

其中：
- `chars` = `${#s}`（bash 字符串长度 = 字符数）
- `bytes` = `wc -c` 输出（字节数）
- `N_4byte` = UTF-8 前导字节 F0-F4 的数量（emoji 和罕见 CJK）

实现使用 `od -A n -t x1` 统计 4 字节前导字节，避免 macOS `tr` 不支持 `\xNN` 字节范围语法的问题。

此公式对 ASCII + CJK + emoji 精确。对罕见 2 字节字符（Latin-1 补充）最多高估 1 列，这是安全的——截断更多而非更少。

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
