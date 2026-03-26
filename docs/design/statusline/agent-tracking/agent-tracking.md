---
feature: agent-tracking
category: statusline
status: complete
created: 2026-03-26
last-updated: 2026-03-26
dependencies:
  - statusline.ps1 (기존 v10)
affects:
  - statusline.ps1
---

# Agent Tracking 설계 문서

> 한 줄 요약: 병렬 실행 중인 서브에이전트의 존재와 상태를 statusline에 표시하여 사용자의 작업 인지도를 높인다.

## 1. 배경과 동기

Claude Code에서 서브에이전트가 병렬 실행될 때, 채팅 창은 멈춰있는 것처럼 보인다. 사용자는 현재 작업이 메인 세션에서 진행 중인지, 백그라운드 에이전트가 처리 중인지 구분할 수 없다. "계획을 세우겠습니다" 메시지 후 긴 대기 시간이 발생하면 시스템이 작동 중인지 확신하기 어렵다.

claude-hud 프로젝트가 transcript JSONL 파싱으로 이 문제를 해결하고 있으나, TypeScript/Node.js 기반이며 플러그인 형태다. 기존 PowerShell 단일 파일 statusline에 동일 기능을 통합한다.

## 2. 목표와 비목표

### 목표
- GOAL-001: 기본 statusline 줄에 현재 running 에이전트 카운트 표시
- GOAL-002: 5초 이상 running 에이전트의 상세 정보(이름, 상태, 경과시간)를 추가 줄로 표시
- GOAL-003: mtime+size 기반 캐시로 불필요한 재파싱 방지

### 비목표
- 에이전트에 대한 액션(중지/재시작) 기능 — 사용자가 자연어로 별도 요청
- transcript 전체 이력/로그 뷰어 기능
- 다중 파일 모듈화 또는 외부 의존성 도입

## 3. 확정된 요구사항

### 데이터 소스
- REQ-001: stdin JSON의 `transcript_path` 필드로 JSONL 파일 경로 획득 — 우선순위: HIGH
- REQ-002: transcript JSONL에서 Agent tool_use 이벤트 파싱 (type="assistant", content[].name="Agent") — 우선순위: HIGH
- REQ-003: tool_use_id 기반으로 tool_result 매칭하여 running/done 상태 판별 — 우선순위: HIGH

### 표시 형태 (하이브리드)
- REQ-004: 기본 줄에 에이전트 카운트 (`◐ N agents`) — 시간 앞 위치 — 우선순위: HIGH
- REQ-005: 5초 이상 running 에이전트는 추가 줄로 상세 표시 — 우선순위: HIGH
- REQ-006: 상세 줄 최대 3개 에이전트 + 초과 시 "+N more" 요약 — 우선순위: MEDIUM
- REQ-007: 에이전트 0개 → 카운트 섹션 및 상세 줄 숨김 — 우선순위: HIGH
- REQ-008: transcript_path 없음 → 에이전트 섹션 전체 숨김 — 우선순위: HIGH

### 에이전트 정보 표시
- REQ-009: 에이전트 이름 = subagent_type (claude-hud 방식) — 우선순위: HIGH
- REQ-010: description 표시 (최대 40자, 초과 시 `...` truncate) — 우선순위: MEDIUM
- REQ-011: 모델 태그 = Agent input에 `model` 키가 있을 때만 `[model]` 표시 — 우선순위: LOW
- REQ-012: 경과시간 = `Nm Ns` 형식 (예: `2m 15s`, `<1s`) — 우선순위: HIGH
- REQ-013: 완료된 에이전트 즉시 제거 (running만 표시) — 우선순위: HIGH

### 성능
- REQ-014: mtime+size 기반 캐시 — 파일 변경 없으면 캐시 사용 — 우선순위: HIGH
- REQ-015: 캐시 파일 별도 분리 (기존 statusline-cache.json과 별개) — 우선순위: MEDIUM
- REQ-016: 파싱 성능 예산 100~300ms — 우선순위: MEDIUM

### 호환성
- REQ-017: 기존 statusline 출력(버전, 모델, 컨텍스트, Git, 시간) 정상 유지 — 우선순위: HIGH
- REQ-018: 단일 ps1 파일 유지 — 우선순위: HIGH

## 4. 설계 개요

### 출력 레이아웃

```
[1줄-기본] v2.1.77 | Opus 4.6 (1M) | .../dev-workflow | main * | ⚡ ████░░ 0% | ◐ 3 | 🕐 12:51:10
[2줄-상세] ◐ explore [haiku]: Finding auth code (2m 15s) | ◐ general-purpose: Searching codebase (1m 30s)
```

### 데이터 흐름

```
stdin JSON
  ├─ 기존 필드 → 1줄 기본 정보 (변경 없음)
  └─ transcript_path → JSONL 파일
       ├─ mtime+size 변경? ─ No → 캐시 사용
       └─ Yes → 전체 파싱
            ├─ Agent tool_use 수집 (subagent_type, description, model, timestamp, tool_use_id)
            ├─ tool_result 매칭 → running/done 판별
            ├─ running 카운트 → 1줄에 추가
            └─ 5초 이상 running → 2줄 상세 표시
```

### ANSI 색상 정책

