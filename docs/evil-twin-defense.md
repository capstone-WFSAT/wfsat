# Evil Twin (기본 공격) 방어 설계 문서

> 대상 공격: `wfast.sh`(airgeddon 기반)의 **기본 evil twin 모드 `et_onlyap`**
> — 오픈 가짜 AP 복제 + deauth 유인 + DHCP/라우팅 장악.
> 범위: **탐지(Detection) + 능동 대응(Active Response)**. 본 문서는 설계만 다루며 구현 코드는 포함하지 않는다.

---

## 1. 위협 모델 (Threat Model)

### 1.1 공격자가 실제로 하는 일 (코드 기준)

기본 공격 `et_onlyap`의 실행 순서는 [`exec_et_onlyap_attack()`](../wfast.sh)에 정의되어 있으며 다음과 같다.

1. **가짜 AP 설정** — [`set_hostapd_config()`](../wfast.sh): `wpa=0`(오픈 네트워크), 타깃과 동일 채널, 동일(사실상) ESSID/BSSID.
2. **가짜 AP 기동** — [`launch_fake_ap()`](../wfast.sh): NetworkManager kill, (옵션) MAC 스푸핑 후 `hostapd` 실행.
3. **네트워크/DHCP** — [`set_network_interface_data()`](../wfast.sh), [`set_dhcp_config()`](../wfast.sh), [`launch_dhcp_server()`](../wfast.sh): `192.169.x.0/24` 대역 배분.
4. **라우팅/NAT** — `set_std_internet_routing_rules()`.
5. **deauth 유인** — [`exec_et_deauth()`](../wfast.sh): 별도 모니터 인터페이스(`mon<phy>`)로 원본 AP에 deauth/disassoc 또는 Auth DoS.

### 1.2 방어자 관점(누가 방어하는가)

| 방어 위치 | 관측 가능 정보 | 대표 대응 |
|-----------|----------------|-----------|
| **인프라/관리자 (WIDS 센서)** | 무선 관리 프레임(beacon, deauth), 채널, BSSID, RSSI | 경보, 블록리스트, 정상 AP 재유도, PMF 강제 |
| **클라이언트 (엔드포인트)** | 자신이 붙은 SSID/BSSID, 암호화, 게이트웨이/DHCP 정보 | 접속 차단, 알림, 알려진 네트워크 프로필 검증 |

본 설계는 **WIDS 센서(모니터 모드 기반)를 1차 방어선**, **클라이언트 측 검증을 보조**로 삼는 이중 구조를 전제한다.

---

## 2. 탐지 (Detection)

기본 공격은 흔적이 뚜렷하다. 아래 6개 신호를 **개별 탐지 → 상관 점수화**한다.

### 2.1 탐지 신호 목록

| # | 신호 | 근거(코드) | 관측 위치 | 신뢰도 | 오탐 요인 |
|---|------|-----------|-----------|--------|-----------|
| S1 | **ESSID 끝의 Zero-Width-Space (U+200B)** | `generate_fake_essid()` — `\xE2\x80\x8B` 부착 | 센서(beacon) | 매우 높음 | 거의 없음. 단 `AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=false`면 미부착 |
| S2 | **한 자리만 다른 쌍둥이 BSSID** | `generate_fake_bssid()` — 16진수 1 nibble 변경 | 센서 | 높음 | 동일 벤더 인접 AP가 우연히 유사할 수 있음 |
| S3 | **암호화 다운그레이드 (WPA2 → Open)** | `set_hostapd_config()` — `wpa=0` | 센서/클라이언트 | 높음 | 원래 오픈 SSID(게스트 등)면 성립 안 함 |
| S4 | **deauth/disassoc 프레임 폭주** | `exec_et_deauth()` — mdk4/aireplay | 센서 | 중간 | 일부 AP의 정상 부하 분산, 로밍 |
| S5 | **동일 ESSID + 상이 BSSID 동시 존재** | 복제 자체의 본질 | 센서 | 중간 | 정상 멀티-AP(로밍) 환경에서 흔함 |
| S6 | **비정상 IP 프로파일 (`192.169.x.0/24`, GW `.1`)** | `set_network_interface_data()` | 클라이언트 | 높음 | 극히 드물게 실제로 이 대역을 쓰는 곳 |

### 2.2 신호별 탐지 로직 (의사 규칙)

