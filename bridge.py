#!/usr/bin/env python3
"""bridge.py - WFSAT 대시보드 실습(라이브) 연동 브리지 서버.

표준 라이브러리만 사용한다(칼리에서 pip 설치 불필요).

역할:
  1) 정적 대시보드(dashboard_html/) 서빙
  2) POST /api/events        - et_logger.sh 의 dashboard_url 웹훅 수신(실시간 이벤트)
  3) GET  /api/state         - 공격 요약 + 이벤트 + 탐지 결과를 하나의 JSON 으로 제공
  4) GET  /api/exec/commands - 심화 탭 콘솔에서 실행 가능한 허용 명령 목록
  5) POST /api/exec          - 화이트리스트에 있는 명령만 서버에서 실행하고 결과 반환

데이터가 하나도 없어도(공격 실행 전) 항상 유효한 JSON 을 200 으로 돌려준다.

환경변수로 경로 조정 가능:
  WFSAT_LOG_DIR      기본 /tmp/et_logs          (et_config.conf 의 log_dir 과 맞출 것)
  WFSAT_DETECT_JSON  기본 <LOG_DIR>/detect.json (et_detector.py --json 저장 경로)
  WFSAT_STATIC_DIR   기본 <스크립트 폴더>/dashboard_html
  WFSAT_HOST         기본 0.0.0.0
  WFSAT_PORT         기본 5000
  WFSAT_ENABLE_EXEC  기본 1  (0 으로 두면 /api/exec 비활성화)
  WFSAT_EXEC_TIMEOUT 기본 60 (초, 포그라운드 명령의 최대 대기 시간)

보안 주의:
  /api/exec 는 아래 ALLOWED_COMMANDS 화이트리스트에 등록된 명령만 실행한다.
  임의 셸 명령은 실행할 수 없으며, 셸 메타문자(; | & ` $ > < 등)는 거부된다.
  다만 이 서버는 기본적으로 0.0.0.0 에 바인딩되므로, 같은 네트워크의 누구나
  이 화이트리스트 명령을 호출할 수 있다. 격리된 실습 랜에서만 사용할 것.
  더 잠그려면 WFSAT_HOST=127.0.0.1 로 실행하거나 WFSAT_ENABLE_EXEC=0 로 끈다.

실행:
  python3 bridge.py
"""

import glob
import json
import mimetypes
import os
import shlex
import shutil
import subprocess
import sys
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

LOG_DIR = os.environ.get("WFSAT_LOG_DIR", "/tmp/et_logs")
DETECT_JSON = os.environ.get("WFSAT_DETECT_JSON", os.path.join(LOG_DIR, "detect.json"))
STATIC_DIR = os.environ.get("WFSAT_STATIC_DIR", os.path.join(SCRIPT_DIR, "dashboard_html"))
HOST = os.environ.get("WFSAT_HOST", "0.0.0.0")
PORT = int(os.environ.get("WFSAT_PORT", "5000"))

# ---------------------------------------------------------------------------
# 명령 콘솔(/api/exec) 설정
# ---------------------------------------------------------------------------
EXEC_ENABLED = os.environ.get("WFSAT_ENABLE_EXEC", "1").strip().lower() not in (
    "0", "false", "no", "off", "",
)
EXEC_TIMEOUT = int(os.environ.get("WFSAT_EXEC_TIMEOUT", "60"))
MAX_OUTPUT = 20000  # 응답에 담을 stdout/stderr 최대 길이(문자)

# root 권한이 필요한 명령 앞에 자동으로 붙일 sudo 커맨드.
#   - 브리지를 root 로 실행 중이면(geteuid()==0) 아예 붙이지 않는다.
#   - 기본값 "sudo -n" 은 비밀번호를 묻지 않는(non-interactive) 모드. NOPASSWD
#     sudoers 가 설정돼 있어야 통과하며, 없으면 즉시 에러(멈추지 않음).
#   - WFSAT_SUDO="" 로 두면 자동 sudo 를 완전히 끈다.
SUDO_CMD = os.environ.get("WFSAT_SUDO", "sudo -n")

