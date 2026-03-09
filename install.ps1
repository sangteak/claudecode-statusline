# Claude Code Statusline - Installer
# Usage: iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex

# Detect pipe execution (iwr | iex): re-launch as new process to avoid $HOME conflict
if (-not $MyInvocation.MyCommand.Path) {
    $tmp = "$env:TEMP\cc-statusline-install.ps1"
    $MyInvocation.MyCommand.ScriptBlock | Out-File -FilePath $tmp -Encoding UTF8
    powershell -ExecutionPolicy Bypass -File $tmp
    exit
}

$REPO_RAW   = "https://raw.githubusercontent.com/sangteak/claudecode-statusline/main"
$hooks_dir  = "$env:USERPROFILE\.claude\hooks"
$script_dst = "$hooks_dir\statusline.ps1"
$settings   = "$env:USERPROFILE\.claude\settings.json"

Write-Host ""
Write-Host "  Claude Code Statusline Installer" -ForegroundColor Cyan
Write-Host "  ---------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 1. Execution policy
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted' -or $policy -eq 'Undefined') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  [1/4] Execution policy -> RemoteSigned" -ForegroundColor Green
} else {
    Write-Host "  [1/4] Execution policy OK ($policy)" -ForegroundColor Green
}

# 2. Create hooks directory
if (-not (Test-Path $hooks_dir)) {
    New-Item -ItemType Directory -Force -Path $hooks_dir | Out-Null
}
Write-Host "  [2/4] Hooks directory ready" -ForegroundColor Green

# 3. Download statusline.ps1
try {
    Invoke-WebRequest -Uri "$REPO_RAW/statusline.ps1" -OutFile $script_dst -UseBasicParsing
    Write-Host "  [3/4] statusline.ps1 downloaded" -ForegroundColor Green
} catch {
    Write-Host "  [3/4] Download failed: $_" -ForegroundColor Red
    exit 1
}

# 4. Update settings.json
$new_statusline = [PSCustomObject]@{
    type    = "command"
    command = "powershell -File `"$script_dst`""
}

if (Test-Path $settings) {
    try {
        $raw = Get-Content $settings -Raw -Encoding UTF8
        $s   = $raw | ConvertFrom-Json

        if ($s.PSObject.Properties['statusLine']) {
            $s.statusLine = $new_statusline
        } else {
            $s | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $new_statusline
        }

        $s | ConvertTo-Json -Depth 10 | Set-Content $settings -Encoding UTF8
        Write-Host "  [4/4] settings.json updated" -ForegroundColor Green
    } catch {
        Write-Host "  [4/4] settings.json parse failed - add manually:" -ForegroundColor Yellow
        Write-Host "        `"statusLine`": { `"type`": `"command`", `"command`": `"powershell -File $script_dst`" }" -ForegroundColor DarkGray
    }
} else {
    @{ statusLine = $new_statusline } | ConvertTo-Json -Depth 10 | Set-Content $settings -Encoding UTF8
    Write-Host "  [4/4] settings.json created" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done! Restart Claude Code to apply." -ForegroundColor Cyan
Write-Host "  NOTE: Hack Nerd Font Mono required for icons." -ForegroundColor Yellow
Write-Host ""
