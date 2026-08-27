# wfsat
capstone project main repository

## 사용 방법

### 1. 의존성 점검/설치 — `et_check_deps.sh`
프로젝트 실행에 필요한 도구(aircrack-ng, hostapd, ettercap, mdk4, dnsmasq, iw 등)의 설치 여부와 버전을 점검한다.
```bash
sudo ./et_check_deps.sh          # 점검 후 누락/구버전 도구 자동 설치
./et_check_deps.sh --check-only  # 설치 없이 점검만 (root 불필요)
```

### 2. AP 스캔 — `et_scan.sh`
무선 인터페이스를 모니터 모드로 전환해 주변 AP를 스캔하고, 선택한 AP 정보를 `et_config.conf`에 저장한다.
```bash
sudo ./et_scan.sh
```
- 인터페이스가 여러 개면 번호 선택 프롬프트가 뜸
- 스캔 후 AP 목록에서 대상 선택 → `bssid`/`essid`/`channel`/`phy_interface`가 설정 파일에 자동 반영됨

### 3. 이블트윈/스니핑 공격 — `et_sniffing_attack.sh`
`et_scan.sh`로 저장된 설정을 기반으로 가짜 AP를 띄우고 트래픽을 스니핑한다.
```bash
sudo ./et_sniffing_attack.sh
```
- 사전에 `et_scan.sh` 실행으로 `et_config.conf`에 대상 AP 정보가 채워져 있어야 함
- 공격 진행 중 이벤트는 `et_logger.sh`를 통해 `et_config.conf`의 `log_dir`(기본 `/tmp/et_logs`)에 JSONL/요약 JSON으로 기록됨

### 4. 대시보드 UI — `dashboard_html/`
정적 HTML/JS 로 만든 교육용 대시보드. **학습 / 실습** 두 모드가 있다(우측 상단 토글).

- **학습 모드** — `scenarios.js` 의 목업 데이터로 8개 공격 시나리오를 단계별로 재생. 읽으며 흐름을 익히는 용도. 서버 없이 열어도 된다:
  ```bash
  python3 -m http.server 8080 --directory dashboard_html
  # http://localhost:8080
  ```
- **실습 모드** — 칼리에서 실제로 실행한 공격/탐지 결과를 실시간으로 표시. 이때는 아래 브리지 서버가 필요하다.

### 5. 실습 연동 — `bridge.py` (라이브 대시보드)
공격/탐지 결과를 대시보드 **실습 모드**로 연결하는 브리지 서버. 표준 라이브러리만 쓰므로 추가 설치가 없다.

```bash
python3 bridge.py            # 기본 0.0.0.0:5000, dashboard_html/ 도 함께 서빙
```

동작:
- `POST /api/events` — `et_logger.sh` 의 웹훅(`dashboard_url`)을 수신
- `GET  /api/state` — 공격 요약 + 이벤트 + 탐지 결과를 합쳐 제공 (대시보드가 3초마다 폴링). 데이터가 없어도 오류 없이 "대기 중" 으로 표시된다.

**연동 순서:**
```bash
# 1) 브리지 서버 먼저 실행 (dashboard_html 도 이 서버가 서빙)
python3 bridge.py

# 2) et_config.conf 에 웹훅 지정 (이 호스트 IP:포트)
#    dashboard_url="http://<칼리IP>:5000/api/events"

# 3) 공격 실행 → 이벤트가 실시간 전송됨
sudo ./et_sniffing_attack.sh

# 4) (선택) 탐지 실행 → 결과 JSON 을 브리지가 읽는 위치에 저장
python3 detector/et_detector.py capture-01.cap --json /tmp/et_logs/detect.json

# 5) 브라우저에서 http://<칼리IP>:5000 → 우측 상단 "실습" 토글
```

경로/포트는 환경변수로 조정한다: `WFSAT_LOG_DIR`(기본 `/tmp/et_logs`, `et_config.conf` 의 `log_dir` 과 일치시킬 것), `WFSAT_DETECT_JSON`(기본 `<LOG_DIR>/detect.json`), `WFSAT_PORT`(기본 `5000`).