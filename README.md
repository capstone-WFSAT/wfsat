# wfsat

capstone project main repository

WiFi 이블트윈/스니핑 공격 실습 도구 모음. 스캔 → 가짜 AP → deauth → 스니핑 → 실시간 대시보드까지의 흐름을 다룬다.

> ⚠️ **본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.**

---

## 목차

- [0. 준비물](#0-준비물)
- [사용 방법 A — 격리된 실습 (권장, 자체 피해 AP)](#사용-방법-a--격리된-실습-권장-자체-피해-ap)
- [사용 방법 B — 실제 대상 (외부 공유기)](#사용-방법-b--실제-대상-외부-공유기)
- [탐지 분석 — detector/et_detector.py](#탐지-분석--detectoret_detectorpy)
- [인터페이스 이름 문제 (wlan0/wlan1 뒤바뀜)](#인터페이스-이름-문제-wlan0wlan1-뒤바뀜)
- [창 모드 (xterm / tmux)](#창-모드-xterm--tmux)
- [대시보드 (실시간) — bridge.py + dashboard_html/](#대시보드-실시간--bridgepy--dashboard_html)
- [파일 구성](#파일-구성)
- [트러블슈팅](#트러블슈팅)

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

## 탐지 분석 — detector/et_detector.py

공격의 반대편, **방어/탐지** 도구다. 저장된 pcap을 오프라인으로 분석해 기본 evil twin 공격(오픈 가짜 AP 복제)을 탐지하고, 결과를 대시보드 **실습 모드의 "Evil Twin 탐지" 카드**에 채워 넣는 JSON을 만든다. 설계 근거·신호 정의는 [`detector/README.md`](detector/README.md) / [`docs/evil-twin-defense.md`](docs/evil-twin-defense.md) 참고.

### 설치
```bash
pip install -r detector/requirements.txt
```

### 1) 분석용 pcap 캡처
관리 프레임(beacon/probe response)이 담긴 pcap이 필요하다. 모니터 모드에서:
```bash
sudo airodump-ng -c <채널> --bssid <타깃> -w capture wlan0mon   # → capture-01.cap
# 또는
sudo tcpdump -i wlan0mon -w capture.pcap
```

### 2) 분석 실행 (+ 대시보드 연동)
```bash
# 리포트만 (stdout)
python3 detector/et_detector.py capture-01.cap

# 리포트 + JSON 저장 → 대시보드 "Evil Twin 탐지" 카드에 반영
python3 detector/et_detector.py capture-01.cap --json /tmp/et_logs/detect.json
```
- `--json <경로>` — `ap_table` + `findings`를 JSON으로 저장. 브리지의 `WFSAT_DETECT_JSON`(기본 `<log_dir>/detect.json`)과 **같은 경로**로 저장하면 대시보드가 자동으로 읽는다.
- `--quiet` — stdout 리포트 없이 JSON만 저장.

**P0 탐지 신호:** S1 ESSID 안 zero-width 문자(가중치 0.45) · S2 1-nibble만 다른 쌍둥이 BSSID(0.20) · S3 암호화 다운그레이드 WPA→OPEN(0.15). `score ≥ 0.6` 또는 S1 참이면 **공격중**, `≥ 0.3`이면 **의심**, 그 외 **정상**.

> 브리지 명령 콘솔(`/api/exec`)의 "Evil Twin 탐지" 명령으로도 실행할 수 있다(화이트리스트 등록됨).

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
  - **상태·이벤트 카드**는 공격 스크립트가 남기는 로그(`et_summary.json` / `*.jsonl`)에서 자동으로 채워진다.
  - **"Evil Twin 탐지" 카드**는 [`et_detector.py`가 만든 `detect.json`](#탐지-분석--detectoret_detectorpy)이 있어야 채워진다.

### 심화 탭 명령 콘솔 (`/api/exec`)
학습 모드 하단 **심화(DEEP DIVE)** 섹션 오른쪽에 채팅형 명령 콘솔이 있다. 여기서 명령을 입력하면 **브리지가 도는 Kali에서 실행**되고 결과가 콘솔에 표시된다.

- **화이트리스트 방식** — `bridge.py`의 `ALLOWED_COMMANDS`에 등록된 명령만 실행된다 (스캔/탐지/의존성 점검/피해 AP/스니핑 공격/인터페이스 조회/설정 확인). 임의 셸 명령은 거부되고, 셸 메타문자(`; | & \` $ > <` 등)도 차단된다.
- 빠른 명령 버튼(칩)으로 채워 넣거나 직접 입력한다. 인자가 필요한 명령은 칩이 앞부분만 채워준다.
- 오래 도는 공격/AP 스크립트(`et_sniffing_attack.sh`, `lab_victim_ap.sh`)는 **백그라운드로 실행**되고 즉시 PID를 돌려준다. 출력은 `<log_dir>/exec_<시각>.log`에 쌓인다.
- 조회성 명령의 최대 대기 시간은 `WFSAT_EXEC_TIMEOUT`(기본 60초).

> ⚠️ **보안** — 브리지는 기본적으로 `0.0.0.0`에 바인딩된다. 즉 같은 네트워크의 누구나 인증 없이 이 화이트리스트 명령을 실행할 수 있다. **격리된 실습 랜에서만** 사용하고, 필요하면 다음으로 잠근다:
> - `WFSAT_HOST=127.0.0.1 python3 bridge.py` — 로컬에서만 접속
> - `WFSAT_ENABLE_EXEC=0 python3 bridge.py` — 콘솔 기능 완전 비활성화 (`/api/exec`는 403, UI는 "비활성화됨" 표시)

### 접속 주소 확인
브리지는 `0.0.0.0:5000`에 바인딩되므로 외부에서는 `http://<Kali IP>:5000/`로 접속한다. IP는:
```bash
ip -brief -4 addr
```
- **`eth0`(유선) IP** → 대시보드 접속용 (폰/노트북이 같은 LAN에 있을 때). `http://<eth0 IP>:5000/`
- `192.168.50.1`(피해 AP) / `192.169.x.x`(가짜 AP)는 관리 접속용으로 부적합
- 접속 후 우측 상단 **"실습"** 토글을 눌러야 폴링이 시작된다 (기본은 학습 모드).

> 공격 실행 시 `airmon-ng`/라우팅 변경으로 WiFi 관리 경로가 끊길 수 있다. 대시보드는 **공격에 안 쓰는 유선(eth0)** 으로 접속하는 것이 안정적이다.

### 원격/외부 접속 — 다른 LAN(또는 인터넷)에서 접속
서버(Kali)를 집에 두고 **다른 네트워크의 노트북**에서 대시보드를 볼 때. VM은 대개 NAT(예: VMware `192.168.x.x`) 뒤에 있어 라우터 포트포워딩은 까다롭다 → **밖으로 나가는 터널**이 NAT를 그냥 통과하므로 가장 쉽다. (모든 명령은 서버 Kali에서 실행한다.)

| 방법 | 공개 URL | 인증 | 비고 |
|---|---|---|---|
| **Tailscale** (권장) | 없음(사설) | 계정 로그인 | 내 기기끼리만 통하는 VPN. 원격이지만 localhost처럼 사용 |
| ngrok | 있음 | `--basic-auth` 가능 | 가입 후 authtoken 1회 등록 필요 |
| cloudflared 즉석 터널 | 있음 | **없음** | `trycloudflare` URL은 인증 불가 → 공개 노출 주의 |
| SSH 포트포워딩 | 없음 | SSH 키 | 서버에 SSH로 닿을 수 있을 때(예: Tailscale SSH 경유) |

**Tailscale (권장 — 공개 URL 없음, 내 기기끼리만):**
```bash
# 서버(Kali)와 노트북 양쪽에서
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4            # 서버의 100.x.x.x 확인
# 노트북 브라우저: http://<서버 tailscale IP>:5000/   (브리지는 WFSAT_HOST=0.0.0.0)
```

**cloudflared 즉석 터널 (계정 불필요, 즉석 시연용):**
```bash
# apt 저장소에 없으므로 공식 바이너리 직접 설치 (arm64면 amd64→arm64)
curl -L -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/
cloudflared tunnel --url http://localhost:5000     # 출력되는 https://xxxx.trycloudflare.com 접속
```

**ngrok (인증 가능):**
```bash
ngrok config add-authtoken <ngrok 사이트 토큰>
ngrok http 5000 --basic-auth "demo:비밀번호"
```

> 🔐 **원격 노출 시 보안 (반드시 읽을 것)** — 명령 콘솔(`/api/exec`)은 인증이 없다. 공개 URL(cloudflared/ngrok 무인증)로 열면 **URL을 아는 누구나 서버에서 공격 명령을 실행**할 수 있다. 원격 시연에서는:
> - **화면만 보여줄 때** → 콘솔을 끄고 터널로만 연다: `WFSAT_HOST=127.0.0.1 WFSAT_ENABLE_EXEC=0 python3 bridge.py` (127.0.0.1이면 LAN 노출도 없이 터널로만 접근)
> - **원격에서 명령까지 조작할 때** → **Tailscale**(사설) 또는 **인증 붙은 터널**(ngrok `--basic-auth`, Cloudflare Access)을 쓴다. 무인증 공개 URL로 콘솔을 켜두지 말 것.
> - 현재 콘솔 활성 여부 확인: `curl -s http://localhost:5000/api/exec/commands | head -c 60` → `"enabled": true/false`

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
| `bridge.py` | 대시보드 브리지 서버 (`/api/state`·`/api/exec` 포함) |
| `dashboard_html/` | 학습/실습 대시보드 (정적) |
| `detector/` | Evil Twin 오프라인 pcap 탐지 분석기 `et_detector.py` (+ 샘플 pcap 생성기, `requirements.txt`) |
| `docs/` | 설계 문서 (`evil-twin-defense.md`, `files.md`, `main.md`) |

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

**피해 단말이 AP엔 붙는데 인터넷이 안 된다 / "인터넷 연결되지 않음"**
- 먼저 인터넷 공유(NAT)가 켜졌는지: lab 스크립트 로그에 `Internet: <iface> -> <uplink> (NAT)`가 떠야 한다. `none`이면 업링크 자동 감지 실패 → `LAB_UPLINK=<인터넷 나가는 인터페이스>`로 지정.
- **제한적 업링크(학교/회사망)에서 자주 발생.** lab 스크립트는 클라이언트에 공개 DNS(`8.8.8.8`/`1.1.1.1`)를 나눠주는데([lab_victim_ap.sh](lab_victim_ap.sh)의 `dhcp-option=6`), 이런 망은 외부 DNS(`:53`)와 DoT(`:853`)를 차단한다 → **IP 통신은 되는데 도메인이 안 풀려** "인터넷 없음"으로 보인다. (홈 공유기처럼 안 막는 망에선 기본값 그대로 잘 됨.)
  - 확인: 피해 단말에서 도메인 대신 **실제 웹서버 IP로 직접 접속**해 열리면 DNS 문제로 확정. (진단은 `sudo tcpdump -ni <uplink> port 53 or port 853` — 질의는 나가는데 응답이 없거나 RST면 차단.)
  - 삼성 등은 **비공개 DNS(Private DNS, DoT)** 가 기본 켜져 있어 막히므로 단말에서 끈다: 설정 → 연결 → 기타 연결 설정 → 비공개 DNS → **끔**.
  - 근본 해결: 업링크가 실제 쓰는 DNS를 클라이언트에 주거나, dnsmasq를 포워딩 리졸버로 돌려 `dhcp-option=6,192.168.50.1`(Kali 자신)로 넘긴다 → 클라이언트 질의가 Kali를 거쳐 업링크 DNS로 나간다.
- 참고: 게이트웨이(`192.168.50.1`)가 단말에 `ICMP time exceeded`를 계속 보내면 포워딩 루프다. 클라이언트 트래픽이 업링크로 정상 NAT되는지(`sudo iptables -t nat -L POSTROUTING -v -n`의 MASQUERADE 카운터 증가) 먼저 확인.

**대시보드가 계속 비어 있다**
- 브리지가 공격과 같은 호스트인지, 주소를 `eth0` IP로 접속했는지, **실습 모드로 토글**했는지 확인.

**외부(다른 기기/LAN)에서 접속이 안 된다**
- `sudo ss -tlnp | grep :5000`이 `0.0.0.0:5000`인지 확인(`127.0.0.1`이면 로컬 전용).
- 접속 주소가 가짜/피해 AP 서브넷(`192.168.50.x`, `192.169.x.x`)이 아니라 실제 접근 가능한 IP인지 확인. VM이 NAT(`192.168.x.x`) 뒤면 다른 LAN에선 직접 접속 불가 → 위 **"원격/외부 접속"** 의 터널(Tailscale 등)을 쓴다.
- 서버 자신에서 `curl -s http://localhost:5000/api/state | head -c 80`이 응답하면 서버는 정상 → 네트워크/방화벽 문제.
- 방화벽: `sudo ufw status` / `sudo iptables -L INPUT -n`. 막혀 있으면 `sudo ufw allow 5000/tcp` 또는 `sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT`.

**인터페이스 이름이 매번 바뀐다**
- 실행 시 `interface=` / `LAB_IFACE=`로 직접 지정한다 (위 "인터페이스 이름 문제" 참고).