| 요소 | RGB | 용도 |
|---|---|---|
| 에이전트 카운트 | (210, 150, 50) 주황 | 활동 상태 암시 |
| 에이전트명 (subagent_type) | (180, 100, 200) 마젠타 | claude-hud 동일 |
| description | (180, 180, 195) 밝은 회색 | $FG_AGENT_DESC 전용 |
| 경과시간 | (160, 170, 200) 연보라 | 기존 FG_TIME 재사용 |
| 상태 아이콘 ◐ | (210, 150, 50) 주황 | 카운트와 통일 |

### 캐시 구조

별도 파일: `.claude/statusline-agents-cache.json`

```json
{
  "transcript_mtime": 1711425600000,
  "transcript_size": 45678,
  "agents": [
    {
      "tool_use_id": "toolu_01...",
      "subagent_type": "explore",
      "description": "Finding auth code",
      "model": null,
      "timestamp": "2026-03-26T04:00:00.000Z",
      "status": "running"
    }
  ]
}
```

## 5. 의존성 맵

| 컴포넌트 | 의존 대상 | 영향받는 컴포넌트 |
|---|---|---|
| statusline.ps1 | stdin JSON (transcript_path) | 터미널 출력 |
| statusline.ps1 | transcript JSONL | 에이전트 상태 |
| .claude/statusline-agents-cache.json | statusline.ps1 | 캐시 성능 |

## 6. 기술 결정 및 대안 검토

| 결정 사항 | 선택 | 근거 | 검토한 대안 | 기각 사유 |
|---|---|---|---|---|
| 파싱 전략 | mtime+size 캐시 | claude-hud 방식, 단일 파일 유지 | 증분 파싱 (byte offset) | 복잡도 높음, 이점 불확실 |
| 파싱 전략 | mtime+size 캐시 | 위와 동일 | 백그라운드 watcher | 별도 프로세스 필요, 단일 파일 위반 |
| 표시 형태 | 하이브리드 (카운트+상세) | Contrarian 비판 반영 | 상세만 | 노이즈 과다 |
| 표시 형태 | 하이브리드 | 위와 동일 | 카운트만 | 정보 부족 |
| 5초 필터 | 적용 | 짧은 에이전트 노이즈 제거 | 필터 없음 | UX 분산 |
| 모델 태그 | input에 model 있을 때만 | 데이터 가용성 기반 | 항상 표시 | 대부분 model 필드 없음 |
| 완료 처리 | 즉시 제거 | 사용자 요청 | 일정 시간 유지 | 불필요한 복잡도 |

## 7. 제약조건과 가정

### 제약조건
- PowerShell 단일 파일 (statusline.ps1)
- Claude Code statusline API의 stdin JSON 구조에 의존
- transcript JSONL은 비공식 인터페이스 (포맷 변경 가능)

### 가정
- stdin JSON에 `transcript_path` 필드가 안정적으로 제공됨
- transcript JSONL의 Agent tool_use/tool_result 구조가 유지됨
- PowerShell에서 JSONL 스트리밍 파싱이 300ms 내 가능
- Claude Code statusline이 multi-line 출력 지원

## 8. 기술 가이드라인

1. **캐시 히트 경로 최적화**: `Get-Item`으로 mtime/size만 확인 → 캐시 JSON 읽기 → 바로 출력. 전체 JSONL 파싱을 건너뛰는 것이 핵심.
2. **대용량 JSONL 대비**: 역순 읽기 또는 최근 N줄만 파싱하는 최적화 고려
3. **중첩 JSON 탐색**: PowerShell의 `ConvertFrom-Json`으로 깊은 구조 탐색 시 null 체크 필수
4. **UTC timestamp**: `[DateTime]::Parse()` 사용, UTC와 로컬 시간 변환 주의
5. **에러 격리**: JSONL 개별 줄 파싱 실패 시 해당 줄만 스킵, 전체 실패하지 않도록

## 9. 구현 결과 및 일탈 사항

### 구현 구조
- `Get-RunningAgents` 함수: transcript JSONL 파싱 + mtime/size 캐시 (별도 파일)
- `Format-AgentDetail` 함수: 에이전트 1개의 ANSI 포매팅
- 기존 출력 조립부 수정 2곳: 카운트 삽입 + 상세 줄 추가

### 설계 대비 일탈
- **description 색상**: 설계에서 `(220,220,230) FG_WHITE 재사용` → 구현에서 `(180,180,195) FG_AGENT_DESC` 전용 변수로 변경 (가독성 향상)
- **$ICON_AGENT**: 설계에서 `$ICON_AGENT`로 아이콘 정의 → 구현에서 동일하게 `[char]0x25D0 (◐)` 사용, 아이콘 블록에 배치
- **running 에이전트 정렬**: Get-RunningAgents 내부에서 timestamp 기준 Sort-Object 적용 (설계에는 미명시, 코드 리뷰에서 추가)
- **캐시 반환 시 배열 래핑**: `@($cached.agents)` 래핑 추가 (PowerShell 단일 요소 배열 언래핑 방지, 코드 리뷰에서 추가)

### 파일 변경
- `statusline.ps1`: 170줄 → 375줄 (+205줄, 함수 2개 + 출력 통합)

## 10. 변경 이력

| 날짜 | 변경 내용 | 영향 범위 | 상태 |
|------|-----------|-----------|------|
| 2026-03-26 | 초안 작성 | 전체 | ready-for-plan |
| 2026-03-26 | 개발 완료 — 문서 통합 | 전체 | complete |