# 새 터미널 창에서 실행하기(공격/스캔처럼 대화형·장시간 명령용).
#   WFSAT_TERMINAL_ENABLE=0 이면 끈다.
#   WFSAT_TERMINAL 로 터미널 명령을 강제 지정 가능(예: "xterm", "qterminal").
#   root 로 실행 중이면 GUI 를 띄우기 위해 WFSAT_DISPLAY / WFSAT_XAUTHORITY 가
#   필요할 수 있다(보통 DISPLAY=:0, XAUTHORITY=로그인 사용자의 ~/.Xauthority).
TERMINAL_ENABLED = os.environ.get("WFSAT_TERMINAL_ENABLE", "1").strip().lower() not in (
    "0", "false", "no", "off", "",
)
TERMINAL_CMD = os.environ.get("WFSAT_TERMINAL", "").strip()
_TERMINALS = ["x-terminal-emulator", "qterminal", "xfce4-terminal",
              "gnome-terminal", "konsole", "mate-terminal", "lxterminal", "xterm"]


def _is_root():
    geteuid = getattr(os, "geteuid", None)
    return geteuid is not None and geteuid() == 0

# 실행 허용 명령 화이트리스트.
#   prefix     : 명령이 이 문자열과 정확히 일치하거나(allow_args=False),
#                이 문자열 + 공백으로 시작해야(allow_args=True) 허용된다.
#   allow_args : True 면 prefix 뒤에 인자를 덧붙일 수 있다(프로그램 자체는 고정).
#   background : True 면 기다리지 않고 백그라운드로 실행하고 즉시 PID 를 돌려준다
#                (오래 도는 공격/AP 스크립트용). 출력은 로그 파일로 리다이렉트된다.
#   root       : True 면 root 권한이 필요한 명령이다. 브리지가 root 가 아니면
#                실행 시 자동으로 SUDO_CMD(기본 "sudo -n")를 앞에 붙인다.
#                → 대시보드에서 "sudo" 를 직접 칠 필요가 없다.
# 사용자가 명령 앞에 "sudo " 를 붙여도 허용되며, 중복 없이 처리된다.
#   group      : 콘솔의 help 목록에서 공격 단계별로 묶어 보여주기 위한 분류.
#   alias      : 콘솔에서 사용자가 읽고/입력하는 짧은 이름. 서버가 실행 전에
#                이 별칭을 prefix(실제 명령)로 바꿔 준다. 실제 명령을 그대로
#                입력해도 동작한다(하위 호환).
ALLOWED_COMMANDS = [
    {"label": "의존성 점검", "alias": "deps", "prefix": "bash et_check_deps.sh", "group": "준비",
     "allow_args": True, "root": True, "terminal": True, "desc": "필요 도구 점검/설치 (--check-only 로 점검만)"},
    {"label": "AP 스캔", "alias": "scan", "prefix": "bash et_scan.sh", "group": "준비",
     "allow_args": True, "root": True, "terminal": True, "desc": "주변 AP 스캔 → et_config.conf 저장 (대상 선택 필요)"},
    {"label": "피해 AP 실행", "alias": "ap", "prefix": "bash lab_victim_ap.sh", "group": "공격",
     "allow_args": True, "root": True, "terminal": True, "background": True, "desc": "실습용 피해 AP 생성 (새 터미널)"},
    {"label": "스니핑 공격 실행", "alias": "attack", "prefix": "bash et_sniffing_attack.sh", "group": "공격",
     "allow_args": True, "root": True, "terminal": True, "background": True, "desc": "가짜 AP+deauth+스니퍼 (새 터미널)"},
    {"label": "Evil Twin 탐지", "alias": "detect", "prefix": "python3 detector/et_detector.py", "group": "탐지",
     "allow_args": True, "root": True, "desc": "pcap 분석으로 Evil Twin 탐지 (인자로 pcap 경로)"},
    {"label": "무선 인터페이스", "alias": "iface", "prefix": "iw dev", "group": "조회",
     "desc": "무선 인터페이스 목록"},
    {"label": "인터페이스 상태", "alias": "wifi", "prefix": "iwconfig", "group": "조회",
     "desc": "무선 어댑터 상태"},
    {"label": "현재 설정", "alias": "config", "prefix": "cat et_config.conf", "group": "조회",
     "desc": "et_config.conf 값 출력"},
]

# 별칭 → 실제 명령 문자열. (예: "scan" → "bash et_scan.sh")
ALIAS_MAP = {e["alias"]: e["prefix"] for e in ALLOWED_COMMANDS if e.get("alias")}


