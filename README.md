# Codex DeepSeek for Mac：Mac 小白安装版

这个项目是 **Mac 专用版**，帮你把 DeepSeek V4 接入 Codex。

适用范围：

- macOS
- Codex Desktop for Mac
- Mac 终端里的 `codex` 命令

暂不支持 Windows / Linux。如果你是 Windows 用户，请不要直接照这个教程操作。

支持两种用法：

| 用法 | 推荐程度 | 适合谁 |
| --- | --- | --- |
| 终端版 `codex -p deepseek` | 推荐 | 日常写代码、改项目 |
| Codex 桌面端 | 可用，但要切换配置 | 想在桌面 App 里体验 DeepSeek |

重要提示：桌面端不是在界面里点选 DeepSeek，而是用脚本临时切换配置。

## 你需要准备什么

1. 一台 Mac。
2. 已安装 Codex Desktop。
3. 一个 DeepSeek API Key。
4. 会打开“终端”。

Codex Desktop 通常在这里：

```text
/Applications/Codex.app
```

DeepSeek API Key 格式类似：

```text
<your-deepseek-api-key>
```

不要把真实 API Key 发到 GitHub、论坛、截图或聊天群。

## 第一步：安装

打开 Mac 的“终端”，复制执行：

```bash
cd ~
git clone https://github.com/zuomian726/codex-deepseek.git
cd codex-deepseek
```

然后执行安装命令。

把 `<your-deepseek-api-key>` 换成你的真实 DeepSeek API Key：

```bash
./deepseek-codex-setup/scripts/install.sh --api-key <your-deepseek-api-key>
```

安装成功后，会看到类似：

```text
Installed DeepSeek Codex profile.
```

## 第二步：测试

复制执行：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

如果看到：

```text
OK
```

说明成功。

如果失败，先看下面的“常见问题”。

## 第三步：选择你的使用方式

### A. 使用终端版 Codex，推荐

每次使用前，先启动 DeepSeek 桥接服务：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

进入你的项目目录：

```bash
cd ~/Code/your-project
```

启动 DeepSeek 版 Codex：

```bash
codex -p deepseek
```

不用时可以停止桥接服务：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

### B. 使用 Codex 桌面端

桌面端要先切换配置。

执行：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
```

然后必须做这一步：

```text
完全退出 Codex 桌面端，再重新打开 Codex 桌面端。
```

建议用 `Command + Q` 退出 Codex，而不是只关闭窗口。

如果想让桌面端恢复默认 OpenAI，执行：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

这个脚本会恢复第一次切换 DeepSeek 前保存的原始 `~/.codex/config.toml`。

然后同样：

```text
完全退出 Codex 桌面端，再重新打开 Codex 桌面端。
```

桌面端注意事项：

- 桌面端切到 DeepSeek 后，每次开机要先执行 `start.sh`。
- 如果桥接服务没启动，桌面端可能一直连接失败。
- 如果出问题，先执行 `desktop-use-default.sh` 恢复默认 OpenAI。

## 以后每天怎么用

如果你用终端版：

```bash
~/.codex/deepseek-responses-proxy/start.sh
cd ~/Code/your-project
codex -p deepseek
```

如果你用桌面端：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

然后打开 Codex 桌面端。

如果桌面端还没切到 DeepSeek，先执行：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh
```

再重启 Codex 桌面端。

## 配置在哪里改

一般不用手动改配置。真要改，看这个表：

| 想改什么 | 改哪个文件 | 改哪里 |
| --- | --- | --- |
| DeepSeek API Key | `~/.codex/.env` | `DEEPSEEK_API_KEY=...` |
| 终端版 DeepSeek 模型 | `~/.codex/deepseek.config.toml` | `model = "deepseek-v4-pro"` |
| 桌面端当前模型 | `~/.codex/config.toml` | `model = "deepseek-v4-pro"` |
| 本地端口 | `~/.codex/deepseek.config.toml` 和 `start.sh` | `8766` |
| 启动桥接 | `~/.codex/deepseek-responses-proxy/start.sh` | 直接执行 |
| 停止桥接 | `~/.codex/deepseek-responses-proxy/stop.sh` | 直接执行 |
| 桌面端切到 DeepSeek | `desktop-use-deepseek.sh` | 直接执行 |
| 桌面端恢复默认 | `desktop-use-default.sh` | 直接执行 |

打开配置文件的命令：

```bash
open ~/.codex/.env
open ~/.codex/deepseek.config.toml
open ~/.codex/config.toml
```

### 修改 API Key

```bash
open ~/.codex/.env
```

把这一行换成新的 key：

```env
DEEPSEEK_API_KEY=<your-deepseek-api-key>
```

然后重启桥接：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

### 修改模型

终端版改：

```bash
open ~/.codex/deepseek.config.toml
```

桌面端改：

```bash
open ~/.codex/config.toml
```

找到：

```toml
model = "deepseek-v4-pro"
```

可以改成其他 DeepSeek 模型，例如：

```toml
model = "deepseek-v4-flash"
```

如果你用桌面端，改完后要完全退出并重新打开 Codex 桌面端。

## 常见问题

### 1. `zsh: command not found: codex`

终端找不到 Codex 命令。

执行：

```bash
ln -sf /Applications/Codex.app/Contents/Resources/codex /usr/local/bin/codex
hash -r
codex --version
```

能看到版本号就好了。

### 2. `ERROR: Reconnecting... 1/5`

通常是桥接服务没启动。

先检查：

```bash
curl http://127.0.0.1:8766/health
```

如果失败，启动桥接：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

然后重新测试：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

### 3. `stream disconnected before completion`

先重启桥接：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

再测试：

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

还不行就看日志：

```bash
sed -n '1,200p' ~/.codex/deepseek-responses-proxy/deepseek-proxy.log
```

### 4. 桌面端打开后一直连接失败

先启动桥接：

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

然后完全退出并重新打开 Codex 桌面端。

如果还不行，先恢复默认 OpenAI：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

再完全退出并重新打开 Codex 桌面端。

### 5. DeepSeek `/responses` 404

不要把 Codex 直接指向 DeepSeek 官方地址。

正确配置应该是本地地址：

```toml
base_url = "http://127.0.0.1:8766"
wire_api = "responses"
```

不是：

```toml
base_url = "https://api.deepseek.com"
```

原因是 Codex 会请求 `/responses`，而 DeepSeek 官方接口是 `/chat/completions`。本项目的本地桥接服务就是用来转换这两个接口的。

## 卸载

如果桌面端曾经切到 DeepSeek，先恢复默认：

```bash
~/.codex/deepseek-responses-proxy/desktop-use-default.sh
```

停止桥接：

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

删除安装文件：

```bash
rm -rf ~/.codex/deepseek-responses-proxy
rm -f ~/.codex/deepseek.config.toml
```

如需删除 API Key：

```bash
open ~/.codex/.env
```

删除这一行：

```env
DEEPSEEK_API_KEY=<your-deepseek-api-key>
```

## 隐私提醒

不要上传这些内容到 GitHub：

```text
~/.codex/.env
真实 API Key
*.log
*.pid
*.sqlite
auth.json
```

这个仓库应该只包含：

```text
README.md
.gitignore
deepseek-codex-setup/
```

## 这个项目做了什么

Codex 当前需要请求：

```text
/responses
```

DeepSeek 当前提供的是：

```text
/chat/completions
```

所以本项目在本机启动一个桥接服务：

```text
Codex -> 本地桥接 -> DeepSeek
```

默认本地地址：

```text
http://127.0.0.1:8766
```
