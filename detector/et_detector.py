#!/usr/bin/env python3
# ============================================================
# et_detector.py — Evil Twin(기본 공격) 오프라인 pcap 분석기 (P0)
# ============================================================
#
# 입력 : 802.11 관리 프레임(beacon/probe response)이 담긴 pcap/pcapng
#        예) et_scan.sh 의 airodump-ng 를 -w 옵션과 함께 실행해 저장한 .cap
# 출력 : 1) AP 테이블 (dashboard/app.py 의 행 스키마와 호환)
#        2) 탐지 findings (Evil Twin 후보)
#        3) 사람이 읽는 요약 리포트(stdout)
#
# 설계 근거는 docs/evil-twin-defense.md 참조.
# 이 도구는 "실시간 탐지"가 아니라 "정확한 오프라인 분석"이 목적이다.
# 라이브 스니핑 대신 저장된 pcap 을 파싱하므로
#   - 같은 입력에 항상 같은 결과(재현성)
#   - 임계값 튜닝 / 정밀도·재현율 정량 평가 가능
# 이라는 캡스톤 목표에 부합한다.
#
# P0 탐지 신호 (가중치):
#   S1  ESSID 안의 Zero-Width 문자(U+200B 등)        0.45  ← airgeddon ESSID stripping 지문
#   S2  한 nibble 만 다른 쌍둥이 BSSID                 0.20  ← generate_fake_bssid 지문
#   S3  동일 ESSID 의 암호화 다운그레이드(WPA→OPEN)    0.15  ← 오픈 가짜 AP
#
# S4(deauth flood), S5(중복 ESSID 단독), S6(클라이언트 IP 프로파일)는
# 후속 단계에서 확장한다. 구조는 신호 추가가 쉽도록 분리해 두었다.
# ============================================================

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

# Windows 등 비 UTF-8 콘솔에서 한글/기호 출력 시 크래시하지 않도록.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

try:
    from scapy.all import (
        PcapReader,
        RadioTap,
        Dot11,
        Dot11Beacon,
        Dot11ProbeResp,
        Dot11Elt,
    )
except ImportError:
    sys.stderr.write(
        "[!] scapy 가 필요합니다.  pip install -r requirements.txt  로 설치하세요.\n"
    )
    sys.exit(2)


# ------------------------------------------------------------
# 상수
# ------------------------------------------------------------

# 표시상 보이지 않는 zero-width 계열 코드포인트.
# airgeddon generate_fake_essid() 가 붙이는 U+200B(ZWSP)가 대표.
ZERO_WIDTH_CODEPOINTS = {0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF}

# 상관 점수 가중치 (docs/evil-twin-defense.md §2.3)
WEIGHT_S1 = 0.45
WEIGHT_S2 = 0.20
WEIGHT_S3 = 0.15

# 등급 임계값
SCORE_HIGH = 0.6
SCORE_MEDIUM = 0.3

# RSN AKM suite 식별자
AKM_SAE = b"\x00\x0f\xac\x08"  # WPA3-SAE

# 대시보드 상태 라벨 (dashboard/app.py 와 동일)
STATUS_NORMAL = "정상"
STATUS_SUSPECT = "의심"
STATUS_ATTACK = "공격중"


# ------------------------------------------------------------
# 데이터 모델
# ------------------------------------------------------------

@dataclass
class AccessPoint:
    bssid: str
    ssid_raw: bytes = b""          # 원본 SSID 바이트 (ZWSP 검사용)
    ssid: str = ""                 # 디코딩된 표시 문자열
    ssid_norm: str = ""            # zero-width 제거 후 정규화 이름 (그룹핑 키)
    channel: int | None = None
    enc: str = "UNKNOWN"           # OPEN / WEP / WPA / WPA2 / WPA3
    rssi: int | None = None        # 가장 강한 신호값
    beacon_count: int = 0
    # 탐지 신호 (True/False)
    s1_zero_width: bool = False
    s2_twin_bssid: bool = False
    s3_downgrade: bool = False
    # 부가 정보
    zero_width_found: list = field(default_factory=list)
    twin_of: list = field(default_factory=list)      # 쌍둥이로 지목된 상대 BSSID
    score: float = 0.0
    status: str = STATUS_NORMAL
    reasons: list = field(default_factory=list)


# ------------------------------------------------------------
# 802.11 요소 파싱 헬퍼
# ------------------------------------------------------------

