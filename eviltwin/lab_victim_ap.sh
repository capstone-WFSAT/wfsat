#!/usr/bin/env bash
# ============================================================
# lab_victim_ap.sh - 격리된 실습용 "피해 AP"를 두 번째 WiFi
#   어댑터에 hostapd로 띄운다. 이 AP를 et_scan.sh / et_sniffing_attack.sh
#   의 공격 대상으로 삼으면, 실제 홈 네트워크를 건드리지 않고
#   Evil Twin 공격을 안전하게 재현할 수 있다.
#
# 사용 예:
#   sudo ./lab_victim_ap.sh                 # 기본값(WPA2)으로 실행
#   sudo LAB_IFACE=wlan1 ./lab_victim_ap.sh # 피해 AP 어댑터 지정
#   sudo LAB_OPEN=1 ./lab_victim_ap.sh      # 오픈 AP(페이크 트윈과 동일 보안)
#   sudo LAB_NAT=0 ./lab_victim_ap.sh       # 인터넷 공유(NAT) 끄기
#
# 종료: Ctrl+C  (인터페이스/방화벽/설정을 자동 복원)
# ============================================================

set -u

# --- 설정(환경변수로 덮어쓸 수 있음) ---------------------------------
LAB_ESSID="${LAB_ESSID:-test_lab}"       # 피해 AP 이름 (공격 대상 ESSID)
LAB_PASS="${LAB_PASS:-labpass123}"       # WPA2 암호 (8자 이상)
LAB_CHANNEL="${LAB_CHANNEL:-6}"          # 2.4GHz 채널
LAB_IFACE="${LAB_IFACE:-}"               # 피해 AP용 어댑터(비우면 자동 감지)
LAB_AP_IP="${LAB_AP_IP:-192.168.50.1}"   # 피해 AP 게이트웨이 IP
LAB_CIDR="${LAB_CIDR:-24}"
LAB_NETMASK="${LAB_NETMASK:-255.255.255.0}"
LAB_DHCP_START="${LAB_DHCP_START:-192.168.50.50}"
LAB_DHCP_END="${LAB_DHCP_END:-192.168.50.150}"
LAB_NET="${LAB_NET:-192.168.50.0}"       # NAT 소스 대역
LAB_UPLINK="${LAB_UPLINK:-}"             # 인터넷 공유용 업링크(비우면 기본 라우트 자동)
LAB_NAT="${LAB_NAT:-1}"                  # 1=인터넷 공유(NAT) 켜기, 0=끄기
LAB_OPEN="${LAB_OPEN:-0}"                # 1=오픈 AP, 0=WPA2
LAB_COUNTRY="${LAB_COUNTRY:-}"           # 국가코드(예: KR, US). 비우면 생략(2.4GHz 1~11 채널은 불필요)
                                         # 주의: '00'은 일부 hostapd 버전에서 거부됨 -> 비워두는 게 안전
LAB_WRITE_CONFIG="${LAB_WRITE_CONFIG:-1}" # 1=et_config.conf에 대상(bssid/essid/channel) 자동 기록 -> et_scan 불필요

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_config_file="${_script_dir}/et_config.conf"
_workdir="/tmp/lab_victim_ap"
_hostapd_conf="${_workdir}/hostapd.conf"
_dnsmasq_conf="${_workdir}/dnsmasq.conf"
_dnsmasq_lease="${_workdir}/dnsmasq.leases"

_hostapd_pid=""
_dnsmasq_pid=""
_nat_added=0
_orig_ip_forward=""
_nm_was_managed=0

# et_config.conf 의 특정 key 값을 안전하게 갱신(특수문자 포함 ESSID 대응)
# 공격용 interface 값은 건드리지 않는다(피해 AP와 별개 어댑터이므로).
function _write_config_value() {
	local key="$1" value="$2" tmp="${_workdir}/conf_update.tmp"
	awk -v k="${key}" -v v="${value}" '
		$0 ~ ("^" k "=") { print k "=\"" v "\""; next }
		{ print }
	' "${_config_file}" > "${tmp}" && mv "${tmp}" "${_config_file}"
}

# --- Root 확인 ------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
	echo "[!] Root privileges required. Run with sudo." >&2
	exit 1
fi

