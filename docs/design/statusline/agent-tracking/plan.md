# Agent Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** statusline.ps1에 transcript JSONL 파싱 기반 에이전트 추적 기능을 추가하여, 기본 줄에 running 에이전트 카운트를, 5초 이상 에이전트는 상세 줄로 표시한다.

**Architecture:** 기존 statusline.ps1의 선형 파이프라인 구조를 유지하면서, `Get-RunningAgents`와 `Format-AgentDetail` 두 함수를 추가하여 JSONL 파싱 복잡도를 격리한다. mtime+size 기반 캐시로 성능을 보장하고, 기존 코드는 출력 조립부 2곳만 수정한다.

**Tech Stack:** PowerShell 5.1+, ANSI escape codes, JSONL parsing, Hack Nerd Font Mono

**Design Doc:** `docs/design/statusline/agent-tracking/agent-tracking.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `statusline.ps1` | Modify | 함수 2개 추가 + ANSI 색상 추가 + 출력 조립 수정 |
| `.claude/statusline-agents-cache.json` | Create (runtime) | 에이전트 파싱 캐시 (mtime, size, agents 배열) |

단일 파일 제약: 모든 코드는 `statusline.ps1` 안에 존재한다.

---

### Task 1: 버전 헤더 업데이트 + ANSI 색상 추가

**Files:**
- Modify: `statusline.ps1:1-6` (헤더 주석)
- Modify: `statusline.ps1:113-131` (ANSI 헬퍼 섹션)
- Modify: `statusline.ps1:141-146` (아이콘 정의)

- [ ] **Step 1: 버전 헤더를 v11로 업데이트하고 에이전트 추적 설명 추가**

```powershell
# ─────────────────────────────────────────
# Claude Code StatusLine v11
# - output 토큰 포함 퍼센트 계산
# - 프로젝트별 캐시 파일 ({project}/.claude/statusline-cache.json)
# - 에이전트 추적 (transcript JSONL 파싱)
# Font: Hack Nerd Font Mono
# ─────────────────────────────────────────
```

- [ ] **Step 2: 에이전트 전용 ANSI 색상 변수 추가**

`$FG_DIRTY` 정의(124줄) 바로 아래에 추가:

```powershell
$FG_AGENT      = fg 210 150 50   # 주황 — 에이전트 카운트/아이콘
$FG_AGENT_NAME = fg 180 100 200  # 마젠타 — subagent_type
$FG_AGENT_DESC = fg 180 180 195  # 밝은 회색 — description
```

- [ ] **Step 3: 에이전트 아이콘 정의 추가**

`$ICON_TIME` 정의(146줄) 바로 아래에 추가:

```powershell
$ICON_AGENT  = [char]0xF0E7  # ⚡ (또는 적합한 Nerd Font 아이콘)
```

- [ ] **Step 4: 수정 확인**

Run: `powershell -File statusline.ps1 < /dev/null`
Expected: 기존과 동일한 출력 (에이전트 관련 코드가 아직 출력에 연결되지 않음)

---

### Task 2: Get-RunningAgents 함수 구현

**Files:**
- Modify: `statusline.ps1` — Git 브랜치 섹션(111줄) 뒤, ANSI 헬퍼(113줄) 앞에 함수 삽입

- [ ] **Step 1: Get-RunningAgents 함수 — 캐시 히트 경로**

`} catch {}` (111줄) 뒤에 삽입:

```powershell
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
                # 캐시 히트 — 저장된 에이전트 배열 반환
                if ($cached.agents -and $cached.agents.Count -gt 0) {
                    return $cached.agents
                }
                return $empty
            }
        } catch {}
    }

    # 캐시 미스 — 전체 JSONL 파싱
    $tool_uses = @{}   # tool_use_id → agent info
    $tool_results = @{} # tool_use_id → $true (완료됨)

    try {
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
                            # tool_uses에 존재하는 Agent의 tool_use_id인지 확인
                            if ($tool_uses.ContainsKey($block.tool_use_id)) {
                                $tool_results[$block.tool_use_id] = $true
                            }
                        }
                    }
                }
            } catch {
                # 개별 줄 파싱 실패 — 스킵
                continue
            }
        }
    } catch {
        return $empty
    }

    # running 에이전트 추출 (tool_result가 없는 tool_use)
    $running = @()
    foreach ($id in $tool_uses.Keys) {
        if (-not $tool_results.ContainsKey($id)) {
            $running += [PSCustomObject]$tool_uses[$id]
        }
    }

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
```

- [ ] **Step 2: 함수 호출 추가**

Get-RunningAgents 함수 정의 직후에 호출 코드 추가:

```powershell
$transcript_path = if ($json.transcript_path) { $json.transcript_path } else { "" }
$running_agents  = @(Get-RunningAgents -TranscriptPath $transcript_path -CacheDir $cache_dir)
$agent_count     = $running_agents.Count
```

- [ ] **Step 3: 동작 확인**

Run: `powershell -File statusline.ps1 < /dev/null`
Expected: 기존과 동일한 출력. `$agent_count`는 0 (transcript 없으므로).

---

### Task 3: Format-AgentDetail 함수 구현

**Files:**
- Modify: `statusline.ps1` — Get-RunningAgents 함수 호출 코드 뒤, ANSI 헬퍼 섹션 앞에 삽입

- [ ] **Step 1: Format-AgentDetail 함수 작성**

```powershell
function Format-AgentDetail {
    param(
        [PSCustomObject]$Agent,
        [string]$FgIcon,
        [string]$FgName,
        [string]$FgDesc,
        [string]$FgTime,
        [string]$Reset
    )

    # 상태 아이콘
    $icon = [char]0x25D0  # ◐

    # subagent_type
    $name = if ($Agent.subagent_type) { $Agent.subagent_type } else { "agent" }

    # model 태그 (있을 때만)
    $model_tag = ""
    if ($Agent.model) {
        $model_tag = " ${FgDesc}[$($Agent.model)]${Reset}"
    }

    # description (40자 truncate)
    $desc = ""
    if ($Agent.description -and $Agent.description -ne "") {
        $d = $Agent.description
        if ($d.Length -gt 40) { $d = $d.Substring(0, 37) + "..." }
        $desc = ": ${FgDesc}${d}${Reset}"
    }

    # 경과시간
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
```

- [ ] **Step 2: 동작 확인**

Run: `powershell -File statusline.ps1 < /dev/null`
Expected: 기존과 동일한 출력. 함수가 정의만 되고 호출되지 않으므로 영향 없음.

---

### Task 4: 기본 줄에 에이전트 카운트 삽입

**Files:**
- Modify: `statusline.ps1:163-167` (출력 조립부 — 컨텍스트 바 ~ 시간)

- [ ] **Step 1: 컨텍스트 바와 시간 사이에 에이전트 카운트 삽입**

기존 코드 (163~167줄):
```powershell
$out += $DIV
$out += $FG_BAR  + "$ICON_CTX "             + $RESET
$out += $bar_str + $RESET + "  "
$out += $FG_BAR  + ("$pct_int%".PadLeft(4)) + $RESET + $DIV
$out += $FG_TIME + "$ICON_TIME $time_str"   + $RESET + "  "
```

변경 후:
```powershell
$out += $DIV
$out += $FG_BAR  + "$ICON_CTX "             + $RESET
$out += $bar_str + $RESET + "  "
$out += $FG_BAR  + ("$pct_int%".PadLeft(4)) + $RESET

# 에이전트 카운트 (running > 0일 때만)
if ($agent_count -gt 0) {
    $ICON_AGENT_SPIN = [char]0x25D0  # ◐
    $out += $DIV + $FG_AGENT + "$ICON_AGENT_SPIN $agent_count" + $RESET
}

$out += $DIV
$out += $FG_TIME + "$ICON_TIME $time_str"   + $RESET + "  "
```

- [ ] **Step 2: 동작 확인 (에이전트 0개)**

Run: `powershell -File statusline.ps1 < /dev/null`
Expected: 기존과 동일한 출력. agent_count=0이므로 카운트 섹션 숨김.

---

### Task 5: 상세 에이전트 줄 출력

**Files:**
- Modify: `statusline.ps1:169` (Write-Host 줄)

- [ ] **Step 1: Write-Host 수정 — 기본 줄 + 조건부 상세 줄**

기존 코드 (169줄):
```powershell
Write-Host $out
```

변경 후:
```powershell
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
        # 최대 3개 표시 (가장 오래된 순)
        $sorted = $long_running | Sort-Object { [DateTime]::Parse($_.timestamp) }
        $to_show = if ($sorted.Count -gt 3) { $sorted[0..2] } else { $sorted }

        $detail_parts = @()
        foreach ($ag in $to_show) {
            $detail_parts += Format-AgentDetail -Agent $ag `
                -FgIcon $FG_AGENT -FgName $FG_AGENT_NAME `
                -FgDesc $FG_AGENT_DESC -FgTime $FG_TIME -Reset $RESET
        }

        $more = ""
        if ($sorted.Count -gt 3) {
            $extra = $sorted.Count - 3
            $more = "  ${FG_DIM}+${extra} more${RESET}"
        }

        $detail_line = "  " + ($detail_parts -join ($FG_DIM + "  $([char]0x2502)  " + $RESET)) + $more
        Write-Host $detail_line
    }
}
```

- [ ] **Step 2: 실제 Claude Code 세션에서 동작 확인**

Claude Code를 실행하여 서브에이전트가 생성되는 작업을 수행한 뒤:
1. 기본 줄에 `◐ N` 카운트가 시간 앞에 표시되는지 확인
2. 5초 이상 에이전트가 있으면 2번째 줄에 상세 정보가 표시되는지 확인
3. 에이전트 완료 후 카운트가 줄어들고 상세 줄이 사라지는지 확인

---

### Task 6: 에이전트 카운트 표시 텍스트 다듬기

**Files:**
- Modify: `statusline.ps1` — Task 4에서 추가한 카운트 코드

- [ ] **Step 1: 카운트 1개일 때 단수/복수 처리**

```powershell
if ($agent_count -gt 0) {
    $ICON_AGENT_SPIN = [char]0x25D0  # ◐
    $agent_label = if ($agent_count -eq 1) { "agent" } else { "agents" }
    $out += $DIV + $FG_AGENT + "$ICON_AGENT_SPIN $agent_count $agent_label" + $RESET
}
```

- [ ] **Step 2: 동작 확인**

Expected: 에이전트 1개 → `◐ 1 agent`, 2개 이상 → `◐ 3 agents`

---

### Task 7: 최종 통합 검증

- [ ] **Step 1: 에이전트 없는 상태 검증**

Run: `powershell -File statusline.ps1 < /dev/null`
Expected: 기존 v10과 동일한 1줄 출력. 에이전트 관련 표시 없음.

- [ ] **Step 2: transcript_path가 있지만 에이전트가 없는 상태 검증**

stdin에 transcript_path를 포함한 JSON을 전달:
```bash
echo '{"transcript_path":"nonexistent.jsonl","version":"2.1.78","model":{"display_name":"Opus 4.6"}}' | powershell -File statusline.ps1
```
Expected: 1줄 출력, 에이전트 카운트 없음 (파일 없으므로).

- [ ] **Step 3: 실제 세션에서 에이전트 생성 시 검증**

Claude Code에서 Agent 도구를 사용하는 작업 수행:
1. 기본 줄에 `◐ N agents` 표시 확인
2. 5초 이상 에이전트 → 상세 줄 표시 확인
3. 5초 미만 에이전트 → 카운트에만 포함, 상세 줄에는 미표시 확인
4. 에이전트 완료 → 카운트 감소 + 상세 줄에서 제거 확인

- [ ] **Step 4: 커밋**

```bash
git add statusline.ps1
git commit -m "feat: add agent tracking to statusline v11

- Parse transcript JSONL for running subagent status
- Show agent count in main line (before timestamp)
- Show detail line for agents running 5+ seconds
- mtime+size cache for performance (separate cache file)
- Hide agent sections when no agents running"
```
