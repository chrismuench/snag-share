#!/usr/bin/env bash
# Interactive one-time setup for the Snag Share client.
# Writes endpoint + token into ~/.config/snag-share/config, which the
# shell script and AppleScript both read at runtime.
#
# Re-run this any time you rotate the token.

set -euo pipefail

CONFIG_DIR="$HOME/.config/snag-share"
CONFIG_FILE="$CONFIG_DIR/config"

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Preserve existing values as defaults if the file already exists.
existing_endpoint=""
existing_token=""
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    existing_endpoint="${SNAG_SHARE_ENDPOINT:-}"
    existing_token="${SNAG_SHARE_TOKEN:-}"
fi

echo "Snag Share setup"
echo "----------------"
echo "Config file: $CONFIG_FILE"
echo

if [[ -n "$existing_endpoint" ]]; then
    read -rp "Worker endpoint URL [$existing_endpoint]: " endpoint
    endpoint="${endpoint:-$existing_endpoint}"
else
    read -rp "Worker endpoint URL (e.g. https://snag-share.xxx.workers.dev): " endpoint
fi

if [[ -n "$existing_token" ]]; then
    read -rsp "Upload token (input hidden, press Enter to keep existing): " token
    echo
    token="${token:-$existing_token}"
else
    read -rsp "Upload token (input hidden): " token
    echo
fi

if [[ -z "$endpoint" || -z "$token" ]]; then
    echo "error: endpoint and token are both required" >&2
    exit 1
fi

# Write atomically so an interrupted run doesn't corrupt the file.
tmp_file="$(mktemp "$CONFIG_DIR/config.XXXXXX")"
cat > "$tmp_file" <<EOF
# Snag Share client config. Edit with macos/setup.sh.
SNAG_SHARE_ENDPOINT=$endpoint
SNAG_SHARE_TOKEN=$token
EOF
chmod 600 "$tmp_file"
mv -f "$tmp_file" "$CONFIG_FILE"

echo
echo "Saved."
echo "Test with:  ./macos/snagit-upload.command /tmp/some.png"
