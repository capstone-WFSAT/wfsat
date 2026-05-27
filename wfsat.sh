#!/usr/bin/env bash
# main.sh - Main flow, menus and initialization
# Auto-split from wfast.sh


#Language vars
#Change this line to select another default language. Select one from available values in array
language="ENGLISH"
declare -A lang_association=(
								["en"]="ENGLISH"
							)

rtl_languages=(
				"ARABIC"
				)

#Tools vars
essential_tools_names=(
						"iw"
						"awk"
						"airmon-ng"
						"airodump-ng"
						"aircrack-ng"
						"xterm"
						"ip"
						"lspci"
						"ps"
					)

optional_tools_names=(
						"wpaclean"
						"crunch"
						"aireplay-ng"
						"mdk4"
						"hashcat"
						"hostapd"
						"dhcpd"
						"nft"
						"ettercap"
						"etterlog"
						"lighttpd"
						"dnsmasq"
						"wash"
						"reaver"
						"bully"
						"pixiewps"
						"bettercap"
						"beef"
						"packetforge-ng"
						"hostapd-wpe"
						"asleap"
						"john"
						"openssl"
						"hcxpcapngtool"
						"hcxdumptool"
						"tshark"
						"tcpdump"
						"besside-ng"
						"hostapd-mana"
						"hcxhash2cap"
						"hcxhashtool"
					)

update_tools=("curl")

declare -A possible_package_names=(
									[${essential_tools_names[0]}]="iw" #iw
									[${essential_tools_names[1]}]="awk / gawk" #awk
									[${essential_tools_names[2]}]="aircrack-ng" #airmon-ng
									[${essential_tools_names[3]}]="aircrack-ng" #airodump-ng
									[${essential_tools_names[4]}]="aircrack-ng" #aircrack-ng
									[${essential_tools_names[5]}]="xterm" #xterm
									[${essential_tools_names[6]}]="iproute2" #ip
									[${essential_tools_names[7]}]="pciutils" #lspci
									[${essential_tools_names[8]}]="procps / procps-ng" #ps
									[${optional_tools_names[0]}]="aircrack-ng" #wpaclean
									[${optional_tools_names[1]}]="crunch" #crunch
									[${optional_tools_names[2]}]="aircrack-ng" #aireplay-ng
									[${optional_tools_names[3]}]="mdk4" #mdk4
									[${optional_tools_names[4]}]="hashcat" #hashcat
									[${optional_tools_names[5]}]="hostapd" #hostapd
									[${optional_tools_names[6]}]="isc-dhcp-server / dhcp-server / dhcp" #dhcpd
									[${optional_tools_names[7]}]="nftables" #nft
									[${optional_tools_names[8]}]="ettercap / ettercap-text-only / ettercap-graphical" #ettercap
									[${optional_tools_names[9]}]="ettercap / ettercap-text-only / ettercap-graphical" #etterlog
									[${optional_tools_names[10]}]="lighttpd" #lighttpd
									[${optional_tools_names[11]}]="dnsmasq" #dnsmasq
									[${optional_tools_names[12]}]="reaver" #wash
									[${optional_tools_names[13]}]="reaver" #reaver
									[${optional_tools_names[14]}]="bully" #bully
									[${optional_tools_names[15]}]="pixiewps" #pixiewps
									[${optional_tools_names[16]}]="bettercap" #bettercap
									[${optional_tools_names[17]}]="beef-xss / beef-project" #beef
									[${optional_tools_names[18]}]="aircrack-ng" #packetforge-ng
									[${optional_tools_names[19]}]="hostapd-wpe" #hostapd-wpe
									[${optional_tools_names[20]}]="asleap" #asleap
									[${optional_tools_names[21]}]="john" #john
									[${optional_tools_names[22]}]="openssl" #openssl
									[${optional_tools_names[23]}]="hcxtools" #hcxpcapngtool
									[${optional_tools_names[24]}]="hcxdumptool" #hcxdumptool
									[${optional_tools_names[25]}]="tshark / wireshark-cli / wireshark" #tshark
									[${optional_tools_names[26]}]="tcpdump" #tcpdump
									[${optional_tools_names[27]}]="aircrack-ng" #besside-ng
									[${optional_tools_names[28]}]="hostapd-mana" #hostapd-mana
									[${optional_tools_names[29]}]="hcxtools" #hcxhash2cap
									[${optional_tools_names[30]}]="hcxtools" #hcxhashtool
									[${update_tools[0]}]="curl" #curl
								)

