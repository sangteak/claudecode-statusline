---
feature: cross-platform
category: statusline
status: complete
created: 2026-05-28
last-updated: 2026-05-28
dependencies:
  - statusline.ps1 (기존 v11 — 폐기됨)
affects:
  - statusline.py (신규)
  - install.sh (신규)
  - install.ps1
  - README.md
---

# Cross-Platform 설계 문서

> 한 줄 요약: Windows 전용 PowerShell statusline을 단일 Python 스크립트로 재작성하여 Windows · Linux · macOS를 모두 지원한다.

## 문제

`statusline.ps1`(v11)은 PowerShell 기반이라 Windows에서만 동작했다. Linux/macOS 사용자(특히 WSL 환경)는 사용할 수 없었다.

탐색 결과, 코드의 OS 종속성은 의외로 작았다:

| 위치 | 종속 요소 |
|------|-----------|
| `statusline.ps1:83` | `$env:USERPROFILE` (홈 경로) — 유일한 실질 종속성 |
| `install.ps1` 전체 | `powershell -File`, USERPROFILE 경로 |
| `settings.json` 명령 | `powershell -File ...` (Linux엔 `powershell` 없음) |

git 로직, ANSI 렌더링, 에이전트 JSONL 파싱은 전부 OS 중립이었다.

## 검토한 런타임 전략

| 전략 | 단일 코드베이스 | 런타임 설치 마찰 | 작업량 |
|------|:--:|:--:|:--:|
| PowerShell Core (pwsh) | ✅ | Linux에 pwsh 설치 필요(heavy) | 최소(~1줄) |
| **Python 재작성** | ✅ | python3 거의 항상 존재 | 전면 재작성 |
| Node 재작성 | ✅ | 없음(Claude Code가 Node 보장) | 전면 재작성 |
| Bash + jq 별도 스크립트 | ❌ (드리프트) | jq 의존 | 중간 |

## 결정

### 선택: Python 단일 스크립트로 완전 교체

**근거:**
- **단일 코드베이스** — 병행 유지는 드리프트 위험이 커서 배제.
- **stdlib만 사용** — `json`/`subprocess`/`os`/`datetime`로 충분, 추가 패키지 0 → 설치 마찰 최소.
- **가독성/수정 편의** — 사용자 선호.
- python3는 거의 모든 Linux/macOS에 기본 존재(없으면 README에 설치 안내).

`statusline.ps1`은 폐기(git 이력에 잔존, 복구 가능).

### 핵심 기술 결정

| 항목 | 방식 | 이유 |
|------|------|------|
| 의존성 | stdlib만 | 설치 마찰 제거 |
| Python 타깃 | 3.7+ | 바인딩 하한 = 3.7 (`subprocess` capture_output/text, `datetime.fromisoformat`, `sys.stdout.reconfigure` 모두 3.7 추가). 3.8 전용 기능은 사용 안 함. `fromisoformat`의 `Z`/과도한 소수점은 수동 정규화로 우회 |
| 홈 경로 | `os.path.expanduser("~")` | `$env:USERPROFILE` 대체 |
| stdout 인코딩 | `sys.stdout.reconfigure(encoding="utf-8")` | 아이콘/`│` 깨짐 방지 |
| 바 채움 반올림 | `round()` | PS `[int]` 캐스팅(banker's rounding)과 동일 동작 |
| settings 명령 | 설치 시 실행파일 감지: Linux/macOS=`python3`, Windows=`python`/`py` | OS별 명령어 차이 흡수 |
| settings 병합 | install.sh도 Python으로 JSON 병합 | jq 의존 회피(이미 python 전제) |

## 기능 동등성

ANSI 색상, Nerd Font 아이콘(동일 코드포인트), 컨텍스트 바, Git dirty 표시, 에이전트 카운트/상세줄(5초·최대3개·`+N more`), mtime+size 캐시, 캐시 폴백 — 모두 동일 출력으로 포팅.

> **참고**: 원본의 미사용 변수 `ctx_size`(used_percentage 직접 참조로 전환된 뒤 dead code)는 포팅에서 제외. 출력에는 영향 없음.

## 검증

이 Linux(WSL2) 환경에서 `statusline.py`를 직접 실행하여 확인:

| 케이스 | 결과 |
|--------|------|
| 기본 JSON (model/version/context/git) | 정상 출력, 바/색상/패딩 일치 |
| 에이전트 추적 (synthetic transcript) | running 카운트·상세줄·5초 필터·description 절단·경과시간 일치 |
| 빈 stdin / `{}` | 캐시 폴백, 크래시 없음 (exit 0) |
| 캐시 히트 | agents-cache 정상 영속/재사용 |
| install.sh settings 병합 | 신규/기존 settings.json 모두 정상(기존 키 보존) |

## 변경 파일

| 파일 | 작업 |
|------|------|
| `statusline.py` | 신규 — 363줄 PowerShell을 Python으로 포팅 |
| `statusline.ps1` | 삭제 |
| `install.sh` | 신규 — Linux/macOS 설치 |
| `install.ps1` | 수정 — Python 다운로드/명령으로 전환, python 감지 |
| `README.md` | 수정 — OS별 요구사항/설치/FAQ |
