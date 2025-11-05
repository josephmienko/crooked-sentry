#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8123}"
PY="${PYTHON:-python3}"

if [[ -x .venv/bin/python ]]; then
  PY=".venv/bin/python"
fi

exec "$PY" simulation/scripts/homeassistant-sim.py --port "$PORT"