#More than one alias can be defined separated by spaces at value
declare -A possible_alias_names=(
									["beef"]="beef-xss beef-server"
								)

#General vars
airgeddon_version="11.61"
language_strings_expected_version="11.61-1"
standardhandshake_filename="handshake-01.cap"
standardpmkid_filename="pmkid_hash.txt"
standardpmkidcap_filename="pmkid.cap"
timeout_capture_handshake_decloak="20"
timeout_capture_pmkid="45"
timeout_capture_identities="45"
timeout_certificates_analysis="45"
timeout_wpa3_downgrade="25"
osversionfile_dir="/etc/"
plugins_dir="plugins/"
ag_orchestrator_file="ag.orchestrator.txt"
system_tmpdir="/tmp/"
minimum_bash_version_required="4.2"
resume_message=224
abort_question=12
pending_of_translation="[PoT]"
escaped_pending_of_translation="\[PoT\]"
standard_resolution="1024x768"
curl_404_error="404: Not Found"
rc_file_name=".airgeddonrc"
alternative_rc_file_name="airgeddonrc"
language_strings_file="language_strings.sh"
broadcast_mac="FF:FF:FF:FF:FF:FF"
minimum_hcxdumptool_filterap_version="6.0.0"
minimum_hcxdumptool_bpf_version="6.3.0"

#5Ghz vars
ghz="Ghz"
band_24ghz="2.4${ghz}"
band_5ghz="5${ghz}"
valid_channels_24_ghz_regexp="([1-9]|1[0-4])"
valid_channels_24_and_5_ghz_regexp="([1-9]|1[0-4]|3[68]|4[02468]|5[02468]|6[024]|10[02468]|11[02468]|12[02468]|13[2468]|14[0249]|15[13579]|16[15])"
minimum_wash_dualscan_version="1.6.5"

#aircrack vars
aircrack_tmp_simple_name_file="aircrack"
aircrack_pot_tmp="${aircrack_tmp_simple_name_file}.pot"
aircrack_pmkid_version="1.4"

#hashcat vars
hashcat3_version="3.0"
hashcat4_version="4.0.0"
hashcat_hccapx_version="3.40"
hashcat_hcx_conversion_version="6.2.0"
minimum_hashcat_pmkid_version="6.0.0"
hashcat_2500_deprecated_version="6.2.4"
hashcat_handshake_cracking_plugin="2500"
hashcat_pmkid_cracking_plugin="22000"
hashcat_enterprise_cracking_plugin="5500"
hashcat_tmp_simple_name_file="hctmp"
hashcat_tmp_file="${hashcat_tmp_simple_name_file}.hccap"
hashcat_pot_tmp="${hashcat_tmp_simple_name_file}.pot"
hashcat_output_file="${hashcat_tmp_simple_name_file}.out"
hccapx_tool="cap2hccapx"
possible_hccapx_converter_known_locations=(
										"/usr/lib/hashcat-utils/${hccapx_tool}.bin"
									)

#john the ripper vars
jtr_tmp_simple_name_file="jtrtmp"
jtr_pot_tmp="${jtr_tmp_simple_name_file}.pot"
jtr_output_file="${jtr_tmp_simple_name_file}.out"

#WEP vars
wep_data="wepdata"
wepdir="wep/"
wep_attack_file="ag.wepattack.sh"
wep_key_handler="ag.wep_key_handler.sh"
wep_processes_file="wep_processes"
wep_besside_log="ag.besside.log"

#WPA3 vars
aircrack_wpa3_version="1.7"
plugin_x="under_construction_message"
plugin_x_under_construction="under_construction"
plugin_y="under_construction_message"
plugin_y_under_construction="under_construction"
plugin_z="under_construction_message"
plugin_z_under_construction="under_construction"

#Docker vars
docker_based_distro="Kali"
docker_io_dir="/io/"

