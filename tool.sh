#Show message for forbidden selected option
function forbidden_menu_option() {

	debug_print

	echo
	language_strings "${language}" 220 "red"
	language_strings "${language}" 115 "read"
}

function initialize_menu_and_print_selections() {

	debug_print

	forbidden_options=()

	case ${current_menu} in
		"main_menu")
			print_iface_selected
		;;
		"decrypt_menu")
			print_decrypt_vars
		;;
		"personal_decrypt_menu")
			print_personal_decrypt_vars
		;;
		"enterprise_decrypt_menu")
			print_enterprise_decrypt_vars
			enterprise_asleap_challenge=""
			enterprise_asleap_response=""
		;;
		"language_menu")
			print_iface_selected
		;;
		"evil_twin_attacks_menu")
			return_to_et_main_menu=0
			return_to_enterprise_main_menu=0
			retry_handshake_capture=0
			return_to_et_main_menu_from_beef=0
			retrying_handshake_capture=0
			internet_interface_selected=0
			enterprise_mode=""
			et_mode=""
			et_processes=()
			secondary_wifi_interface=""
			et_attack_adapter_prerequisites_ok=0
			advanced_captive_portal=0
			print_iface_selected
			print_all_target_vars_et
		;;
	esac
}

#Check if an interface is a Wi-Fi adapter or not
function check_interface_wifi() {

	debug_print

	iw "${1}" info > /dev/null 2>&1
	return $?
}

#DoS Evil Twin and Enterprise attacks menu
function et_dos_menu() {

	debug_print

	clear

	current_menu="et_dos_menu"
	initialize_menu_and_print_selections
	echo
	print_simple_separator
	if [ "${1}" = "enterprise" ]; then
		language_strings "${language}" 521
	else
		language_strings "${language}" 266
	fi
	print_simple_separator
	language_strings "${language}" 139 mdk_attack_dependencies[@]
	language_strings "${language}" 140 aireplay_attack_dependencies[@]
	language_strings "${language}" 141 mdk_attack_dependencies[@]
	print_hint

	read -rp "> " et_dos_option
	case ${et_dos_option} in
		0)
			if [ "${1}" != "enterprise" ]; then
				return_to_et_main_menu_from_beef=1
			fi
			return
		;;
		1)
			if contains_element "${et_dos_option}" "${forbidden_options[@]}"; then
				forbidden_menu_option
			else
				et_dos_attack="${mdk_command}"

				echo
				language_strings "${language}" 509 "yellow"

				if ! dos_pursuit_mode_et_handler; then
					return
				fi

				if [[ "${et_mode}" = "et_captive_portal" ]] || [[ -n "${enterprise_mode}" ]]; then
					et_prerequisites
				else
					if detect_internet_interface; then
						et_prerequisites
					else
						return
					fi
				fi
			fi
		;;
		2)
			if contains_element "${et_dos_option}" "${forbidden_options[@]}"; then
				forbidden_menu_option
			else
				et_dos_attack="Aireplay"

				echo
				language_strings "${language}" 509 "yellow"

				if ! dos_pursuit_mode_et_handler; then
					return
				fi

				if [[ "${et_mode}" = "et_captive_portal" ]] || [[ -n "${enterprise_mode}" ]]; then
					et_prerequisites
				else
					if detect_internet_interface; then
						et_prerequisites
					else
						return
					fi
				fi
			fi
		;;
		3)
			if contains_element "${et_dos_option}" "${forbidden_options[@]}"; then
				forbidden_menu_option
			else
				et_dos_attack="Auth DoS"

				echo
				language_strings "${language}" 509 "yellow"

				if ! dos_pursuit_mode_et_handler; then
					return
				fi

				if [[ "${et_mode}" = "et_captive_portal" ]] || [[ -n "${enterprise_mode}" ]]; then
					et_prerequisites
				else
					if detect_internet_interface; then
						et_prerequisites
					else
						return
					fi
				fi
			fi
		;;
		*)
			invalid_menu_option
		;;
	esac

	if [ "${1}" = "enterprise" ]; then
		et_dos_menu "${1}"
	else
		et_dos_menu
	fi
}

