# Phase 3: 검증 (Validation) — Agent Tracking

## TD 기술 검토 결과

| 요구사항 | 판단 | 리스크 | 가이드라인 |
|---|---|---|---|
| JSONL 파싱 (mtime+size 캐시) | 캐시 히트 시 비용 0, 미스 시 전체 파싱 필요 | 중간 | 역순 읽기 또는 증분 파싱 최적화 권장 |
| tool_use_id 매칭 | assistant.content[].tool_use ↔ user.content[].tool_result | 낮음 | 구조 확인 완료 |
| Multi-line 출력 | claude-hud가 이미 multi-line 구현 | 낮음 | Write-Host 여러 번 호출 |
| 5초 필터 | timestamp 비교로 구현 간단 | 낮음 | UTC 기준 비교 |
| 모델 태그 | Agent input에 model 키 선택적 — 대부분 없음 | 낮음 | 있을 때만 표시 |

## 발견된 사실

- Agent tool_use input 필드: `subagent_type`, `description`, `prompt` (model은 선택적)
- tool_result에 `agentId`, `usage` (total_tokens, tool_uses, duration_ms) 포함
- 현재 세션 260줄 → 장시간 세션 수천 줄 가능

## 재협의 사항

- REQ-5 모델 태그: "에이전트 간 다를 때만 표시" → "input에 model 키가 있을 때만 표시"로 변경 (데이터 가용성 기반)

## 기술 가이드라인

1. 캐시 히트 경로 최적화가 성능의 핵심
2. 대용량 JSONL 대비 역순 읽기 또는 증분 파싱 고려
3. PowerShell ConvertFrom-Json의 중첩 구조 탐색 시 null 체크 필수
4. UTC timestamp 파싱: `[DateTime]::Parse()` 사용