#WPS vars
minimum_reaver_pixiewps_version="1.5.2"
minimum_reaver_nullpin_version="1.6.1"
minimum_bully_pixiewps_version="1.1"
minimum_bully_verbosity4_version="1.1"
minimum_wash_json_version="1.6.2"
known_pins_dbfile="known_pins.db"
pins_dbfile_checksum="pindb_checksum.txt"
wps_default_generic_pin="12345670"
wps_attack_script_file="ag.wpsattack.sh"
wps_out_file="ag.wpsout.txt"
timeout_secs_per_pin="30"
timeout_secs_per_pixiedust="30"

#Repository and contact vars
repository_hostname="github.com"
github_user="v1s1t0r1sh3r3"
github_repository="airgeddon"
branch="master"
script_filename="airgeddon.sh"
urlgithub="https://${repository_hostname}/${github_user}/${github_repository}"
urlscript_directlink="https://raw.githubusercontent.com/${github_user}/${github_repository}/${branch}/${script_filename}"
urlscript_pins_dbfile="https://raw.githubusercontent.com/${github_user}/${github_repository}/${branch}/${known_pins_dbfile}"
urlscript_pins_dbfile_checksum="https://raw.githubusercontent.com/${github_user}/${github_repository}/${branch}/${pins_dbfile_checksum}"
urlscript_language_strings_file="https://raw.githubusercontent.com/${github_user}/${github_repository}/${branch}/${language_strings_file}"
urlscript_options_config_file="https://raw.githubusercontent.com/${github_user}/${github_repository}/${branch}/${rc_file_name}"
urlgithub_wiki="https://${repository_hostname}/${github_user}/${github_repository}/wiki"
urlmerchandising_shop="https://airgeddon.creator-spring.com/"
mail="v1s1t0r.1s.h3r3@gmail.com"
author="v1s1t0r"
wpa3_online_attack_plugin_repo="https://${repository_hostname}/OscarAkaElvis/airgeddon-plugins"
wpa3_dragon_drain_plugin_repo="https://${repository_hostname}/Janek79ax/dragon-drain-wpa3-airgeddon-plugin"
wpa3_cookie_guzzler_plugin_repo="https://${repository_hostname}/OscarAkaElvis/airgeddon-plugins"

#Dhcpd, Hostapd, Hostapd-wpe, Hostapd-mana and misc Evil Twin vars
loopback_ip="127.0.0.1"
loopback_ipv6="::1/128"
loopback_interface="lo"
routing_tmp_file="ag.iptables_nftables"
dhcpd_file="ag.dhcpd.conf"
dhcpd_pid_file="dhcpd.pid"
dnsmasq_file="ag.dnsmasq.conf"
internet_dns1="8.8.8.8"
internet_dns2="8.8.4.4"
internet_dns3="139.130.4.5"
bettercap_proxy_port="8080"
bettercap_dns_port="5300"
dns_port="53"
dhcp_port="67"
www_port="80"
https_port="443"
minimum_bettercap_advanced_options="1.5.9"
minimum_bettercap_fixed_beef_iptables_issue="1.6.2"
bettercap2_version="2.0"
bettercap2_sslstrip_working_version="2.28"
ettercap_file="ag.ettercap.log"
bettercap_file="ag.bettercap.log"
bettercap_config_file="ag.bettercap.cap"
bettercap_hook_file="ag.bettercap.js"
beef_port="3000"
beef_control_panel_url="http://${loopback_ip}:${beef_port}/ui/panel"
jshookfile="hook.js"
beef_file="ag.beef.conf"
beef_pass="airgeddon"
beef_db="beef.db"
beef_default_cfg_file="config.yaml"
beef_needed_brackets_version="0.4.7.2"
beef_installation_url="https://${repository_hostname}/beefproject/beef/wiki/Installation"
hostapd_file="ag.hostapd.conf"
hostapd_wifi7_version="2.12"
hostapd_wpe_wifi7_version="2.12"
hostapd_wpe_file="ag.hostapd_wpe.conf"
hostapd_wpe_log="ag.hostapd_wpe.log"
hostapd_wpe_default_log="hostapd-wpe.log"
hostapd_mana_file="ag.hostapd_mana.conf"
hostapd_mana_log="ag.hostapd_mana.log"
hostapd_mana_out="ag.hostapd_mana.hccapx"
control_et_file="ag.et_control.sh"
control_enterprise_file="ag.enterprise_control.sh"
enterprisedir="enterprise/"
certsdir="certs/"
certspass="airgeddon"
default_certs_path="/etc/hostapd-wpe/certs/"
default_certs_pass="whatever"
mana_pass="airgeddon"
mana_cap_file="ag.mana.cap"
mana_tmp_file="ag.mana.txt"
webserver_file="ag.lighttpd.conf"
webserver_log="ag.lighttpd.log"
webdir="www/"
indexfile="index.htm"
checkfile="check.htm"
cssfile="portal.css"
jsfile="portal.js"
pixelfile="pixel.png"
attemptsfile="ag.et_attempts.txt"
currentpassfile="ag.et_currentpass.txt"
et_successfile="ag.et_success.txt"
enterprise_successfile="ag.enterprise_success.txt"
et_processesfile="ag.et_processes.txt"
asleap_pot_tmp="ag.asleap_tmp.txt"
channelfile="ag.et_channel.txt"
customportals_php_as_cgi=1
possible_dhcp_leases_files=(
								"/var/lib/dhcp/dhcpd.leases"
								"/var/state/dhcp/dhcpd.leases"
								"/var/lib/dhcpd/dhcpd.leases"
							)
