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
open "$ROOT/dist/LogX.app"
echo "OPENED $ROOT/dist/LogX.app"
