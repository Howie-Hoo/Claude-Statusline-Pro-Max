# 更新日志

Claude-Statusline-Pro-Max 的所有重要变更均记录于此。

## v1.3.0 — 2026-06-05

Claude Code v2.1.163 兼容：思考模式、新指示器、ultracode 支持和扩展指标。

### 新功能

- **自适应思考标记**：`thinking.type=adaptive` 时显示 `◉`，传统 `enabled` 模式显示 `●`。与即将到来的 Claude Code API 变更前向兼容。
- **Ultracode 努力等级**：`effort.level=ultracode` 时显示 `◆`（紫色粗体，xhigh + 动态工作流编排）。
- **快速模式指示器**：快速模式活跃时 Zone 1 显示 `⚡`。
- **远程会话指示器**：远程连接时 Zone 1 显示 `🌐`。
- **PR 编号显示**：审查 PR 时 Zone 3 显示 `#123`。
- **代码行变更指标**：Zone 4 显示 `+123`（绿色）/ `-45`（红色），紧随时长。
- **上下文溢出检测**：`exceeds_200k_tokens=true` 且使用率 > 85% 时强制红色，表示自动压缩在临界阈值处已禁用。

### 架构

- **Zone 4 变体**：5 个预计算标志组合（原 4 个），增加 `lines_only` 变体
- **try_build 简化**：Zone 4 字符串组装改为从预计算变体中选择
- **n3sw 字符列表**：扩展至 8 项（`◉◆⚠`）

### Bug 修复

- **`_z4_dur_only` / `_z4_dur_rate` 在无时长时为空**：修复种子逻辑，确保仅行场景在移除时长的响应级别中正确显示
- **`_z4_lines_only` 未预计算**：修复缺失变体导致的窄宽度仅行场景溢出

### 标记

| 标记 | 含义 | 区域 |
|------|------|------|
| ◉ | 自适应思考 | 区域 1 |
| ● | 传统思考已启用 | 区域 1 |
| ◆ | Ultracode（xhigh + 工作流） | 区域 1 |
| x | 努力：xhigh | 区域 1 |
| h | 努力：high | 区域 1 |
| M | 努力：max | 区域 1 |
| ⚡ | 快速模式活跃 | 区域 1 |
| 🌐 | 远程会话活跃 | 区域 1 |
| @name | 代理活跃 | 区域 1 |
| #N | PR 编号 | 区域 3 |
| [N]/[I]/[V]/[V-L] | Vim 模式 | 区域 3 |
| +N/-N | 代码行增/删 | 区域 4 |

## v1.2.0 — 2026-06-01

移除会话 token 显示（与 Zone 2 上下文信息重复）。

### 不兼容变更

- **Zone 4 移除会话 token**：Claude Code v2.1.132+ 的 `total_input_tokens`/`total_output_tokens` 字段现在反映当前上下文使用量（非会话累计值），与 Zone 2 的 token 计数重复。已移除以消除重复信息。

## v1.1.0 — 2026-05-02

增量改进：TIER 信号质量、响应式覆盖间隙、CJK/emoji 安全性和 bug 修复。

### 架构

- **TIER 信号质量系统**：上下文显示根据可用信号强度自适应
  - TIER 1：完整保真 — 进度条 + 百分比 + 已用/总量 token
  - TIER 2：条 + 百分比 + 大小（无 token 分解）
  - TIER 3：仅大小（"ctx 200.0k"）
  - TIER 0：无数据（"n/a"）
- **家族保留模型名截断**：提取家族关键词 + 版本链，跳过 "claude" 前缀和日期戳
  - `claude-opus-4-7` → 中等: `opus-4-7`, 短名: `opus`
  - `claude-3-5-sonnet-20241022` → 中等: `3-5-sonnet`, 短名: `sonnet`
  - `claude-haiku-4-5-20251001` → 中等: `haiku-4-5`, 短名: `haiku`
- **15 个响应级别 + 2 个回退 + 紧急**（原 12+2）：渐进截断，无间隙
- **零 fork 响应式循环**：预计算区域长度，热路径纯算术
- **8 种 Zone4 标志组合**：所有 (show_dur, show_session, show_rate) 排列预计算

### Bug 修复

- **紧急回退 CJK/emoji 溢出**：原按字符数截断；现使用 `visible_len` 驱动的循环
- **响应式覆盖间隙**：L2→L3 跳跃 64 字符（103→39）；新增 L2a/L2b/L3a 中间级别
- **path_mid 未截断 project_name**：72 字符项目名未被截断；现限制为 20 字符（与根目录情况一致）
- **速率限制阈值过于激进**：从 50/80 改为 60/85（绿色 ≤59%，黄色 60-84%，红色 ≥85%）
- **printf "%b" 反斜杠解释**：模型名/分支/路径中的 `\n` 可能破坏单行保证；改为 `printf '%s'` + 实际 ESC 字节
- **UTF-8 locale 下 n4 计数返回 0**：Bash glob 匹配整字符时无法匹配 `\xf0`；改用 LC_ALL=C 剥离剩余法
- **HOME 前缀匹配**：`$HOME*` 可能匹配 `/home/user2`；现要求 `$HOME/` 或精确匹配
- **visible_len 变量泄漏**：`_old_lc`、`_only_n4`、`_t` 泄漏到全局作用域；现声明为 `local`
- **eval 后换行注入**：`jq @sh` + `eval` 后包含换行的字符串值破坏单行不变量；添加清理
- **stat 命令仅支持 macOS**：添加 Linux 回退（`stat -c %Y`）

### 性能

- 子 shell 消除：`visible_len` → `_VL`，`fmt_tok` → `_FT`，`try_len` → `_TL` 全局变量
- 平均每次调用 ~44ms（5 秒刷新间隔）

### 测试

- 19 个场景 × 24 种终端宽度，共 432 个测试用例
- 使用 `unicodedata.east_asian_width` 的 Python 真值验证
- CJK、emoji 和混合内容：所有宽度下零溢出
- 极窄终端（4-10 列）：零溢出

## v1.0.0 — 2026-04-29

初始发布。

- 4 区域布局：Model | Context | Workspace | Duration
- 12 个响应级别 + 2 个回退
- 按模型系列颜色编码（Opus=品红, Sonnet=蓝, Haiku=青）
- 上下文进度条，颜色阈值 70%/86%
- Git 分支缓存（5 秒 TTL）
- 思考/努力/代理标记（● h/x/M）
- Vim 模式指示器
- 时长复合格式（1h24m）
- 速率限制显示