#Manage target exploration and parse the output files
function explore_for_targets_option() {

	debug_print

	echo
	language_strings "${language}" 103 "title"
	language_strings "${language}" 65 "green"

	if ! check_monitor_enabled "${interface}"; then
		echo
		language_strings "${language}" 14 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	echo
	language_strings "${language}" 66 "yellow"
	echo

	local cypher_filter
	if [ -n "${1}" ]; then
		cypher_filter="${1}"
		case ${cypher_filter} in
			"WEP")
				#Only WEP
				language_strings "${language}" 67 "yellow"
			;;
			"WPA1")
				#Only WPA including WPA/WPA2 in Mixed mode
				#Not used yet in airgeddon
				:
			;;
			"WPA2")
				#Only WPA2 including WPA/WPA2 and WPA2/WPA3 in Mixed mode
				#Not used yet in airgeddon
				:
			;;
			"WPA3")
				#Only WPA3 including WPA2/WPA3 in Mixed mode
				language_strings "${language}" 758 "yellow"
			;;
			"WPA")
				#All, WPA, WPA2 and WPA3 including all Mixed modes
				if [[ -n "${2}" ]] && [[ "${2}" = "enterprise" ]]; then
					language_strings "${language}" 527 "yellow"
				else
					language_strings "${language}" 215 "blue"
					echo
					language_strings "${language}" 361 "yellow"
				fi
			;;
		esac
		cypher_cmd=" --encrypt ${cypher_filter} "
	else
		cypher_filter=""
		cypher_cmd=" "
		language_strings "${language}" 366 "yellow"
	fi
	language_strings "${language}" 115 "read"

	rm -rf "${tmpdir}nws"* > /dev/null 2>&1
	rm -rf "${tmpdir}clts.csv" > /dev/null 2>&1

	if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
		airodump_band_modifier="bg"
	else
		airodump_band_modifier="abg"
	fi

	recalculate_windows_sizes
	manage_output "+j -bg \"#000000\" -fg \"#FFFFFF\" -geometry ${g1_topright_window} -T \"Exploring for targets\"" "airodump-ng -w ${tmpdir}nws${cypher_cmd}${interface} --band ${airodump_band_modifier}" "Exploring for targets" "active"
	wait_for_process "airodump-ng -w ${tmpdir}nws${cypher_cmd}${interface} --band ${airodump_band_modifier}" "Exploring for targets"
	targetline=$(awk '/(^Station[s]?|^Client[es]?)/{print NR}' "${tmpdir}nws-01.csv" 2> /dev/null)
	targetline=$((targetline - 1))
	head -n "${targetline}" "${tmpdir}nws-01.csv" &> "${tmpdir}nws.csv"
	tail -n +"${targetline}" "${tmpdir}nws-01.csv" &> "${tmpdir}clts.csv"

	csvline=$(wc -l "${tmpdir}nws.csv" 2> /dev/null | awk '{print $1}')
	if [ "${csvline}" -le 3 ]; then
		echo
		language_strings "${language}" 68 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	rm -rf "${tmpdir}nws.txt" > /dev/null 2>&1
	rm -rf "${tmpdir}wnws.txt" > /dev/null 2>&1
	local i=0
	local enterprise_network_counter
	local pure_wpa3
	while IFS=, read -r exp_mac _ _ exp_channel _ exp_enc _ exp_auth exp_power _ _ _ exp_idlength exp_essid _; do

		pure_wpa3=""
		chars_mac=${#exp_mac}
		if [ "${chars_mac}" -ge 17 ]; then
			i=$((i + 1))
			if [ "${exp_power}" -lt 0 ]; then
				if [ "${exp_power}" -eq -1 ]; then
					exp_power=0
				else
					exp_power=$((exp_power + 100))
				fi
			fi

			exp_power=$(echo "${exp_power}" | awk '{gsub(/ /,""); print}')
			exp_essid=${exp_essid:1:${exp_idlength}}

			if [[ ${exp_channel} =~ ${valid_channels_24_and_5_ghz_regexp} ]]; then
				exp_channel=$(echo "${exp_channel}" | awk '{gsub(/ /,""); print}')
			else
				exp_channel=0
			fi

			if [[ "${exp_essid}" = "" ]] || [[ "${exp_channel}" = "-1" ]]; then
				exp_essid="(Hidden Network)"
			fi

			exp_enc=$(echo "${exp_enc}" | awk '{print $1}')

			if [ -n "${1}" ]; then
				case ${cypher_filter} in
					"WEP")
						#Only WEP
						echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
					;;
					"WPA1")
						#Only WPA including WPA/WPA2 in Mixed mode
						#Not used yet in airgeddon
						echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
					;;
					"WPA2")
						#Only WPA2 including WPA/WPA2 and WPA2/WPA3 in Mixed mode
						#Not used yet in airgeddon
						echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
					;;
					"WPA3")
						#Only WPA3 including WPA2/WPA3 in Mixed mode
						echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
					;;
					"WPA")
						#All, WPA, WPA2 and WPA3 including all Mixed modes
						if [[ -n "${2}" ]] && [[ "${2}" = "enterprise" ]]; then
							if [[ "${exp_auth}" =~ MGT ]] || [[ "${exp_auth}" =~ CMAC && ! "${exp_auth}" =~ PSK ]]; then
								enterprise_network_counter=$((enterprise_network_counter + 1))
								echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
							fi
						else
							[[ ${exp_auth} =~ ^[[:blank:]](SAE)$ ]] && pure_wpa3="${BASH_REMATCH[1]}"
							if [ "${pure_wpa3}" != "SAE" ]; then
								echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
							fi
						fi
					;;
				esac
			else
				echo -e "${exp_mac},${exp_channel},${exp_power},${exp_essid},${exp_enc},${exp_auth}" >> "${tmpdir}nws.txt"
			fi
		fi
	done < "${tmpdir}nws.csv"

	if [[ -n "${2}" ]] && [[ "${2}" = "enterprise" ]] && [[ "${enterprise_network_counter}" -eq 0 ]]; then
		echo
		language_strings "${language}" 612 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	sort -t "," -d -k 3 "${tmpdir}nws.txt" > "${tmpdir}wnws.txt"
	select_target
}