def iter_elements(pkt):
    """정보 요소를 (ID, value_bytes) 튜플로 순회한다.

    scapy 버전에 따라 RSN/DSSet 등이 별도 하위클래스로 분해되어
    ``.info`` 접근이 달라지므로, 요소 전체를 raw 바이트로 얻어
    TLV(ID/len/value)를 직접 파싱한다. 이러면 버전 무관하게 견고하다.
    """
    elt = pkt.getlayer(Dot11Elt)
    if elt is None:
        return
    blob = bytes(elt)
    i, n = 0, len(blob)
    while i + 2 <= n:
        eid = blob[i]
        length = blob[i + 1]
        value = blob[i + 2:i + 2 + length]
        yield eid, value
        i += 2 + length


def rsn_has_sae(rsn: bytes) -> bool:
    """RSN 정보 요소 바이트를 파싱해 AKM 에 SAE(WPA3)가 있는지 확인."""
    try:
        i = 2                       # version(2)
        i += 4                      # group cipher suite(4)
        pcount = int.from_bytes(rsn[i:i + 2], "little")
        i += 2 + 4 * pcount         # pairwise cipher list
        akm_count = int.from_bytes(rsn[i:i + 2], "little")
        i += 2
        for _ in range(akm_count):
            suite = rsn[i:i + 4]
            i += 4
            if suite == AKM_SAE:
                return True
    except (IndexError, ValueError):
        pass
    return False


def detect_encryption(pkt) -> str:
    """beacon/probe response 로부터 암호화 방식을 판별."""
    has_rsn = False
    has_wpa = False
    akm_sae = False

    for eid, value in iter_elements(pkt):
        if eid == 48:  # RSN (WPA2/WPA3)
            has_rsn = True
            if rsn_has_sae(value):
                akm_sae = True
        elif eid == 221:  # Vendor Specific
            # Microsoft OUI(00:50:F2) + type 1 == WPA(1)
            if value[:4] == b"\x00\x50\xf2\x01":
                has_wpa = True

    if has_rsn:
        return "WPA3" if akm_sae else "WPA2"
    if has_wpa:
        return "WPA"

    # RSN/WPA 요소가 없으면 capability 의 Privacy 비트로 WEP/OPEN 구분
    layer = pkt.getlayer(Dot11Beacon) or pkt.getlayer(Dot11ProbeResp)
    cap = int(layer.cap) if layer is not None else 0
    privacy = bool(cap & 0x10)      # bit4 = Privacy
    return "WEP" if privacy else "OPEN"


def extract_ssid(pkt) -> bytes:
    """SSID 정보 요소(ID 0)의 원본 바이트를 반환 (없으면 b'')."""
    for eid, value in iter_elements(pkt):
        if eid == 0:
            return value
    return b""


def extract_channel(pkt):
    """DS Parameter Set(ID 3)에서 채널을 읽는다."""
    for eid, value in iter_elements(pkt):
        if eid == 3 and len(value) >= 1:
            return value[0]
    return None


def extract_rssi(pkt):
    """RadioTap 헤더에서 dBm 신호세기를 읽는다 (없으면 None)."""
    if pkt.haslayer(RadioTap):
        try:
            return int(pkt[RadioTap].dBm_AntSignal)
        except (AttributeError, TypeError, ValueError):
            return None
    return None


def find_zero_width(text: str) -> list:
    """문자열에서 zero-width 문자를 찾아 코드포인트 목록을 반환."""
    return sorted({f"U+{ord(c):04X}" for c in text if ord(c) in ZERO_WIDTH_CODEPOINTS})


def normalize_ssid(text: str) -> str:
    """zero-width 문자와 트레일링 null 을 제거한 정규화 이름."""
    stripped = "".join(c for c in text if ord(c) not in ZERO_WIDTH_CODEPOINTS)
    return stripped.rstrip("\x00").strip()


def nibble_distance(mac_a: str, mac_b: str) -> int:
    """두 MAC 의 16진수 nibble 단위 해밍 거리 (형식 오류면 큰 값)."""
    a = mac_a.replace(":", "").lower()
    b = mac_b.replace(":", "").lower()
    if len(a) != 12 or len(b) != 12:
        return 99
    return sum(1 for x, y in zip(a, b) if x != y)


# ------------------------------------------------------------
# 1단계: pcap 파싱 → AP 인벤토리 구축
# ------------------------------------------------------------

