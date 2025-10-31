#!/usr/bin/env bash
set -euo pipefail
echo "[*] sanity check"
command -v ansible-playbook >/dev/null || { echo "install ansible"; exit 1; }
[ -s compose/docker-compose.yml ] || { echo "missing compose/docker-compose.yml"; exit 1; }
echo "ok"
