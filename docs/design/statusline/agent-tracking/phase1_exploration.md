# Phase 1: 탐색 (Exploration) — Agent Tracking

## 페르소나 구성
- 🛠️ Tool Developer: CLI 도구 개발, PowerShell, 성능 최적화
- 👤 End User: Claude Code 사용자, UX, 가독성
- 🔧 TD (국면3 활성화)

## 본질 질문 (Ontologist)

1. **Essence**: 에이전트 목록 표시가 아닌 "시스템이 일하고 있다는 확신" 제공
2. **Root Cause**: 에이전트 병렬 실행 시 채팅 창이 멈춰 보여 에이전트/현재 세션 구분 불가
3. **Prerequisites**: transcript JSONL에 에이전트 생성/종료 기록 필요 → 검증 완료
4. **Hidden Assumptions**: JSONL 포맷 안정성 → 비공식이나 claude-hud가 이미 의존 중

## 인터뷰 결과 (Socratic Interviewer)

### 확인된 사실
- stdin JSON에 `transcript_path`, `session_id` 포함 (검증 완료)
- transcript JSONL: Agent tool_use (name="Agent", subagent_type, description, timestamp)
- tool_result로 완료 판별 가능 (tool_use_id 매칭)
- claude-hud 파싱 전략: mtime+size 캐시, readline 스트리밍, 최근 agent 10개 유지

### 결정사항
| 항목 | 결정 | 근거 |
|---|---|---|
| 파싱 전략 | mtime+size 캐시 (claude-hud 방식) | 단일 ps1 유지 + 비용 최소 |
| 성능 예산 | 100~300ms 허용 | 인지용, 게임급 반응성 불필요 |
| 상태 표현 | running/done 이진 상태 | 비용 최소 |
| 캐시 파일 | 별도 파일 분리 | 비용 최소 방향 |
| 초과 에이전트 | 최근 3개 + "+N more" | 줄 수 제한 |
| 완료 에이전트 | 즉시 제거 | 사용자 요청 |

## Contrarian 비판 및 반영

### 비판 요약
1. 대화 흐름에서 이미 보이는 정보의 중복 → **반박: 병렬 에이전트는 채팅에서 인지 불가**
2. transcript 파싱은 책임 역전 → **인정하지만 현실적 차선책**
3. 완료 즉시 제거 시 짧은 에이전트 인지 불가 → **수용: 5초 필터 도입**

### 반영: 하이브리드 접근
- **1줄(기본)**: 에이전트 카운트 (`◐ 3 agents`) — 기존 statusline에 추가
- **2줄+(상세)**: 5초 이상 running 에이전트만 상세 표시
- 에이전트 0개 → 카운트 섹션 숨김 + 상세 줄 없음
- 전부 5초 미만 → 카운트만 표시, 상세 줄 없음

## 시드

```yaml
goal: "statusline.ps1에 하이브리드 에이전트 표시 기능 추가: 기본 줄에 카운트, 5초 이상 에이전트는 상세 줄로 표시"

constraints:
  - "단일 ps1 파일 유지"
  - "mtime+size 기반 캐시 (별도 파일)"
  - "최대 3개 에이전트 상세 표시 + '+N more' 요약"
  - "running/done 이진 상태"
  - "완료 에이전트 즉시 제거"
  - "5초 미만 에이전트는 상세 줄에서 제외"
  - "100~300ms 성능 예산"

non_goals:
  - "에이전트 액션(중지/재시작)"
  - "transcript 전체 이력/로그 뷰어"
  - "다중 파일 모듈화/외부 의존성"

success_criteria:
  - "기본 줄에 running 에이전트 카운트 표시"
  - "5초 이상 running 에이전트의 이름/상태/경과시간 상세 표시"
  - "에이전트 0개 시 관련 섹션 숨김"
  - "mtime 캐시로 불필요한 재파싱 방지"
  - "기존 statusline 출력 정상 유지"

assumptions:
  - "stdin JSON에 transcript_path 필드 안정적 제공"
  - "transcript JSONL의 Agent tool_use/tool_result 구조 유지"
  - "PowerShell에서 JSONL 스트리밍 파싱이 300ms 내 가능"

open_questions: []

context: |
  claude-hud의 에이전트 추적을 참고하되, PowerShell 단일 파일로 구현.
  Contrarian 비판을 반영하여 하이브리드 접근(카운트+상세) 채택.
```

## 명확도 체크
- ✅ Goal Clarity: 하이브리드 표시 (카운트 + 5초 필터 상세)
- ✅ Constraint Clarity: 단일 파일, 캐시, 성능 예산 확정
- ✅ Success Criteria: 측정 가능한 기준 5개
- ✅ Open Questions: 전부 해결됨
