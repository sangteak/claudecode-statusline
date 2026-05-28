# Claude Code Statusline

Claude Code 하단에 버전, 모델, 경로, Git 브랜치, 컨텍스트 사용량, 에이전트 상태, 시간을 표시하는 statusline.

![default](images/claudecode-statueline-default.png)

![contains git](images/claudecode-statueline-git.png)

## 요구사항

Python으로 구현되어 Windows · Linux · macOS에서 동일하게 동작합니다.

- **Python 3.7+** (표준 라이브러리만 사용 — 추가 패키지 설치 불필요)
- [Hack Nerd Font Mono](https://www.nerdfonts.com/font-downloads) 등 Nerd Font (아이콘 표시용)
- 터미널에서 해당 폰트 설정 + UTF-8 출력

## 설치

### 1. Python 설치

먼저 Python 3.7 이상이 설치돼 있는지 확인하세요. (이미 있으면 이 단계는 건너뜁니다.)

```bash
python3 --version   # Linux / macOS
python --version    # Windows
```

`3.7` 이상이 출력되면 OK입니다. 명령을 찾을 수 없다면 아래에서 OS에 맞게 설치하세요. (3.7·3.8은 이미 지원 종료됐으니, 새로 설치한다면 최신 버전을 권장합니다.)

**Windows** — winget(권장) 또는 공식 설치 파일:

```powershell
winget install Python.Python.3.13
```

- winget 패키지 ID는 마이너 버전별로 나뉩니다(`Python.Python.3.13` 등). `winget search Python.Python` 으로 현재 받을 수 있는 최신 버전을 확인할 수 있습니다.
- winget이 없다면 [python.org 다운로드 페이지](https://www.python.org/downloads/windows/)에서 설치 파일을 받으세요.
- 공식 설치 파일 실행 시 **"Add python.exe to PATH"** 체크박스를 반드시 켜야 터미널에서 `python`이 인식됩니다.

**Linux** — 배포판 패키지 매니저:

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y python3

# Fedora / RHEL
sudo dnf install -y python3

# Arch
sudo pacman -S python
```

대부분의 Linux 배포판에는 `python3`가 기본 포함돼 있습니다.

**macOS** — Homebrew(권장):

```bash
brew install python
```

- Homebrew가 없다면 [brew.sh](https://brew.sh) 안내로 설치하거나, [python.org 다운로드 페이지](https://www.python.org/downloads/macos/)에서 설치 파일을 받으세요.

> 어떤 OS든 공식 다운로드 허브는 **<https://www.python.org/downloads/>** 입니다.

### 2. Nerd Font 설치

1. [Nerd Fonts 다운로드 페이지](https://www.nerdfonts.com/font-downloads)에서 **Hack** 다운로드
2. 압축 해제 후 `Mono` 가 포함된 `.ttf` 파일을 설치
   - **Windows**: 우클릭 → **모든 사용자용으로 설치**
   - **Linux**: `~/.local/share/fonts/`에 복사 후 `fc-cache -f`
   - **macOS**: 더블클릭 → **글꼴 설치**
3. 터미널 프로필의 글꼴을 `Hack Nerd Font Mono` 로 변경
   - Windows Terminal: 설정(`Ctrl + ,`) → 프로필 → **모양** → 글꼴

### 3. statusline 설치

**Windows** (PowerShell):

```powershell
iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex
```

**Linux / macOS** (bash):

```bash
curl -fsSL https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.sh | bash
```

설치 스크립트가 `~/.claude/hooks/statusline.py`를 내려받고 `settings.json`의 `statusLine` 명령을 설정합니다. Claude Code 재시작 후 자동 적용.

## 업데이트

재설치하면 `statusline.py`만 덮어써서 업데이트돼. settings.json의 다른 설정은 유지됨.

```powershell
# Windows
iwr https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.ps1 | iex
```

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.sh | bash
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

### 아이콘이 □/?로 보여요

아이콘 자리가 빈 네모(□)나 `?`로 표시되면 터미널 글꼴이 Nerd Font가 아닙니다. 터미널 프로필 글꼴을 `Hack Nerd Font Mono` 등 Nerd Font로 변경하세요.

### 아이콘/문자가 깨져서 표시돼요 (Windows)

**현상**  
아이콘이나 `│` 구분선이 `?` 또는 이상한 문자로 표시됨.

**문제 원인**  
한국어 Windows는 시스템 로케일이 기본 CP949(EUC-KR)로 설정되어 있어 콘솔이 UTF-8 문자를 올바르게 출력하지 못함.

**해결 방법**  
1. `Win + R` → `intl.cpl` 실행
2. **관리** 탭 → **시스템 로케일 변경** 클릭
3. **Beta: 세계 언어 지원을 위해 Unicode UTF-8 사용** 체크
4. 재부팅

### statusline이 아예 표시되지 않아요

`settings.json`의 `statusLine.command`에 적힌 Python 실행파일이 PATH에 있는지 확인하세요. Linux/macOS는 `python3`, Windows는 `python`이 기본입니다.

```bash
python3 --version   # Linux/macOS
python --version    # Windows
```

버전이 출력되지 않으면 Python이 없거나 PATH에 등록되지 않은 것입니다. [설치 → 1. Python 설치](#1-python-설치)를 참고하세요.
