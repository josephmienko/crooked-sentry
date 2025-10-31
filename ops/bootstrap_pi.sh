#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-crookedsentry.local}"
PI_USER="${2:-bossbitch}"

echo "[*] Creating target dir on Pi..."
ssh "${PI_USER}@${PI_HOST}" 'mkdir -p ~/crooked-sentry'

echo "[*] Syncing repo to Pi..."
rsync -az --delete --exclude ".git" ./ "${PI_USER}@${PI_HOST}:~/crooked-sentry/"

echo
echo "[i] Next: run the Ansible playbook:"
echo "    ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml --ask-vault-pass"
