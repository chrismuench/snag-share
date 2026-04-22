#!/usr/bin/env bash
# Build a "Snag Share.app" Automator application without ever opening
# Automator.app. An Automator application is just Apple's signed stub
# (the "Automator Application Stub") with a document.wflow file inside.
# Because the launching binary is signed by Apple, Gatekeeper never
# prompts — which dodges the "Press Run to run this script" dialog
# that osacompile-based AppleScript apps trigger on modern macOS.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out="$here/Snag Share.app"
shell_script_path="$here/snagit-upload.command"

if [[ ! -x "$shell_script_path" ]]; then
    echo "error: $shell_script_path is not executable (run: chmod +x \"$shell_script_path\")" >&2
    exit 1
fi

# Locate Apple's Automator Application Stub.
stub=""
for candidate in \
    "/System/Library/Automator/Automator Application Stub.app" \
    "/System/Library/CoreServices/Automator Application Stub.app"; do
    if [[ -d "$candidate" ]]; then
        stub="$candidate"
        break
    fi
done
if [[ -z "$stub" ]]; then
    # Last resort — search Spotlight's index.
    stub="$(mdfind -name 'Automator Application Stub.app' 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$stub" || ! -d "$stub" ]]; then
    echo "error: Automator Application Stub.app not found on this system." >&2
    echo "       It ships with macOS by default — is Automator installed?" >&2
    exit 1
fi

echo "Using Automator stub at: $stub"

# Wipe any previous build and copy the stub fresh.
rm -rf "$out"
cp -R "$stub" "$out"
chmod -R u+w "$out"

# Write the workflow XML. The critical bits:
#   workflowTypeIdentifier = application        → standalone app, not a Service
#   inputTypeIdentifier = fileSystemObject      → accepts a file as input
#   ActionName = Run Shell Script               → only action, runs bash
#   inputMethod = 1                             → pass input as arguments ($1, $2, ...)
#   shell = /bin/bash
#   COMMAND_STRING = invoke our uploader with the first file
workflow="$out/Contents/document.wflow"

cat > "$workflow" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>512</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>*</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>*</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>"${shell_script_path}" "\$1"</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>5A1A8C6B-0001-4E2F-8E1C-F02B0A4B4C5D</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>5A1A8C6B-0002-4E2F-8E1C-F02B0A4B4C5E</string>
				<key>UUID</key>
				<string>5A1A8C6B-0003-4E2F-8E1C-F02B0A4B4C5F</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>isViewVisible</key>
				<true/>
				<key>location</key>
				<string>309.500000:316.000000</string>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<true/>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceApplicationBundleID</key>
		<string></string>
		<key>serviceApplicationPath</key>
		<string></string>
		<key>serviceInputTypeIdentifier</key>
		<string></string>
		<key>serviceOutputTypeIdentifier</key>
		<string></string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>systemImageName</key>
		<string></string>
		<key>useAutomaticInputType</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.application</string>
	</dict>
</dict>
</plist>
PLIST

# Give the bundle a nice name so it shows up as "Snag Share" in Snagit's picker.
info_plist="$out/Contents/Info.plist"
if [[ -f "$info_plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleName 'Snag Share'" "$info_plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 'Snag Share'" "$info_plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 'Snag Share'" "$info_plist" 2>/dev/null || true
fi

# Strip any quarantine xattr so Gatekeeper doesn't re-evaluate the bundle.
xattr -cr "$out" 2>/dev/null || true

# We intentionally do NOT re-codesign. The Automator stub inside is signed by
# Apple, and the Automator runtime accepts workflow XML as data — re-signing
# ad-hoc would just replace Apple's signature with something less trusted.

echo "Built: $out"
echo
echo "Next: in Snagit → Preferences → Share → + → Program,"
echo "pick \"$out\""
