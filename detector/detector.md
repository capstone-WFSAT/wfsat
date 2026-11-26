# detector — Evil Twin 오프라인 탐지 분석기 (P0)

`et_detector.py`는 저장된 **pcap/pcapng** 파일을 오프라인으로 분석해 기본 evil twin
공격(오픈 가짜 AP 복제)을 탐지한다. 설계 근거: [`docs/evil-twin-defense.md`](../docs/evil-twin-defense.md).

## 왜 실시간이 아니라 pcap 오프라인인가

이 프로젝트의 목표는 **정확한 분석**이지 실시간 탐지가 아니다. 오프라인 pcap 분석은:

- **재현성** — 같은 캡처에 항상 같은 결과. 임계값을 바꿔 반복 실험 가능.
- **정량 평가** — 공격 있음/없음 캡처를 라벨링해 **정밀도·재현율·오탐율** 측정 가능.
- **프레임 단위 정밀도** — airodump-ng CSV로는 못 얻는 raw SSID 바이트(ZWSP),
  RSN/WPA 정보 요소, (후속) deauth reason code 까지 접근.

즉 라이브 스니핑의 불안정성 없이 최고 수준의 분석 정확도를 얻는다.

## P0 탐지 신호

| 신호 | 내용 | 가중치 |
|------|------|--------|
| S1 | ESSID 안의 zero-width 문자(U+200B 등) — airgeddon ESSID stripping 지문 | 0.45 |
| S2 | 정상 BSSID와 16진수 1 nibble 만 다른 쌍둥이 MAC | 0.20 |
| S3 | 동일 ESSID의 암호화 다운그레이드(WPA/WPA2 → OPEN) | 0.15 |

상관 점수화: `score = 0.45·S1 + 0.20·S2 + 0.15·S3`
- `S1` 참이거나 `score ≥ 0.6` → **공격중**
- `score ≥ 0.3` → **의심**
- 그 외 → **정상**

S4는 숫자 접미사를 가진 유사 SSID가 여러 BSSID에 나타나는 Beacon Flood 패턴을 탐지한다.

## Beacon 타임라인

`--json` 결과의 `beacon_timeline`에는 `start_ms`(첫 Beacon의 Unix 시각, 밀리초), `bins`(1초 구간 목록), `outside_window`(표시 범위를 벗어난 Beacon 수)가 담긴다. 집계와 상세 표에는 Beacon 프레임만 포함한다. 각 구간의 `count`는 캡처된 Beacon 전체 수이며 `frames`는 캡처 순서상 처음 24개다. 구간의 최대 표시 범위는 첫 Beacon부터 120초다. Beacon이 없으면 `bins`가 비어 있다.

막대 높이는 캡처에서 관찰한 Beacon 수다. S4 판정은 기존 SSID·BSSID 패턴 기준을 사용한다.

## 연결 타임라인

`association_timeline.frames`는 PCAP에서 처음 읽은 최대 500개의 802.11 연결·재연결 요청과 응답을 시각순으로 정렬한 목록이다. 시각은 Unix 밀리초로 저장하며, 클라이언트 MAC, AP BSSID, 프레임 유형, 응답 상태 코드를 함께 기록한다. 초과한 프레임 수는 `omitted`에 저장한다.

응답 상태 `0`은 AP가 연결 요청을 수락했다는 뜻이다. 암호화 키 교환이나 인터넷 접속 성공에는 별도의 증거가 필요하다. AP 보안 설정은 같은 PCAP에 관찰된 Beacon이나 Probe Response의 정보로 비교한다.

## 설치

```bash
pip install -r requirements.txt
```

## 입력 pcap 만들기 (캡처)

기존 `et_scan.sh`가 이미 모니터 모드 + airodump-ng를 쓰므로, `-w`로 pcap도 함께 저장하면 된다.

```bash
# 모니터 모드 준비 후
sudo airodump-ng -c <채널> --bssid <타깃> -w capture wlan0mon
# → capture-01.cap 생성 (이 파일을 분석기 입력으로 사용)
```

또는 tcpdump/tshark로도 가능:

```bash
sudo tcpdump -i wlan0mon -w capture.pcap
```

## 실행

```bash
# 리포트만
python et_detector.py capture-01.cap

# 리포트 + JSON 저장 (대시보드 연동용)
python et_detector.py capture-01.cap --json output/result.json
```

종료 코드: 탐지가 있으면 `1`, 없으면 `0` (스크립트/CI 연동용).

## 출력 형식

`--json` 결과는 두 부분으로 구성된다.

- `ap_table` — `dashboard/app.py`의 AP 행 스키마와 호환:
  `ssid, bssid, channel, rssi, enc, status(정상/의심/공격중), pkt_rate`
  (+ 분석 부가정보 `score`, `signals`, `ssid_raw_hex`, `reasons`)
- `findings` — Evil Twin 후보: `severity, ssid, suspect_bssid, legit_bssid, reasons` 등

## 대시보드 연동 (다음 단계)

현재 `dashboard/app.py`는 mock 데이터로 동작한다. 이 분석기의 `ap_table`/`findings`
JSON을 읽도록 대시보드의 mock 부분을 교체하면, 목업이 실제 탐지 대시보드가 된다.

## 검증용 합성 캡처

`make_sample_pcap.py`가 정상 AP + (ZWSP·쌍둥이·OPEN) 가짜 AP가 섞인 테스트용 pcap을
생성한다. 실제 무선카드 없이 로직을 검증할 때 사용한다.

```bash
python make_sample_pcap.py sample.pcap
python et_detector.py sample.pcap
```
