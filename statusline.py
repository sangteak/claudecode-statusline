#!/usr/bin/env python3
# ─────────────────────────────────────────
# Claude Code StatusLine (cross-platform)
# - output 토큰 포함 퍼센트 계산 (used_percentage 직접 참조)
# - 프로젝트별 캐시 파일 ({project}/.claude/statusline-cache.json)
# - 에이전트 추적 (transcript JSONL 파싱)
# Font: Hack Nerd Font Mono (또는 임의의 Nerd Font)
# Runtime: Python 3.7+ (stdlib only) — Windows / Linux / macOS
# ─────────────────────────────────────────

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone


def dig(obj, *path):
    """중첩 dict 안전 접근. 경로 중간이 dict가 아니면 None."""
    cur = obj
    for key in path:
        if isinstance(cur, dict):
            cur = cur.get(key)
        else:
            return None
    return cur


def parse_ts(ts):
    """ISO8601 타임스탬프를 UTC aware datetime으로 파싱 ('Z'/과도한 소수점 허용)."""
    s = ts.strip().replace("Z", "+00:00")
    m = re.match(r"(.*\.\d{6})\d+(.*)", s)  # 소수점 7자리 이상 → 6자리로 절단
    if m:
        s = m.group(1) + m.group(2)
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        dt = datetime.fromisoformat(re.sub(r"\.\d+", "", s))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def get_running_agents(transcript_path, cache_dir):
    """transcript JSONL을 파싱해 아직 결과가 없는(running) Agent 목록 반환. mtime+size 캐시."""
    if not transcript_path or not os.path.exists(transcript_path):
        return []

    agents_cache_path = os.path.join(cache_dir, "statusline-agents-cache.json")
    try:
        st = os.stat(transcript_path)
    except OSError:
        return []
    current_mtime = st.st_mtime_ns
    current_size = st.st_size

    # 캐시 히트 확인
    if os.path.exists(agents_cache_path):
        try:
            with open(agents_cache_path, "r", encoding="utf-8") as f:
                cached = json.load(f)
            if (cached.get("transcript_mtime") == current_mtime
                    and cached.get("transcript_size") == current_size):
                return cached.get("agents") or []
        except Exception:
            pass

    # 캐시 미스 — 전체 JSONL 파싱
    # 전체 파일을 한 번에 읽음 — 대용량 세션에서는 성능 병목이 될 수 있음 (향후 최적화 가능)
    tool_uses = {}
    tool_results = {}
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        return []

    for line in lines:
        line = line.strip()
        if line == "":
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue

        etype = entry.get("type")
        content = dig(entry, "message", "content")
        if not isinstance(content, list):
            continue

        if etype == "assistant":
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use" and block.get("name") == "Agent":
                    inp = block.get("input") or {}
                    tool_uses[block.get("id")] = {
                        "tool_use_id": block.get("id"),
                        "subagent_type": inp.get("subagent_type") or "agent",
                        "description": inp.get("description") or "",
                        "model": inp.get("model"),
                        "timestamp": entry.get("timestamp"),
                    }
        elif etype == "user":
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_result":
                    tuid = block.get("tool_use_id")
                    if tuid and tuid in tool_uses:
                        tool_results[tuid] = True

    running = [v for k, v in tool_uses.items() if k not in tool_results]
    running.sort(key=lambda a: a.get("timestamp") or "")

    # 캐시 갱신
    try:
        os.makedirs(cache_dir, exist_ok=True)
        with open(agents_cache_path, "w", encoding="utf-8") as f:
            json.dump({
                "transcript_mtime": current_mtime,
                "transcript_size": current_size,
                "agents": running,
            }, f)
    except Exception:
        pass

    return running


