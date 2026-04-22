@echo off
REM Wrapper Snagit points to as its "Program" output.
REM Snagit passes the captured file path as %1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0snagit-upload.ps1" -File "%~1"