- **S1 — ZWSP 탐지**
  - beacon/probe-response의 SSID 필드 바이트를 그대로 검사한다(디코딩된 표시 문자열이 아니라 **raw bytes**).
  - `0xE2 0x80 0x8B` 또는 기타 zero-width 계열(U+200B~200D, U+FEFF) 포함 시 즉시 고위험.
  - 가장 강력한 단일 지표. 표시상 동일한 SSID인데 바이트 길이가 다르면 경보.

- **S2 — 쌍둥이 BSSID**
  - 화이트리스트(정상 AP BSSID 목록)와 신규 BSSID 간 **16진수 해밍 거리** 계산.
  - 같은 ESSID를 광고하면서 정상 BSSID와 **정확히 1 nibble** 차이면 강한 지표.
  - OUI(앞 3옥텟)가 정상 AP와 동일한데 뒤쪽만 1자리 다르면 가중치 상향.

- **S3 — 암호화 다운그레이드**
  - 기준선에 각 SSID의 정상 암호화(RSN/WPA2/WPA3 여부)를 저장.
  - 동일 ESSID가 **Open(암호화 없음)** 으로 광고되면 다운그레이드로 판정.
  - RSN IE 유무·Privacy 비트로 판별.

- **S4 — deauth 폭주**
  - 슬라이딩 윈도우(예: 10초)당 deauth/disassoc 프레임 수 임계값 초과 탐지.
  - 특정 BSSID(정상 AP) 대상 deauth가 급증하면 유인 공격으로 판정.
  - Reason code(7, 15 등) 분포와 발신 MAC 위조 여부도 함께 본다.

- **S5 — 동일 SSID 다중 BSSID**
  - 동일 ESSID를 광고하는 BSSID 집합을 추적.
  - 기준선에 없던 **새 BSSID**가 등장하고 RSSI/채널이 기존과 튀면 후보.
  - 단독으로는 약함 → 반드시 S1~S3와 상관.

- **S6 — 클라이언트 측 IP 프로파일**
  - 접속 후 게이트웨이가 `192.169.x.1`, 서브넷 `192.169.x.0/24`이면 매우 이례적(공인 대역).
  - DHCP 리스 600초, 범위 `.33~.100`, DNS가 `8.8.8.8/8.8.4.4` 조합이면 airgeddon 기본값과 일치.
  - 자신이 "알던" 회사/집 SSID인데 게이트웨이 MAC/서브넷이 프로필과 다르면 경보.

### 2.3 상관 점수화 (Correlation Scoring)

단일 신호로 단정하지 않고 가중합으로 위험도를 산정한다(값은 초기 제안, 튜닝 대상).

```
score = 0.45*S1 + 0.20*S2 + 0.15*S3 + 0.10*S4 + 0.05*S5 + 0.15*S6   # S6는 클라이언트 채널
등급:  score >= 0.6  → HIGH(즉시 대응)
       0.3~0.6      → MEDIUM(경보 + 관찰)
       < 0.3        → LOW(로깅)
```

- S1(ZWSP)만 참이어도 단독 HIGH로 승격(지문 수준).
- S5 단독은 절대 HIGH로 올리지 않음(정상 로밍 오탐 방지).

### 2.4 오탐(False Positive) 관리

- **기준선(baseline) 학습**: 평상시 정상 AP의 (ESSID, BSSID, 채널, 암호화, 벤더, 위치별 RSSI 범위)를 등록.
- **화이트리스트 우선**: 등록된 정상 BSSID는 S2/S5 판정에서 제외.
- **로밍 예외**: 동일 관리 도메인(같은 OUI+운영자 등록)의 다중 BSSID는 정상 로밍으로 간주.
- **게스트 오픈망 예외**: 원래 Open으로 운영되는 SSID는 S3에서 제외.

---

## 3. 능동 대응 (Active Response)

> **경계선(중요)**: 정당한 능동 대응은 *자신이 소유·관리하는 자산*에 대한 조치와 알림에 한정한다.
> 공격자 가짜 AP를 향한 **역-deauth/재밍/전파 방해는 그 자체가 DoS 공격이며 다수 국가에서 불법**이므로 본 설계의 대응 대상에서 **명시적으로 제외**한다.

### 3.1 대응 레벨 (Detection 등급 연동)