possible_beef_known_locations=(
									"/usr/share/beef/"
									"/usr/share/beef-xss/"
									"/opt/beef/"
									"/opt/beef-project/"
									"/usr/lib/beef/"
									#Custom BeEF location (set=0)
								)

#Connection vars
ips_to_check_internet=(
						"${internet_dns1}"
						"${internet_dns2}"
						"${internet_dns3}"
					)

#Distros vars
known_compatible_distros=(
							"Wifislax"
							"Kali"
							"Parrot"
							"Backbox"
							"BlackArch"
							"Cyborg"
							"Ubuntu"
							"Mint"
							"Debian"
							"SuSE"
							"CentOS"
							"Gentoo"
							"Fedora"
							"Red Hat"
							"Arch"
							"OpenMandriva"
							"Pentoo"
							"Manjaro"
							"CachyOS"
							"Puppy"
						)

known_incompatible_distros=(
							"Microsoft"
						)

known_arm_compatible_distros=(
								"Raspbian"
								"Raspberry Pi OS"
								"Parrot arm"
								"Kali arm"
							)

#Sponsors
sponsors=(
		"Raleigh2016"
		"hmmlopl"
		"codythebeast89"
		"Kaliscandinavia"
		"Furrycoder"
		"Jonathon Coy"
		"Matthew Ebert"
		)

#Hint vars
declare main_hints=(128 134 163 437 438 442 445 516 590 626 660 697 699 712 739)
declare dos_hints=(129 131 133 697 699)
declare handshake_pmkid_decloaking_hints=(127 130 132 664 665 697 699 728 729)
declare dos_handshake_decloak_hints=(142 697 699 733 739)
declare dos_info_gathering_enterprise_hints=(697 699 733 739)
declare decrypt_hints=(171 179 208 244 163 697 699)
declare personal_decrypt_hints=(171 178 179 208 244 163 697 699)
declare enterprise_decrypt_hints=(171 179 208 244 163 610 697 699)
declare select_interface_hints=(246 697 699 712 739)
declare language_hints=(250 438)
declare option_hints=(445 250 448 477 591 626 697 699)
declare evil_twin_hints=(254 258 264 269 309 328 400 509 697 699 739)
declare evil_twin_dos_hints=(267 268 509 697 699)
declare wpa3_dos_hints=(267 268 697 699 777)
declare beef_hints=(408)
declare wps_hints=(342 343 344 356 369 390 490 625 697 699 739)
declare wep_hints=(431 429 428 432 433 697 699 739)
declare enterprise_hints=(112 332 483 518 629 301 697 699 739 742)
declare wpa3_hints=(128 134 437 438 442 445 516 590 626 660 697 699 764)

