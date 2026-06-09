# Codex 使用 DeepSeek V4 小白安装包

这个项目的作用：让你的 **Codex CLI** 和 **Codex 桌面端** 可以使用 **DeepSeek V4**。

你只需要准备一个 DeepSeek API Key，然后复制几条命令即可。

## 先看结论

推荐用法是终端 CLI：

```bash
~/.codex/deepseek-responses-proxy/start.sh
codex -p deepseek
```

桌面端也可以用，但需要先切换桌面端配置：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
```

然后 **完全退出 Codex 桌面端，再重新打开 Codex 桌面端**。

想恢复桌面端默认配置：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

测试是否成功：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

看到 `OK` 就说明成功。

## 适合谁

适合：

- 想用 Codex，但希望模型走 DeepSeek V4。
- 想降低一部分 AI 使用成本。
- 想在多台 Mac 上复用同一套配置。
- 想让 Codex 桌面端临时切到 DeepSeek。

不适合：

- 完全不想打开终端的人。
- 想在 Codex 桌面端界面里直接点选 DeepSeek 的人。当前不是点选切换，而是通过脚本切换配置。
- 需要完整 MCP、多模态、web search 等高级能力的人。

## 准备工作

### 1. 安装 Codex Desktop

先确认你的 Mac 已经安装 Codex Desktop。

Codex 程序通常在这里：

```text
/Applications/Codex.app
```

### 2. 准备 DeepSeek API Key

去 DeepSeek 平台创建 API Key。

拿到的 key 类似：

```text
<your-deepseek-api-key>
```

注意：不要把真实 API Key 发到 GitHub、微信群、论坛或截图里。

## 小白安装步骤

### 第 1 步：打开终端

在 Mac 上打开：

```text
启动台 -> 其他 -> 终端
```

或者用 Spotlight 搜索：

```text
Terminal
```

### 第 2 步：下载项目

复制下面命令到终端：

```bash
cd ~
git clone https://github.com/zuomian726/codex-deepseek.git
cd codex-deepseek
```

如果提示 `git: command not found`，说明电脑还没有 Git，需要先安装 Git 或 Xcode Command Line Tools。

### 第 3 步：安装配置

把下面命令里的 `<your-deepseek-api-key>` 替换成你自己的 DeepSeek API Key：

```bash
./deepseek-codex-setup/scripts/install.sh --api-key <your-deepseek-api-key>
```

例如格式是这样：

```bash
./deepseek-codex-setup/scripts/install.sh --api-key 你的真实key
```

注意：不要把真实 key 提交到 GitHub。

### 第 4 步：测试

复制执行：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

如果看到：

```text
OK
```

说明安装成功。

### 第 5 步：正式使用

如果你使用终端版 Codex，按这里做。

进入你的项目目录，例如：

```bash
cd ~/Code/your-project
```

启动 DeepSeek 桥接服务：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

用 DeepSeek 启动 Codex：

```bash
codex -p deepseek
```

不用的时候，可以停止：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

如果你想使用 **Codex 桌面端**，继续看下一节。

## 重点：桌面端使用方法

Codex 桌面端目前没有明显的 `-p deepseek` 入口，所以不能像终端这样启动：

```bash
codex -p deepseek
```

桌面端要使用 DeepSeek，需要临时修改 Codex 的全局配置。这个项目已经提供了两个脚本，不需要你手动改配置。

### 桌面端切换到 DeepSeek

先确保你已经完成上面的安装步骤。

然后执行：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
```

这个脚本会自动做三件事：

- 启动本地 DeepSeek 桥接服务。
- 备份当前 `~/.codex/config.toml`。
- 把 Codex 桌面端默认模型切到 DeepSeek。

执行完成后，必须做这一步：

```text
完全退出 Codex 桌面端，然后重新打开 Codex 桌面端
```

注意：只是关闭窗口不一定够，建议在菜单栏退出 Codex，或者按 `Command + Q`。

### 桌面端恢复默认 OpenAI

如果你想让桌面端恢复默认模型，执行：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

执行完成后，同样需要：

```text
完全退出 Codex 桌面端，然后重新打开 Codex 桌面端
```

### 桌面端每次开机后要注意什么

如果桌面端已经切到 DeepSeek，每次开机后都要先启动桥接服务：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

否则桌面端可能会一直连接失败。

### 桌面端配置改了哪里

桌面端切换脚本会修改：

```text
~/.codex/config.toml
```

并把原文件备份到：

```text
~/.codex/config-backups/
```

如果你想手动查看：

```bash
open ~/.codex/config.toml
```

DeepSeek 桌面端配置会类似：

```toml
model = "deepseek-v4-pro"
model_provider = "deepseek_proxy"

[model_providers.deepseek_proxy]
name = "DeepSeek v4 via local Responses proxy"
base_url = "http://127.0.0.1:8766"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"
supports_websockets = false
```

小白用户不建议手动改这里，优先使用脚本：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

## 每次使用要做什么

每次开机后，如果你想用 DeepSeek 版 Codex，建议先执行：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

然后进入项目目录：

```bash
cd ~/Code/your-project
```

再启动：

```bash
codex -p deepseek
```

