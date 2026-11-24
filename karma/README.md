# karma — KARMA 공격 (airbase-ng -P)

클라이언트는 과거에 접속했던 네트워크 목록(PNL, Preferred Network List)을 **directed
probe request** 로 계속 "거기 있니?" 하고 묻는다. 자동 연결이 켜진 Open 네트워크가
PNL 에 있으면, 그 이름의 AP 가 나타나는 순간 사용자 확인 없이 붙어 버린다.

**KARMA AP** 는 어떤 SSID 를 물어봐도 "응, 내가 그 네트워크야" 하고 응답(`airbase-ng -P`)해
자동 연결 기기를 공격자의 Open AP(`at0`)로 끌어들인다.

## 동작 개요

```
클라이언트 ──probe "Cafe_Free_WiFi?"──▶ KARMA AP(airbase-ng -P)
          ◀──probe response "여기 있음"── (실제로는 비컨한 적 없는 SSID도 응답)
클라이언트 ──association / DHCP──▶ at0 (10.0.0.1, dnsmasq) ──NAT──▶ uplink(인터넷)
```

- `airbase-ng -P` : 모든 probe request 에 응답 (KARMA 핵심)
- `airbase-ng -C <초>` : probe 로 알게 된 SSID 를 주기적으로 비컨
- `at0` : airbase-ng 가 만드는 가짜 AP 측 tap 인터페이스 → IP/DHCP/NAT 를 여기에 건다
- `dnsmasq` : at0 에 DHCP 제공(클라이언트가 실제 IP 를 받고 붙음)
- 선택적 NAT : 클라이언트에게 인터넷을 제공해 자연스럽게 연결 유지

## 요구 도구

`aircrack-ng`(airbase-ng), `dnsmasq`, `iw`, `ip`, (NAT 시) `iptables`.
`sudo bash et_check_deps.sh` 로 한번에 점검/설치.

## 실행

```bash
# 기본값으로 실행 (2번째 무선 어댑터 자동 선택, NAT 자동)
sudo bash karma/et_karma_attack.sh

# 옵션 (모두 env 로 지정)
sudo KARMA_ESSID="Cafe_Free" KARMA_CHANNEL=6 bash karma/et_karma_attack.sh
sudo interface=wlan1 bash karma/et_karma_attack.sh     # 공격 어댑터 직접 지정
sudo KARMA_NAT=0 bash karma/et_karma_attack.sh          # 인터넷 공유(NAT) 끄기
```

종료는 **Ctrl+C** (또는 `sudo bash et_stop.sh`). airbase-ng/dnsmasq 종료,
인터페이스 managed 복구, NAT 룰 제거, `attack_stop` 기록까지 자동 정리된다.

### 주요 환경변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `interface` | 자동(2번째 무선) | 공격 어댑터 (monitor 모드로 전환됨) |
| `KARMA_ESSID` | `Free_WiFi` | 기본 비컨 ESSID (probe 응답은 어떤 SSID든) |
| `KARMA_CHANNEL` | config `channel` > `6` | 채널 |
| `KARMA_BEACON_SEC` | `30` | `-C`: probe된 SSID 비컨 주기(초) |
| `KARMA_NAT` | `1` | uplink 로 인터넷 공유(NAT) on/off |
| `KARMA_UPLINK` | config `internet_interface` > 자동 | NAT 업링크 NIC |
| `KARMA_AP_IP` | `10.0.0.1` | at0 게이트웨이 IP |

## 대시보드 연동

다른 공격과 동일하게 `et_logger.sh` 를 사용해 `log_dir`(기본 `/tmp/et_logs`)에
이벤트를 남긴다. dnsmasq 의 DHCPACK 로그를 로거가 기대하는 `clts.txt` 형식으로
변환하므로, **실습 탭의 상태/이벤트 카드(attack_start · client_connected ·
attack_stop · 클라이언트 수)가 그대로 채워진다.** 대시보드 학습 모드에는 KARMA
시나리오 시각화가 이미 들어 있다(`dashboard_html/scenarios.js`).

> ⚠️ 본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.
