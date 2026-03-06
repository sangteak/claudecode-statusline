# ─────────────────────────────────────────
# Claude Code StatusLine v9
# - SessionStart 캐시 파일 폴백 지원
# - 세션 시작 직후부터 표시
# Font: Hack Nerd Font Mono
# ─────────────────────────────────────────

# ── JSON 로드: stdin 우선, 없으면 캐시 파일 ──
$input_data = $input | Out-String
$cache_path = "$env:USERPROFILE\.claude\statusline-cache.json"

$json = $null
try {
    $trimmed = $input_data.Trim()
    if ($trimmed -ne "" -and $trimmed -ne "{}") {
        $json = $trimmed | ConvertFrom-Json
        # 유효한 JSON이면 캐시 갱신
        $trimmed | Set-Content -Path $cache_path -Encoding UTF8 -ErrorAction SilentlyContinue
    }
} catch {}

# stdin 파싱 실패 시 캐시 파일로 폴백
if ($null -eq $json -and (Test-Path $cache_path)) {
    try {
        $json = Get-Content $cache_path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {}
}

# 그래도 없으면 빈 객체
if ($null -eq $json) { $json = [PSCustomObject]@{} }

# ── 버전 ─────────────────────────────────
$cc_version = $null
if ($json.version -and $json.version -ne "") {
    $cc_version = "v" + $json.version
} else {
    try {
        $ver_raw    = & claude --version 2>$null
        $cc_version = if ($ver_raw -match '(\d+\.\d+\.\d+)') { "v" + $matches[1] } else { "v?" }
    } catch { $cc_version = "v?" }
}

# ── 모델명 ───────────────────────────────
$model_name = $null
if     ($json.model.display_name -and $json.model.display_name -ne "") { $model_name = $json.model.display_name }
elseif ($json.model.id -and $json.model.id -ne "") {
    $model_name = if ($json.model.id -match 'claude-([a-z]+-[\d]+(?:-[\d]+)?)') { $matches[1] } else { $json.model.id }
}
elseif ($json.model.api_model_id -and $json.model.api_model_id -ne "") {
    $model_name = if ($json.model.api_model_id -match 'claude-([a-z]+-[\d]+(?:-[\d]+)?)') { $matches[1] } else { $json.model.api_model_id }
}
else { $model_name = "Claude" }

# ── 컨텍스트 ─────────────────────────────
$ctx_size = if ($json.context_window.context_window_size) { [int]$json.context_window.context_window_size } else { 200000 }

$in_tok = 0; $cache_c = 0; $cache_r = 0
if ($null -ne $json.context_window.current_usage) {
    $in_tok  = if ($json.context_window.current_usage.input_tokens)                { [int]$json.context_window.current_usage.input_tokens }                else { 0 }
    $cache_c = if ($json.context_window.current_usage.cache_creation_input_tokens) { [int]$json.context_window.current_usage.cache_creation_input_tokens } else { 0 }
    $cache_r = if ($json.context_window.current_usage.cache_read_input_tokens)     { [int]$json.context_window.current_usage.cache_read_input_tokens }     else { 0 }
}

$pct = 0.0
if ($null -ne $json.context_window.used_percentage -and [double]$json.context_window.used_percentage -gt 0) {
    $pct = [double]$json.context_window.used_percentage
} elseif ($ctx_size -gt 0 -and ($in_tok + $cache_c + $cache_r) -gt 0) {
    $pct = ($in_tok + $cache_c + $cache_r) * 100.0 / $ctx_size
}
$pct_int = [int]$pct

# ── PWD ──────────────────────────────────
$raw_pwd = if ($json.workspace.current_dir) { $json.workspace.current_dir }
           elseif ($json.cwd)               { $json.cwd }
           else                             { (Get-Location).Path }

$home = $env:USERPROFILE
if ($raw_pwd.StartsWith($home)) { $raw_pwd = "~" + $raw_pwd.Substring($home.Length) }
$raw_pwd = $raw_pwd -replace '\\', '/'
$parts   = $raw_pwd -split '/'
$pwd_str = if ($raw_pwd.Length -gt 35 -and $parts.Count -gt 3) {
    ".../" + $parts[-2] + "/" + $parts[-1]
} else { $raw_pwd }

# ── Git 브랜치 ────────────────────────────
$git_branch = $null; $git_dirty = $false
$work_dir   = if ($json.workspace.current_dir) { $json.workspace.current_dir }
              elseif ($json.cwd)               { $json.cwd }
              else                             { (Get-Location).Path }
try {
    $branch = & git -C $work_dir branch --show-current 2>$null
    if ($LASTEXITCODE -eq 0 -and $branch -and $branch.Trim() -ne "") {
        $git_branch = $branch.Trim()
        $status     = & git -C $work_dir status --porcelain 2>$null
        $git_dirty  = ($status -and $status.Trim() -ne "")
    }
} catch {}

# ── ANSI 헬퍼 ────────────────────────────
function fg($r, $g, $b) { return "$([char]27)[38;2;${r};${g};${b}m" }
$RESET = "$([char]27)[0m"

$FG_DIM     = fg 100 100 120
$FG_WHITE   = fg 220 220 230
$FG_TIME    = fg 160 170 200
$FG_DIR     = fg 120 160 220
$FG_VERSION = fg 150 120 200
$FG_MODEL   = fg 100 180 200
$FG_BRANCH  = fg 180 150 80
$FG_DIRTY   = fg 210 100 80

if ($pct_int -ge 95)      { $bar_r = 220; $bar_g = 60;  $bar_b = 60  }
elseif ($pct_int -ge 80)  { $bar_r = 210; $bar_g = 110; $bar_b = 50  }
elseif ($pct_int -ge 50)  { $bar_r = 200; $bar_g = 170; $bar_b = 50  }
else                      { $bar_r = 80;  $bar_g = 180; $bar_b = 100 }
$FG_BAR   = fg $bar_r $bar_g $bar_b
$FG_EMPTY = fg 60 60 75

$total_bars = 15
$filled     = [int]($pct_int * $total_bars / 100)
$bar_str    = ""
for ($i = 1; $i -le $total_bars; $i++) {
    if ($i -le $filled) { $bar_str += $FG_BAR   + [char]0x2588 }
    else                { $bar_str += $FG_EMPTY + [char]0x2591 }
}

$ICON_VER    = [char]0xF487
$ICON_MODEL  = [char]0xF06E
$ICON_DIR    = [char]0xF07C
$ICON_BRANCH = [char]0xE0A0
$ICON_CTX    = [char]0xF0E7
$ICON_TIME   = [char]0xF017

$DIV      = $FG_DIM + "  │  " + $RESET
$time_str = Get-Date -Format "HH:mm:ss"

$out  = "  "
$out += $FG_VERSION + "$ICON_VER $cc_version"   + $RESET + $DIV
$out += $FG_MODEL   + "$ICON_MODEL $model_name"  + $RESET + $DIV
$out += $FG_DIR     + "$ICON_DIR "               + $RESET
$out += $FG_WHITE   + $pwd_str                   + $RESET

if ($git_branch) {
    $bc = if ($git_dirty) { $FG_DIRTY } else { $FG_BRANCH }
    $dm = if ($git_dirty) { " *" } else { "" }
    $out += $DIV + $bc + "$ICON_BRANCH $git_branch$dm" + $RESET
}

$out += $DIV
$out += $FG_BAR  + "$ICON_CTX "             + $RESET
$out += $bar_str + $RESET + "  "
$out += $FG_BAR  + ("$pct_int%".PadLeft(4)) + $RESET + $DIV
$out += $FG_TIME + "$ICON_TIME $time_str"   + $RESET + "  "

Write-Host $out