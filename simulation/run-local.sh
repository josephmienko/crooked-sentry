#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-5500}"
PY="${PYTHON:-python3}"

if [[ -x .venv/bin/python ]]; then
  PY=".venv/bin/python"
fi

# Ensure Pillow is available
if ! "$PY" - <<'PY' >/dev/null 2>&1
import PIL
PY
then
  echo "Installing Pillow into current Python environment..."
  "$PY" -m pip install --upgrade pip pillow >/dev/null
fi

exec "$PY" simulation/scripts/frigate-sim.py --port "$PORT"
