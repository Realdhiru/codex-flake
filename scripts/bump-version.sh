#!/usr/bin/env bash
set -euo pipefail
DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
NIX_FILE="pkgs/chatgpt.nix"
cur=$(sed -n 's/.*sha256 = "\([^"]*\)".*/\1/p' "$NIX_FILE" | head -1)
new=$(nix-prefetch-url "$DEB_URL" 2>/dev/null | tail -1)
[ -z "$new" ] && { echo "fail"; exit 1; }
sed -i "s|sha256 = \"$cur\"|sha256 = \"$new\"|" "$NIX_FILE"
nix flake lock >/dev/null 2>&1 || true
nix build .#chatgpt >/dev/null 2>&1 && echo "ok $new" || { echo "build-fail"; exit 1; }
