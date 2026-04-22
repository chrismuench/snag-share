#!/usr/bin/env bash
# Compile snag-share.applescript into a "Snag Share.app" bundle that
# Snagit's Share → Program output will accept.
#
# Run from the repo root:  ./macos/build-app.sh

set -euo pipefail

# Resolve the repo root = parent of the directory this script lives in.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"

src="$here/snag-share.applescript"
out="$here/Snag Share.app"
shell_script_path="$here/snagit-upload.command"

if [[ ! -x "$shell_script_path" ]]; then
    echo "error: $shell_script_path is not executable (run: chmod +x \"$shell_script_path\")"
    exit 1
fi

# Substitute the placeholder with the real absolute path to the uploader.
tmp_applescript="$(mktemp -t snag-share.XXXXXX).applescript"
sed "s|__SCRIPT_PATH__|${shell_script_path}|g" "$src" > "$tmp_applescript"

# Remove any previous build.
rm -rf "$out"

osacompile -o "$out" "$tmp_applescript"
rm -f "$tmp_applescript"

echo "Built: $out"
echo
echo "Next: in Snagit → Preferences → Share → + → Program,"
echo "pick \"$out\""
