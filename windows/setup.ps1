# Interactive one-time setup for the Snag Share Windows client.
# Writes endpoint + token to %USERPROFILE%\.config\snag-share\config,
# which snagit-upload.ps1 reads at runtime. Mirrors macos/setup.sh.
#
# Re-run this any time you rotate the token.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$configDir  = Join-Path $env:USERPROFILE '.config\snag-share'
$configPath = Join-Path $configDir 'config'

if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory -Force | Out-Null
}

# Preserve existing values as defaults if the file already exists.
$existingEndpoint = ''
$existingToken    = ''
if (Test-Path $configPath) {
    Get-Content $configPath | ForEach-Object {
        if     ($_ -match '^SNAG_SHARE_ENDPOINT=(.*)$') { $existingEndpoint = $Matches[1] }
        elseif ($_ -match '^SNAG_SHARE_TOKEN=(.*)$')    { $existingToken    = $Matches[1] }
    }
}

# Reveal a SecureString back to a plaintext string (we need plaintext to
# write it into the file; Windows doesn't enforce a secrets-at-rest model
# for arbitrary user-space files, so this is the same trust boundary as
# storing it in an environment variable).
function ConvertFrom-SecureStringPlain {
    param([Security.SecureString]$SecureString)
    if (-not $SecureString) { return '' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Host 'Snag Share setup'
Write-Host '----------------'
Write-Host "Config file: $configPath"
Write-Host ''

# Endpoint prompt
if ($existingEndpoint) {
    $input = Read-Host "Worker endpoint URL [$existingEndpoint]"
    $endpoint = if ($input) { $input } else { $existingEndpoint }
} else {
    $endpoint = Read-Host 'Worker endpoint URL (e.g. https://snag-share.xxx.workers.dev)'
}

# Token prompt — hidden input
if ($existingToken) {
    $secure = Read-Host 'Upload token (input hidden, press Enter to keep existing)' -AsSecureString
    $entered = ConvertFrom-SecureStringPlain $secure
    $token = if ($entered) { $entered } else { $existingToken }
} else {
    $secure = Read-Host 'Upload token (input hidden)' -AsSecureString
    $token = ConvertFrom-SecureStringPlain $secure
}

if (-not $endpoint -or -not $token) {
    Write-Error 'endpoint and token are both required'
    exit 1
}

# Atomic write: write to temp, move over.
$tmp = "$configPath.tmp"
$content = "# Snag Share client config. Edit with windows\setup.ps1.`r`nSNAG_SHARE_ENDPOINT=$endpoint`r`nSNAG_SHARE_TOKEN=$token`r`n"
Set-Content -Path $tmp -Value $content -NoNewline -Encoding UTF8
Move-Item -Path $tmp -Destination $configPath -Force

# Best-effort: restrict ACL to the current user only.
try {
    $acl = Get-Acl $configPath
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $user, 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $configPath -AclObject $acl
} catch {
    Write-Warning "Couldn't tighten ACL on $configPath ($($_.Exception.Message)). File is still usable."
}

Write-Host ''
Write-Host 'Saved.'
Write-Host 'Test with:  windows\snagit-upload.bat C:\path\to\some.png'
