# wfsat

capstone project main repository

WiFi 이블트윈/스니핑 공격 실습 도구 모음. 스캔 → 가짜 AP → deauth → 스니핑 → 실시간 대시보드까지의 흐름을 다룬다.

> ⚠️ **본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.**

---

## 0. 준비물

- Kali Linux (또는 유사 배포판)
- **무선 어댑터 2개** (실습용 lab 모드 기준)
  - 하나는 공격용(스캔/가짜 AP/deauth), 하나는 실습용 피해 AP
  - AP 모드를 지원해야 함 → `iw list`의 `Supported interface modes`에 `AP`가 있어야 함
  - 가능하면 서로 다른 물리 라디오(phy). `iw dev`의 `wiphy` 번호가 다르면 독립 라디오.
- 실제 대상(외부 공유기)을 공격하는 경우엔 어댑터 1개로도 가능

### 의존성 점검/설치 — `et_check_deps.sh`
필요한 도구를 점검하고 누락분을 apt로 설치한다. (aircrack-ng, hostapd, dnsmasq, ettercap, mdk4, iw, iptables, **xterm/tmux**, network-manager, python3 등)
```bash
sudo bash et_check_deps.sh          # 점검 후 누락/구버전 자동 설치
bash et_check_deps.sh --check-only  # 설치 없이 점검만 (root 불필요)
```
> **xterm은 필수다.** 공격 스크립트는 각 컴포넌트(hostapd/deauth/ettercap)를 xterm 창에서 실행한다. xterm이 없으면 가짜 AP가 조용히 실행되지 않는다. 헤드리스/SSH 환경이라면 아래 "창 모드(tmux)" 참고.

---

## 사용 방법 A — 격리된 실습 (권장, 자체 피해 AP)

실제 홈 네트워크를 건드리지 않고, 직접 만든 피해 AP를 대상으로 공격을 재현한다.

### 1) 피해 AP 띄우기 — `lab_victim_ap.sh`
두 번째 어댑터에 hostapd로 "피해 AP"(`test_lab`)를 만든다.
```bash
sudo LAB_IFACE=wlan1 LAB_OPEN=1 bash lab_victim_ap.sh
```
- `LAB_IFACE` — 피해 AP용 어댑터 (생략 시 공격 인터페이스가 아닌 무선 어댑터 자동 선택)
- `LAB_OPEN=1` — **개방형 AP로 생성**. 가짜 트윈이 개방형(`wpa=0`)이라, 피해 AP도 개방형이어야 deauth 후 폰이 트윈으로 자동 로밍한다. (기본값은 WPA2)
- 그 외: `LAB_ESSID`(기본 test_lab), `LAB_PASS`(WPA2 암호, 8자+), `LAB_CHANNEL`(기본 6), `LAB_NAT=0`(인터넷 공유 끄기)

이 스크립트는 실행 시 `et_config.conf`에 대상(`bssid`/`essid`/`channel`)을 자동 기록하고, `preserve_external_aps=1`도 설정한다 → **et_scan을 건너뛸 수 있고, 스캔/공격이 이 피해 AP를 죽이지 않는다.** 종료(Ctrl+C) 시 원상복구.

### 2) 피해 단말 연결
헌 폰/노트북 등을 `test_lab`에 연결한다. (개방형이면 그냥 접속)

### 3) 공격 실행 — `et_sniffing_attack.sh`
스캔 없이 바로 실행. 공격에 쓸 인터페이스를 지정한다:
```bash
sudo interface=wlanatk bash et_sniffing_attack.sh
```
- `interface=` — 이번 실행에 쓸 공격 어댑터 (config보다 우선). 생략하면 config 값 → 그것도 없으면 목록에서 선택.
- "All components running"이 뜨면 가짜 AP + deauth + 스니퍼가 동작 중.

### 4) (선택) 대시보드로 실시간 확인
아래 "대시보드" 섹션 참고.

---

## 사용 방법 B — 실제 대상 (외부 공유기)

허가받은 실제 AP를 대상으로 하는 경우.

### 1) AP 스캔 — `et_scan.sh`
```bash
sudo bash et_scan.sh
# 또는 인터페이스 지정: sudo interface=wlan0 bash et_scan.sh
```
- 무선 인터페이스를 모니터 모드로 전환해 주변 AP 스캔
- 목록에서 대상 선택 → `bssid`/`essid`/`channel`/`phy_interface`/`internet_interface`가 `et_config.conf`에 자동 반영 (`internet_interface`는 기본 라우트에서 자동 감지)

### 2) 공격 실행
```bash
sudo bash et_sniffing_attack.sh
```

---

## 인터페이스 이름 문제 (wlan0/wlan1 뒤바뀜)

`wlanX` 번호는 연결/부팅 순서에 따라 **바뀔 수 있다.** 그래서 실행할 때마다 인터페이스를 직접 지정하는 방식을 쓴다:
```bash
iw dev                                        # 지금 이름↔어댑터 확인
sudo LAB_IFACE=<피해AP 어댑터> bash lab_victim_ap.sh
sudo interface=<공격 어댑터> bash et_sniffing_attack.sh
```
`et_scan.sh` / `et_sniffing_attack.sh` 모두 `interface=` 환경변수를 지원한다 (config보다 우선, stale `phy_interface`는 자동 무시).

---

## 창 모드 (xterm / tmux)

공격 컴포넌트는 기본적으로 **xterm 창**에서 실행된다.

