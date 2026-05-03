# 更新日志

Claude-Statusline-Pro-Max 的所有重要变更均记录于此。

## v1.1.0 — 2026-05-02

增量改进：TIER 信号质量、响应式覆盖间隙、CJK/emoji 安全性和 bug 修复。

### 架构

- **TIER 信号质量系统**：上下文显示根据可用信号强度自适应
  - TIER 1：完整保真 — 进度条 + 百分比 + token 数量
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
