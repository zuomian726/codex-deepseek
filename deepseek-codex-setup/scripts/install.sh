#!/bin/zsh
set -euo pipefail

MODEL="deepseek-v4-pro"
PORT="8766"
API_KEY="${DEEPSEEK_API_KEY:-}"
CODEX_BIN="/Applications/Codex.app/Contents/Resources/codex"
CODEX_NODE="/Applications/Codex.app/Contents/Resources/node"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

usage() {
  cat <<'USAGE'
Usage:
  install.sh --api-key <your-deepseek-api-key> [--model deepseek-v4-pro] [--port 8766]

Environment alternative:
  DEEPSEEK_API_KEY=<your-deepseek-api-key> install.sh
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$API_KEY" ]]; then
  echo "Missing DeepSeek API key. Pass --api-key or set DEEPSEEK_API_KEY." >&2
  exit 2
fi

if [[ ! -x "$CODEX_BIN" ]]; then
  echo "Codex desktop binary not found at $CODEX_BIN." >&2
  echo "Install Codex Desktop first, or edit CODEX_BIN in this script." >&2
  exit 1
fi

if [[ ! -x "$CODEX_NODE" ]]; then
  echo "Codex bundled node not found at $CODEX_NODE." >&2
  exit 1
fi

ROOT="$CODEX_HOME/deepseek-responses-proxy"
ENV_FILE="$CODEX_HOME/.env"
PROFILE_FILE="$CODEX_HOME/deepseek.config.toml"
SCRIPT_DIR="${0:A:h}"

mkdir -p "$CODEX_HOME" "$ROOT"
cp "$SCRIPT_DIR/server.mjs" "$ROOT/server.mjs"
chmod 700 "$ROOT/server.mjs"

if [[ -f "$ENV_FILE" ]]; then
  if grep -q '^DEEPSEEK_API_KEY=' "$ENV_FILE"; then
    tmp_file="$(mktemp)"
    sed 's/^DEEPSEEK_API_KEY=.*/DEEPSEEK_API_KEY='"$API_KEY"'/' "$ENV_FILE" > "$tmp_file"
    mv "$tmp_file" "$ENV_FILE"
  else
    printf '\nDEEPSEEK_API_KEY=%s\n' "$API_KEY" >> "$ENV_FILE"
  fi
else
  printf 'DEEPSEEK_API_KEY=%s\n' "$API_KEY" > "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

cat > "$PROFILE_FILE" <<TOML
model = "$MODEL"
model_provider = "deepseek_proxy"

[model_providers.deepseek_proxy]
name = "DeepSeek v4 via local Responses proxy"
base_url = "http://127.0.0.1:$PORT"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"
supports_websockets = false
TOML
chmod 600 "$PROFILE_FILE"

cat > "$ROOT/start.sh" <<SH
#!/bin/zsh
set -euo pipefail

ROOT="\$HOME/.codex/deepseek-responses-proxy"
ENV_FILE="\$HOME/.codex/.env"
PID_FILE="\$ROOT/deepseek-proxy.pid"
LOG_FILE="\$ROOT/deepseek-proxy.log"

if [[ -f "\$PID_FILE" ]] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
  echo "DeepSeek proxy already running: \$(cat "\$PID_FILE")"
  exit 0
fi

rm -f "\$PID_FILE"

set -a
source "\$ENV_FILE"
set +a

DEEPSEEK_PROXY_PORT="$PORT" nohup "$CODEX_NODE" "\$ROOT/server.mjs" > "\$LOG_FILE" 2>&1 &
echo \$! > "\$PID_FILE"
sleep 0.8

if kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null && curl -fsS --connect-timeout 2 "http://127.0.0.1:$PORT/health" >/dev/null; then
  echo "DeepSeek proxy started: http://127.0.0.1:$PORT"
  echo "Log: \$LOG_FILE"
else
  echo "DeepSeek proxy failed to start. See: \$LOG_FILE"
  exit 1
fi
SH

cat > "$ROOT/stop.sh" <<'SH'
#!/bin/zsh
set -euo pipefail

ROOT="$HOME/.codex/deepseek-responses-proxy"
PID_FILE="$ROOT/deepseek-proxy.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "DeepSeek proxy is not running."
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "DeepSeek proxy stopped: $PID"
else
  echo "DeepSeek proxy process was not running: $PID"
fi

rm -f "$PID_FILE"
SH

chmod 700 "$ROOT/start.sh" "$ROOT/stop.sh"
ln -sf "$CODEX_BIN" /usr/local/bin/codex 2>/dev/null || true

"$ROOT/start.sh"
echo
echo "Installed DeepSeek Codex profile."
echo "Test with:"
echo "  codex exec -p deepseek --skip-git-repo-check \"只回复 OK\""
echo "Interactive use:"
echo "  codex -p deepseek"
