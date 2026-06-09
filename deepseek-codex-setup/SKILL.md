---
name: deepseek-codex-setup
description: Configure or repair Codex CLI/Desktop to use DeepSeek V4 through a local Responses API proxy. Use when the user asks to connect DeepSeek API to Codex, migrate the same DeepSeek Codex setup to another Mac, fix `codex -p deepseek`, create a reusable DeepSeek setup, or troubleshoot `/responses` 404, `Reconnecting...`, or `stream disconnected` errors with DeepSeek-backed Codex.
---

# DeepSeek Codex Setup

## Purpose

Use this skill to install, repair, test, or explain the local DeepSeek V4 bridge for Codex. Codex expects a Responses API provider, while DeepSeek V4 exposes Chat Completions, so this setup runs a local proxy:

```text
Codex -> http://127.0.0.1:8766/responses -> https://api.deepseek.com/chat/completions
```

## Install Or Repair

Use the bundled installer unless the user only wants an explanation.

```bash
~/.codex/skills/deepseek-codex-setup/scripts/install.sh --api-key <your-deepseek-api-key>
```

If the key is already in the environment:

```bash
DEEPSEEK_API_KEY=<your-deepseek-api-key> ~/.codex/skills/deepseek-codex-setup/scripts/install.sh
```

The installer writes:

- `~/.codex/.env` with `DEEPSEEK_API_KEY`
- `~/.codex/deepseek.config.toml`
- `~/.codex/deepseek-responses-proxy/server.mjs`
- `~/.codex/deepseek-responses-proxy/start.sh`
- `~/.codex/deepseek-responses-proxy/stop.sh`
- `/usr/local/bin/codex` symlink to the Codex desktop binary when possible

Never print the API key in user-facing output. Mask it in diagnostics.

## Daily Commands

Start the proxy before using the DeepSeek profile:

```bash
~/.codex/deepseek-responses-proxy/start.sh
```

Interactive Codex with DeepSeek:

```bash
codex -p deepseek
```

One-shot test:

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

Stop the proxy:

```bash
~/.codex/deepseek-responses-proxy/stop.sh
```

Health check:

```bash
curl http://127.0.0.1:8766/health
```

Expected:

```json
{"ok":true,"provider":"deepseek","base_url":"https://api.deepseek.com"}
```

## Troubleshooting

For `zsh: command not found: codex`, recreate the symlink:

```bash
ln -sf /Applications/Codex.app/Contents/Resources/codex /usr/local/bin/codex
hash -r
codex --version
```

For `ERROR: Reconnecting... 1/5` or `stream disconnected before completion`, check whether the proxy is running:

```bash
curl http://127.0.0.1:8766/health
```

If it fails:

```bash
~/.codex/deepseek-responses-proxy/stop.sh
~/.codex/deepseek-responses-proxy/start.sh
```

Then test:

```bash
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
```

For direct DeepSeek `/responses` 404 errors, confirm `~/.codex/deepseek.config.toml` points to the local proxy, not to `https://api.deepseek.com`:

```toml
base_url = "http://127.0.0.1:8766"
wire_api = "responses"
```

## Desktop Guidance

Prefer terminal usage with `codex -p deepseek`. Codex Desktop does not expose the same obvious profile switch. Do not make DeepSeek the global desktop default unless the user accepts the risk that Desktop will fail when the local proxy is not running.

If the user asks for Desktop switching, propose separate backup/restore scripts rather than permanently editing `~/.codex/config.toml`.

## Migration To Another Mac

Copy this skill directory to the other Mac:

```text
~/.codex/skills/deepseek-codex-setup
```

Then run:

```bash
~/.codex/skills/deepseek-codex-setup/scripts/install.sh --api-key <your-deepseek-api-key>
```

Requirements on the target Mac:

- Codex Desktop installed at `/Applications/Codex.app`
- Network access to `https://api.deepseek.com`
- A valid DeepSeek API key

## Validation Checklist

After installation or repair, run:

```bash
codex --version
~/.codex/deepseek-responses-proxy/start.sh
curl http://127.0.0.1:8766/health
codex exec -p deepseek --skip-git-repo-check "只回复 OK"
codex exec -p deepseek --skip-git-repo-check "请用命令查看当前目录，并告诉我有哪些文件夹"
```

Successful validation means text output works and basic command tool calls work.