#Charset vars
crunch_lowercasecharset="abcdefghijklmnopqrstuvwxyz"
crunch_uppercasecharset="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
crunch_numbercharset="0123456789"
crunch_symbolcharset="!#$%/=?{}[]-*:;"
hashcat_charsets=("?l" "?u" "?d" "?s")

#Tmux vars
airgeddon_uid=""
session_name="airgeddon"
tmux_main_window="airgeddon-Main"
no_hardcore_exit=0






function main() {

	initialize_script_settings
	initialize_colors
	env_vars_initialization
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		initialize_tmux "${1}" "${2}"
	fi
	initialize_instance_settings
	detect_distro_phase1
	detect_distro_phase2
	special_distro_features

	if "${AIRGEDDON_AUTO_CHANGE_LANGUAGE:-true}"; then
		autodetect_language
	fi

	detect_rtl_language
	check_language_strings
	initialize_language_strings
	iptables_nftables_detection
	set_mdk_version
	dependencies_modifications

	if "${AIRGEDDON_PLUGINS_ENABLED:-true}"; then
		parse_plugins "$@"
		apply_plugin_functions_rewriting
	fi

	remap_colors
	hookable_for_languages

	clear
	current_menu="pre_main_menu"
	docker_detection
	set_default_save_path
	graphics_prerequisites

	if [[ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]] && [[ "${tmux_error}" -eq 1 ]]; then
		language_strings "${language}" 86 "title"
		echo
		language_strings "${language}" 621 "yellow"
		language_strings "${language}" 115 "read"
		create_tmux_session "${session_name}" "false"

		exit_code=1
		exit ${exit_code}
	fi

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
		check_graphics_system
		detect_screen_resolution
	fi

	set_possible_aliases
	initialize_optional_tools_values

	if ! "${AIRGEDDON_DEVELOPMENT_MODE:-false}"; then
		if ! "${AIRGEDDON_SKIP_INTRO:-false}"; then
			language_strings "${language}" 86 "title"
			language_strings "${language}" 6 "blue"
			echo
			if check_window_size_for_intro; then
				print_intro
			else
				language_strings "${language}" 228 "green"
				echo
				language_strings "${language}" 395 "yellow"
				sleep 3
			fi
		fi

		clear
		language_strings "${language}" 86 "title"
		language_strings "${language}" 7 "pink"
		language_strings "${language}" 114 "pink"

		if [ "${autochanged_language}" -eq 1 ]; then
			echo
			language_strings "${language}" 2 "yellow"
		fi

		check_bash_version
		check_root_permissions
		check_wsl

		if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "xterm" ]; then
			echo
			if [[ "${resolution_detected}" -eq 1 ]] && [[ "${xterm_ok}" -eq 1 ]]; then
				language_strings "${language}" 294 "blue"
			else
				if [ "${xterm_ok}" -eq 0 ]; then
					case "${graphics_system}" in
						"x11")
							language_strings "${language}" 476 "red"
							exit_code=1
							exit_script_option
						;;
						"wayland")
							language_strings "${language}" 704 "red"
							exit_code=1
							exit_script_option
						;;
						"tty"|*)
							language_strings "${language}" 705 "red"
							exit_code=1
							exit_script_option
						;;
					esac
				else
					language_strings "${language}" 295 "red"
					echo
					language_strings "${language}" 300 "yellow"
				fi
			fi
		fi

		detect_running_instances
		if [ "$?" -gt 1 ]; then
			echo
			language_strings "${language}" 720 "yellow"
			echo
			language_strings "${language}" 721 "blue"
			language_strings "${language}" 115 "read"
		fi

		echo
		language_strings "${language}" 8 "blue"
		print_known_distros
		echo
		language_strings "${language}" 9 "blue"
		general_checkings
		language_strings "${language}" 115 "read"

		airmonzc_security_check
		check_update_tools
	fi

	print_configuration_vars_issues
	initialize_extended_colorized_output
	initialize_sounds
	set_windows_sizes
	select_interface
	initialize_menu_options_dependencies
	remove_warnings
	evil_twin_attacks_menu
}

#Script starts to execute stuff from this point, traps and then the main function
for f in SIGINT SIGHUP INT SIGTSTP; do
	trap_cmd="trap \"capture_traps ${f}\" \"${f}\""
	eval "${trap_cmd}"
done

main "$@"