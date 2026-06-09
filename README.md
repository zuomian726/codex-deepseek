# DeepSeek Codex Setup

把 DeepSeek V4 接入 Codex 的可复用 skill。

这个项目提供一个本地桥接服务，让 Codex 使用 `Responses API` 形态访问 DeepSeek 的 `Chat Completions` API。

```text
Codex -> http://127.0.0.1:8766/responses -> https://api.deepseek.com/chat/completions
```

## 适用场景

- 想在 Codex CLI 中使用 DeepSeek V4。
- 想把同一套 DeepSeek Codex 配置迁移到多台 Mac。
- 遇到 DeepSeek 直连 Codex 时的 `/responses 404` 问题。
- 想用 `codex -p deepseek` 独立启用 DeepSeek，不影响默认 OpenAI Codex。

## 注意事项

这是本地桥接方案，不是 Codex 官方原生 DeepSeek 支持。

已验证能力：

- 普通文本回复。
- 基础命令工具调用。

不保证完整兼容：

- 复杂 MCP 工具链。
- 多模态输入。
- Web search。
- Codex Desktop 全局默认模型切换。

建议默认继续使用官方 OpenAI Codex，需要 DeepSeek 时使用：

```bash
codex -p deepseek
```

## 安装

### 1. 复制 skill

把 `deepseek-codex-setup` 目录放到目标机器：

```bash
mkdir -p ~/.codex/skills
cp -R deepseek-codex-setup ~/.codex/skills/
```

如果你是从压缩包解压：

```bash
mkdir -p ~/.codex/skills
tar -xzf deepseek-codex-setup-skill.tar.gz -C ~/.codex/skills
```

### 2. 安装配置

```bash
~/.codex/skills/deepseek-codex-setup/scripts/install.sh --api-key <your-deepseek-api-key>
```

也可以用环境变量：

```bash
DEEPSEEK_API_KEY=<your-deepseek-api-key> ~/.codex/skills/deepseek-codex-setup/scripts/install.sh
```

安装脚本会写入：

```text
~/.codex/.env
~/.codex/deepseek.config.toml
~/.codex/deepseek-responses-proxy/server.mjs
~/.codex/deepseek-responses-proxy/start.sh
~/.codex/deepseek-responses-proxy/stop.sh
```

同时会尝试创建：

```text
/usr/local/bin/codex -> /Applications/Codex.app/Contents/Resources/codex
```

## 使用

每次使用 DeepSeek profile 前，先启动桥接服务：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

进入项目目录后启动 Codex：

```bash
codex -p deepseek
```

一次性测试：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

停止桥接服务：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

## 验证

检查 Codex CLI：

```bash
codex --version
```

检查桥接服务：

```bash
curl http://127.0.0.1:8766/health
```

正常返回：

```json
{"ok":true,"provider":"deepseek","base_url":"https://api.deepseek.com"}
```

测试 DeepSeek 文本回复：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

测试工具调用：

```bash
codex exec -p deepseek --skip-git-repo-check "请用命令查看当前目录，并告诉我有哪些文件夹"
```

## 常见问题

### zsh: command not found: codex

创建 Codex CLI 软链接：

```bash
ln -sf /Applications/Codex.app/Contents/Resources/codex /usr/local/bin/codex
hash -r
codex --version
```

### ERROR: Reconnecting... 1/5

通常是本地桥接服务没启动或已经退出。

```bash
curl http://127.0.0.1:8766/health
```

如果失败，重启：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

### DeepSeek /responses 404

不要让 Codex 直接请求 DeepSeek 官方域名的 `/responses`。

正确配置是：

```toml
base_url = "http://127.0.0.1:8766"
wire_api = "responses"
```

## 隐私和安全

不要提交任何真实密钥。

公开仓库里不应该出现：

- `DEEPSEEK_API_KEY=<real-api-key>`
- `~/.codex/.env`
- `auth.json`
- `*.log`
- `*.pid`
- `*.sqlite`
- 本机用户名路径或绝对家目录路径
- 私有仓库地址、邮箱、Apple ID、服务器 IP、数据库密码

本项目的公开文档只使用通用路径：

```text
~/.codex
/Applications/Codex.app
/usr/local/bin/codex
```

发布到 GitHub 前建议再做一次全文搜索，重点检查真实 API Key、本机用户名路径、邮箱、服务器地址、数据库密码、运行日志和本地状态数据库。真实隐私信息必须删除后再提交。

## 目录结构

```text
deepseek-codex-setup/
  SKILL.md
  agents/
    openai.yaml
  scripts/
    install.sh
    server.mjs
```

## 卸载

停止桥接服务：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

删除安装产物：

```bash
rm -rf ~/.codex/deepseek-responses-proxy
rm -f ~/.codex/deepseek.config.toml
```

如需删除 API Key，请编辑：

```text
~/.codex/.env
```

删除其中的：

```env
DEEPSEEK_API_KEY=...
```
