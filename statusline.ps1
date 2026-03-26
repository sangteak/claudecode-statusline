# ─────────────────────────────────────────
# Claude Code StatusLine v11
# - output 토큰 포함 퍼센트 계산
# - 프로젝트별 캐시 파일 ({project}/.claude/statusline-cache.json)
# - 에이전트 추적 (transcript JSONL 파싱)
# Font: Hack Nerd Font Mono
# ─────────────────────────────────────────

# ── 인코딩 강제 설정 (powershell.exe 환경 대응) ──
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ── stdin 파싱 ────────────────────────────
$input_data = $input | Out-String
$json_raw   = $null
try {
    $trimmed = $input_data.Trim()
    if ($trimmed -ne "" -and $trimmed -ne "{}") {
        $json_raw = $trimmed | ConvertFrom-Json
    }
} catch {}

# ── 캐시 경로: 프로젝트 디렉토리 기준 ───────
# stdin JSON이 있으면 workspace.current_dir 사용, 없으면 현재 위치
$proj_dir   = if ($json_raw.workspace.current_dir) { $json_raw.workspace.current_dir }
              elseif ($json_raw.cwd)               { $json_raw.cwd }
              else                                 { (Get-Location).Path }
$cache_dir  = Join-Path $proj_dir ".claude"
$cache_path = Join-Path $cache_dir "statusline-cache.json"

