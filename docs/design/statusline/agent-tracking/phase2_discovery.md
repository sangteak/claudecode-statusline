# Phase 2: 발견 (Discovery) — Agent Tracking

## 국면 2에서 발견된 미정의 영역

1. transcript JSONL 파싱 로직 (tool_use_id 매칭)
2. 에이전트 카운트 위치
3. ANSI 색상/아이콘 정책
4. 에이전트 이름 truncate 규칙
5. 모델 태그 표시 조건
6. 경과시간 형식

## 결정 사항

| 항목 | 결정 | 근거 |
|---|---|---|
| tool_use/result 매칭 | tool_use_id 기반 | transcript JSONL 구조 검증 완료 |
| 카운트 위치 | 시간 앞 (`바 \| ◐ N \| 🕐`) | 리소스 상태(바/시간)와 작업 상태(에이전트) 분리 |
| 에이전트 이름 | subagent_type (주표시) + description (축약 40자) | claude-hud 동일 |
| 모델 태그 | 에이전트 간 모델이 다를 때만 `[model]` 표시 | 노이즈 감소 |
| 경과시간 | `2m 15s` 형식 | 사용자 선택 |
| ANSI 색상 | 카운트(주황), 이름(마젠타), desc(흰색), 시간(연보라) | 기존 체계 확장 |
| truncate | description만 40자 + `...` | claude-hud 동일 |

## 페르소나 피드백 요약

- 🛠️ Tool Developer: tool_use_id 매칭 확정, 색상 체계 제안
- 👤 End User: 카운트 위치/truncate 합의
- 전원 합의