| 등급 | 자동 대응 | 사람 개입 |
|------|-----------|-----------|
| LOW | 로깅, 지표 축적 | 불필요 |
| MEDIUM | 관리자/사용자 알림, 해당 BSSID 집중 관찰, 근처 클라이언트 목록화 | 확인 |
| HIGH | 아래 3.2 조치 실행 | 사후 검토 |

### 3.2 정당한 능동 대응 카탈로그

1. **경보 및 통지**
   - SIEM/Slack/이메일로 실시간 알림. 페이로드: 가짜 BSSID, 채널, RSSI(대략적 위치), 탐지 신호 조합, 타임스탬프.
   - 사용자 대상 알림: "이 SSID가 암호 없는 가짜일 수 있으니 접속 금지".

2. **관리 인프라 블록리스트(자신의 AP/컨트롤러)**
   - 탐지된 가짜 BSSID를 **자사 무선 컨트롤러의 rogue/block 목록**에 등록(관리 대상 장비 한정).
   - 관리 디바이스(MDM 등록 단말)의 Wi-Fi 프로필에서 해당 BSSID 접속을 차단.

3. **정상 AP로의 재유도 (관리 단말 한정)**
   - MDM/에이전트가 설치된 자사 단말에 한해, 알려진 정상 BSSID로 재연결을 유도.
   - deauth로 끊긴 세션을 정상 프로필로 재-associate.

4. **근본 예방(deauth 무력화)**
   - **802.11w PMF(Protected Management Frames) 강제** — 관리 프레임을 보호해 S4(deauth 유인) 자체를 무력화. 기본 공격의 핵심 유인 수단을 차단하는 가장 효과적인 근본 대책.
   - **WPA3 전환** — PMF 필수화 + 오픈망 오인 접속 감소.

5. **클라이언트 측 자기 방어**
   - "알던 SSID인데 오픈/게이트웨이 프로필 불일치" 시 자동 연결 해제 + 사용자 확인 요구.
   - 저장된 네트워크 프로필에 **기대 BSSID/암호화/게이트웨이 MAC**을 바인딩하고 위반 시 차단.

6. **위치 추정(선택)**
   - 다중 센서 RSSI 삼각측량으로 가짜 AP의 물리적 위치를 근사 → 물리적 제거를 위한 인력 대응.

### 3.3 대응 시 안전장치

- 자동 블록리스트/재유도는 **화이트리스트 검증 후에만** 실행(정상 AP를 실수로 차단 방지).
- 모든 자동 조치는 audit log 기록 + 롤백 가능해야 함.
- HIGH 조치라도 인프라 전체에 영향 주는 변경(예: 채널 강제 변경)은 사람 승인 게이트 통과.

---

## 4. 시스템 아키텍처

```
[모니터모드 NIC(채널 호핑)] ──raw 802.11──▶ [Capture]
                                              │
                                              ▼
                                   [Parse: beacon/deauth/RSN IE/SSID raw bytes]
                                              │
                          ┌───────────────────┼────────────────────┐
                          ▼                    ▼                     ▼
                   [Baseline/화이트리스트]  [신호 탐지 S1~S5]    [deauth 카운터 S4]
                          └───────────────────┼────────────────────┘
                                              ▼
                                     [상관 점수화 엔진]
                                              │
                              ┌───────────────┴───────────────┐
                              ▼                                ▼
                        [Alert/SIEM]                    [Active Response]
                                                     (블록리스트/재유도/PMF)

[클라이언트 에이전트] ── SSID/BSSID/암호화/게이트웨이/DHCP 검사(S3,S6) ──▶ [Alert/자기차단]
```

### 4.1 구성 요소

- **Sensor**: 모니터 모드 인터페이스 + 채널 호핑(2.4/5GHz). 다중 채널 커버리지 위해 인터페이스 복수 권장.
- **Baseline Store**: 정상 AP 인벤토리(ESSID, BSSID, 채널, 암호화, 벤더, RSSI 범위).
- **Detection Engine**: S1~S6 규칙 + 상관 점수화 + 오탐 필터.
- **Responder**: 알림 채널 + (관리 자산 한정) 블록리스트/재유도 훅.
- **Client Agent(선택)**: 엔드포인트에서 S3/S6 검증.

### 4.2 데이터 모델(개략)

