# wfsat — WiFi Frame Security Analysis Tool

무선 공격을 **공격 → 탐지 → 방어** 흐름으로 실습하고, 실시간 대시보드로 관찰하는 교육용 도구 모음.

> ⚠️ **본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.**

---

## 목차

- [0. 준비물](#0-준비물)
- [1. 대시보드 실행 & 명령 콘솔](#1-대시보드-실행--명령-콘솔)
- [2. 인터페이스 자동 배정 규칙](#2-인터페이스-자동-배정-규칙)
- [3. 공격별 흐름](#3-공격별-흐름)
  - [3-1. Evil Twin (스니핑 공격)](#3-1-evil-twin-스니핑-공격)
  - [3-2. Beacon Flood](#3-2-beacon-flood)
- [4. 탐지 분석 — detector/et_detector.py](#4-탐지-분석--detectoret_detectorpy)
- [5. 파일 구성](#5-파일-구성)
- [6. 트러블슈팅](#6-트러블슈팅)
- [7. 원격/외부 접속](#7-원격외부-접속)

---

## 0. 준비물

- Kali Linux (또는 유사 배포판), `mdk4`·`aircrack-ng`·`hostapd`·`dnsmasq`·`ettercap`·`tcpdump`·`iw`·`iptables`·`python3` 등
- **무선 어댑터**
  - **Evil Twin**: 어댑터 2개 필요 (1개=피해 AP, 1개=공격). AP 모드 지원(`iw list`의 `Supported interface modes`에 `AP`).
  - **Beacon Flood**: 어댑터 1개로도 가능 (단, 같은 어댑터로 캡처는 불가 → 탐지까지 하려면 캡처용 어댑터가 하나 더 있으면 편함).
- 탐지기용 파이썬 패키지: `pip install -r detector/requirements.txt`

### 의존성 점검/설치 — `et_check_deps.sh` (콘솔 별칭: `deps`)
```bash
sudo bash et_check_deps.sh          # 점검 후 누락/구버전 자동 설치
bash et_check_deps.sh --check-only  # 설치 없이 점검만 (root 불필요)
```

---

## 1. 대시보드 실행 & 명령 콘솔

정적 대시보드에 **학습 / 실습** 두 모드가 있다 (우측 상단 토글).
- **학습 모드** — `scenarios.js` 목업으로 공격 시나리오를 단계별로 재생. 서버 없이도 됨.
- **실습 모드** — 실제 공격/탐지 결과를 3초마다 폴링해 표시 + **명령 콘솔** 제공. 브리지 서버 필요.

### 브리지 실행
```bash
# 프로젝트 루트에서 실행 (명령 경로가 루트 기준이라 위치가 중요)
sudo python3 bridge.py     # 127.0.0.1:5000, dashboard_html/ 도 함께 서빙
```
- 공격이 `log_dir`(기본 `/tmp/et_logs`)에 남긴 로그를 직접 읽으므로 **공격과 같은 Kali에서 실행**한다.
- 접속: `http://<Kali IP>:5000/` → 우측 상단 **"실습"** 토글.
- 브리지는 스스로 프로젝트 루트를 찾아 명령을 그 위치에서 실행한다(어디서 띄우든 동작).

### 명령 콘솔 (실습 탭 오른쪽)
실습 탭 오른쪽에 **명령 콘솔**이 붙어 있다(스크롤해도 고정). 여기 입력한 명령은 **브리지가 도는 Kali에서 실행**되고, 결과/진행 로그가 콘솔에 **실시간으로** 표시된다.

- **짧은 별칭**으로 입력한다. 서버가 실제 명령으로 변환해 실행한다:

  | 별칭 | 실제 실행 (프로젝트 루트 기준) | 단계 | 설명 |
  |------|-----------|------|------|
  | `deps` | `bash et_check_deps.sh` | 준비 | 의존성 점검/설치 |
  | `scan` | `bash evil_twin/et_scan.sh` | 준비 | 주변 AP 스캔 → config 저장 (실제 대상용) |
  | `ap` | `bash evil_twin/lab_victim_ap.sh` | 공격 | 실습용 피해 AP 생성 + 대상 자동 등록 |
  | `attack` | `bash evil_twin/et_sniffing_attack.sh` | 공격 | Evil Twin(가짜 AP+deauth+스니퍼) |
  | `beacon` | `bash beacon_flood/et_beacon_flood.sh` | 공격 | Beacon Flood(가짜 SSID 대량 송출) |
  | `karma` | `bash karma/et_karma_attack.sh` | 공격 | KARMA(모든 probe 에 응답하는 가짜 AP → 자동 연결 유도) |
  | `arp` | `bash arp_spoofing/et_arp_spoof.sh` | 공격 | ARP 스푸핑(피해자↔게이트웨이 MITM) |
  | `wps` | `bash wps/et_wps_attack.sh` | 공격 | WPS PIN 공격(reaver pixie-dust) → PSK 획득 |
  | `capture` | `bash beacon_flood/et_capture.sh` | 탐지 | 관리 프레임 pcap 캡처 |
  | `detect` | `python3 detector/et_detector.py` | 탐지 | pcap 분석 → Evil Twin·Beacon Flood 탐지 |
  | `stop` | `bash et_stop.sh` | 조회 | 실행 중인 공격 중지 (`stop all`=피해 AP까지) |
  | `iface` | `iw dev` | 조회 | 무선 인터페이스 목록 |
  | `wifi` | `iwconfig` | 조회 | 무선 어댑터 상태 |
  | `config` | `cat et_config.conf` | 조회 | 설정값 출력 |

  > 콘솔에서는 별칭(`scan`·`attack`…)만 입력하면 되고, 서버가 위 경로로 변환해 실행한다. 아래 표는 파일이 실제로 어디 있는지 참고용.

- **`help`** 를 입력하면 현재 상황에 맞는 **다음 단계**와 명령을 안내한다(순차 가이드). `reset` 으로 진행 초기화.
- **root 자동 처리**: root가 필요한 명령은 서버가 자동으로 `sudo -n`을 붙인다(브리지를 root로 실행 중이면 그대로). → 콘솔에서 `sudo`를 칠 필요 없음. (NOPASSWD sudoers 또는 root로 브리지 실행 필요 — [docs/security.md](docs/security.md) 참고)
- 오래 도는 명령(`ap`/`attack`/`beacon`/`capture`)은 **백그라운드**로 돌고 로그가 콘솔에 실시간 스트리밍된다. 로그는 `<log_dir>/job_*.log`에도 저장.

브리지는 기본적으로 `127.0.0.1`에서 수신한다. 콘솔 API에 자체 인증이 없으므로 외부 인터페이스에서 열람을 제공하려면 `WFSAT_ENABLE_EXEC=0`으로 실행 API를 끈다. [콘솔 보안 설정](docs/security.md)

---

## 2. 인터페이스 자동 배정 규칙

각 작업은 **무선 어댑터를 순서대로 자동 배정**한다(대화형 선택 없음). 순서는 이름순(`wlan0`, `wlan1`…).

| 작업 | 사용 어댑터 | 비고 |
|------|-------------|------|
| 피해 AP (`ap`) | **1번째** (예: wlan0) | 공격 어댑터와 다른 것을 자동 선택 |
| 공격 (`attack`) | **2번째** (예: wlan1) | 어댑터가 1개뿐이면 **에러**(Evil Twin은 2개 필요) |
| Beacon Flood (`beacon`) | **2번째**, 없으면 1개 | 단독 실행은 1개로도 가능 |
| 스캔 (`scan`) / 캡처 (`capture`) | **2번째**, 없으면 1개 | 캡처는 flood 중인 어댑터와 겹치지 않게 |

- 특정 어댑터를 강제하려면 실행 시 환경변수로 지정: `interface=wlan1` (공격/스캔/캡처/beacon), `LAB_IFACE=wlan0` (피해 AP).
- `wlanX` 번호는 부팅/연결 순서로 바뀔 수 있다 → 헷갈리면 `iface`(=`iw dev`)로 현재 이름을 확인하고 env로 고정.

---

## 3. 공격별 흐름

### 3-1. Evil Twin (스니핑 공격)

**개요** — 정상 AP를 사칭한 **개방형 가짜 AP**를 띄우고 deauth로 피해자를 원래 AP에서 떼어내 가짜 AP로 유인, 트래픽/자격증명을 가로챈다.

**대시보드 흐름 (실습 탭 콘솔)**
```
ap                      # ① 피해 AP(test_lab) 생성 + 대상(bssid/essid/channel) 자동 등록  [wlan0]
                        #    → 피해 단말(헌 폰/노트북)을 test_lab 에 연결
attack                  # ② 가짜 AP + deauth + 스니퍼 실행  [wlan1]
                        #    "All components running" 이면 동작 중, 실습 탭 상태/이벤트에 표시
capture                 # ③ 비콘/프로브 캡처 → /tmp/et_logs/capture_*.pcap
detect /tmp/et_logs/capture_*.pcap --json /tmp/et_logs/detect.json   # ④ 탐지 → "Evil Twin 탐지" 표
stop                    # ⑤ 공격 중지 (인터페이스/방화벽 자동 복구)
```

**CLI로 직접** (프로젝트 루트에서)
```bash
sudo LAB_OPEN=1 bash evil_twin/lab_victim_ap.sh   # 피해 AP(개방형) — 대상 자동 등록
sudo bash evil_twin/et_sniffing_attack.sh         # 공격 (인터페이스 자동, 또는 interface= 로 지정)
sudo bash beacon_flood/et_capture.sh              # 캡처
python3 detector/et_detector.py <pcap> --json /tmp/et_logs/detect.json
sudo bash et_stop.sh
```

**핵심 포인트**
- 피해 AP는 **개방형(`LAB_OPEN=1`)** 으로 띄운다. 가짜 트윈이 개방형이라, 보안 방식이 같아야 deauth 후 단말이 트윈으로 자동 로밍한다.
- `lab_victim_ap.sh`가 대상값과 `preserve_external_aps=1`을 `et_config.conf`에 자동 기록 → **`scan` 불필요**, 스캔/공격이 실습 AP를 죽이지 않음.
- 실제 외부 AP를 대상으로 할 땐 `ap` 대신 `scan`으로 대상을 잡고 `attack`.

### 3-2. Beacon Flood

**개요** — **고정 이름 + 숫자**(예: `Free_WiFi_1`, `Free_WiFi_2` …)의 가짜 SSID를 대량 송출해 주변 AP 목록과 채널을 혼잡하게 만드는 DoS. 클라이언트의 AP 선택을 방해한다.

**대시보드 흐름 (실습 탭 콘솔)**
```
beacon                  # ① 가짜 SSID 대량 송출 (기본 Free_WiFi_1..30)  [wlan1 또는 유일 어댑터]
capture                 # ② 비콘 캡처 → /tmp/et_logs/capture_*.pcap   (flood 와 다른 어댑터 권장)
detect /tmp/et_logs/capture_*.pcap --json /tmp/et_logs/detect.json   # ③ 탐지 → "Beacon Flood(BF)" 표시
stop                    # ④ 중지
```

**CLI로 직접 / 파라미터** (프로젝트 루트에서)
```bash
sudo bash beacon_flood/et_beacon_flood.sh
# 옵션(env):
sudo BF_BASE="Cafe_" BF_COUNT=50 BF_PPS=1000 BF_CHANNEL=6 bash beacon_flood/et_beacon_flood.sh
```
| env | 기본값 | 설명 |
|-----|--------|------|
| `BF_BASE` | `Free_WiFi_` | 고정 base 이름 (뒤에 숫자) |
| `BF_COUNT` | `30` | 생성할 SSID 개수 |
| `BF_PPS` | `1000` | 초당 beacon 수 |
| `BF_CHANNEL` | config `channel` 또는 `6` | 송출 채널 |

**핵심 포인트**
- 내부적으로 `mdk4 <iface> b -f <SSID목록> -c <ch> -s <pps>` 를 쓴다(없으면 `mdk3`).
- 탐지는 **같은 base 이름의 숫자형 SSID가 서로 다른 BSSID 8개 이상**이면 Beacon Flood로 판정(신호 **S4**).
- 어댑터가 2개뿐(피해 AP + flood)이면 캡처할 여유가 없다 → flood를 잠깐 `stop` 하고 캡처하거나, 캡처용 어댑터를 따로 둔다.

### KARMA 공격 — `karma/et_karma_attack.sh`

클라이언트가 자동 연결을 위해 과거 접속 네트워크(PNL)를 directed probe 로 계속 묻는 점을 악용한다. `airbase-ng -P` 로 **어떤 SSID 를 물어봐도 "여기 있다"고 응답**하는 가짜 AP(`at0`)를 띄워 자동 연결 기기를 끌어들이고, dnsmasq(DHCP)+선택적 NAT 로 실제 연결까지 재현한다.

```bash
sudo bash karma/et_karma_attack.sh
# 옵션(env):
sudo KARMA_ESSID="Cafe_Free" KARMA_CHANNEL=6 bash karma/et_karma_attack.sh
sudo KARMA_NAT=0 bash karma/et_karma_attack.sh          # 인터넷 공유 끄기
sudo interface=wlan1 bash karma/et_karma_attack.sh      # 공격 어댑터 지정
```
- 클라이언트 연결은 다른 공격과 동일하게 실습 탭의 **상태/이벤트 카드**(attack_start · client_connected · 클라이언트 수 · attack_stop)에 채워진다.
- 종료는 Ctrl+C 또는 `stop`. 자세한 옵션은 [`karma/README.md`](karma/README.md).

### ARP 스푸핑 공격 — `arp_spoofing/et_arp_spoof.sh`

LAN 에서 피해자에게 "게이트웨이 = 내 MAC", 게이트웨이에 "피해자 = 내 MAC" 이라고 위조 ARP 를 주입해 둘 사이 트래픽을 공격자로 끌어오는 **중간자(MITM)** 공격. `ip_forward` 로 트래픽을 중계하므로 피해자는 인터넷이 그대로 되는 것처럼 보인다.

```bash
sudo ARP_TARGET=192.168.10.24 bash arp_spoofing/et_arp_spoof.sh
# 전부 지정:
sudo ARP_TARGET=192.168.10.24 ARP_GATEWAY=192.168.10.1 ARP_IFACE=eth0 bash arp_spoofing/et_arp_spoof.sh
```
- `ARP_TARGET`(피해자 IP)만 필수. 게이트웨이/인터페이스는 기본 라우트에서 자동 감지.
- 종료(Ctrl+C) 시 arpspoof 가 정상 ARP 를 재전송해 ARP 테이블을 복구. 자세히는 [`arp_spoofing/README.md`](arp_spoofing/README.md).

### WPS 공격 — `wps/et_wps_attack.sh`

WPS PIN(8자리)의 설계 약점을 공격해 WPA/WPA2 비밀번호(PSK)를 얻는다. 기본은 **pixie-dust**(오프라인, 빠름), `WPS_PIXIE=0` 이면 온라인 PIN brute.

```bash
sudo bash wps/et_wps_attack.sh                                   # 대상 미지정 → WPS AP 스캔(wash)
sudo WPS_BSSID=AA:BB:CC:11:22:33 WPS_CHANNEL=6 bash wps/et_wps_attack.sh
```
- `WPS_BSSID` 가 없으면 `wash` 로 WPS 활성 AP 를 스캔해 보여주고 종료 → 대상 골라 재실행.
- PIN/PSK 를 찾으면 `credential_captured` 이벤트로 기록 → 실습 탭 **자격증명 수**에 반영. 자세히는 [`wps/README.md`](wps/README.md).

> 학습 탭에는 이 공격들 외에도 목업 시나리오(Auth DoS, WIDS 혼란, Handshake 등)가 있으나, **실제 실행 스크립트가 있는 건 Evil Twin · Beacon Flood · KARMA · ARP 스푸핑 · WPS** 다섯 가지다.

---

## 4. 탐지 분석 — detector/et_detector.py

저장된 PCAP을 오프라인으로 분석해 **Evil Twin**과 **Beacon Flood**를 탐지하고, 대시보드의 탐지 표와 Beacon 타임라인에 표시할 JSON을 만든다.

```bash
pip install -r requirements.txt
python3 detector/et_detector.py capture.pcap                                  # 리포트만
python3 detector/et_detector.py capture.pcap --json /tmp/et_logs/detect.json  # + 대시보드 연동
```
- `--json <경로>` — AP 목록, 탐지 항목, Beacon 타임라인 저장. 브리지의 `WFSAT_DETECT_JSON`(기본 `<log_dir>/detect.json`)과 같은 경로면 대시보드가 자동으로 읽는다.
- `--quiet` — 리포트 없이 JSON만.

실습 탭의 **Beacon Flood 패킷 분석**에서 1초 단위 막대를 선택하면 시각(UTC), SSID, 송신 주소, BSSID, 채널을 볼 수 있다. 캡처 파일에서 처음 읽은 Beacon을 기준으로 최대 120초를 집계하고, 각 구간의 상세 표에는 처음 24개 프레임을 표시한다. 기존 JSON에 타임라인이 없으면 원본 PCAP을 다시 분석한다. [탐지 결과 형식](detector/detector.md)

**탐지 신호**
- **S1** ESSID 내 zero-width 문자 (가중치 0.45) — Evil Twin
- **S2** 1-nibble만 다른 쌍둥이 BSSID (0.20) — Evil Twin
- **S3** 암호화 다운그레이드 WPA→OPEN (0.15) — Evil Twin
- **S4** 같은 base 이름 + 숫자 SSID가 서로 다른 BSSID **8개 이상** — Beacon Flood
- 판정: `score ≥ 0.6` 또는 S1/S4 → **공격중**, `≥ 0.3` → **의심**, 그 외 **정상**.

설계 근거는 [`detector/README.md`](detector/README.md) / [`docs/evil-twin-defense.md`](docs/evil-twin-defense.md).

---

## 5. 파일 구성

공격 종류별로 폴더를 나눴다. 공유 파일(설정·로거·의존성 점검)은 루트에 둔다.

```
wfsat/
├─ bridge.py               # 브리지 서버 (/api/state·/api/exec·/api/exec/log)
├─ et_config.conf          # 공용 설정 (공격 대상·인터페이스·log_dir 등)
├─ et_logger.sh            # 공격 이벤트 로깅 (JSONL/요약 JSON)
├─ et_check_deps.sh        # 의존성 점검/설치            (deps)
├─ et_stop.sh              # 실행 중인 공격 중지          (stop)
├─ evil_twin/
│  ├─ et_scan.sh           # 주변 AP 스캔 → et_config.conf (scan)
│  ├─ lab_victim_ap.sh     # 실습용 피해 AP 생성 + 대상 자동 등록 (ap)
│  └─ et_sniffing_attack.sh# Evil Twin/스니핑 공격 본체    (attack)
├─ beacon_flood/
│  ├─ et_beacon_flood.sh   # Beacon Flood 공격            (beacon)
│  └─ et_capture.sh        # 관리 프레임 pcap 캡처         (capture)
├─ karma/
│  ├─ et_karma_attack.sh   # KARMA 공격(airbase-ng -P)    (karma)
│  └─ README.md            # KARMA 공격 설명
├─ arp_spoofing/
│  ├─ et_arp_spoof.sh      # ARP 스푸핑 MITM(arpspoof)    (arp)
│  └─ README.md            # ARP 스푸핑 설명
├─ wps/
│  ├─ et_wps_attack.sh     # WPS PIN 공격(reaver)         (wps)
│  └─ README.md            # WPS 공격 설명
├─ detector/
│  └─ et_detector.py       # Evil Twin·Beacon Flood 오프라인 pcap 탐지기 (detect)
├─ dashboard_html/         # 학습/실습 대시보드 (정적: index.html·app.js·…)
└─ docs/                   # 설계·보안 문서 (evil-twin-defense.md, security.md, …)
```

> - 서버 코드(`bridge.py`)·제어 스크립트(`et_stop.sh`)는 **정적 서빙 폴더(`dashboard_html/`) 밖**에 둔다 → 웹으로 소스가 노출되지 않는다.
> - 셸 스크립트들은 `et_config.conf`/`et_logger.sh`를 "같은 폴더 → 없으면 상위(루트)" 순으로 찾으므로, 서브폴더에 있어도 루트의 공용 파일을 그대로 쓴다.

### 주요 설정값 (`et_config.conf`)
- `interface` — 공격 어댑터 (실행 시 `interface=`로 덮어쓰기 가능)
- `internet_interface` — 인터넷 공유용 업링크(예: `eth0`, `scan`이 자동 감지)
- `preserve_external_aps` — `1`이면 공격 인터페이스만 정리(실습 AP 보호). `ap`가 자동 설정.
- `log_dir` — 로그 경로(기본 `/tmp/et_logs`, 브리지 `WFSAT_LOG_DIR`과 일치)
- `dashboard_url` — 웹훅 전송용(비우면 브리지가 로그 파일 직접 읽음)

---

## 6. 트러블슈팅

**`attack`이 "All components running"인데 폰에 가짜 AP가 안 뜬다**
- 가짜 AP 이름엔 보이지 않는 문자(zero-width space)가 붙어 실제와 **똑같아 보인다.** WiFi Analyzer(BSSID 표시)로 보면 같은 이름이 BSSID 2개로 뜬다.
- `iface`(=`iw dev`)에서 공격 인터페이스가 `type AP`인지 확인. `type managed`면 hostapd 미기동 → **xterm 미설치**가 대표 원인(`sudo apt install -y xterm`) 또는 tmux 모드 사용.

**deauth 후 폰이 트윈으로 안 붙는다**
- 피해 AP가 WPA2인데 트윈은 개방형이라 보안이 달라 자동 로밍이 안 됨 → `LAB_OPEN=1`로 피해 AP를 개방형으로.

**어댑터가 1개뿐이라 `attack`이 에러난다**
- Evil Twin은 피해 AP(1번째)와 공격(2번째)에 각각 어댑터가 필요하다. 두 번째 무선 어댑터를 연결하거나 `interface=`로 지정.

**`beacon` 후 `detect`에 Beacon Flood가 안 뜬다**
- 캡처(`capture`)를 flood와 **다른 어댑터/같은 채널**에서 했는지 확인. 같은 어댑터면 flood 중이라 캡처가 안 된다.
- 기본 임계값은 서로 다른 BSSID 8개 이상. `BF_COUNT`가 충분한지 확인.

**대시보드가 계속 비어 있다**
- 브리지가 공격과 같은 호스트인지, 실제 접근 가능한 IP(가짜/피해 AP 서브넷 `192.168.50.x` 아님)로 접속했는지, **실습 모드로 토글**했는지 확인.
- 공격 실행 시 WiFi 관리 경로가 끊길 수 있으니 대시보드는 **유선(eth0)** 으로 접속하는 게 안정적.

**외부(다른 기기/LAN)에서 접속이 안 된다**
- 브리지가 `127.0.0.1:5000`에서 수신 중인지 확인하고 [원격 접속](#7-원격외부-접속) 절차를 사용한다.

---

## 7. 원격/외부 접속

본인 기기의 터미널에서 SSH 키로 터널을 연 뒤, 같은 기기의 브라우저에서 대시보드를 열 수 있다. 준비 사항, 접속 명령, 종료 방법은 [SSH 원격 열람 가이드](docs/remote-access.md)를 참고한다.

원격에서 저장된 탐지 결과를 콘솔로 조회하려면 가이드의 `WFSAT_REPORT_ONLY=1` 설정으로 실행한 뒤 `report`를 입력한다.

---

## 창 모드 (xterm / tmux)

`attack`(Evil Twin)은 내부 컴포넌트(hostapd/deauth/ettercap)를 **xterm 창**에서 띄운다.
- **GUI 데스크톱**: `xterm`만 있으면 됨(`deps`가 설치).
- **SSH/헤드리스**: X 디스플레이가 없으면 tmux 모드 사용:
  ```bash
  sudo tmux new -s airgeddon
  AIRGEDDON_WINDOWS_HANDLING=tmux interface=wlan1 bash evil_twin/et_sniffing_attack.sh
  ```
