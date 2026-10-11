#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }

DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
NIX_FILE="pkgs/chatgpt.nix"

get_current_version() {
  sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$NIX_FILE" | head -1
}

get_current_sha() {
  sed -n 's/.*sha256 = "\([^"]*\)".*/\1/p' "$NIX_FILE" | head -1
}

fetch_hash() {
  nix-prefetch-url "$DEB_URL" 2>/dev/null | tail -1
}

update() {
  local new_hash
  new_hash=$(fetch_hash)
  [[ -z "$new_hash" ]] && { err "failed to fetch hash"; exit 1; }
  sed -i "s|sha256 = \"[^\"]*\"|sha256 = \"$new_hash\"|" "$NIX_FILE"
  log "updated sha256 to $new_hash"
  # try to get version from deb filename via curl -I? not trivial; but hash changed -> new build
  nix build .#chatgpt >/dev/null 2>&1 && log "build ok" || { err "build failed"; exit 1; }
}

case "${1:-update}" in
  update) update ;;
  *) echo "usage: $0 update"; exit 1 ;;
esac
