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

CODEX_HOME="\${CODEX_HOME:-\$HOME/.codex}"
ROOT="\$CODEX_HOME/deepseek-responses-proxy"
ENV_FILE="\$CODEX_HOME/.env"
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

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ROOT="$CODEX_HOME/deepseek-responses-proxy"
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

cat > "$ROOT/desktop-use-deepseek.sh" <<SH
#!/bin/zsh
set -euo pipefail

CODEX_HOME="\${CODEX_HOME:-\$HOME/.codex}"
CONFIG_FILE="\$CODEX_HOME/config.toml"
BACKUP_DIR="\$CODEX_HOME/config-backups"
START_SCRIPT="\$CODEX_HOME/deepseek-responses-proxy/start.sh"

mkdir -p "\$BACKUP_DIR"
"\$START_SCRIPT"

if [[ -f "\$CONFIG_FILE" ]]; then
  BACKUP_FILE="\$BACKUP_DIR/config.toml.before-deepseek-desktop.\$(date +%Y%m%d-%H%M%S)"
  cp "\$CONFIG_FILE" "\$BACKUP_FILE"
  echo "Backup: \$BACKUP_FILE"
else
  touch "\$CONFIG_FILE"
fi

ruby - "\$CONFIG_FILE" <<'RUBY'
path = ARGV.fetch(0)
lines = File.exist?(path) ? File.readlines(path, chomp: true) : []
out = []
table = nil
skip_deepseek_provider = false

lines.each do |line|
  if line =~ /^\\s*\\[([^\\]]+)\\]\\s*$/
    table = \$1
    skip_deepseek_provider = (table == "model_providers.deepseek_proxy")
    next if skip_deepseek_provider
  end

  next if skip_deepseek_provider
  next if table.nil? && line =~ /^\\s*(model|model_provider)\\s*=/

  out << line
end

out << "" unless out.empty? || out.last == ""
out << 'model = "$MODEL"'
out << 'model_provider = "deepseek_proxy"'
out << ""
out << "[model_providers.deepseek_proxy]"
out << 'name = "DeepSeek v4 via local Responses proxy"'
out << 'base_url = "http://127.0.0.1:$PORT"'
out << 'env_key = "DEEPSEEK_API_KEY"'
out << 'wire_api = "responses"'
out << 'supports_websockets = false'

File.write(path, out.join("\\n") + "\\n")
RUBY

echo
echo "Codex Desktop is now configured to use DeepSeek."
echo "Important: fully quit Codex Desktop and open it again."
echo "To restore default config later:"
echo "  ~/.codex/deepseek-responses-proxy/desktop-use-default.sh"
SH

cat > "$ROOT/desktop-use-default.sh" <<'SH'
#!/bin/zsh
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CODEX_HOME/config.toml"
BACKUP_DIR="$CODEX_HOME/config-backups"

LATEST_BACKUP="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'config.toml.before-deepseek-desktop.*' -print 2>/dev/null | sort -r | head -n 1 || true)"

if [[ -n "$LATEST_BACKUP" ]]; then
  cp "$LATEST_BACKUP" "$CONFIG_FILE"
  echo "Restored: $LATEST_BACKUP"
  echo "Important: fully quit Codex Desktop and open it again."
  exit 0
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "No config.toml found. Nothing to restore."
  exit 0
fi

ruby - "$CONFIG_FILE" <<'RUBY'
path = ARGV.fetch(0)
lines = File.readlines(path, chomp: true)
out = []
table = nil
skip_deepseek_provider = false

lines.each do |line|
  if line =~ /^\s*\[([^\]]+)\]\s*$/
    table = $1
    skip_deepseek_provider = (table == "model_providers.deepseek_proxy")
    next if skip_deepseek_provider
  end

  next if skip_deepseek_provider
  next if table.nil? && line =~ /^\s*(model|model_provider)\s*=/

  out << line
end

File.write(path, out.join("\n") + "\n")
RUBY

echo "Removed DeepSeek Desktop config block."
echo "Important: fully quit Codex Desktop and open it again."
SH

chmod 700 "$ROOT/start.sh" "$ROOT/stop.sh" "$ROOT/desktop-use-deepseek.sh" "$ROOT/desktop-use-default.sh"
ln -sf "$CODEX_BIN" /usr/local/bin/codex 2>/dev/null || true

"$ROOT/start.sh"
echo
echo "Installed DeepSeek Codex profile."
echo "Test with:"
echo "  codex exec -p deepseek --skip-git-repo-check \"只回复 OK\""
echo "Interactive use:"
echo "  codex -p deepseek"
echo "Desktop use:"
echo "  ~/.codex/deepseek-responses-proxy/desktop-use-deepseek.sh"
echo "Desktop restore:"
echo "  ~/.codex/deepseek-responses-proxy/desktop-use-default.sh"