def format_agent_detail(agent, fg_icon, fg_name, fg_desc, fg_time, reset):
    icon = "◐"  # ◐
    name = agent.get("subagent_type") or "agent"

    model_tag = ""
    if agent.get("model"):
        model_tag = " {0}[{1}]{2}".format(fg_desc, agent["model"], reset)

    desc = ""
    d = agent.get("description")
    if d:
        if len(d) > 40:
            d = d[:37] + "..."
        desc = ": {0}{1}{2}".format(fg_desc, d, reset)

    elapsed = ""
    ts = agent.get("timestamp")
    if ts:
        try:
            start = parse_ts(ts)
            diff = (datetime.now(timezone.utc) - start).total_seconds()
            total_sec = int(diff)
            if total_sec < 1:
                elapsed = "<1s"
            elif total_sec < 60:
                elapsed = "{0}s".format(total_sec)
            else:
                m = int(diff // 60)
                s = total_sec % 60
                elapsed = "{0}m {1}s".format(m, s)
        except Exception:
            elapsed = "?"
    elapsed_str = " {0}({1}){2}".format(fg_time, elapsed, reset) if elapsed != "" else ""

    return "{0}{1} {2}{3}{4}{5}{6}{7}".format(
        fg_icon, icon, fg_name, name, reset, model_tag, desc, elapsed_str
    )


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    # ── stdin 파싱 ────────────────────────────
    raw = sys.stdin.read()
    trimmed = raw.strip()
    json_raw = None
    if trimmed != "" and trimmed != "{}":
        try:
            json_raw = json.loads(trimmed)
        except Exception:
            json_raw = None

    # ── 캐시 경로: 프로젝트 디렉토리 기준 ───────
    proj_dir = (dig(json_raw, "workspace", "current_dir")
                or dig(json_raw, "cwd")
                or os.getcwd())
    cache_dir = os.path.join(proj_dir, ".claude")
    cache_path = os.path.join(cache_dir, "statusline-cache.json")

    # ── JSON 확정: stdin 우선, 없으면 캐시 폴백 ──
    data = None
    if json_raw is not None:
        data = json_raw
        try:
            os.makedirs(cache_dir, exist_ok=True)
            with open(cache_path, "w", encoding="utf-8") as f:
                f.write(trimmed)
        except Exception:
            pass
    elif os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = None
    if data is None:
        data = {}

    # ── 버전 ─────────────────────────────────
    ver = dig(data, "version")
    if ver:
        cc_version = "v" + str(ver)
    else:
        try:
            out = subprocess.run(
                ["claude", "--version"], capture_output=True, text=True, timeout=5
            ).stdout
            m = re.search(r"(\d+\.\d+\.\d+)", out)
            cc_version = "v" + m.group(1) if m else "v?"
        except Exception:
            cc_version = "v?"

    # ── 모델명 ───────────────────────────────
    model_re = r"claude-([a-z]+-\d+(?:-\d+)?)"
    dn = dig(data, "model", "display_name")
    mid = dig(data, "model", "id")
    amid = dig(data, "model", "api_model_id")
    if dn:
        model_name = dn
    elif mid:
        m = re.search(model_re, mid)
        model_name = m.group(1) if m else mid
    elif amid:
        m = re.search(model_re, amid)
        model_name = m.group(1) if m else amid
    else:
        model_name = "Claude"

    # ── 컨텍스트 (live stdin 전용 — 캐시 사용 안 함) ──
    # Claude Code 기본 Statusline과 동일한 수치 사용 (used_percentage 직접 참조)
    up = dig(json_raw, "context_window", "used_percentage")
    pct_int = int(up) if (json_raw is not None and up is not None) else 0

    # ── PWD ──────────────────────────────────
    raw_pwd = (dig(data, "workspace", "current_dir")
               or dig(data, "cwd")
               or os.getcwd())
    home_dir = os.path.expanduser("~")
    if home_dir and raw_pwd.startswith(home_dir):
        raw_pwd = "~" + raw_pwd[len(home_dir):]
    raw_pwd = raw_pwd.replace("\\", "/")
    parts = raw_pwd.split("/")
    if len(raw_pwd) > 35 and len(parts) > 3:
        pwd_str = ".../" + parts[-2] + "/" + parts[-1]
    else:
        pwd_str = raw_pwd

    # ── Git 브랜치 ────────────────────────────
    git_branch = None
    git_dirty = False
    work_dir = (dig(data, "workspace", "current_dir")
                or dig(data, "cwd")
                or os.getcwd())
    try:
        r = subprocess.run(
            ["git", "-C", work_dir, "branch", "--show-current"],
            capture_output=True, text=True, timeout=5,
        )
        branch = r.stdout.strip()
        if r.returncode == 0 and branch:
            git_branch = branch
            rs = subprocess.run(
                ["git", "-C", work_dir, "status", "--porcelain"],
                capture_output=True, text=True, timeout=5,
            )
            git_dirty = bool(rs.stdout.strip())
    except Exception:
        pass

    # ── 에이전트 추적 ─────────────────────────
    transcript_path = dig(data, "transcript_path") or ""
    running_agents = get_running_agents(transcript_path, cache_dir)
    agent_count = len(running_agents)

    # ── ANSI 헬퍼 ────────────────────────────
    def fg(r, g, b):
        return "\x1b[38;2;{0};{1};{2}m".format(r, g, b)

    RESET = "\x1b[0m"
    FG_DIM = fg(100, 100, 120)
    FG_WHITE = fg(220, 220, 230)
    FG_TIME = fg(160, 170, 200)
    FG_DIR = fg(120, 160, 220)
    FG_VERSION = fg(150, 120, 200)
    FG_MODEL = fg(100, 180, 200)
    FG_BRANCH = fg(180, 150, 80)
    FG_DIRTY = fg(210, 100, 80)
    FG_AGENT = fg(210, 150, 50)        # 주황 — 에이전트 카운트/아이콘
    FG_AGENT_NAME = fg(180, 100, 200)  # 마젠타 — subagent_type
    FG_AGENT_DESC = fg(180, 180, 195)  # 밝은 회색 — description

    if pct_int >= 95:
        bar_rgb = (220, 60, 60)
    elif pct_int >= 80:
        bar_rgb = (210, 110, 50)
    elif pct_int >= 50:
        bar_rgb = (200, 170, 50)
    else:
        bar_rgb = (80, 180, 100)
    FG_BAR = fg(*bar_rgb)
    FG_EMPTY = fg(60, 60, 75)

    total_bars = 15
    filled = round(pct_int * total_bars / 100)
    bar_str = ""
    for i in range(1, total_bars + 1):
        if i <= filled:
            bar_str += FG_BAR + "█"
        else:
            bar_str += FG_EMPTY + "░"

    ICON_VER = ""
    ICON_MODEL = ""
    ICON_DIR = ""
    ICON_BRANCH = ""
    ICON_CTX = ""
    ICON_TIME = ""
    ICON_AGENT = "◐"  # ◐

    DIV = FG_DIM + "  │  " + RESET
    time_str = datetime.now().strftime("%H:%M:%S")

    out = "  "
    out += FG_VERSION + "{0} {1}".format(ICON_VER, cc_version) + RESET + DIV
    out += FG_MODEL + "{0} {1}".format(ICON_MODEL, model_name) + RESET + DIV
    out += FG_DIR + "{0} ".format(ICON_DIR) + RESET
    out += FG_WHITE + pwd_str + RESET

    if git_branch:
        bc = FG_DIRTY if git_dirty else FG_BRANCH
        dm = " *" if git_dirty else ""
        out += DIV + bc + "{0} {1}{2}".format(ICON_BRANCH, git_branch, dm) + RESET

    out += DIV
    out += FG_BAR + "{0} ".format(ICON_CTX) + RESET
    out += bar_str + RESET + "  "
    out += FG_BAR + "{0}%".format(pct_int).rjust(4) + RESET

    # 에이전트 카운트 (running > 0일 때만)
    if agent_count > 0:
        agent_label = "agent" if agent_count == 1 else "agents"
        out += DIV + FG_AGENT + "{0} {1} {2}".format(ICON_AGENT, agent_count, agent_label) + RESET

    out += DIV
    out += FG_TIME + "{0} {1}".format(ICON_TIME, time_str) + RESET + "  "

    print(out)

    # 상세 에이전트 줄 (5초 이상 running만)
    if agent_count > 0:
        now_utc = datetime.now(timezone.utc)
        long_running = []
        for ag in running_agents:
            ts = ag.get("timestamp")
            if ts:
                try:
                    start = parse_ts(ts)
                    diff = (now_utc - start).total_seconds()
                    if diff >= 5:
                        long_running.append(ag)
                except Exception:
                    pass

        if len(long_running) > 0:
            # 최대 3개 표시 (가장 오래된 순 — running_agents는 timestamp 정렬됨)
            to_show = long_running[:3]
            detail_parts = [
                format_agent_detail(
                    ag, FG_AGENT, FG_AGENT_NAME, FG_AGENT_DESC, FG_TIME, RESET
                )
                for ag in to_show
            ]

            more = ""
            if len(long_running) > 3:
                extra = len(long_running) - 3
                more = "  {0}+{1} more{2}".format(FG_DIM, extra, RESET)

            sep = FG_DIM + "  │  " + RESET
            detail_line = "  " + sep.join(detail_parts) + more
            print(detail_line)


if __name__ == "__main__":
    main()
