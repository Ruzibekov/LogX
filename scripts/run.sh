#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MONITOR="${LOGX_MONITOR_ROOT:-$HOME/Projects/online-mahalla}"
export LOGX_PROJECT_ROOT="$MONITOR"
if ! curl -fsS --max-time 1 "http://127.0.0.1:8787/api/devices" >/dev/null 2>&1; then
  if [[ -x "$MONITOR/tools/rsid-http-monitor/service.sh" || -f "$MONITOR/tools/rsid-http-monitor/service.sh" ]]; then
    bash "$MONITOR/tools/rsid-http-monitor/service.sh" start || true
  fi
fi
bash "$ROOT/scripts/package-app.sh"
BIN="$ROOT/dist/LogX.app/Contents/MacOS/LogX"
if pgrep -f "$BIN" >/dev/null 2>&1; then
  pkill -TERM -f "$BIN" || true
  for _ in {1..25}; do
    pgrep -f "$BIN" >/dev/null 2>&1 || break
    sleep 0.2
  done
  pkill -KILL -f "$BIN" 2>/dev/null || true
fi
open "$ROOT/dist/LogX.app"
echo "OPENED $ROOT/dist/LogX.app"
