# Claude-Statusline-Pro-Max

> Claude Code CLI 的响应式状态栏 | A responsive, information-dense statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

<p align="center">
<img width="800" alt="statusline 预览" src="docs/preview.svg" />
</p>

**[English Docs](README.md)**

## 显示内容

| 区域 | 内容 | 示例 |
|------|------|------|
| 模型 | 名称 + 思考/努力/代理标记 | `Opus 4.7 ✦ ⚡ 🤖` |
| 路径 | 工作目录（截断） | `~/projects/app` |
| 分支 | Git 分支（带缓存） | `main` |
| 上下文 | 用量进度条 + 百分比 | `▓▓▓▓░░ 67%` |
| 速率 | Token 速率（可用时） | `42t/s` |
| Vim | Vim 模式指示器 | `NORMAL` |
| 时长 | 会话时长 | `1h24m` |

## 核心特性

- **12 级响应式布局** — 从宽终端到窄面板优雅适配
- **精确 CJK/emoji 宽度** — 基于 `od` 的公式正确处理中文、日文、韩文和 emoji
- **第三方 Provider 支持** — 兼容自定义模型端点（没有 `rate_limits` 字段也不报错）
- **5 秒 Git 分支缓存** — 避免每次刷新都 fork `git` 进程
- **复合时长格式** — `1h24m`、`2d3h`，不是 `84m` 或 `5040s`
- **零外部依赖** — 纯 bash，仅需 `jq` 解析 Claude Code schema

## 快速开始

```bash
# 克隆
git clone https://github.com/Howie-Hoo/Claude-Statusline-Pro-Max.git
cd Claude-Statusline-Pro-Max

# 安装
bash install.sh

# 或安装并自动写入配置
bash install.sh --write-config

# 重启 Claude Code
```

### 手动安装

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
```

然后在 `~/.claude/settings.json` 中添加：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
```

## 文档

| 文档 | 内容 |
|------|------|
| [架构](docs/ARCHITECTURE.md) | 区域布局、响应级别、宽度算法 |
| [自定义](docs/CUSTOMIZATION.md) | 颜色、符号、阈值、添加新元素 |
| [兼容性](docs/COMPATIBILITY.md) | 平台说明、已知问题、第三方 Provider |
| [更新日志](docs/CHANGELOG.md) | 版本历史 |
| [架构（中文）](docs/zh/ARCHITECTURE.md) | 架构中文版 |
| [自定义（中文）](docs/zh/CUSTOMIZATION.md) | 自定义中文版 |
| [兼容性（中文）](docs/zh/COMPATIBILITY.md) | 兼容性中文版 |
| [更新日志（中文）](docs/zh/CHANGELOG.md) | 更新日志中文版 |

## 依赖

- Claude Code CLI
- bash 3.2+（macOS 默认）
- `jq`（解析 Claude Code schema）
- Git（可选，用于分支显示）

## 性能

Apple Silicon 上每次刷新约 3-4ms。5 秒间隔下无感知延迟。

## 许可证

[MIT](LICENSE)