def parse_pcap(path: str) -> dict:
    """pcap 을 스트리밍으로 읽어 BSSID 별 AccessPoint 를 구성."""
    aps: dict[str, AccessPoint] = {}

    with PcapReader(path) as reader:
        for pkt in reader:
            if not pkt.haslayer(Dot11):
                continue
            if not (pkt.haslayer(Dot11Beacon) or pkt.haslayer(Dot11ProbeResp)):
                continue

            bssid = pkt[Dot11].addr3
            if bssid is None:
                continue
            bssid = bssid.lower()

            ap = aps.get(bssid)
            if ap is None:
                ap = AccessPoint(bssid=bssid)
                aps[bssid] = ap

            ap.beacon_count += 1

            ssid_raw = extract_ssid(pkt)
            if ssid_raw and not ap.ssid_raw:
                ap.ssid_raw = ssid_raw
                ap.ssid = ssid_raw.decode("utf-8", errors="replace")
                ap.ssid_norm = normalize_ssid(ap.ssid)

            if ap.channel is None:
                ap.channel = extract_channel(pkt)

            enc = detect_encryption(pkt)
            # 암호화가 확정(비 UNKNOWN)이면 갱신. OPEN 오탐을 줄이려 한 번이라도
            # 암호화 요소가 잡히면 그 값을 우선한다.
            if ap.enc == "UNKNOWN" or (ap.enc == "OPEN" and enc != "OPEN"):
                ap.enc = enc

            rssi = extract_rssi(pkt)
            if rssi is not None and (ap.rssi is None or rssi > ap.rssi):
                ap.rssi = rssi

    return aps


# ------------------------------------------------------------
# 2단계: 탐지 신호 적용
# ------------------------------------------------------------

def apply_signals(aps: dict) -> None:
    """AP 인벤토리에 S1/S2/S3 신호를 채운다."""
    # 정규화 이름(빈 이름=히든 SSID 제외)으로 그룹핑
    groups: dict[str, list] = defaultdict(list)
    for ap in aps.values():
        if ap.ssid_norm:
            groups[ap.ssid_norm].append(ap)

    for ap in aps.values():
        # --- S1: zero-width 문자 ---
        zw = find_zero_width(ap.ssid)
        if zw:
            ap.s1_zero_width = True
            ap.zero_width_found = zw
            ap.reasons.append(f"S1: ESSID 에 zero-width 문자 {', '.join(zw)} 포함")

    for name, members in groups.items():
        if len(members) < 2:
            continue

        # 그룹 내 암호화된 AP 존재 여부 (S3 판정 기준)
        encrypted = [m for m in members if m.enc not in ("OPEN", "UNKNOWN")]

        for ap in members:
            # --- S2: 한 nibble 만 다른 쌍둥이 BSSID ---
            for other in members:
                if other is ap:
                    continue
                if nibble_distance(ap.bssid, other.bssid) == 1:
                    ap.s2_twin_bssid = True
                    if other.bssid not in ap.twin_of:
                        ap.twin_of.append(other.bssid)
            if ap.s2_twin_bssid and ap.twin_of:
                ap.reasons.append(
                    f"S2: 쌍둥이 BSSID({', '.join(ap.twin_of)}) — 1 nibble 차이"
                )

            # --- S3: 암호화 다운그레이드 (같은 이름의 암호화 AP 가 있는데 본인은 OPEN) ---
            if ap.enc == "OPEN" and encrypted:
                ap.s3_downgrade = True
                peers = ", ".join(f"{e.bssid}={e.enc}" for e in encrypted)
                ap.reasons.append(f"S3: 동일 ESSID 암호화 다운그레이드 (OPEN vs {peers})")


# ------------------------------------------------------------
# 3단계: 상관 점수화 → 상태 판정
# ------------------------------------------------------------

def score_aps(aps: dict) -> None:
    for ap in aps.values():
        ap.score = round(
            WEIGHT_S1 * ap.s1_zero_width
            + WEIGHT_S2 * ap.s2_twin_bssid
            + WEIGHT_S3 * ap.s3_downgrade,
            3,
        )

        # ZWSP(S1)는 사실상 지문 → 단독으로도 최고 등급으로 승격
        if ap.s1_zero_width or ap.score >= SCORE_HIGH:
            ap.status = STATUS_ATTACK
        elif ap.score >= SCORE_MEDIUM:
            ap.status = STATUS_SUSPECT
        else:
            ap.status = STATUS_NORMAL


# ------------------------------------------------------------
# 출력
# ------------------------------------------------------------

