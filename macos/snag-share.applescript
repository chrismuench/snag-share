-- Snag Share launcher
--
-- Snagit's "Program" share output on macOS only accepts .app bundles, not
-- shell scripts. This tiny AppleScript is compiled into a .app so Snagit can
-- pick it; when Snagit hands it a captured file (via the Apple Event "odoc"),
-- we shell out to snagit-upload.command with the file path.
--
-- Build it with macos/build-app.sh.

property script_path : "__SCRIPT_PATH__"

on open these_files
	-- The shell script loads its own config from ~/.config/snag-share/config,
	-- so we don't need to propagate any environment here.
	repeat with f in these_files
		try
			do shell script quoted form of script_path & " " & quoted form of (POSIX path of f)
		on error errMsg number errNum
			display notification ("Error " & errNum & ": " & errMsg) with title "Snag Share"
		end try
	end repeat
end open

on run
	display dialog "Snag Share is a launcher for Snagit's Share → Program output. Configure it there, or drop a PNG onto this app's icon to test." buttons {"OK"} default button "OK"
end run