#Evil Twin attacks menu
function evil_twin_attacks_menu() {

	debug_print

	clear

	language_strings "${language}" 256 et_onlyap_dependencies[@]

    explore_for_targets_option

    current_iface_on_messages="${interface}"
    if check_interface_wifi "${interface}"; then
        if [ "${adapter_vif_support}" -eq 0 ]; then
            ask_yesno 696 "no"
            if [ "${yesno}" = "y" ]; then
                et_attack_adapter_prerequisites_ok=1
            fi
        else
            et_attack_adapter_prerequisites_ok=1
        fi

        if [ "${et_attack_adapter_prerequisites_ok}" -eq 1 ]; then

            declare -gA ports_needed
            ports_needed["tcp"]=""
            ports_needed["udp"]="${dhcp_port}"
            if check_busy_ports; then
                et_mode="et_onlyap"
                et_dos_menu
            fi
        fi
    else
        echo
        language_strings "${language}" 281 "red"
        language_strings "${language}" 115 "read"
    fi

	evil_twin_attacks_menu
}

function main_menu() {

	debug_print

	clear
	language_strings "${language}" 101 "title"
	current_menu="main_menu"
	initialize_menu_and_print_selections
	echo
	language_strings "${language}" 47 "green"
	print_simple_separator
	language_strings "${language}" 61
	language_strings "${language}" 48
	language_strings "${language}" 55
	language_strings "${language}" 56
	print_simple_separator
	language_strings "${language}" 118
	language_strings "${language}" 119
	language_strings "${language}" 169
	language_strings "${language}" 252
	language_strings "${language}" 333
	language_strings "${language}" 426
	language_strings "${language}" 57
	language_strings "${language}" 754
	print_simple_separator
	language_strings "${language}" 60
	language_strings "${language}" 444
	print_hint

	read -rp "> " main_option
	case ${main_option} in
		0)
			exit_script_option
		;;
		1)
			select_interface
		;;
		2)
			monitor_option "${interface}"
		;;
		3)
			managed_option "${interface}"
		;;
		4)
			dos_attacks_menu
		;;
		5)
			handshake_pmkid_decloaking_tools_menu
		;;
		6)
			decrypt_menu
		;;
		7)
			evil_twin_attacks_menu
		;;
		8)
			wps_attacks_menu
		;;
		9)
			wep_attacks_menu
		;;
		10)
			enterprise_attacks_menu
		;;
		11)
			hookable_wpa3_attacks_menu
		;;
		12)
			credits_option
		;;
		13)
			option_menu
		;;
		*)
			invalid_menu_option
		;;
	esac

	main_menu
}

#Print a simple separator
function print_simple_separator() {

	debug_print

	echo_blue "---------"
}