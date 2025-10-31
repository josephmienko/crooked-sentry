#!/usr/bin/env bash
set -euo pipefail
BUMP="${1:-patch}"
CURRENT="$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)"
BASE="${CURRENT#v}"
IFS=. read -r MA MI PA <<<"$BASE"
case "$BUMP" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *) echo "use: major|minor|patch"; exit 1 ;;
esac
NEW="v${MA}.${MI}.${PA}"
git tag -a "$NEW" -m "release $NEW"
echo "Tagged $NEW. Push with: git push --tags"