# ── JSON 확정: stdin 우선, 없으면 캐시 폴백 ──
$json = $null
if ($null -ne $json_raw) {
    $json = $json_raw
    # 유효한 JSON이면 프로젝트 캐시 갱신
    try {
        if (-not (Test-Path $cache_dir)) { New-Item -ItemType Directory -Force -Path $cache_dir | Out-Null }
        $trimmed | Set-Content -Path $cache_path -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
} elseif (Test-Path $cache_path) {
    try { $json = Get-Content $cache_path -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
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
# ── 컨텍스트 (live stdin 전용 — 캐시 사용 안 함) ──
$ctx_size = if ($json_raw.context_window.context_window_size) { [int]$json_raw.context_window.context_window_size } else { 200000 }

$in_tok = 0; $out_tok = 0; $cache_c = 0; $cache_r = 0
if ($null -ne $json_raw -and $null -ne $json_raw.context_window.current_usage) {
    $in_tok  = if ($json_raw.context_window.current_usage.input_tokens)                { [int]$json_raw.context_window.current_usage.input_tokens }                else { 0 }
    $out_tok = if ($json_raw.context_window.current_usage.output_tokens)               { [int]$json_raw.context_window.current_usage.output_tokens }               else { 0 }
    $cache_c = if ($json_raw.context_window.current_usage.cache_creation_input_tokens) { [int]$json_raw.context_window.current_usage.cache_creation_input_tokens } else { 0 }
    $cache_r = if ($json_raw.context_window.current_usage.cache_read_input_tokens)     { [int]$json_raw.context_window.current_usage.cache_read_input_tokens }     else { 0 }
}

# output 토큰 포함하여 직접 계산 (used_percentage는 output 미포함이라 사용 안 함)
$pct = 0.0
if ($ctx_size -gt 0 -and ($in_tok + $out_tok + $cache_c + $cache_r) -gt 0) {
    $pct = ($in_tok + $out_tok + $cache_c + $cache_r) * 100.0 / $ctx_size
}
$pct_int = [int]$pct

# ── PWD ──────────────────────────────────
$raw_pwd = if ($json.workspace.current_dir) { $json.workspace.current_dir }
           elseif ($json.cwd)               { $json.cwd }
           else                             { (Get-Location).Path }

$home_dir = $env:USERPROFILE
if ($raw_pwd.StartsWith($home_dir)) { $raw_pwd = "~" + $raw_pwd.Substring($home_dir.Length) }
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

# ── 에이전트 추적 (transcript JSONL) ─────
function Get-RunningAgents {
    param([string]$TranscriptPath, [string]$CacheDir)

    $empty = @()

    # 경로 없으면 즉시 반환
    if (-not $TranscriptPath -or $TranscriptPath -eq "") { return $empty }
    if (-not (Test-Path $TranscriptPath)) { return $empty }

    # mtime+size 캐시 판별
    $agents_cache_path = Join-Path $CacheDir "statusline-agents-cache.json"
    $file_info = Get-Item $TranscriptPath -ErrorAction SilentlyContinue
    if (-not $file_info) { return $empty }

    $current_mtime = $file_info.LastWriteTimeUtc.Ticks
    $current_size  = $file_info.Length

    # 캐시 히트 확인
    if (Test-Path $agents_cache_path) {
        try {
            $cached = Get-Content $agents_cache_path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cached.transcript_mtime -eq $current_mtime -and $cached.transcript_size -eq $current_size) {
                if ($cached.agents -and $cached.agents.Count -gt 0) {
                    return @($cached.agents)
                }
                return $empty
            }
        } catch {}
    }

    # 캐시 미스 — 전체 JSONL 파싱
    $tool_uses = @{}
    $tool_results = @{}

    try {
        # 전체 파일을 한 번에 읽음 — 대용량 세션에서는 성능 병목이 될 수 있음 (향후 최적화 가능)
        $lines = Get-Content $TranscriptPath -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $lines) { return $empty }

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -eq "") { continue }

            try {
                $entry = $line | ConvertFrom-Json

                if ($entry.type -eq "assistant" -and $entry.message.content) {
                    foreach ($block in $entry.message.content) {
                        if ($block.type -eq "tool_use" -and $block.name -eq "Agent") {
                            $inp = $block.input
                            $tool_uses[$block.id] = @{
                                tool_use_id   = $block.id
                                subagent_type = if ($inp.subagent_type) { $inp.subagent_type } else { "agent" }
                                description   = if ($inp.description) { $inp.description } else { "" }
                                model         = if ($inp.model) { $inp.model } else { $null }
                                timestamp     = if ($entry.timestamp) { $entry.timestamp } else { $null }
                            }
                        }
                    }
                }
                elseif ($entry.type -eq "user" -and $entry.message.content) {
                    foreach ($block in $entry.message.content) {
                        if ($block.type -eq "tool_result" -and $block.tool_use_id) {
                            if ($tool_uses.ContainsKey($block.tool_use_id)) {
                                $tool_results[$block.tool_use_id] = $true
                            }
                        }
                    }
                }
            } catch {
                continue
            }
        }
    } catch {
        return $empty
    }

    # running 에이전트 추출
    $running = @()
    foreach ($id in $tool_uses.Keys) {
        if (-not $tool_results.ContainsKey($id)) {
            $running += [PSCustomObject]$tool_uses[$id]
        }
    }
    $running = $running | Sort-Object { $_.timestamp }

    # 캐시 갱신
    try {
        if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }
        $cache_obj = @{
            transcript_mtime = $current_mtime
            transcript_size  = $current_size
            agents           = $running
        }
        $cache_obj | ConvertTo-Json -Depth 5 | Set-Content -Path $agents_cache_path -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}

    return $running
}

function Format-AgentDetail {
    param(
        [PSCustomObject]$Agent,
        [string]$FgIcon,
        [string]$FgName,
        [string]$FgDesc,
        [string]$FgTime,  # 경과 시간 색상 — 호출자는 $FG_TIME 전달 권장
        [string]$Reset
    )

    $icon = [char]0x25D0  # ◐

    $name = if ($Agent.subagent_type) { $Agent.subagent_type } else { "agent" }

    $model_tag = ""
    if ($Agent.model) {
        $model_tag = " ${FgDesc}[$($Agent.model)]${Reset}"
    }

    $desc = ""
    if ($Agent.description -and $Agent.description -ne "") {
        $d = $Agent.description
        if ($d.Length -gt 40) { $d = $d.Substring(0, 37) + "..." }
        $desc = ": ${FgDesc}${d}${Reset}"
    }

    $elapsed = ""
    if ($Agent.timestamp) {
        try {
            $start = [DateTime]::Parse($Agent.timestamp).ToUniversalTime()
            $now   = [DateTime]::UtcNow
            $diff  = $now - $start
            $total_sec = [int]$diff.TotalSeconds
            if ($total_sec -lt 1)  { $elapsed = "<1s" }
            elseif ($total_sec -lt 60) { $elapsed = "${total_sec}s" }
            else {
                $m = [int][Math]::Floor($diff.TotalMinutes)
                $s = $total_sec % 60
                $elapsed = "${m}m ${s}s"
            }
        } catch { $elapsed = "?" }
    }
    $elapsed_str = if ($elapsed -ne "") { " ${FgTime}(${elapsed})${Reset}" } else { "" }

    return "${FgIcon}${icon} ${FgName}${name}${Reset}${model_tag}${desc}${elapsed_str}"
}

