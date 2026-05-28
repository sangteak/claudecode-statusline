# Claude Code Statusline - Installer (Windows)
# Usage: iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex

$REPO_RAW   = "https://raw.githubusercontent.com/sangteak/claudecode-statusline/main"
$hooks_dir  = "$env:USERPROFILE\.claude\hooks"
$script_dst = "$hooks_dir\statusline.py"
$settings   = "$env:USERPROFILE\.claude\settings.json"

Write-Host ""
Write-Host "  Claude Code Statusline Installer" -ForegroundColor Cyan
Write-Host "  ---------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 1. Detect Python
$py = $null
foreach ($cand in @("python", "py", "python3")) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host "  [1/3] Python not found. Install Python 3 from https://www.python.org/downloads/" -ForegroundColor Red
    return
}
Write-Host "  [1/3] Python found ($py)" -ForegroundColor Green

# 2. Install statusline.py — copy local file if running from a clone, else download
if (-not (Test-Path $hooks_dir)) {
    New-Item -ItemType Directory -Force -Path $hooks_dir | Out-Null
}
$local_py = if ($PSScriptRoot) { Join-Path $PSScriptRoot "statusline.py" } else { $null }
if ($local_py -and (Test-Path $local_py)) {
    Copy-Item $local_py $script_dst -Force
    Write-Host "  [2/3] statusline.py copied from local repo" -ForegroundColor Green
} else {
    try {
        Invoke-WebRequest -Uri "$REPO_RAW/statusline.py" -OutFile $script_dst -UseBasicParsing
        Write-Host "  [2/3] statusline.py downloaded" -ForegroundColor Green
    } catch {
        Write-Host "  [2/3] Download failed: $_" -ForegroundColor Red
        return
    }
}

# 3. Update settings.json
$new_statusline = [PSCustomObject]@{
    type    = "command"
    command = "$py `"$script_dst`""
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
        Write-Host "  [3/3] settings.json updated" -ForegroundColor Green
    } catch {
        Write-Host "  [3/3] settings.json parse failed - add manually:" -ForegroundColor Yellow
        Write-Host "        `"statusLine`": { `"type`": `"command`", `"command`": `"$py $script_dst`" }" -ForegroundColor DarkGray
    }
} else {
    @{ statusLine = $new_statusline } | ConvertTo-Json -Depth 10 | Set-Content $settings -Encoding UTF8
    Write-Host "  [3/3] settings.json created" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done! Restart Claude Code to apply." -ForegroundColor Cyan
Write-Host "  NOTE: Hack Nerd Font Mono required for icons." -ForegroundColor Yellow
Write-Host ""