# --- 의존성 확인 ----------------------------------------------------
_missing_deps=""
for _bin in hostapd dnsmasq iw ip; do
	command -v "${_bin}" > /dev/null 2>&1 || _missing_deps="${_missing_deps} ${_bin}"
done
if [ -n "${_missing_deps}" ]; then
	echo "[!] Missing required tools:${_missing_deps}" >&2
	echo "    Install: sudo apt update && sudo apt install -y hostapd dnsmasq iw" >&2
	exit 1
fi

# --- 공격에 쓰는 인터페이스(피해 AP로 쓰면 안 되는 것) 파악 ---------
_attack_iface=""
if [ -f "${_config_file}" ]; then
	_attack_iface=$(tr -d '\r' < "${_config_file}" | awk -F'"' '/^interface=/{print $2}')
fi

# --- 피해 AP 어댑터 자동 감지 ---------------------------------------
if [ -z "${LAB_IFACE}" ]; then
	for _dir in /sys/class/net/*/; do
		_name=$(basename "${_dir}")
		[ -d "/sys/class/net/${_name}/wireless" ] || continue
		[ "${_name}" = "${_attack_iface}" ] && continue
		LAB_IFACE="${_name}"
		break
	done
fi

if [ -z "${LAB_IFACE}" ]; then
	echo "[!] No second WiFi adapter found for the victim AP." >&2
	echo "    A separate adapter from the attack one (${_attack_iface:-unset}) is required." >&2
	echo "    Set it explicitly with LAB_IFACE=wlanX." >&2
	exit 1
fi

if [ "${LAB_IFACE}" = "${_attack_iface}" ]; then
	echo "[!] LAB_IFACE (${LAB_IFACE}) is the same as the attack interface." >&2
	echo "    The victim AP and the attack must use different adapters." >&2
	exit 1
fi

if [ "${LAB_OPEN}" != "1" ] && [ "${#LAB_PASS}" -lt 8 ]; then
	echo "[!] WPA2 passphrase (LAB_PASS) must be at least 8 characters." >&2
	exit 1
fi

# --- 업링크(NAT) 자동 감지 ------------------------------------------
if [ "${LAB_NAT}" = "1" ] && [ -z "${LAB_UPLINK}" ]; then
	LAB_UPLINK=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
	if [ -z "${LAB_UPLINK}" ] || [ "${LAB_UPLINK}" = "${LAB_IFACE}" ]; then
		echo "[!] Could not auto-detect an uplink; disabling internet sharing (NAT)."
		LAB_NAT=0
	fi
fi

# ============================================================
# 정리(cleanup): 종료 시 원래 상태로 복원
# ============================================================
function _cleanup() {
	echo
	echo "[*] Cleaning up victim AP..."

	[ -n "${_hostapd_pid}" ] && kill "${_hostapd_pid}" 2>/dev/null
	[ -n "${_dnsmasq_pid}" ] && kill "${_dnsmasq_pid}" 2>/dev/null
	wait "${_hostapd_pid}" 2>/dev/null
	wait "${_dnsmasq_pid}" 2>/dev/null

	if [ "${_nat_added}" -eq 1 ]; then
		iptables -t nat -D POSTROUTING -s "${LAB_NET}/${LAB_CIDR}" -o "${LAB_UPLINK}" -j MASQUERADE 2>/dev/null
		iptables -D FORWARD -i "${LAB_UPLINK}" -o "${LAB_IFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
		iptables -D FORWARD -i "${LAB_IFACE}" -o "${LAB_UPLINK}" -j ACCEPT 2>/dev/null
	fi
	if [ -n "${_orig_ip_forward}" ]; then
		echo "${_orig_ip_forward}" > /proc/sys/net/ipv4/ip_forward 2>/dev/null
	fi

	ip addr flush dev "${LAB_IFACE}" 2>/dev/null
	ip link set "${LAB_IFACE}" down 2>/dev/null

	# NetworkManager 관리 복원
	if [ "${_nm_was_managed}" -eq 1 ] && command -v nmcli > /dev/null 2>&1; then
		nmcli dev set "${LAB_IFACE}" managed yes 2>/dev/null
	fi

	# preserve_external_aps 를 원래대로(0) 되돌린다: 다음번 실제 대상 공격 때는
	# 전역 check kill(기본 동작)로 돌아가도록.
	if [ "${LAB_WRITE_CONFIG}" = "1" ] && [ -f "${_config_file}" ]; then
		_write_config_value "preserve_external_aps" "0" 2>/dev/null
	fi

	echo "[+] Cleanup complete."
}
trap _cleanup EXIT INT TERM

# ============================================================
# 인터페이스 준비
# ============================================================
echo "[*] Victim AP configuration"
echo "    ESSID     : ${LAB_ESSID}"
if [ "${LAB_OPEN}" = "1" ]; then
	echo "    Security  : OPEN"
else
	echo "    Security  : WPA2 (passphrase: ${LAB_PASS})"
fi
echo "    Channel   : ${LAB_CHANNEL}"
echo "    Interface : ${LAB_IFACE}"
echo "    Gateway   : ${LAB_AP_IP}/${LAB_CIDR}"
if [ "${LAB_NAT}" = "1" ]; then
	echo "    Internet  : ${LAB_IFACE} -> ${LAB_UPLINK} (NAT)"
else
	echo "    Internet  : none"
fi
echo

mkdir -p "${_workdir}"

# NetworkManager가 이 인터페이스를 잡고 있으면 hostapd가 실패하므로 관리 해제
if command -v nmcli > /dev/null 2>&1; then
	_nm_state=$(nmcli -t -f GENERAL.STATE dev show "${LAB_IFACE}" 2>/dev/null)
	if [ -n "${_nm_state}" ]; then
		_nm_was_managed=1
		nmcli dev set "${LAB_IFACE}" managed no 2>/dev/null
	fi
fi

# 이 인터페이스에 붙은 wpa_supplicant 종료(있으면)
pkill -f "wpa_supplicant.*${LAB_IFACE}" 2>/dev/null

ip link set "${LAB_IFACE}" down 2>/dev/null
iw dev "${LAB_IFACE}" set type managed 2>/dev/null
ip addr flush dev "${LAB_IFACE}" 2>/dev/null
ip addr add "${LAB_AP_IP}/${LAB_CIDR}" dev "${LAB_IFACE}" 2>/dev/null
ip link set "${LAB_IFACE}" up 2>/dev/null

# ============================================================
# hostapd 설정 생성
# ============================================================
{
	echo "interface=${LAB_IFACE}"
	echo "driver=nl80211"
	echo "ssid=${LAB_ESSID}"
	echo "hw_mode=g"
	echo "channel=${LAB_CHANNEL}"
	# 유효한 국가코드가 지정된 경우에만 기록('00'은 hostapd가 거부하므로 제외)
	if [ -n "${LAB_COUNTRY}" ] && [ "${LAB_COUNTRY}" != "00" ]; then
		echo "country_code=${LAB_COUNTRY}"
	fi
	echo "ignore_broadcast_ssid=0"
	echo "auth_algs=1"
	if [ "${LAB_OPEN}" != "1" ]; then
		echo "wpa=2"
		echo "wpa_passphrase=${LAB_PASS}"
		echo "wpa_key_mgmt=WPA-PSK"
		echo "rsn_pairwise=CCMP"
	fi
} > "${_hostapd_conf}"

# ============================================================
# dnsmasq(DHCP) 설정 생성
# ============================================================
{
	echo "port=0"                        # DNS 서비스 끔(시스템 dnsmasq 포트 53 충돌 방지) — DHCP만 제공
	echo "interface=${LAB_IFACE}"
	echo "bind-interfaces"
	echo "except-interface=lo"
	echo "dhcp-range=${LAB_DHCP_START},${LAB_DHCP_END},${LAB_NETMASK},12h"
	echo "dhcp-option=3,${LAB_AP_IP}"    # gateway
	echo "dhcp-option=6,8.8.8.8,1.1.1.1" # DNS = 공인 리졸버(NAT 통해 조회)
	echo "dhcp-leasefile=${_dnsmasq_lease}"
	echo "log-dhcp"
} > "${_dnsmasq_conf}"

# ============================================================
# NAT(인터넷 공유) 설정 — 공격 전 "정상" 상태를 만들기 위함
# 주의: et_sniffing_attack.sh 는 시작 시 iptables 를 flush 할 수 있어
#       공격을 켜면 이 NAT 규칙이 사라질 수 있다(피해자 인터넷이 끊김 = 정상 시연).
# ============================================================
if [ "${LAB_NAT}" = "1" ]; then
	_orig_ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
	echo "1" > /proc/sys/net/ipv4/ip_forward 2>/dev/null
	iptables -t nat -A POSTROUTING -s "${LAB_NET}/${LAB_CIDR}" -o "${LAB_UPLINK}" -j MASQUERADE 2>/dev/null
	iptables -A FORWARD -i "${LAB_UPLINK}" -o "${LAB_IFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
	iptables -A FORWARD -i "${LAB_IFACE}" -o "${LAB_UPLINK}" -j ACCEPT 2>/dev/null
	_nat_added=1
fi

# ============================================================
# hostapd / dnsmasq 실행
# ============================================================
echo "[*] Starting hostapd..."
hostapd "${_hostapd_conf}" > "${_workdir}/hostapd.log" 2>&1 &
_hostapd_pid=$!

sleep 2
if ! kill -0 "${_hostapd_pid}" 2>/dev/null; then
	echo "[!] hostapd failed to start. Log:" >&2
	sed 's/^/    /' "${_workdir}/hostapd.log" >&2
	exit 1
fi

echo "[*] Starting dnsmasq (DHCP)..."
# 시스템 dnsmasq 서비스와 충돌하지 않게 단독 실행
dnsmasq --conf-file="${_dnsmasq_conf}" --no-daemon > "${_workdir}/dnsmasq.log" 2>&1 &
_dnsmasq_pid=$!

sleep 1
if ! kill -0 "${_dnsmasq_pid}" 2>/dev/null; then
	echo "[!] dnsmasq failed to start. Log:" >&2
	sed 's/^/    /' "${_workdir}/dnsmasq.log" >&2
	echo "    (If the system dnsmasq service is running: sudo systemctl stop dnsmasq)" >&2
	exit 1
fi

_bssid=$(cat "/sys/class/net/${LAB_IFACE}/address" 2>/dev/null)

# 대상 값을 et_config.conf 에 기록 -> et_scan.sh 를 건너뛸 수 있다
# (아래 preserve_external_aps=1 덕분에 et_scan 을 돌려 이 AP 를 골라도 죽지 않는다.
#  스캔은 대상을 이미 알고 있으니 불필요할 뿐, 돌려도 문제는 없다.)
if [ "${LAB_WRITE_CONFIG}" = "1" ] && [ -f "${_config_file}" ]; then
	_write_config_value "bssid"   "${_bssid}"
	_write_config_value "essid"   "${LAB_ESSID}"
	_write_config_value "channel" "${LAB_CHANNEL}"
	# 전역 check kill 대신 공격 인터페이스만 NM 해제하도록 해서
	# 스캔/공격이 이 피해 AP(hostapd)를 죽이지 않게 한다.
	_write_config_value "preserve_external_aps" "1"
	echo "[+] Wrote target (bssid/essid/channel) to et_config.conf"
	echo "[+] Set preserve_external_aps=1 (scan/attack won't kill this AP)"
	echo "    -> You can now run et_scan.sh AND et_sniffing_attack.sh without dropping this AP."
fi

echo
echo "================================================================"
echo " [+] Victim AP is up"
echo "     ESSID   : ${LAB_ESSID}"
echo "     BSSID   : ${_bssid}"
echo "     Channel : ${LAB_CHANNEL}"
echo "     DHCP    : ${LAB_DHCP_START} - ${LAB_DHCP_END}"
echo "================================================================"
echo
echo " Next steps:"
echo "   1) Connect a victim device to '${LAB_ESSID}'"
echo "   2) In another terminal:  sudo interface=<attack-iface> bash et_sniffing_attack.sh"
echo "      (et_scan.sh is optional - target is already saved to et_config.conf."
echo "       Running et_scan is also safe: preserve_external_aps=1 keeps this AP alive.)"
echo
echo " Press Ctrl+C to stop the victim AP."
echo

# hostapd 가 살아있는 동안 유지(둘 중 하나가 죽으면 정리 후 종료)
while kill -0 "${_hostapd_pid}" 2>/dev/null && kill -0 "${_dnsmasq_pid}" 2>/dev/null; do
	sleep 2
done