$transcript_path = if ($json.transcript_path) { $json.transcript_path } else { "" }
$running_agents  = @(Get-RunningAgents -TranscriptPath $transcript_path -CacheDir $cache_dir)
$agent_count     = $running_agents.Count

# ── ANSI 헬퍼 ────────────────────────────
function fg($r, $g, $b) { return "$([char]27)[38;2;${r};${g};${b}m" }
$RESET = "$([char]27)[0m"

$FG_DIM     = fg 100 100 120
$FG_WHITE   = fg 220 220 230
$FG_TIME    = fg 160 170 200  # 시간 표시 및 에이전트 경과 시간용 (Format-AgentDetail $FgTime 인자로 전달)
$FG_DIR     = fg 120 160 220
$FG_VERSION = fg 150 120 200
$FG_MODEL   = fg 100 180 200
$FG_BRANCH  = fg 180 150 80
$FG_DIRTY   = fg 210 100 80
$FG_AGENT      = fg 210 150 50   # 주황 — 에이전트 카운트/아이콘
$FG_AGENT_NAME = fg 180 100 200  # 마젠타 — subagent_type
$FG_AGENT_DESC = fg 180 180 195  # 밝은 회색 — description

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

$DIV      = $FG_DIM + "  $([char]0x2502)  " + $RESET
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
$out += $FG_BAR  + ("$pct_int%".PadLeft(4)) + $RESET

# 에이전트 카운트 (running > 0일 때만)
if ($agent_count -gt 0) {
    $ICON_AGENT_SPIN = [char]0x25D0  # ◐
    $agent_label = if ($agent_count -eq 1) { "agent" } else { "agents" }
    $out += $DIV + $FG_AGENT + "$ICON_AGENT_SPIN $agent_count $agent_label" + $RESET
}

$out += $DIV
$out += $FG_TIME + "$ICON_TIME $time_str"   + $RESET + "  "

Write-Host $out

# 상세 에이전트 줄 (5초 이상 running만)
if ($agent_count -gt 0) {
    $now_utc = [DateTime]::UtcNow
    $long_running = @()
    foreach ($ag in $running_agents) {
        if ($ag.timestamp) {
            try {
                $start = [DateTime]::Parse($ag.timestamp).ToUniversalTime()
                $diff  = ($now_utc - $start).TotalSeconds
                if ($diff -ge 5) { $long_running += $ag }
            } catch {}
        }
    }

    if ($long_running.Count -gt 0) {
        # 최대 3개 표시 (가장 오래된 순 — 이미 정렬됨)
        $to_show = if ($long_running.Count -gt 3) { $long_running[0..2] } else { $long_running }

        $detail_parts = @()
        foreach ($ag in $to_show) {
            $detail_parts += Format-AgentDetail -Agent $ag `
                -FgIcon $FG_AGENT -FgName $FG_AGENT_NAME `
                -FgDesc $FG_AGENT_DESC -FgTime $FG_TIME -Reset $RESET
        }

        $more = ""
        if ($long_running.Count -gt 3) {
            $extra = $long_running.Count - 3
            $more = "  ${FG_DIM}+${extra} more${RESET}"
        }

        $detail_line = "  " + ($detail_parts -join ($FG_DIM + "  $([char]0x2502)  " + $RESET)) + $more
        Write-Host $detail_line
    }
}
