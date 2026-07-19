#!/usr/bin/env python3
# ============================================================
# make_sample_pcap.py — et_detector.py 검증용 합성 pcap 생성
# ============================================================
# 실제 무선 카드/캡처 없이 탐지 로직을 검증하기 위해,
# 정상 AP 와 (ZWSP·쌍둥이 BSSID·OPEN 다운그레이드) 가짜 AP 가
# 섞인 beacon 프레임들을 만들어 pcap 으로 저장한다.
# ============================================================

import sys

from scapy.all import (
    RadioTap,
    Dot11,
    Dot11Beacon,
    Dot11Elt,
    wrpcap,
)


def make_beacon(bssid, ssid_bytes, channel, rssi, encrypted):
    """하나의 beacon 프레임을 만든다.

    ssid_bytes : SSID 원본 바이트 (ZWSP 삽입을 위해 bytes 로 받음)
    encrypted  : True 면 RSN(WPA2) 정보 요소 + Privacy 비트 추가
    """
    # capability: ESS(0x01) + (암호화면 Privacy 0x10)
    cap = 0x01 | (0x10 if encrypted else 0x00)

    dot11 = Dot11(
        type=0, subtype=8,               # management / beacon
        addr1="ff:ff:ff:ff:ff:ff",
        addr2=bssid, addr3=bssid,
    )
    beacon = Dot11Beacon(cap=cap)

    # SSID (ID 0)
    frame = dot11 / beacon / Dot11Elt(ID=0, info=ssid_bytes)
    # DS Parameter Set (ID 3) = 채널
    frame /= Dot11Elt(ID=3, info=bytes([channel]))

    if encrypted:
        # 최소 RSN 정보 요소 (WPA2-PSK, CCMP)
        rsn = (
            b"\x01\x00"                    # version
            b"\x00\x0f\xac\x04"            # group cipher: CCMP
            b"\x01\x00\x00\x0f\xac\x04"    # pairwise: 1 x CCMP
            b"\x01\x00\x00\x0f\xac\x02"    # AKM: 1 x PSK
            b"\x00\x00"                    # RSN capabilities
        )
        frame /= Dot11Elt(ID=48, info=rsn)

    # RadioTap 헤더에 신호세기 부여
    return RadioTap(present="dBm_AntSignal", dBm_AntSignal=rssi) / frame


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "sample.pcap"
    zwsp = "​".encode("utf-8")       # U+200B

    frames = []

    # 1) 정상 AP — HomeWiFi_5G, WPA2, 신호 -45
    for _ in range(20):
        frames.append(make_beacon(
            "aa:11:22:33:44:01", b"HomeWiFi_5G", 6, -45, encrypted=True))

    # 2) 가짜 AP — 같은 이름 + ZWSP, BSSID 1 nibble 차이(...44:01 → ...44:11), OPEN
    for _ in range(15):
        frames.append(make_beacon(
            "aa:11:22:33:44:11", b"HomeWiFi_5G" + zwsp, 6, -38, encrypted=False))

    # 3) 정상 AP — OfficeAP, WPA3(간이로 WPA2 표기), 신호 -60  (오탐 확인용)
    for _ in range(12):
        frames.append(make_beacon(
            "cc:33:44:55:66:03", b"OfficeAP", 1, -60, encrypted=True))

    # 4) 완전 무관한 오픈 AP — Guest_Lobby (오탐 확인용, 쌍둥이 없음)
    for _ in range(8):
        frames.append(make_beacon(
            "dd:44:55:66:77:04", b"Guest_Lobby", 3, -70, encrypted=False))

    wrpcap(out, frames)
    print(f"[+] 합성 pcap 생성: {out}  (frames={len(frames)})")


if __name__ == "__main__":
    main()