- `Baseline{ essid, bssid, channel, security, vendor_oui, rssi_range }`
- `Detection{ ts, essid, suspect_bssid, channel, rssi, signals[], score, level }`
- `Response{ ts, detection_id, action, target_asset, actor(auto/human), result }`

### 4.3 구현 결정 — 오프라인 pcap 분석 (실시간 아님)

본 캡스톤의 목표는 **정확한 분석**이지 실시간 탐지가 아니므로, 탐지 엔진은
라이브 스니핑이 아니라 **저장된 pcap 을 오프라인으로 파싱**하는 방식으로 구현한다.

- **캡처(기존 재사용, bash)**: `et_scan.sh` 의 모니터 모드 + `airodump-ng -w` 로 pcap 저장.
- **분석(신규 기여, Python + scapy)**: [`detector/et_detector.py`](../detector/et_detector.py) 가
  pcap 을 파싱해 S1~S6 신호·상관 점수를 계산하고 AP 테이블/findings 를 JSON 으로 출력.
- **시각화(기존 재사용, Python)**: `dashboard/app.py`(Streamlit) 가 그 JSON 을 소비.

이유:
- **재현성** — 같은 pcap 에 항상 같은 결과. 임계값 튜닝 반복 가능.
- **정량 평가** — 라벨링된 캡처로 정밀도·재현율·오탐율 측정 가능(§5).
- **프레임 단위 정밀도** — airodump CSV 로는 못 얻는 raw SSID 바이트(ZWSP)·RSN IE·
  (후속) deauth reason code 접근. 즉 "기존 bash 형식"의 정확도 한계를 넘는다.

P0 구현 범위: **S1(ZWSP) + S2(쌍둥이 BSSID) + S3(암호화 다운그레이드)**.
(S4 deauth, S5 중복 ESSID, S6 클라이언트 IP 프로파일은 후속 확장. S6 는 무선 프레임
pcap 이 아니라 클라이언트 측 관측이 필요하므로 별도 경로.)

---

## 5. 검증(Validation) 방법

- **레드팀 재현**: 본 저장소의 `et_onlyap` 모드로 실제 공격을 재현하고 탐지율/오탐율 측정.
- **테스트 케이스**
  - TC1: ZWSP 부착 상태 → S1 단독 HIGH 확인.
  - TC2: `AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=false`(ZWSP 미부착) → S2+S3+S4 상관으로 HIGH 도달하는지 확인(가장 중요한 회피 시나리오).
  - TC3: 정상 멀티-AP 로밍 환경 → S5 단독으로 오탐 발생하지 않는지.
  - TC4: 클라이언트 접속 시 `192.169.x.1` 게이트웨이 감지(S6).
- **지표**: 탐지 지연(deauth 시작~경보), 정탐율, 오탐율, 대응 실행 성공률.

---

## 6. 우선순위 및 로드맵

| 단계 | 내용 | 근거 |
|------|------|------|
| P0 | S1(ZWSP) + S3(다운그레이드) + S6(IP 프로파일) 탐지 | 구현 단순·오탐 최저·본 도구 지문 정확 |
| P1 | S2(쌍둥이 BSSID) + baseline/화이트리스트 | 오탐 관리의 핵심 |
| P2 | S4(deauth) + 상관 점수화 엔진 | 유인 공격 실시간성 |
| P3 | 능동 대응(알림→블록리스트→재유도) | 관리 자산 한정, 안전장치 포함 |
| P4 | 근본 대책(PMF/WPA3) 배포 가이드 | deauth 유인 무력화 |

---

## 7. 핵심 요약

- 기본 evil twin은 **ZWSP SSID·쌍둥이 BSSID·오픈 다운그레이드·deauth 폭주·`192.169.x.x` 대역**이라는 뚜렷한 지문을 남긴다.
- 탐지는 **단일 신호 단정 금지 → 상관 점수화**가 원칙이며, ZWSP(S1)만 예외적으로 단독 고위험.
- 능동 대응은 **자기 자산 한정 + 알림/블록리스트/재유도 + 근본적으로 802.11w PMF**로 구성한다. 역공격(재밍/역-deauth)은 불법이므로 배제.
- 가장 중요한 회피 시나리오는 **ZWSP 비활성화**이므로, S1에 의존하지 않고도 S2~S4 상관으로 탐지되도록 설계해야 한다.