- **GUI 데스크톱**: `xterm`만 설치돼 있으면 됨 (`et_check_deps.sh`가 설치).
- **SSH/헤드리스**: X 디스플레이가 없으면 xterm이 안 뜬다. tmux 모드를 쓴다:
  ```bash
  sudo tmux new -s airgeddon
  # tmux 세션 안(이미 root)에서:
  AIRGEDDON_WINDOWS_HANDLING=tmux interface=wlanatk bash et_sniffing_attack.sh
  ```
  tmux 창 전환: `Ctrl+b` → `n`/`p` 또는 숫자키.

---

## 대시보드 (실시간) — `bridge.py` + `dashboard_html/`

정적 대시보드에 **학습 / 실습** 두 모드가 있다 (우측 상단 토글).

- **학습 모드** — `scenarios.js` 목업으로 공격 시나리오를 단계별 재생. 서버 없이도 가능.
- **실습 모드** — 실제 공격 결과를 3초마다 폴링해 표시. 브리지 서버 필요.

### 브리지 실행
```bash
python3 bridge.py     # 0.0.0.0:5000, dashboard_html/ 도 함께 서빙 (추가 설치 불필요)
```
- 공격이 `et_config.conf`의 `log_dir`(기본 `/tmp/et_logs`)에 남긴 로그를 직접 읽는다 → **브리지는 공격과 같은 Kali에서 실행**해야 한다.
- `GET /api/state` — 요약+이벤트+탐지 결과 통합 JSON (데이터 없어도 "대기 중" 반환)

### 접속 주소 확인
브리지는 `0.0.0.0:5000`에 바인딩되므로 외부에서는 `http://<Kali IP>:5000/`로 접속한다. IP는:
```bash
ip -brief -4 addr
```
- **`eth0`(유선) IP** → 대시보드 접속용 (폰/노트북이 같은 LAN에 있을 때). `http://<eth0 IP>:5000/`
- `192.168.50.1`(피해 AP) / `192.169.x.x`(가짜 AP)는 관리 접속용으로 부적합
- 접속 후 우측 상단 **"실습"** 토글을 눌러야 폴링이 시작된다 (기본은 학습 모드).

> 공격 실행 시 `airmon-ng`/라우팅 변경으로 WiFi 관리 경로가 끊길 수 있다. 대시보드는 **공격에 안 쓰는 유선(eth0)** 으로 접속하는 것이 안정적이다.

---

## 파일 구성

| 파일 | 역할 |
|---|---|
| `et_check_deps.sh` | 의존성 점검/설치 |
| `et_scan.sh` | AP 스캔 → `et_config.conf` 기록 |
| `lab_victim_ap.sh` | 실습용 피해 AP 생성 (hostapd/dnsmasq) |
| `et_sniffing_attack.sh` | 이블트윈/스니핑 공격 본체 |
| `et_logger.sh` | 공격 이벤트 로깅 (JSONL/요약 JSON) |
| `et_config.conf` | 공용 설정 파일 |
| `bridge.py` | 대시보드 브리지 서버 |
| `dashboard_html/` | 학습/실습 대시보드 (정적) |
| `detector/` | 탐지 로직 |

### 주요 설정값 (`et_config.conf`)
- `interface` — 공격 어댑터 (실행 시 `interface=`로 덮어쓸 수 있음)
- `internet_interface` — 인터넷 공유용 업링크 (예: `eth0`, 스캔이 자동 감지)
- `preserve_external_aps` — `1`이면 전역 `airmon-ng check kill` 대신 공격 인터페이스만 정리 (같은 머신의 실습 AP 보호). lab 스크립트가 자동 설정.
- `log_dir` — 이벤트 로그 저장 경로 (기본 `/tmp/et_logs`, 브리지의 `WFSAT_LOG_DIR`과 일치시킬 것)
- `dashboard_url` — 웹훅 방식 전송 시에만 사용 (비워두면 브리지가 로그 파일을 직접 읽음)

---

## 트러블슈팅

**공격은 "All components running"인데 폰에 가짜 AP가 안 뜬다**
- 가짜 AP 이름엔 보이지 않는 문자(zero-width space)가 붙어 실제와 **똑같아 보인다.** WiFi Analyzer 앱(BSSID 표시)으로 보면 `test_lab`이 BSSID 2개로 뜬다.
- `sudo iw dev`에서 공격 인터페이스가 `type AP`인지 확인. `type managed`면 hostapd가 안 뜬 것 → **xterm 미설치**가 대표 원인. `sudo apt install -y xterm` 후 재시도(또는 tmux 모드).

**deauth 후 폰이 트윈으로 안 붙는다 / `client_connected` 이벤트가 없다**
- 피해 AP가 WPA2인데 트윈은 개방형이라 보안이 달라 자동 로밍이 안 되는 것. `LAB_OPEN=1`로 피해 AP를 개방형으로 띄운다.

**et_scan / 공격이 실습용 피해 AP를 죽인다**
- `preserve_external_aps=1`이 설정돼 있어야 한다 (lab 스크립트가 자동 설정). `grep preserve_external_aps et_config.conf`로 확인.

**대시보드가 계속 비어 있다**
- 브리지가 공격과 같은 호스트인지, 주소를 `eth0` IP로 접속했는지, **실습 모드로 토글**했는지 확인.

**인터페이스 이름이 매번 바뀐다**
- 실행 시 `interface=` / `LAB_IFACE=`로 직접 지정한다 (위 "인터페이스 이름 문제" 참고).
