# Claude Code Statusline

Claude Code 하단에 버전, 모델, 경로, Git 브랜치, 컨텍스트 사용량, 시간을 표시하는 statusline.

```
 v2.1.58  │   Sonnet  │   ~/GW-Server  │   feature/my-branch  │   ███████░░░░░░░  47%  │   15:27:59
```

## 요구사항

- Windows + PowerShell 5.1+
- [Hack Nerd Font Mono](https://www.nerdfonts.com/font-downloads) (아이콘 표시용)
- Windows Terminal에서 해당 폰트 설정

## 설치

PowerShell에서 아래 한 줄 실행:

```powershell
iwr https://raw.githubusercontent.com/{username}/claude-statusline/main/install.ps1 | iex
```

Claude Code 재시작 후 자동 적용.

## 업데이트

재설치하면 `statusline.ps1`만 덮어써서 업데이트돼. settings.json은 변경 없음.

```powershell
iwr https://raw.githubusercontent.com/{username}/claude-statusline/main/install.ps1 | iex
```

## 표시 정보

| 구획 | 내용 |
|---|---|
|  버전 | Claude Code 버전 |
|  모델 | 현재 모델 (Sonnet / Opus 등) |
|  경로 | 현재 작업 디렉토리 |
|  브랜치 | Git 브랜치 (git 프로젝트일 때만 표시) |
|  진행바 | 컨텍스트 사용량 (0~100%) |
|  시간 | 현재 시각 |

## 컨텍스트 색상

| 색상 | 범위 |
|---|---|
| 🟢 초록 | 0 ~ 49% |
| 🟡 노랑 | 50 ~ 79% |
| 🟠 주황 | 80 ~ 94% |
| 🔴 빨강 | 95% ~ |