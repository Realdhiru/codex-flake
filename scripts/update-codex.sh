#!/usr/bin/env bash
set -Eeuo pipefail

DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
NIX_FILE="pkgs/chatgpt.nix"

die() { echo "ERROR: $*" >&2; exit 1; }
trap 'status=$?; echo "ERROR: update-codex.sh failed at line $LINENO (exit $status)." >&2; exit "$status"' ERR

[[ -f "$NIX_FILE" ]] || die "Run this script from the repository root; missing $NIX_FILE."
command -v nix-prefetch-url >/dev/null || die "nix-prefetch-url is required."
command -v nix >/dev/null || die "nix is required."

current_hash="$(sed -n 's/.*sha256 = "\([^"]*\)".*/\1/p' "$NIX_FILE" | head -n1)"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "$NIX_FILE" | head -n1)"
[[ -n "$current_hash" && -n "$current_version" ]] || die "Could not read current version and hash from $NIX_FILE."

echo "Checking the official Codex Debian package..."
new_hash="$(nix-prefetch-url "$DEB_URL" | tail -n1)"
[[ "$new_hash" =~ ^[0-9abcdfghijklmnpqrsvwxyz]{52}$ ]] || die "Could not obtain a valid Nix base32 SHA256 from $DEB_URL."

if [[ "$current_hash" == "$new_hash" ]]; then
  echo "Codex is already current ($current_version)."
  echo "changed=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# The /latest URL does not publish a stable version in its filename. Read the
# Debian control metadata from the downloaded artifact so version and hash stay
# paired. nix-prefetch-url has already cached the bytes in the Nix store.
store_path="$(nix-prefetch-url "$DEB_URL" --print-path | tail -n1)"
command -v dpkg-deb >/dev/null || die "dpkg-deb is required to read package metadata."
new_version="$(dpkg-deb -f "$store_path" Version | sed 's/-[^-]*$//')"
[[ "$new_version" =~ ^[0-9]+([.][0-9A-Za-z+~:-]+)*$ ]] || die "Could not read a valid Debian package version (got '$new_version')."

sed -i \
  -e "s/^[[:space:]]*version = \".*\";/  version = \"$new_version\";/" \
  -e "s/^[[:space:]]*sha256 = \".*\";/    sha256 = \"$new_hash\";/" \
  "$NIX_FILE"

echo "Updated Codex $current_version -> $new_version; building package..."
nix build .#chatgpt --print-build-logs
echo "changed=true" >> "${GITHUB_OUTPUT:-/dev/null}"