def _resolve_alias(cmd):
    """맨 앞 토큰이 별칭이면 실제 명령으로 바꾼다. 뒤의 인자와 sudo 접두사는 보존.
    별칭이 아니거나 이미 실제 명령이면 그대로 돌려준다(하위 호환)."""
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return cmd
    if not tokens:
        return cmd
    # 앞에 붙은 "sudo [옵션]" 은 그대로 두고 그 다음 토큰을 별칭 후보로 본다.
    i = 0
    head = []
    while i < len(tokens) and tokens[i] == "sudo":
        head.append(tokens[i]); i += 1
        while i < len(tokens) and tokens[i].startswith("-"):
            head.append(tokens[i]); i += 1
    if i >= len(tokens):
        return cmd
    alias = tokens[i]
    if alias not in ALIAS_MAP:
        return cmd
    rest = tokens[i + 1:]
    return " ".join(head + [ALIAS_MAP[alias]] + rest)

# shell=False 로 실행하므로 아래 문자들은 어차피 특별한 의미가 없지만,
# 방어적으로(그리고 화이트리스트 우회 시도 차단을 위해) 명령 문자열에서 거부한다.
_FORBIDDEN_CHARS = [";", "|", "&", "`", "$", ">", "<", "\n", "\r", "\\",
                    "*", "?", "(", ")", "{", "}", "[", "]", "!", "~"]


def _clip_output(text):
    if not text:
        return ""
    if len(text) > MAX_OUTPUT:
        return text[:MAX_OUTPUT] + "\n... (출력이 잘렸습니다)"
    return text


def _match_allowed(cmd):
    """명령 문자열에 대응하는 화이트리스트 항목을 찾는다. 없으면 None."""
    core = cmd
    if core.startswith("sudo "):
        core = core[len("sudo "):].lstrip()
    for entry in ALLOWED_COMMANDS:
        prefix = entry["prefix"]
        if entry.get("allow_args"):
            if core == prefix or core.startswith(prefix + " "):
                return entry
        elif core == prefix:
            return entry
    return None


