# wps — WPS 공격 (reaver / pixie-dust)

WPS(Wi-Fi Protected Setup)의 **8자리 PIN** 은 앞 4자리·뒤 3자리로 나눠 검증되어
실질 경우의 수가 크게 줄어든다. 이 약점을 공격해 WPA/WPA2 비밀번호(PSK)를 얻는다.

- **pixie-dust**(기본): 일부 칩셋의 취약한 난수 때문에 PIN 을 **오프라인**으로 빠르게 복구(`reaver -K 1` + `pixiewps`).
- **온라인 PIN brute**(`WPS_PIXIE=0`): PIN 을 AP 에 직접 반복 시도(느림, 잠금 걸릴 수 있음).

**핵심 도구:** `reaver`(+`wash` 스캔), `pixiewps`

## 요구 도구

`reaver`, `wash`(reaver 동봉), `pixiewps`, `iw`, `ip`.
`sudo bash et_check_deps.sh` 로 점검/설치.

## 실행

```bash
# 1) 대상 미지정 → WPS 활성 AP 스캔(wash) 후 종료
sudo bash wps/et_wps_attack.sh

# 2) 스캔 목록에서 대상 골라 공격
sudo WPS_BSSID=AA:BB:CC:11:22:33 WPS_CHANNEL=6 bash wps/et_wps_attack.sh

# 온라인 PIN brute 로
sudo WPS_PIXIE=0 WPS_BSSID=AA:BB:CC:11:22:33 bash wps/et_wps_attack.sh
```

| env | 기본값 | 설명 |
|---|---|---|
| `WPS_BSSID` | config `bssid` | 대상 AP BSSID (없으면 wash 스캔) |
| `WPS_CHANNEL` | config `channel` | 대상 채널 |
| `WPS_PIXIE` | `1` | 1=pixie-dust(오프라인), 0=온라인 PIN brute |
| `WPS_SCAN_SECS` | `15` | 대상 미지정 시 wash 스캔 시간(초) |
| `interface` | 자동(2번째 무선) | 공격 어댑터 (monitor 모드로 전환됨) |

종료는 **Ctrl+C**(또는 `stop`). reaver 종료, 인터페이스 managed 복구,
`attack_stop` 기록까지 자동 정리된다.

## 대시보드 연동

reaver 출력에서 **WPS PIN / WPA PSK** 를 찾으면 `credential_captured` 이벤트로
기록하므로, 실습 탭의 **자격증명 수**와 이벤트 피드에 그대로 표시된다.

> ⚠️ 본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.
