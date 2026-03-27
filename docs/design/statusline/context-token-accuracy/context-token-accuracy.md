# Context Token Accuracy

## 개요

StatusLine의 context 사용량 표시가 Claude Code 기본 Statusline과 ~3% 차이가 나고,
Claude Code 내부 시스템 경고와는 ~9% 차이가 나는 문제에 대한 분석 및 결정.

## 문제 분석

### 세 가지 계산 계층

| 계층 | 공식 | 특성 |
|------|------|------|
| **Claude Code 기본 Statusline** | `used_percentage` (output 미포함) | 공식 제공값 |
| **우리 StatusLine (변경 전)** | `(input + output + cache_c + cache_r) / ctx_size` | output 포함, 시스템 오버헤드 누락 |
| **Claude Code 내부 경고** | 모든 토큰 + 시스템 오버헤드 포함, autocompact 버퍼 차감 | 가장 보수적 |

### 수치 시뮬레이션 (1M context, input=500K, output=30K, cache=60K, sys_overhead=50K)

- Claude Code 기본: **56%**
- 우리 StatusLine (변경 전): **59%** (+3%)
- Claude Code 내부 경고: **~66%** (+10%)

### 근본 원인

`context_window.current_usage` 필드에 **시스템 오버헤드가 포함되지 않음**:
- system prompt
- tool definitions (~16K-57K tokens)
- MCP schemas
- CLAUDE.md 내용

이는 Claude Code 측의 알려진 이슈:
- GitHub #17959: `used_percentage`가 내부 경고와 불일치
- GitHub #21651: statusLine 퍼센트가 UI 퍼센트와 불일치
- GitHub #28389: 인프라 오버헤드로 실제 사용 가능 context 감소

## 결정

### 선택: Claude Code 기본 Statusline과 동일한 수치 사용

**`used_percentage` 필드를 직접 사용한다.**

### 근거

1. **일관성**: Claude Code 기본 UI와 동일한 수치 → 사용자 혼란 제거
2. **공식 데이터**: Anthropic이 제공하는 공식 계산값 사용
3. **유지보수**: 계산 로직 변경 시 자동 반영
4. **시스템 오버헤드 문제**: Claude Code 팀이 해결해야 할 이슈 (외부에서 추정 불가)

### 변경 내용

**Before** (statusline.ps1:73-86):
```powershell
$in_tok = 0; $out_tok = 0; $cache_c = 0; $cache_r = 0
if ($null -ne $json_raw -and $null -ne $json_raw.context_window.current_usage) {
    $in_tok  = ...
    $out_tok = ...
    $cache_c = ...
    $cache_r = ...
}
# output 토큰 포함하여 직접 계산
$pct = ($in_tok + $out_tok + $cache_c + $cache_r) * 100.0 / $ctx_size
$pct_int = [int]$pct
```

**After**:
```powershell
# Claude Code 기본 Statusline과 동일한 수치 사용
$pct_int = if ($null -ne $json_raw -and $null -ne $json_raw.context_window.used_percentage) {
    [int]$json_raw.context_window.used_percentage
} else { 0 }
```

### 영향 범위

- `$pct_int` 이후 코드 (색상, 프로그레스바, 표시): **변경 없음**
- 개별 토큰 변수 (`$in_tok`, `$out_tok`, `$cache_c`, `$cache_r`): **제거**
- `$ctx_size`: context window 크기 표시용으로 **유지**

## 참고

- Claude Code 내부 경고와의 ~9% 차이는 여전히 존재
- 이는 `used_percentage` 자체의 한계이며, Claude Code 팀의 수정 대상
- 사용자는 이 차이를 인지하고 여유 있게 HANDOFF 타이밍을 잡을 것
