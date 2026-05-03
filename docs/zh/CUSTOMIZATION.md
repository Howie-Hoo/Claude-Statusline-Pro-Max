# 自定义

## 颜色

所有颜色在 `statusline-command.sh` 顶部定义，使用实际 ESC 字节：

```bash
RST=$'\033'[0m;  BOLD=$'\033'[1m;  DIM=$'\033'[2m
RED=$'\033'[31m; GRN=$'\033'[32m; YLW=$'\033'[33m
BLU=$'\033'[34m; MGN=$'\033'[35m; CYN=$'\033'[36m; GRY=$'\033'[90m
```

注意：颜色变量使用 `$'\033'[...m` 语法（实际 ESC 字节），非 `'\033[...m'` 字符串。这确保 `printf '%s'` 正常工作，不会产生反斜杠解释。

### 模型颜色映射

```bash
# 模型区域的颜色按模型系列分配：
Opus   → MGN（品红）
Sonnet → BLU（蓝色）
Haiku  → CYN（青色）
其他   → GRN（绿色）
```

要修改模型颜色，找到模型区域的 `case` 代码块，更改颜色变量即可。

### 上下文进度条阈值

```bash
# 绿色：  0-69%
# 黄色： 70-85%
# 红色：  86%+
```

在上下文进度条渲染区域调整阈值：

```bash
if [ "$pct_int" -gt 85 ]; then
  ctx_color=$RED
elif [ "$pct_int" -gt 69 ]; then
  ctx_color=$YLW
else
  ctx_color=$GRN
fi
```

### 速率限制阈值

```bash
# 绿色：  ≤59%
# 黄色： 60-84%
# 红色：  ≥85%
```

在速率区域调整：

```bash
if [ "$r5h_int" -gt 84 ]; then r5h_color=$RED
elif [ "$r5h_int" -gt 59 ]; then r5h_color=$YLW
else r5h_color=$GRN
fi
```

## 标记

| 标记 | 含义 | 变量 |
|------|------|------|
| `●` | 思考已启用 | `think_mark` |
| `●` | 代理活跃 | `agent_mark` |
| `h` | 努力：high | `effort_mark` |
| `x` | 努力：xhigh | `effort_mark` |
| `M` | 努力：max | `effort_mark` |
| `[N]` | Vim：NORMAL | `vim_mark` |
| `[I]` | Vim：INSERT | `vim_mark` |
| `[V]` | Vim：VISUAL | `vim_mark` |
| `[V-L]` | Vim：VISUAL LINE | `vim_mark` |
| `│` | 区域分隔符 | `sep` |
| `▓` | 进度条填充格 | — |
| `░` | 进度条空白格 | — |

要修改标记，在脚本中搜索并替换。

## 响应级别阈值

脚本使用 `try_build`/`try_len` 的不同参数组合。每个级别按从最多信息（L0）到最少（最后手段）的顺序尝试。

调整各宽度下显示哪些元素：

1. 找到响应级别区域（搜索 `L0` 到 `L12`）
2. 修改 `try_build`/`try_len` 调用参数：
   - `show_rate=1/0` — 显示/隐藏速率限制
   - `show_vim=1/0` — 显示/隐藏 Vim 模式
   - `show_dur=1/0` — 显示/隐藏时长
   - `show_session=1/0` — 显示/隐藏会话 token
3. 通过移动 `try_build`/`try_len` 调用对重新排列级别

### 添加新元素

1. 在数据提取区域计算元素的字符串
2. 给 `try_build` 和 `try_len` 添加 `show_xxx` 标志参数
3. 在 `try_build` 组装逻辑中添加元素
4. 在 `try_len` 中添加长度计算
5. 预计算所有 Zone 4 标志组合
6. 创建包含/排除该元素的响应级别
7. 在所有终端宽度下测试（4-200 列）

## Git 分支缓存

分支缓存 5 秒，存储在 `/tmp/.claude-git-branch-$(cwd的md5)`：

```bash
# 要修改缓存时长，更改：
if [ $(( now - cache_time )) -gt 5 ]; then
```

把 `5` 改为你想要的秒数。设为 `0` 禁用缓存。

## 刷新间隔

在 `settings.json` 中配置，不在脚本中：

```json
{
  "statusLine": {
    "refreshInterval": 5
  }
}
```

值越低 = 更响应但更多 CPU。推荐 3-5 秒。

## 路径显示

脚本使用 Claude Code schema 的 `project_dir`（非原始 `cwd`）。在项目内时显示项目名 + 相对路径。

- `path_mid` 截断：项目名上限 20 字符
- `path_short` 截断：项目名上限 15 字符
- HOME 前缀要求尾部斜杠或精确匹配（防止误匹配）

要强制显示完整路径：

```bash
# 找到路径计算区域，将相对路径逻辑改为：
# p="$cwd"
```

## 时长格式

默认复合格式：`1h24m`、`2d3h`、`45s`。

会话 token 作为 Zone 4 的次要统计与时长一起显示，使用 `fmt_tok` 格式化（如 `80.0k`）。

## 上下文 TIER 系统

上下文区域根据信号质量自适应。要修改 TIER 行为：

1. 找到 `ctx_tier` 计算区域
2. 调整每个 TIER 的条件
3. 修改每个 TIER 的 `ctx_full`/`ctx_mid`/`ctx_short` 显示格式