## 配置文件在哪里

安装脚本会自动创建这些文件。

| 文件 | 作用 |
| --- | --- |
| `~/.codex/.env` | 保存 DeepSeek API Key |
| `~/.codex/deepseek.config.toml` | Codex 的 DeepSeek profile 配置 |
| `~/.codex/deepseek-responses-proxy/server.mjs` | 本地桥接服务 |
| `~/.codex/deepseek-responses-proxy/start.sh` | 启动桥接服务 |
| `~/.codex/deepseek-responses-proxy/stop.sh` | 停止桥接服务 |
| `~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh` | 让 Codex 桌面端使用 DeepSeek |
| `~/.codex/deepseek-responses-proxy/desktop-use-default.sh` | 让 Codex 桌面端恢复默认配置 |
| `~/.codex/config.toml` | Codex 桌面端会读取的全局配置 |
| `~/.codex/config-backups/` | 桌面端切换前的配置备份 |

## 想修改配置，改哪里

### 修改 API Key

打开这个文件：

```bash
open ~/.codex/.env
```

里面是：

```env
DEEPSEEK_API_KEY=<your-deepseek-api-key>
```

把等号后面的内容换成新的 key。

修改后重启桥接服务：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

### 修改 DeepSeek 模型

打开：

```bash
open ~/.codex/deepseek.config.toml
```

找到：

```toml
model = "deepseek-v4-pro"
```

如果你想换模型，就改这一行。

示例：

```toml
model = "deepseek-v4-flash"
```

修改后重新启动 Codex：

```bash
codex -p deepseek
```

如果你用的是桌面端，还要重新执行桌面端切换脚本：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
```

然后完全退出并重新打开 Codex 桌面端。

### 修改本地端口

默认端口是：

```text
8766
```

一般不需要改。

如果端口冲突，需要同时改两个地方。

第一个文件：

```bash
open ~/.codex/deepseek.config.toml
```

把：

```toml
base_url = "http://127.0.0.1:8766"
```

改成：

```toml
base_url = "http://127.0.0.1:新的端口"
```

第二个文件：

```bash
open ~/.codex/deepseek-responses-proxy/start.sh
```

找到：

```bash
DEEPSEEK_PROXY_PORT="8766"
```

改成同一个新端口。

然后重启：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

### 修改 DeepSeek 官方 API 地址

一般不需要改。

如果 DeepSeek 后续更换 API 地址，改这个文件：

```bash
open ~/.codex/deepseek-responses-proxy/start.sh
```

在启动命令前增加或修改：

```bash
DEEPSEEK_BASE_URL="https://api.deepseek.com"
```

普通用户不要改这个。

## 为什么不是直接填 DeepSeek 地址

Codex 当前需要请求：

```text
/responses
```

DeepSeek 当前提供的是：

```text
/chat/completions
```

如果直接让 Codex 请求 DeepSeek：

```text
https://api.deepseek.com/responses
```

会报：

```text
404 Not Found
```

所以这个项目加了一个本地桥接：

```text
Codex -> 本地桥接 -> DeepSeek
```

## 常见问题

### 1. zsh: command not found: codex

说明终端找不到 Codex 命令。

执行：

```bash
ln -sf /Applications/Codex.app/Contents/Resources/codex /usr/local/bin/codex
hash -r
codex --version
```

如果能看到版本号，就好了。

### 2. ERROR: Reconnecting... 1/5

通常是桥接服务没启动。

先检查：

```bash
curl http://127.0.0.1:8766/health
```

如果失败，执行：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

再测试：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

### 3. stream disconnected before completion

先重启桥接：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

再试：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

如果还不行，检查日志：

```bash
sed -n '1,200p' ~/.codex/deepseek-responses-proxy/deepseek-proxy.log
```

### 4. DeepSeek /responses 404

说明你可能把 Codex 直接指向了 DeepSeek 官方 API。

检查：

```bash
open ~/.codex/deepseek.config.toml
```

正确应该是：

```toml
base_url = "http://127.0.0.1:8766"
wire_api = "responses"
```

不是：

```toml
base_url = "https://api.deepseek.com"
```

### 5. 桌面端打开后一直连接失败

先确认桥接服务是否启动：

```bash
curl http://127.0.0.1:8766/health
```

如果失败，执行：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

然后完全退出并重新打开 Codex 桌面端。

如果仍然不行，先恢复默认 OpenAI：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

再完全退出并重新打开 Codex 桌面端。

## 卸载

停止桥接：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

删除配置：

```bash
rm -rf ~/.codex/deepseek-responses-proxy
rm -f ~/.codex/deepseek.config.toml
```

如果你曾经让桌面端切到 DeepSeek，先恢复默认：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

如果要删除 API Key：

```bash
open ~/.codex/.env
```

删除这一行：

```env
DEEPSEEK_API_KEY=<your-deepseek-api-key>
```

## 隐私提醒

不要把真实 API Key 上传到 GitHub。

不要上传这些文件：

```text
~/.codex/.env
*.log
*.pid
*.sqlite
auth.json
```

这个仓库只应该包含：

```text
README.md
.gitignore
deepseek-codex-setup/
```