def _run_foreground(argv, cmd):
    try:
        proc = subprocess.run(
            argv, cwd=SCRIPT_DIR, timeout=EXEC_TIMEOUT,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        return {"ok": False, "command": cmd, "returncode": None,
                "stdout": "", "stderr": "",
                "error": "명령을 찾을 수 없습니다: %s" % argv[0]}
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout.decode("utf-8", "replace") if exc.stdout else ""
        err = exc.stderr.decode("utf-8", "replace") if exc.stderr else ""
        return {"ok": False, "command": cmd, "returncode": None, "timeout": True,
                "stdout": _clip_output(out), "stderr": _clip_output(err),
                "error": "%d초 안에 끝나지 않아 중단했습니다. (오래 도는 명령은 "
                         "백그라운드 항목을 쓰세요)" % EXEC_TIMEOUT}
    return {"ok": proc.returncode == 0, "command": cmd,
            "returncode": proc.returncode,
            "stdout": _clip_output(proc.stdout.decode("utf-8", "replace")),
            "stderr": _clip_output(proc.stderr.decode("utf-8", "replace"))}


def _run_background(argv, cmd):
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
    except OSError:
        pass
    logpath = os.path.join(LOG_DIR, "exec_%d.log" % int(time.time()))
    try:
        logfh = open(logpath, "ab")
    except OSError:
        logfh = subprocess.DEVNULL
        logpath = "(로그 파일을 열 수 없음)"
    try:
        proc = subprocess.Popen(
            argv, cwd=SCRIPT_DIR,
            stdin=subprocess.DEVNULL, stdout=logfh, stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    except FileNotFoundError:
        return {"ok": False, "command": cmd, "returncode": None,
                "stdout": "", "stderr": "",
                "error": "명령을 찾을 수 없습니다: %s" % argv[0]}
    return {"ok": True, "command": cmd, "background": True, "pid": proc.pid,
            "returncode": None, "log": logpath,
            "stdout": "백그라운드로 실행했습니다. (PID %d)\n로그: %s"
                      % (proc.pid, logpath),
            "stderr": ""}


def _find_terminal():
    """사용 가능한 터미널 에뮬레이터 실행 파일 이름을 찾는다. 없으면 None."""
    if TERMINAL_CMD:
        exe = shlex.split(TERMINAL_CMD)[0] if TERMINAL_CMD else ""
        return TERMINAL_CMD if (exe and shutil.which(exe)) else None
    for t in _TERMINALS:
        if shutil.which(t):
            return t
    return None


def _terminal_argv(term, inner):
    """터미널별로 'bash -lc <inner>' 를 실행하는 argv 를 만든다."""
    if TERMINAL_CMD and len(shlex.split(TERMINAL_CMD)) > 1:
        return shlex.split(TERMINAL_CMD) + ["bash", "-lc", inner]
    name = os.path.basename(shlex.split(term)[0])
    if name == "gnome-terminal":
        return ["gnome-terminal", "--", "bash", "-lc", inner]
    if name == "xfce4-terminal":
        return ["xfce4-terminal", "--hold", "-e", "bash -lc " + shlex.quote(inner)]
    return [term, "-e", "bash", "-lc", inner]


def _gui_env():
    """GUI 창을 띄우기 위한 DISPLAY / XAUTHORITY 를 채운 환경을 반환한다."""
    env = dict(os.environ)
    disp = env.get("DISPLAY") or os.environ.get("WFSAT_DISPLAY") or ":0"
    env["DISPLAY"] = disp
    xauth = env.get("XAUTHORITY") or os.environ.get("WFSAT_XAUTHORITY")
    if not xauth and _is_root():
        # sudo 로 root 실행 시, 로그인 사용자의 Xauthority 를 찾아본다.
        cands = []
        user = os.environ.get("SUDO_USER")
        if user:
            cands.append("/home/%s/.Xauthority" % user)
        cands.append("/root/.Xauthority")
        for c in cands:
            if os.path.exists(c):
                xauth = c
                break
    if xauth:
        env["XAUTHORITY"] = xauth
    return env, disp


def _run_in_terminal(cmd):
    """새 터미널 창을 열어 cmd 를 실행한다. 출력은 창에 보이면서 로그 파일에도 tee 된다.
    터미널을 찾지 못하거나 실패하면 None 을 돌려 호출부가 대체 실행하도록 한다."""
    term = _find_terminal()
    if not term:
        return None
    env, disp = _gui_env()
    if not disp:
        return None
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
    except OSError:
        pass
    logpath = os.path.join(LOG_DIR, "term_%d.log" % int(time.time()))
    inner = (
        "cd %s; %s 2>&1 | tee %s; rc=${PIPESTATUS[0]}; echo; "
        "echo \"[끝났습니다 · 종료 코드 $rc · 이 창은 닫아도 됩니다]\"; exec bash"
    ) % (shlex.quote(SCRIPT_DIR), cmd, shlex.quote(logpath))
    term_argv = _terminal_argv(term, inner)
    try:
        proc = subprocess.Popen(
            term_argv, cwd=SCRIPT_DIR, env=env,
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except (FileNotFoundError, OSError):
        return None
    return {"ok": True, "command": cmd, "terminal": True, "pid": proc.pid,
            "returncode": None, "log": logpath,
            "stdout": "새 터미널 창에서 실행했습니다. (%s · PID %d)\n로그: %s\n"
                      "창에서 실시간으로 진행 상황을 보고, 대화형 입력(예: 스캔 대상 선택)도 "
                      "그 창에서 하면 됩니다." % (os.path.basename(term), proc.pid, logpath),
            "stderr": ""}


def run_command(cmd):
    """화이트리스트 검증 후 명령을 실행하고 결과 dict 를 반환한다."""
    cmd = (cmd or "").strip()
    if not cmd:
        return {"ok": False, "command": cmd, "error": "빈 명령입니다."}
    cmd = _resolve_alias(cmd)  # 별칭(scan/attack/…)을 실제 명령으로 변환
    for ch in _FORBIDDEN_CHARS:
        if ch in cmd:
            return {"ok": False, "command": cmd,
                    "error": "허용되지 않은 문자가 포함되어 있습니다: %r" % ch}
    entry = _match_allowed(cmd)
    if entry is None:
        return {"ok": False, "command": cmd,
                "error": "허용되지 않은 명령입니다. 허용 목록의 명령만 실행할 수 있습니다."}
    try:
        tokens = shlex.split(cmd)
    except ValueError as exc:
        return {"ok": False, "command": cmd,
                "error": "명령을 해석할 수 없습니다: %s" % exc}
    # 사용자가 직접 붙였을 수 있는 "sudo [옵션]" 접두사를 제거한다(중복 방지).
    while tokens and tokens[0] == "sudo":
        tokens.pop(0)
        while tokens and tokens[0].startswith("-"):
            tokens.pop(0)
    # root 가 필요한 명령이면 브리지가 root 가 아닌 한 sudo 를 자동으로 붙인다.
    if entry.get("root") and SUDO_CMD and not _is_root():
        argv = shlex.split(SUDO_CMD) + tokens
    else:
        argv = tokens
    eff_cmd = " ".join(shlex.quote(a) for a in argv)
    # 터미널 실행 대상이면 새 창에서 실행(대화형/장시간 명령).
    if TERMINAL_ENABLED and entry.get("terminal"):
        res = _run_in_terminal(eff_cmd)
        if res is not None:
            return res
        # 새 터미널을 못 열면 백그라운드 로그 실행으로 대체한다.
        res = _run_background(argv, eff_cmd)
        res["stdout"] = ("새 터미널을 열 수 없어(터미널/디스플레이 미검출) 백그라운드로 "
                         "실행했습니다.\n" + res.get("stdout", ""))
        return res
    if entry.get("background"):
        return _run_background(argv, eff_cmd)
    return _run_foreground(argv, eff_cmd)


def exec_commands_info():
    """콘솔 UI 가 표시할 허용 명령 목록."""
    return {
        "enabled": EXEC_ENABLED,
        "timeout": EXEC_TIMEOUT,
        "commands": [
            {"label": e["label"], "prefix": e["prefix"],
             "alias": e.get("alias", ""),
             "desc": e.get("desc", ""),
             "group": e.get("group", "기타"),
             "allow_args": bool(e.get("allow_args")),
             "background": bool(e.get("background")),
             "terminal": bool(e.get("terminal"))}
            for e in ALLOWED_COMMANDS
        ],
    }

# 웹훅으로 들어온 이벤트를 담아두는 링 버퍼(최근 500개). 서버 재시작 시 비며,
# 그 경우 GET /api/state 는 로그 디렉토리의 최신 .jsonl 파일에서 이벤트를 복원한다.
_EVENTS = deque(maxlen=500)
_EVENTS_LOCK = threading.Lock()

MAX_EVENTS_OUT = 100  # 응답에 포함할 최근 이벤트 개수


def _read_json_file(path):
    """파일을 읽어 파싱한다. 없거나 깨졌으면 None(예외를 던지지 않음)."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def read_summary():
    """et_summary.json 을 읽는다. 없으면 None."""
    return _read_json_file(os.path.join(LOG_DIR, "et_summary.json"))


def read_detections():
    """et_detector.py --json 결과를 읽는다. 없으면 빈 구조."""
    data = _read_json_file(DETECT_JSON)
    if not isinstance(data, dict):
        return {"ap_table": [], "findings": []}
    return {
        "ap_table": data.get("ap_table") or [],
        "findings": data.get("findings") or [],
    }


def _events_from_logfile():
    """웹훅 버퍼가 비었을 때, 로그 디렉토리의 최신 .jsonl 에서 이벤트를 복원한다."""
    try:
        files = glob.glob(os.path.join(LOG_DIR, "*.jsonl"))
        if not files:
            return []
        newest = max(files, key=os.path.getmtime)
        events = []
        with open(newest, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except ValueError:
                    continue
        return events[-MAX_EVENTS_OUT:]
    except OSError:
        return []


def read_events():
    """실시간 이벤트 목록.

    로그 파일(.jsonl)을 우선 소스로 삼는다. 로거가 파일에 동기적으로 기록하므로
    브리지를 공격 도중 재시작해도 전체 이력이 보인다. 로그 파일이 없을 때
    (예: 브리지를 로그와 다른 호스트에서 실행)만 웹훅 버퍼로 폴백한다.
    """
    events = _events_from_logfile()
    if events:
        return events
    with _EVENTS_LOCK:
        return list(_EVENTS)[-MAX_EVENTS_OUT:]


def build_state():
    """대시보드가 폴링하는 통합 상태. 데이터가 없어도 항상 유효한 구조."""
    summary = read_summary()
    status = "idle"
    if isinstance(summary, dict) and summary.get("status"):
        status = summary["status"]  # running | stopped
    return {
        "status": status,
        "summary": summary,          # dict 또는 None
        "events": read_events(),     # list (빈 배열 가능)
        "detections": read_detections(),
    }


class Handler(BaseHTTPRequestHandler):
    # 기본 요청 로그를 조용히(한 줄 요약만)
    def log_message(self, fmt, *args):
        sys.stderr.write("  %s - %s\n" % (self.address_string(), fmt % args))

    def _send_json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        # 같은 origin 에서 서빙하지만, 별도 호스트에서 열 경우를 위해 CORS 허용
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):  # CORS preflight
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/exec/commands":
            self._send_json(exec_commands_info())
            return
        if path == "/api/state":
            try:
                self._send_json(build_state())
            except Exception as exc:  # 어떤 경우에도 500 대신 빈 상태
                self._send_json({
                    "status": "idle", "summary": None,
                    "events": [], "detections": {"ap_table": [], "findings": []},
                    "error": str(exc),
                })
            return
        self._serve_static(path)

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/exec":
            self._handle_exec()
            return
        if path != "/api/events":
            self._send_json({"error": "unknown endpoint"}, code=404)
            return
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            event = json.loads(raw.decode("utf-8", "replace"))
        except ValueError:
            self._send_json({"error": "invalid json"}, code=400)
            return
        with _EVENTS_LOCK:
            _EVENTS.append(event)
        self._send_json({"ok": True})

    def _handle_exec(self):
        if not EXEC_ENABLED:
            self._send_json({"ok": False,
                             "error": "명령 실행 기능이 비활성화되어 있습니다. "
                                      "(WFSAT_ENABLE_EXEC=1 로 실행)"}, code=403)
            return
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw.decode("utf-8", "replace"))
        except ValueError:
            self._send_json({"ok": False, "error": "invalid json"}, code=400)
            return
        cmd = (payload or {}).get("command", "")
        try:
            result = run_command(cmd)
        except Exception as exc:  # 어떤 실행 오류도 500 대신 JSON 으로
            result = {"ok": False, "command": cmd,
                      "error": "실행 중 오류: %s" % exc}
        self._send_json(result)

    def _serve_static(self, path):
        if path == "/" or path == "":
            path = "/index.html"
        # 경로 탈출 방지: STATIC_DIR 밖으로 나가지 못하게 정규화
        rel = os.path.normpath(path.lstrip("/")).replace("\\", "/")
        if rel.startswith("..") or os.path.isabs(rel):
            self._send_json({"error": "forbidden"}, code=403)
            return
        full = os.path.join(STATIC_DIR, rel)
        if not os.path.isfile(full):
            self._send_json({"error": "not found", "path": path}, code=404)
            return
        ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
        try:
            with open(full, "rb") as fh:
                body = fh.read()
        except OSError:
            self._send_json({"error": "read error"}, code=500)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    if not os.path.isdir(STATIC_DIR):
        sys.stderr.write("[!] Static folder not found: %s\n" % STATIC_DIR)
        sys.stderr.write("    Set WFSAT_STATIC_DIR to the dashboard_html path.\n")
        return 1
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print("=" * 60)
    print(" WFSAT Dashboard Bridge Server")
    print("=" * 60)
    print(" Dashboard  : http://%s:%d/  (live data in the Practice tab)"
          % ("localhost" if HOST == "0.0.0.0" else HOST, PORT))
    print(" Webhook    : POST http://<this host IP>:%d/api/events" % PORT)
    print("              -> set as dashboard_url in et_config.conf")
    print(" State API  : GET  /api/state")
    if EXEC_ENABLED:
        print(" Exec API   : POST /api/exec  (whitelist only, %ds timeout)"
              % EXEC_TIMEOUT)
        print("              !! binds %s - anyone reachable can run the "
              "whitelisted commands" % HOST)
        if _is_root():
            print(" Privilege  : running as root - root commands run directly "
                  "(no sudo)")
        elif SUDO_CMD:
            print(" Privilege  : not root - root commands auto-prefixed with "
                  "'%s'" % SUDO_CMD)
            print("              -> needs NOPASSWD sudoers, or start with sudo")
        else:
            print(" Privilege  : not root and WFSAT_SUDO disabled - root "
                  "commands will fail")
        if TERMINAL_ENABLED:
            term = _find_terminal()
            if term:
                print(" Terminal   : new window via '%s' (attack/scan run there)"
                      % os.path.basename(shlex.split(term)[0]))
            else:
                print(" Terminal   : no terminal emulator found - will fall back "
                      "to background logs")
        else:
            print(" Terminal   : disabled (WFSAT_TERMINAL_ENABLE=0)")
    else:
        print(" Exec API   : disabled (set WFSAT_ENABLE_EXEC=1 to enable)")
    print(" Log dir    : %s" % LOG_DIR)
    print(" Detect JSON: %s" % DETECT_JSON)
    print(" Static dir : %s" % STATIC_DIR)
    print("-" * 60)
    print(" Press Ctrl+C to stop")
    print("=" * 60)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[+] Shutting down.")
        server.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
