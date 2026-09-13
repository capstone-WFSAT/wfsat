#!/usr/bin/env bash
# ============================================================
# et_capture.sh - 모니터 인터페이스에서 관리 프레임(beacon/probe)을
#   몇 초간 캡처해 pcap 으로 저장한다. 저장된 pcap 을 detect 로 분석하면
#   Evil Twin / Beacon Flood 를 탐지할 수 있다.
#
# 사용 예:
#   sudo bash et_capture.sh                         # 기본 15초, config 채널
#   sudo CAP_SECS=20 CAP_CHANNEL=6 bash et_capture.sh
#   sudo interface=wlan0 bash et_capture.sh          # 캡처 어댑터 지정
#
# 완료 후 안내되는 detect 명령으로 분석하면 된다.
# ============================================================
set -u

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# et_config.conf 는 스크립트와 같은 폴더 또는 상위(프로젝트 루트)에 있다.
[ -f "${_script_dir}/et_config.conf" ] || _script_dir="${_script_dir}/.."
_config_file="${_script_dir}/et_config.conf"

_cli_interface="${interface:-}"
if [ -f "${_config_file}" ]; then
	# shellcheck disable=SC1090
	source <(tr -d '\r' < "${_config_file}")
fi
[ -n "${_cli_interface}" ] && interface="${_cli_interface}"

CAP_SECS="${CAP_SECS:-15}"
CAP_CHANNEL="${CAP_CHANNEL:-${channel:-6}}"
_log_dir="${WFSAT_LOG_DIR:-${log_dir:-/tmp/et_logs}}"
mkdir -p "${_log_dir}" 2>/dev/null
_pcap="${CAP_OUT:-${_log_dir}/capture_$(date +%Y%m%d_%H%M%S).pcap}"

if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
	echo "[!] Root 권한이 필요합니다. sudo 로 실행하세요." >&2
	exit 1
fi
if ! command -v tcpdump > /dev/null 2>&1; then
	echo "[!] tcpdump 가 필요합니다.  Install: sudo apt install -y tcpdump" >&2
	exit 1
fi

# 인터페이스 자동 배정(대화형 없음): 2번째 어댑터 우선, 하나뿐이면 그거.
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
	echo "[*] 캡처 인터페이스 자동 선택: ${interface}"
fi

if [ ! -d "/sys/class/net/${interface}/wireless" ]; then
	echo "[!] '${interface}' 는 무선 인터페이스가 아닙니다." >&2
	exit 1
fi

_restore() {
	ip link set "${interface}" down > /dev/null 2>&1
	iw "${interface}" set type managed > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
	command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed yes > /dev/null 2>&1
}
trap _restore EXIT INT TERM

# 모니터 모드 전환
echo "[*] '${interface}' 를 monitor 모드로 전환 (채널 ${CAP_CHANNEL})…"
command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed no > /dev/null 2>&1
ip link set "${interface}" down > /dev/null 2>&1
iw "${interface}" set type monitor > /dev/null 2>&1
ip link set "${interface}" up > /dev/null 2>&1
iw dev "${interface}" set channel "${CAP_CHANNEL}" > /dev/null 2>&1
_mode=$(iw "${interface}" info 2>/dev/null | awk '/type/{print $2}')
if [ "${_mode}" != "monitor" ]; then
	echo "[!] ${interface} 를 monitor 모드로 전환하지 못했습니다." >&2
	exit 1
fi

echo "[*] ${CAP_SECS}초 동안 관리 프레임(beacon/probe) 캡처 중… -> ${_pcap}"
# 관리 프레임만 저장(파일 작게 유지). timeout 으로 시간 제한.
timeout "${CAP_SECS}" tcpdump -i "${interface}" -w "${_pcap}" 'type mgt' 2>/dev/null
_rc=$?
# timeout 은 시간초과 종료 시 124 를 돌려주는데, 이는 정상(원하는 만큼 캡처)이다.
if [ ! -s "${_pcap}" ]; then
	echo "[!] 캡처된 데이터가 없습니다. 채널/어댑터를 확인하세요." >&2
	exit 1
fi

echo "[+] 캡처 완료: ${_pcap}"
echo "    분석:  detect ${_pcap} --json ${_log_dir}/detect.json"