def to_dashboard_rows(aps: dict) -> list:
    """dashboard/app.py 의 AP_ROWS 스키마와 호환되는 행 목록."""
    rows = []
    for ap in sorted(aps.values(), key=lambda a: (-a.score, a.ssid_norm)):
        rows.append({
            # dashboard/app.py 가 쓰는 필드
            "ssid": ap.ssid_norm or ap.ssid or "<hidden>",
            "bssid": ap.bssid.upper(),
            "channel": ap.channel,
            "rssi": ap.rssi,
            "enc": ap.enc,
            "status": ap.status,
            "pkt_rate": ap.beacon_count,   # P0 에서는 beacon 수를 대용(proxy)으로 사용
            # 분석 부가 정보 (대시보드는 무시 가능)
            "score": ap.score,
            "signals": {
                "S1_zero_width": ap.s1_zero_width,
                "S2_twin_bssid": ap.s2_twin_bssid,
                "S3_downgrade": ap.s3_downgrade,
            },
            "ssid_raw_hex": ap.ssid_raw.hex(),
            "reasons": ap.reasons,
        })
    return rows


def build_findings(aps: dict) -> list:
    """상태가 정상이 아닌 AP 를 Evil Twin finding 으로 정리."""
    findings = []
    for ap in aps.values():
        if ap.status == STATUS_NORMAL:
            continue
        severity = "HIGH" if ap.status == STATUS_ATTACK else "MEDIUM"
        findings.append({
            "type": "Evil Twin",
            "severity": severity,
            "ssid": ap.ssid_norm or ap.ssid,
            "suspect_bssid": ap.bssid.upper(),
            "legit_bssid": [b.upper() for b in ap.twin_of],
            "channel": ap.channel,
            "enc": ap.enc,
            "score": ap.score,
            "reasons": ap.reasons,
        })
    findings.sort(key=lambda f: (f["severity"] != "HIGH", -f["score"]))
    return findings


def print_report(aps: dict, findings: list) -> None:
    print("\n" + "=" * 64)
    print(" WFSAT Evil Twin 오프라인 분석 리포트 (P0)")
    print("=" * 64)
    print(f" 관측된 AP 수 : {len(aps)}")
    print(f" 탐지 findings : {len(findings)}")
    print("-" * 64)

    header = f"{'STATUS':<7} {'SSID':<20} {'BSSID':<18} {'ENC':<6} {'CH':>3} {'SCORE':>6}"
    print(header)
    print("-" * 64)
    for ap in sorted(aps.values(), key=lambda a: (-a.score, a.ssid_norm)):
        name = (ap.ssid_norm or ap.ssid or "<hidden>")[:20]
        ch = ap.channel if ap.channel is not None else "-"
        print(f"{ap.status:<7} {name:<20} {ap.bssid.upper():<18} "
              f"{ap.enc:<6} {str(ch):>3} {ap.score:>6.2f}")

    if findings:
        print("\n" + "-" * 64)
        print(" [!] 탐지 상세")
        print("-" * 64)
        for i, f in enumerate(findings, 1):
            print(f" [{i}] {f['severity']}  {f['type']}  SSID='{f['ssid']}'  "
                  f"의심 BSSID={f['suspect_bssid']}")
            for r in f["reasons"]:
                print(f"       - {r}")
    print("=" * 64 + "\n")


# ------------------------------------------------------------
# main
# ------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Evil Twin(기본 공격) 오프라인 pcap 분석기 (P0)"
    )
    parser.add_argument("pcap", help="분석할 pcap/pcapng 파일 경로")
    parser.add_argument("--json", metavar="PATH",
                        help="결과(JSON: ap_table + findings)를 저장할 경로")
    parser.add_argument("--quiet", action="store_true",
                        help="stdout 리포트 생략(JSON 저장만)")
    args = parser.parse_args()

    if not Path(args.pcap).is_file():
        sys.stderr.write(f"[!] 파일을 찾을 수 없습니다: {args.pcap}\n")
        return 1

    aps = parse_pcap(args.pcap)
    apply_signals(aps)
    score_aps(aps)

    rows = to_dashboard_rows(aps)
    findings = build_findings(aps)

    if not args.quiet:
        print_report(aps, findings)

    if args.json:
        out_path = Path(args.json)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as fh:
            json.dump(
                {"ap_table": rows, "findings": findings},
                fh, ensure_ascii=False, indent=2,
            )
        if not args.quiet:
            print(f"[+] JSON 저장: {out_path}")

    # 탐지가 있으면 종료코드 1(스크립트 연동/CI 용), 없으면 0
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
