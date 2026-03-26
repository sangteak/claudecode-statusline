# Claude Code Statusline

Claude Code 하단에 버전, 모델, 경로, Git 브랜치, 컨텍스트 사용량, 에이전트 상태, 시간을 표시하는 statusline.

![default](images/claudecode-statueline-default.png)

![contains git](images/claudecode-statueline-git.png)

## 요구사항

- Windows + PowerShell 5.1+
- [Hack Nerd Font Mono](https://www.nerdfonts.com/font-downloads) (아이콘 표시용)
- Windows Terminal에서 해당 폰트 설정

## 설치

### 1. Hack Nerd Font Mono 설치

1. [Nerd Fonts 다운로드 페이지](https://www.nerdfonts.com/font-downloads)에서 **Hack** 다운로드
2. 압축 해제 후 `Mono` 가 포함된 `.ttf` 파일 선택
3. 우클릭 → **모든 사용자용으로 설치**
4. Windows Terminal 설정(`Ctrl + ,`) → 사용 중인 프로필 → **모양** → 글꼴을 `Hack Nerd Font Mono` 로 변경

### 2. statusline 설치

PowerShell에서 아래 한 줄 실행:

```powershell
iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex
```

Claude Code 재시작 후 자동 적용.

## 업데이트

재설치하면 `statusline.ps1`만 덮어써서 업데이트돼. settings.json은 변경 없음.

```powershell
iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex
```

## 표시 정보

| 구획 | 내용 |
|---|---|
|  버전 | Claude Code 버전 |
|  모델 | 현재 모델 (Sonnet / Opus 등) |
|  경로 | 현재 작업 디렉토리 |
|  브랜치 | Git 브랜치 (git 프로젝트일 때만 표시) |
|  진행바 | 컨텍스트 사용량 (0~100%) |
| ◐ 에이전트 | 실행 중인 서브에이전트 수 (있을 때만 표시) |
|  시간 | 현재 시각 |

## 에이전트 추적

서브에이전트가 병렬 실행될 때, 기본 줄에 에이전트 카운트가 표시됩니다.
5초 이상 실행 중인 에이전트는 2번째 줄에 상세 정보(이름, 설명, 경과시간)가 표시됩니다.

```
v2.1.78 | Opus 4.6 | .../project | main * | ⚡ ████░░ 12% | ◐ 3 agents | 🕐 15:30:00
◐ explore: Finding auth code (2m 15s)  |  ◐ general-purpose: Searching (1m 30s)
```

- 에이전트 0개: 관련 표시 없음
- 에이전트 5초 미만: 카운트만 표시, 상세 줄 없음
- 최대 3개 상세 표시, 초과 시 `+N more`

## 컨텍스트 색상

| 색상 | 범위 |
|---|---|
| 🟢 초록 | 0 ~ 49% |
| 🟡 노랑 | 50 ~ 79% |
| 🟠 주황 | 80 ~ 94% |
| 🔴 빨강 | 95% ~ |

---

## 자주 묻는 질문

### 아이콘/문자가 깨져서 표시돼요

**현상**  
아이콘이나 `│` 구분선이 `?` 또는 이상한 문자로 표시됨.

**문제 원인**  
한국어 Windows는 시스템 로케일이 기본 CP949(EUC-KR)로 설정되어 있어 PowerShell 콘솔이 UTF-8 문자를 올바르게 출력하지 못함.

**해결 방법**  
1. `Win + R` → `intl.cpl` 실행
2. **관리** 탭 → **시스템 로케일 변경** 클릭
3. **Beta: 세계 언어 지원을 위해 Unicode UTF-8 사용** 체크
4. 재부팅
