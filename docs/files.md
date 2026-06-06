# 파일 역할 정리

## 핵심 파일 (실행에 필요)

| 파일 | 역할 |
|------|------|
| `et_scan.sh` | 주변 AP를 airodump-ng로 스캔하고 사용자가 선택한 타겟의 BSSID·ESSID·채널·인터페이스 정보를 `et_config.conf`에 저장 |
| `et_sniffing_attack.sh` | Evil Twin Sniffing 공격 메인 스크립트. 가짜 AP(hostapd) → DHCP 서버 → NAT 라우팅 → deauth → ettercap 스니퍼 순으로 실행하고 Ctrl+C 시 전체 정리 |
| `et_logger.sh` | `et_sniffing_attack.sh`에 source되는 로깅 유틸리티. 공격 이벤트를 JSON Lines 파일로 기록하고 대시보드 폴링용 요약 JSON을 갱신. `dashboard_url` 설정 시 HTTP POST로 이벤트 전송 |
| `et_config.conf` | `et_scan.sh`와 `et_sniffing_attack.sh`가 공유하는 설정 파일. 인터페이스·타겟 AP 정보·공격 옵션·로그 경로·대시보드 URL 등을 관리 |

---

## 불필요한 파일 (airgeddon 원본)

`et_sniffing_attack.sh`가 airgeddon(`wfsat.sh`)에서 독립 실행형으로 추출·재작성되면서 아래 파일들과의 의존성이 제거됨

| 파일 | 원래 역할 |
|------|-----------|
| `wfsat.sh` | airgeddon 전체 메뉴 시스템 래퍼. WEP·WPA·WPS·Evil Twin 등 모든 공격 메뉴를 포함하는 메인 진입점 |
| `language_strings.sh` | airgeddon 다국어(한국어·영어 등) 문자열 테이블. `et_sniffing_attack.sh`에서는 `function language_strings() { :; }` 스텁으로 대체됨 |
| `known_pins.db` | WPS PIN 데이터베이스 공격에 사용하는 제조사별 알려진 PIN 목록 |
| `pindb_checksum.txt` | `known_pins.db` 파일의 무결성 검사용 체크섬 |
| `.airgeddonrc` | airgeddon 런타임 옵션 설정 파일 (창 처리 방식, 5GHz 허용 여부 등) |

### `sh/` 디렉토리

`wfsat.sh`에서 분리된 파일들로, 세 스크립트 중 어디서도 참조하지 않음

| 파일 | 원래 역할 |
|------|-----------|
| `sh/main.sh` | wfsat.sh 메인 흐름 및 메뉴 로직 |
| `sh/utils.sh` | wfsat.sh 유틸리티 함수 (라우팅·iptables·DHCP 등) |
| `sh/attacks.sh` | wfsat.sh 공격 실행 함수 모음 (WEP·WPS·ET·Enterprise 등) |

### `plugins/` 디렉토리

| 파일 | 원래 역할 |
|------|-----------|
| `plugins/missing_dependencies.sh` | wfsat.sh 실행 전 필수 도구(aircrack-ng, ettercap 등) 설치 여부를 검사하는 의존성 체크 |

---

## 메타·개발 파일

| 파일 | 역할 |
|------|------|
| `README.md` | 프로젝트 설명 문서 |
| `.editorconfig` | 에디터 들여쓰기·인코딩 통일 설정 |
| `.gitattributes` | git 줄 끝(CRLF/LF) 처리 및 diff 설정 |
