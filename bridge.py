#!/usr/bin/env python3
"""bridge.py - WFSAT 대시보드 실습(라이브) 연동 브리지 서버.

표준 라이브러리만 사용한다(칼리에서 pip 설치 불필요).

역할:
  1) 정적 대시보드(dashboard_html/) 서빙
  2) POST /api/events  - et_logger.sh 의 dashboard_url 웹훅 수신(실시간 이벤트)
  3) GET  /api/state   - 공격 요약 + 이벤트 + 탐지 결과를 하나의 JSON 으로 제공

데이터가 하나도 없어도(공격 실행 전) 항상 유효한 JSON 을 200 으로 돌려준다.

환경변수로 경로 조정 가능:
  WFSAT_LOG_DIR      기본 /tmp/et_logs          (et_config.conf 의 log_dir 과 맞출 것)
  WFSAT_DETECT_JSON  기본 <LOG_DIR>/detect.json (et_detector.py --json 저장 경로)
  WFSAT_STATIC_DIR   기본 <스크립트 폴더>/dashboard_html
  WFSAT_HOST         기본 0.0.0.0
  WFSAT_PORT         기본 5000

실행:
  python3 bridge.py
"""

import glob
import json
import mimetypes
import os
import sys
import threading
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

LOG_DIR = os.environ.get("WFSAT_LOG_DIR", "/tmp/et_logs")
DETECT_JSON = os.environ.get("WFSAT_DETECT_JSON", os.path.join(LOG_DIR, "detect.json"))
STATIC_DIR = os.environ.get("WFSAT_STATIC_DIR", os.path.join(SCRIPT_DIR, "dashboard_html"))
HOST = os.environ.get("WFSAT_HOST", "0.0.0.0")
PORT = int(os.environ.get("WFSAT_PORT", "5000"))

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
