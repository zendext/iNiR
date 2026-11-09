#!/usr/bin/env bash
set -euo pipefail

YEAR="${1:-$(date +%Y)}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/calendar/holiday-cn"
URL="https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/${YEAR}.json"

mkdir -p "${CACHE_DIR}"
file="$(mktemp "${CACHE_DIR}/.${YEAR}.XXXXXXXX")"
trap 'rm -f -- "$file"' EXIT
curl -fsSL "${URL}" -o "$file"
mv -f -- "$file" "${CACHE_DIR}/${YEAR}.json"
