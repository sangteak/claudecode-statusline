# ═══════════════════════════════════════════════════════
# Claude Code Statusline - Installer
# 사용법: iwr https://raw.githubusercontent.com/{username}/claude-statusline/main/install.ps1 | iex
# ═══════════════════════════════════════════════════════

$REPO_RAW   = "https://raw.githubusercontent.com/{username}/claude-statusline/main"
$hooks_dir  = "$env:USERPROFILE\.claude\hooks"
$script_dst = "$hooks_dir\statusline.ps1"
$settings   = "$env:USERPROFILE\.claude\settings.json"

Write-Host ""
Write-Host "  Claude Code Statusline Installer" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# ── 1. 실행 정책 확인 ─────────────────────
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted' -or $policy -eq 'Undefined') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  [1/4] 실행 정책 설정 완료 (RemoteSigned)" -ForegroundColor Green
} else {
    Write-Host "  [1/4] 실행 정책 확인 ($policy)" -ForegroundColor Green
}

# ── 2. hooks 디렉토리 생성 ────────────────
if (-not (Test-Path $hooks_dir)) {
    New-Item -ItemType Directory -Force -Path $hooks_dir | Out-Null
}
Write-Host "  [2/4] hooks 디렉토리 준비 완료" -ForegroundColor Green

# ── 3. statusline.ps1 다운로드 ───────────
try {
    Invoke-WebRequest -Uri "$REPO_RAW/statusline.ps1" -OutFile $script_dst -UseBasicParsing
    Write-Host "  [3/4] statusline.ps1 다운로드 완료" -ForegroundColor Green
} catch {
    Write-Host "  [3/4] 다운로드 실패: $_" -ForegroundColor Red
    exit 1
}

# ── 4. settings.json 업데이트 ────────────
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
        Write-Host "  [4/4] settings.json 업데이트 완료" -ForegroundColor Green
    } catch {
        Write-Host "  [4/4] settings.json 파싱 실패 - 수동으로 추가해주세요:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host '  "statusLine": {' -ForegroundColor DarkGray
        Write-Host "    `"type`": `"command`"," -ForegroundColor DarkGray
        Write-Host "    `"command`": `"powershell -File $script_dst`"" -ForegroundColor DarkGray
        Write-Host '  }' -ForegroundColor DarkGray
    }
} else {
    # settings.json 없으면 새로 생성
    @{ statusLine = $new_statusline } | ConvertTo-Json -Depth 10 | Set-Content $settings -Encoding UTF8
    Write-Host "  [4/4] settings.json 생성 완료" -ForegroundColor Green
}

# ── 완료 ─────────────────────────────────
Write-Host ""
Write-Host "  ✅ 설치 완료!" -ForegroundColor Cyan
Write-Host ""
Write-Host "  설치된 파일:" -ForegroundColor DarkGray
Write-Host "    $script_dst" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ⚠  Hack Nerd Font Mono 가 설치되어 있어야 아이콘이 정상 표시됩니다." -ForegroundColor Yellow
Write-Host "  →  Claude Code를 재시작하면 statusline이 적용됩니다." -ForegroundColor White
Write-Host ""