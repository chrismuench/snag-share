#!/usr/bin/env bash
# Snagit macOS "Program" share destination.
# Receives a file path as $1, uploads it to the snag-share Worker,
# and copies the returned URL to the clipboard.

set -euo pipefail

# --- CONFIG ---------------------------------------------------------------
# Either edit these two lines, or set them as environment variables in
# ~/.zshenv so you don't keep secrets inside the script itself.
: "${SNAG_SHARE_ENDPOINT:=https://snag-share.YOURSUBDOMAIN.workers.dev}"
: "${SNAG_SHARE_TOKEN:=REPLACE_WITH_YOUR_UPLOAD_TOKEN}"
# --------------------------------------------------------------------------

notify() {
  # title, message
  /usr/bin/osascript -e "display notification \"$2\" with title \"$1\""
}

file="${1:-}"
if [[ -z "$file" || ! -f "$file" ]]; then
  notify "Snag Share" "No file passed to uploader"
  exit 1
fi

# Pick a content type from the extension.
ext="${file##*.}"
ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
case "$ext_lc" in
  png)       ct="image/png" ;;
  jpg|jpeg)  ct="image/jpeg" ;;
  gif)       ct="image/gif" ;;
  webp)      ct="image/webp" ;;
  *)
    notify "Snag Share" "Unsupported file type: .$ext"
    exit 1
    ;;
esac

# Upload.
http_code=0
response="$(
  /usr/bin/curl --silent --show-error --fail-with-body \
    --max-time 60 \
    -X POST "$SNAG_SHARE_ENDPOINT/upload" \
    -H "Authorization: Bearer $SNAG_SHARE_TOKEN" \
    -H "Content-Type: $ct" \
    --data-binary "@$file" 2>&1
)" || http_code=$?

if [[ $http_code -ne 0 ]]; then
  notify "Snag Share upload failed" "$response"
  exit 2
fi

url="$(printf '%s' "$response" | tr -d '\r\n' | awk '{$1=$1; print}')"

if [[ "$url" != http* ]]; then
  notify "Snag Share" "Unexpected response: $url"
  exit 3
fi

# Copy to clipboard (no trailing newline).
printf '%s' "$url" | /usr/bin/pbcopy

notify "Snag Share" "URL copied: $url"
