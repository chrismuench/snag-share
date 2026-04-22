# Snagit Windows "Program" share destination.
# Uploads the passed file to the snag-share Worker and copies the URL to the clipboard.
#
# Snagit invokes this via the snagit-upload.bat wrapper, which passes the
# captured file path as the first argument.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $File
)

# --- CONFIG -----------------------------------------------------------------
# Config lives in %USERPROFILE%\.config\snag-share\config (created by
# windows\setup.ps1). It's a KEY=VALUE file parsed here. Env vars win if
# they're already set, which is handy for testing from a shell.
$ConfigPath = Join-Path $env:USERPROFILE '.config\snag-share\config'
if (Test-Path -LiteralPath $ConfigPath) {
    Get-Content -LiteralPath $ConfigPath | ForEach-Object {
        if ($_ -match '^\s*(SNAG_SHARE_ENDPOINT|SNAG_SHARE_TOKEN)=(.*)$') {
            $name  = $Matches[1]
            $value = $Matches[2]
            if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
                [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            }
        }
    }
}

$Endpoint = $env:SNAG_SHARE_ENDPOINT
$Token    = $env:SNAG_SHARE_TOKEN
# ---------------------------------------------------------------------------

function Show-Toast {
    param([string]$Title, [string]$Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.Visible = $true
        $notify.ShowBalloonTip(4000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Milliseconds 500
        $notify.Dispose()
    } catch {
        Write-Host "[$Title] $Message"
    }
}

if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    Show-Toast -Title 'Snag Share' -Message "File not found: $File"
    exit 1
}

if (-not $Endpoint -or -not $Token) {
    Show-Toast -Title 'Snag Share' -Message 'Config missing — run windows\setup.ps1'
    exit 1
}

$ext = [System.IO.Path]::GetExtension($File).TrimStart('.').ToLowerInvariant()
switch ($ext) {
    'png'  { $contentType = 'image/png' }
    'jpg'  { $contentType = 'image/jpeg' }
    'jpeg' { $contentType = 'image/jpeg' }
    'gif'  { $contentType = 'image/gif' }
    'webp' { $contentType = 'image/webp' }
    default {
        Show-Toast -Title 'Snag Share' -Message "Unsupported file type: .$ext"
        exit 1
    }
}

try {
    $bytes = [System.IO.File]::ReadAllBytes($File)
    $headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = $contentType
    }

    # Force TLS 1.2 for older PowerShell on Windows 10.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $response = Invoke-RestMethod -Uri "$Endpoint/upload" `
        -Method Post `
        -Headers $headers `
        -Body $bytes `
        -TimeoutSec 60

    $url = ($response | Out-String).Trim()
    if (-not $url.StartsWith('http')) {
        Show-Toast -Title 'Snag Share' -Message "Unexpected response: $url"
        exit 3
    }

    Set-Clipboard -Value $url
    Show-Toast -Title 'Snag Share' -Message "URL copied: $url"
}
catch {
    Show-Toast -Title 'Snag Share upload failed' -Message $_.Exception.Message
    exit 2
}
