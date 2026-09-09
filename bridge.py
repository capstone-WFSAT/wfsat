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

# 실행 허용 명령 화이트리스트.
#   prefix     : 명령이 이 문자열과 정확히 일치하거나(allow_args=False),
#                이 문자열 + 공백으로 시작해야(allow_args=True) 허용된다.
#   allow_args : True 면 prefix 뒤에 인자를 덧붙일 수 있다(프로그램 자체는 고정).
#   background : True 면 기다리지 않고 백그라운드로 실행하고 즉시 PID 를 돌려준다
#                (오래 도는 공격/AP 스크립트용). 출력은 로그 파일로 리다이렉트된다.
# 명령 앞의 "sudo " 접두사는 허용된다(브리지를 root 로 실행하지 않은 경우 대비).
ALLOWED_COMMANDS = [
    {"label": "의존성 점검", "prefix": "bash et_check_deps.sh",
     "allow_args": True, "desc": "필요 도구 점검/설치 (--check-only 로 점검만)"},
    {"label": "AP 스캔", "prefix": "bash et_scan.sh",
     "allow_args": True, "desc": "주변 AP 스캔"},
    {"label": "Evil Twin 탐지", "prefix": "python3 detector/et_detector.py",
     "allow_args": True, "desc": "pcap 분석으로 Evil Twin 탐지 (인자로 pcap 경로)"},
    {"label": "피해 AP 실행", "prefix": "bash lab_victim_ap.sh",
     "allow_args": True, "background": True, "desc": "실습용 피해 AP 생성 (백그라운드)"},
    {"label": "스니핑 공격 실행", "prefix": "bash et_sniffing_attack.sh",
     "allow_args": True, "background": True, "desc": "가짜 AP+deauth+스니퍼 (백그라운드)"},
    {"label": "무선 인터페이스", "prefix": "iw dev",
     "desc": "무선 인터페이스 목록"},
    {"label": "인터페이스 상태", "prefix": "iwconfig",
     "desc": "무선 어댑터 상태"},
    {"label": "현재 설정", "prefix": "cat et_config.conf",
     "desc": "et_config.conf 값 출력"},
]

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


def run_command(cmd):
    """화이트리스트 검증 후 명령을 실행하고 결과 dict 를 반환한다."""
    cmd = (cmd or "").strip()
    if not cmd:
        return {"ok": False, "command": cmd, "error": "빈 명령입니다."}
    for ch in _FORBIDDEN_CHARS:
        if ch in cmd:
            return {"ok": False, "command": cmd,
                    "error": "허용되지 않은 문자가 포함되어 있습니다: %r" % ch}
    entry = _match_allowed(cmd)
    if entry is None:
        return {"ok": False, "command": cmd,
                "error": "허용되지 않은 명령입니다. 허용 목록의 명령만 실행할 수 있습니다."}
    try:
        argv = shlex.split(cmd)
    except ValueError as exc:
        return {"ok": False, "command": cmd,
                "error": "명령을 해석할 수 없습니다: %s" % exc}
    if entry.get("background"):
        return _run_background(argv, cmd)
    return _run_foreground(argv, cmd)


def exec_commands_info():
    """콘솔 UI 가 표시할 허용 명령 목록."""
    return {
        "enabled": EXEC_ENABLED,
        "timeout": EXEC_TIMEOUT,
        "commands": [
            {"label": e["label"], "prefix": e["prefix"],
             "desc": e.get("desc", ""),
             "allow_args": bool(e.get("allow_args")),
             "background": bool(e.get("background"))}
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
