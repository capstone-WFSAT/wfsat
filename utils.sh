#!/usr/bin/env bash
# utils.sh - Utility and helper functions
# Auto-split from wfast.sh

function check_language_strings() {

	debug_print

	if [ -f "${scriptfolder}${language_strings_file}" ]; then

		language_file_found=1
		language_file_mismatch=0
		#shellcheck source=./language_strings.sh
		source "${scriptfolder}${language_strings_file}"
		set_language_strings_version
		if [ "${language_strings_version}" != "${language_strings_expected_version}" ]; then
			language_file_mismatch=1
		fi
	else
		language_file_found=0
	fi

	if [[ "${language_file_found}" -eq 0 ]] || [[ "${language_file_mismatch}" -eq 1 ]]; then

		language_strings_handling_messages

		generate_dynamic_line "airgeddon" "title"
		if [ "${language_file_found}" -eq 0 ]; then
			echo_red "${language_strings_no_file[${language}]}"
			if [ "${airgeddon_version}" = "6.1" ]; then
				echo
				echo_yellow "${language_strings_first_time[${language}]}"
			fi
		elif [ "${language_file_mismatch}" -eq 1 ]; then
			echo_red "${language_strings_file_mismatch[${language}]}"
		fi

		echo
		echo_blue "${language_strings_try_to_download[${language}]}"
		read -p "${language_strings_key_to_continue[${language}]}" -r

		if check_repository_access; then

			if download_language_strings_file; then
				echo
				echo_yellow "${language_strings_successfully_downloaded[${language}]}"
				read -p "${language_strings_key_to_continue[${language}]}" -r
				clear
				return 0
			else
				echo
				echo_red "${language_strings_failed_downloading[${language}]}"
			fi
		else
			echo
			echo_red "${language_strings_failed_downloading[${language}]}"
		fi

		echo
		echo_blue "${language_strings_exiting[${language}]}"
		echo
		hardcore_exit
	fi
}
function download_language_strings_file() {

	debug_print

	local lang_file_downloaded=0
	remote_language_strings_file=$(timeout -s SIGTERM 15 curl -L ${urlscript_language_strings_file} 2> /dev/null)

	if [[ -n "${remote_language_strings_file}" ]] && [[ "${remote_language_strings_file}" != "${curl_404_error}" ]]; then
		lang_file_downloaded=1
	else
		http_proxy_detect
		if [ "${http_proxy_set}" -eq 1 ]; then

			remote_language_strings_file=$(timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_language_strings_file} 2> /dev/null)
			if [[ -n "${remote_language_strings_file}" ]] && [[ "${remote_language_strings_file}" != "${curl_404_error}" ]]; then
				lang_file_downloaded=1
			fi
		fi
	fi

	if [ "${lang_file_downloaded}" -eq 1 ]; then
		echo "${remote_language_strings_file}" > "${scriptfolder}${language_strings_file}"
		chmod +x "${scriptfolder}${language_strings_file}" > /dev/null 2>&1
		#shellcheck source=./language_strings.sh
		source "${scriptfolder}${language_strings_file}"
		return 0
	else
		return 1
	fi
}
function language_strings_handling_messages() {

	declare -gA language_strings_no_file
	language_strings_no_file["ENGLISH"]="Error. Language strings file not found"
	language_strings_no_file["SPANISH"]="Error. No se ha encontrado el fichero de traducciones"
	language_strings_no_file["FRENCH"]="Erreur. Fichier contenant les traductions absent"
	language_strings_no_file["CATALAN"]="Error. No s'ha trobat el fitxer de traduccions"
	language_strings_no_file["PORTUGUESE"]="Erro. O arquivo de tradução não foi encontrado"
	language_strings_no_file["RUSSIAN"]="Ошибка. Не найден языковой файл"
	language_strings_no_file["GREEK"]="Σφάλμα. Το αρχείο γλωσσών δεν βρέθηκε"
	language_strings_no_file["ITALIAN"]="Errore. Non si trova il file delle traduzioni"
	language_strings_no_file["POLISH"]="Błąd. Nie znaleziono pliku tłumaczenia"
	language_strings_no_file["GERMAN"]="Fehler. Die Übersetzungsdatei wurde nicht gefunden"
	language_strings_no_file["TURKISH"]="Hata. Çeviri dosyası bulunamadı"
	language_strings_no_file["ARABIC"]="خطأ. ملف اللغة غير موجود"
	language_strings_no_file["CHINESE"]="错误。未找到语言支持文件"

	declare -gA language_strings_file_mismatch
	language_strings_file_mismatch["ENGLISH"]="Error. The language strings file found mismatches expected version"
	language_strings_file_mismatch["SPANISH"]="Error. El fichero de traducciones encontrado no es la versión esperada"
	language_strings_file_mismatch["FRENCH"]="Erreur. Les traductions trouvées ne sont pas celles attendues"
	language_strings_file_mismatch["CATALAN"]="Error. El fitxer de traduccions trobat no és la versió esperada"
	language_strings_file_mismatch["PORTUGUESE"]="Erro. O a versão do arquivos de tradução encontrado é a incompatível"
	language_strings_file_mismatch["RUSSIAN"]="Ошибка. Языковой файл не соответствует ожидаемой версии"
	language_strings_file_mismatch["GREEK"]="Σφάλμα. Το αρχείο γλωσσών που έχει βρεθεί δεν αντιστοιχεί με την προαπαιτούμενη έκδοση"
	language_strings_file_mismatch["ITALIAN"]="Errore. Il file delle traduzioni trovato non è la versione prevista"
	language_strings_file_mismatch["POLISH"]="Błąd. Znaleziony plik tłumaczenia nie jest oczekiwaną wersją"
	language_strings_file_mismatch["GERMAN"]="Fehler. Die gefundene Übersetzungsdatei ist nicht die erwartete Version"
	language_strings_file_mismatch["TURKISH"]="Hata. Bulunan çeviri dosyası beklenen sürüm değil"
	language_strings_file_mismatch["ARABIC"]="خطأ. ملف اللغة غيرمتطابق مع الإصدار المتوقع"
	language_strings_file_mismatch["CHINESE"]="错误。发现语言支持文件与预期版本不匹配"

	declare -gA language_strings_try_to_download
	language_strings_try_to_download["ENGLISH"]="airgeddon will try to download the language strings file..."
	language_strings_try_to_download["SPANISH"]="airgeddon intentará descargar el fichero de traducciones..."
	language_strings_try_to_download["FRENCH"]="airgeddon va essayer de télécharger les fichiers de traductions..."
	language_strings_try_to_download["CATALAN"]="airgeddon intentarà descarregar el fitxer de traduccions..."
	language_strings_try_to_download["PORTUGUESE"]="O airgeddon tentará baixar o arquivo de tradução..."
	language_strings_try_to_download["RUSSIAN"]="airgeddon попытается загрузить языковой файл..."
	language_strings_try_to_download["GREEK"]="Το airgeddon θα προσπαθήσει να κατεβάσει το αρχείο γλωσσών..."
	language_strings_try_to_download["ITALIAN"]="airgeddon cercherá di scaricare il file delle traduzioni..."
	language_strings_try_to_download["POLISH"]="airgeddon spróbuje pobrać plik tłumaczeń..."
	language_strings_try_to_download["GERMAN"]="airgeddon wird versuchen, die Übersetzungsdatei herunterzuladen..."
	language_strings_try_to_download["TURKISH"]="airgeddon çeviri dosyasını indirmeye çalışacak..."
	language_strings_try_to_download["ARABIC"]="سيحاول airgeddon تنزيل ملف سلاسل اللغة ..."
	language_strings_try_to_download["CHINESE"]="airgeddon 将尝试下载语言支持文件..."

	declare -gA language_strings_successfully_downloaded
	language_strings_successfully_downloaded["ENGLISH"]="Language strings file was successfully downloaded"
	language_strings_successfully_downloaded["SPANISH"]="Se ha descargado con éxito el fichero de traducciones"
	language_strings_successfully_downloaded["FRENCH"]="Les fichiers traduction ont été correctement téléchargés"
	language_strings_successfully_downloaded["CATALAN"]="S'ha descarregat amb èxit el fitxer de traduccions"
	language_strings_successfully_downloaded["PORTUGUESE"]="O arquivo de tradução foi baixado com sucesso"
	language_strings_successfully_downloaded["RUSSIAN"]="Языковой файл был успешно загружен"
	language_strings_successfully_downloaded["GREEK"]="Το αρχείο γλωσσών κατέβηκε με επιτυχία"
	language_strings_successfully_downloaded["ITALIAN"]="Il file delle traduzioni è stato scaricato con successo"
	language_strings_successfully_downloaded["POLISH"]="Plik z tłumaczeniem został pomyślnie pobrany"
	language_strings_successfully_downloaded["GERMAN"]="Die Übersetzungsdatei wurde erfolgreich heruntergeladen"
	language_strings_successfully_downloaded["TURKISH"]="Çeviri dosyası başarıyla indirildi"
	language_strings_successfully_downloaded["ARABIC"]="تم تنزيل ملف سلاسل اللغة بنجاح"
	language_strings_successfully_downloaded["CHINESE"]="语言支持文件已成功下载"

	declare -gA language_strings_failed_downloading
	language_strings_failed_downloading["ENGLISH"]="The language string file can't be downloaded. Check your internet connection or download it manually from ${normal_color}${urlgithub}"
	language_strings_failed_downloading["SPANISH"]="No se ha podido descargar el fichero de traducciones. Comprueba tu conexión a internet o descárgalo manualmente de ${normal_color}${urlgithub}"
	language_strings_failed_downloading["FRENCH"]="Impossible de télécharger le fichier traduction. Vérifiez votre connexion à internet ou téléchargez le fichier manuellement ${normal_color}${urlgithub}"
	language_strings_failed_downloading["CATALAN"]="No s'ha pogut descarregar el fitxer de traduccions. Comprova la connexió a internet o descarrega'l manualment de ${normal_color}${urlgithub}"
	language_strings_failed_downloading["PORTUGUESE"]="Não foi possível baixar o arquivos de tradução. Verifique a sua conexão com a internet ou baixe manualmente em ${normal_color}${urlgithub}"
	language_strings_failed_downloading["RUSSIAN"]="Языковой файл не может быть загружен. Проверьте подключение к Интернету или загрузите его вручную с ${normal_color}${urlgithub}"
	language_strings_failed_downloading["GREEK"]="Το αρχείο γλωσσών δεν μπορεί να κατέβει. Ελέγξτε τη σύνδεση σας με το διαδίκτυο ή κατεβάστε το χειροκίνητα ${normal_color}${urlgithub}"
	language_strings_failed_downloading["ITALIAN"]="Impossibile scaricare il file delle traduzioni. Controlla la tua connessione a internet o scaricalo manualmente ${normal_color}${urlgithub}"
	language_strings_failed_downloading["POLISH"]="Nie można pobrać pliku tłumaczenia. Sprawdź połączenie internetowe lub pobierz go ręcznie z ${normal_color}${urlgithub}"
	language_strings_failed_downloading["GERMAN"]="Die Übersetzungsdatei konnte nicht heruntergeladen werden. Überprüfen Sie Ihre Internetverbindung oder laden Sie sie manuell von ${normal_color}${urlgithub} runter"
	language_strings_failed_downloading["TURKISH"]="Çeviri dosyası indirilemedi. İnternet bağlantınızı kontrol edin veya manuel olarak indirin ${normal_color}${urlgithub}"
	language_strings_failed_downloading["ARABIC"]="${normal_color}${urlgithub}${red_color} لا يمكن تنزيل ملف اللغة. تحقق من اتصالك بالإنترنت أو قم بتنزيله يدويًا من"
	language_strings_failed_downloading["CHINESE"]="无法下载语言支持文件。检查您的互联网连接或从 手动下载 ${normal_color}${urlgithub}"

	declare -gA language_strings_first_time
	language_strings_first_time["ENGLISH"]="If you are seeing this message after an automatic update, don't be scared! It's probably because airgeddon has different file structure since version 6.1. It will be automatically fixed"
	language_strings_first_time["SPANISH"]="Si estás viendo este mensaje tras una actualización automática, ¡no te asustes! probablemente es porque a partir de la versión 6.1 la estructura de ficheros de airgeddon ha cambiado. Se reparará automáticamente"
	language_strings_first_time["FRENCH"]="Si vous voyez ce message après une mise à jour automatique ne vous inquiétez pas! A partir de la version 6.1 la structure de fichier d'airgeddon a changé. L'ajustement se fera automatiquement"
	language_strings_first_time["CATALAN"]="Si estàs veient aquest missatge després d'una actualització automàtica, no t'espantis! probablement és perquè a partir de la versió 6.1 l'estructura de fitxers de airgeddon ha canviat. Es repararà automàticament"
	language_strings_first_time["PORTUGUESE"]="Se você está vendo esta mensagem depois de uma atualização automática, não tenha medo! A partir da versão 6.1 da estrutura de arquivos do airgeddon mudou. Isso será corrigido automaticamente"
	language_strings_first_time["RUSSIAN"]="Если вы видите это сообщение после автоматического обновления, не переживайте! Вероятно, это объясняется тем, что, начиная с версии 6.1, airgeddon имеет другую структуру файлов. Проблема будет разрешена автоматически"
	language_strings_first_time["GREEK"]="Εάν βλέπετε αυτό το μήνυμα μετά από κάποια αυτόματη ενημέρωση, μην τρομάξετε! Πιθανόν είναι λόγω της διαφορετικής δομής του airgeddon μετά από την έκδοση 6.1. Θα επιδιορθωθεί αυτόματα"
	language_strings_first_time["ITALIAN"]="Se stai vedendo questo messaggio dopo un aggiornamento automatico, niente panico! probabilmente è perché a partire dalla versione 6.1 é cambiata la struttura dei file di airgeddon. Sarà riparato automaticamente"
	language_strings_first_time["POLISH"]="Jeśli widzisz tę wiadomość po automatycznej aktualizacji, nie obawiaj się! To prawdopodobnie dlatego, że w wersji 6.1 zmieniła się struktura plików airgeddon. Naprawi się automatycznie"
	language_strings_first_time["GERMAN"]="Wenn Sie diese Nachricht nach einem automatischen Update sehen, haben Sie keine Angst! Das liegt vermutlich daran, dass ab Version 6.1 die Dateistruktur von airgeddon geändert wurde. Es wird automatisch repariert"
	language_strings_first_time["TURKISH"]="Otomatik bir güncellemeden sonra bu mesajı görüyorsanız, korkmayın! muhtemelen 6.1 sürümünden itibaren airgeddon dosya yapısı değişmiştir. Otomatik olarak tamir edilecektir"
	language_strings_first_time["ARABIC"]="إذا كنت ترى هذه الرسالة بعد التحديث التلقائي ، فلا تخف! ربما يرجع السبب في ذلك إلى أن airgeddon له بنية ملفات مختلفة منذ الإصدار 6.1. سيتم إصلاحه تلقائيًا "
	language_strings_first_time["CHINESE"]="如果您在自动更新后看到此消息，请不要害怕！这可能是因为 airgeddon 从 6.1 版本开始有不同的文件结构。会自动修复"

	declare -gA language_strings_exiting
	language_strings_exiting["ENGLISH"]="Exiting airgeddon script v${airgeddon_version} - See you soon! :)"
	language_strings_exiting["SPANISH"]="Saliendo de airgeddon script v${airgeddon_version} - Nos vemos pronto! :)"
	language_strings_exiting["FRENCH"]="Fermeture du script airgeddon v${airgeddon_version} - A bientôt! :)"
	language_strings_exiting["CATALAN"]="Sortint de airgeddon script v${airgeddon_version} - Ens veiem aviat! :)"
	language_strings_exiting["PORTUGUESE"]="Saindo do script airgeddon v${airgeddon_version} - Até breve! :)"
	language_strings_exiting["RUSSIAN"]="Выход из скрипта airgeddon v${airgeddon_version} - До встречи! :)"
	language_strings_exiting["GREEK"]="Κλείσιμο του airgeddon v${airgeddon_version} - Αντίο :)"
	language_strings_exiting["ITALIAN"]="Uscendo dallo script airgeddon v${airgeddon_version} - A presto! :)"
	language_strings_exiting["POLISH"]="Wyjście z skryptu airgeddon v${airgeddon_version} - Do zobaczenia wkrótce! :)"
	language_strings_exiting["GERMAN"]="Sie verlassen airgeddon v${airgeddon_version} - Bis bald! :)"
	language_strings_exiting["TURKISH"]="airgeddon yazılımından çıkış yapılıyor v${airgeddon_version} - Yakında görüşürüz! :)"
	language_strings_exiting["ARABIC"]="الخروج من البرنامج airgeddon v${airgeddon_version}- نراكم قريبًا! :)"
	language_strings_exiting["CHINESE"]="退出 airgeddon 脚本 v${airgeddon_version} - 待会见！ :)"

	declare -gA language_strings_key_to_continue
	language_strings_key_to_continue["ENGLISH"]="Press [Enter] key to continue..."
	language_strings_key_to_continue["SPANISH"]="Pulsa la tecla [Enter] para continuar..."
	language_strings_key_to_continue["FRENCH"]="Pressez [Enter] pour continuer..."
	language_strings_key_to_continue["CATALAN"]="Prem la tecla [Enter] per continuar..."
	language_strings_key_to_continue["PORTUGUESE"]="Pressione a tecla [Enter] para continuar..."
	language_strings_key_to_continue["RUSSIAN"]="Нажмите клавишу [Enter] для продолжения..."
	language_strings_key_to_continue["GREEK"]="Πατήστε το κουμπί [Enter] για να συνεχίσετε..."
	language_strings_key_to_continue["ITALIAN"]="Premere il tasto [Enter] per continuare..."
	language_strings_key_to_continue["POLISH"]="Naciśnij klawisz [Enter] aby kontynuować..."
	language_strings_key_to_continue["GERMAN"]="Drücken Sie die [Enter]-Taste um fortzufahren..."
	language_strings_key_to_continue["TURKISH"]="Devam etmek için [Enter] tuşuna basın..."
	language_strings_key_to_continue["ARABIC"]="اضغط على مفتاح [Enter] للمتابعة ..."
	language_strings_key_to_continue["CHINESE"]="按 [Enter] 键继续..."
}
function get_current_permanent_language() {

	debug_print

	current_permanent_language=$(grep "language=" "${scriptfolder}${scriptname}" | grep -v "auto_change_language" | head -n 1 | awk -F "=" '{print $2}')
	current_permanent_language=$(echo "${current_permanent_language}" | sed -e 's/^"//;s/"$//')
}
function set_permanent_language() {

	debug_print

	sed -ri "s:^([l]anguage)=\"[a-zA-Z]+\":\1=\"${language}\":" "${scriptfolder}${scriptname}" 2> /dev/null
	if ! grep -E "^[l]anguage=\"${language}\"" "${scriptfolder}${scriptname}" > /dev/null; then
		return 1
	fi
	return 0
}
function debug_print() {

	if "${AIRGEDDON_DEBUG_MODE:-true}"; then

		declare excluded_functions=(
							"airmon_fix"
							"ask_yesno"
							"check_pending_of_translation"
							"clean_env_vars"
							"contains_element"
							"create_instance_orchestrator_file"
							"create_rcfile"
							"echo_blue"
							"echo_brown"
							"echo_cyan"
							"echo_green"
							"echo_green_title"
							"echo_pink"
							"echo_red"
							"echo_red_slim"
							"echo_white"
							"echo_yellow"
							"env_vars_initialization"
							"env_vars_values_validation"
							"fix_autocomplete_chars"
							"flying_saucer"
							"generate_dynamic_line"
							"initialize_colors"
							"initialize_instance_settings"
							"initialize_script_settings"
							"instance_setter"
							"interrupt_checkpoint"
							"language_strings"
							"last_echo"
							"physical_interface_finder"
							"print_hint"
							"print_large_separator"
							"print_simple_separator"
							"read_yesno"
							"register_instance_pid"
							"remove_warnings"
							"set_absolute_path"
							"set_script_paths"
							"special_text_missed_optional_tool"
							"store_array"
							"under_construction_message"
						)

		if (IFS=$'\n'; echo "${excluded_functions[*]}") | grep -qFx "${FUNCNAME[1]}"; then
			return 1
		fi

		echo "Line:${BASH_LINENO[1]}" "${FUNCNAME[1]}"
	fi

	return 0
}
function interrupt_checkpoint() {

	debug_print

	if [ -z "${last_buffered_type1}" ]; then
		last_buffered_message1=${1}
		last_buffered_message2=${1}
		last_buffered_type1=${2}
		last_buffered_type2=${2}
	else
		if [[ "${1}" -ne "${resume_message}" ]] 2> /dev/null && [[ "${1}" != "${resume_message}" ]]; then
			last_buffered_message2=${last_buffered_message1}
			last_buffered_message1=${1}
			last_buffered_type2=${last_buffered_type1}
			last_buffered_type1=${2}
		fi
	fi
}
function generate_dynamic_line() {

	debug_print

	local type=${2}
	if [ "${type}" = "title" ]; then
		if [[ "${FUNCNAME[2]}" = "main_menu" ]] || [[ "${FUNCNAME[2]}" = "main_menu_override" ]]; then
			ncharstitle=91
		else
			ncharstitle=78
		fi
		titlechar="*"
	elif [ "${type}" = "separator" ]; then
		ncharstitle=58
		titlechar="-"
	fi

	titletext=${1}
	titlelength=${#titletext}
	finaltitle=""

	for ((i=0; i < (ncharstitle/2 - titlelength+(titlelength/2)); i++)); do
		finaltitle="${finaltitle}${titlechar}"
	done

	if [ "${type}" = "title" ]; then
		finaltitle="${finaltitle} ${titletext} "
	elif [ "${type}" = "separator" ]; then
		finaltitle="${finaltitle} (${titletext}) "
	fi

	for ((i=0; i < (ncharstitle/2 - titlelength+(titlelength/2)); i++)); do
		finaltitle="${finaltitle}${titlechar}"
	done

	if [ $((titlelength % 2)) -gt 0 ]; then
		finaltitle+="${titlechar}"
	fi

	if [ "${type}" = "title" ]; then
		echo_green_title "${finaltitle}"
	elif [ "${type}" = "separator" ]; then
		echo_blue "${finaltitle}"
	fi
}
function check_to_set_managed() {

	debug_print

	check_interface_mode "${1}"
	case "${ifacemode}" in
		"Managed")
			echo
			language_strings "${language}" 0 "red"
			language_strings "${language}" 115 "read"
			return 1
		;;
		"(Non wifi adapter)")
			echo
			language_strings "${language}" 1 "red"
			language_strings "${language}" 115 "read"
			return 1
		;;
	esac
	return 0
}
function check_to_set_monitor() {

	debug_print

	check_interface_mode "${1}"
	case "${ifacemode}" in
		"Monitor")
			echo
			language_strings "${language}" 10 "red"
			language_strings "${language}" 115 "read"
			return 1
		;;
		"(Non wifi adapter)")
			echo
			language_strings "${language}" 13 "red"
			language_strings "${language}" 115 "read"
			return 1
		;;
	esac
	return 0
}
function check_monitor_enabled() {

	debug_print

	mode=$(iw "${1}" info 2> /dev/null | grep type | awk '{print $2}')

	current_iface_on_messages="${1}"

	if [[ ${mode^} != "Monitor" ]]; then
		return 1
	fi
	return 0
}
function check_interface_wifi() {

	debug_print

	iw "${1}" info > /dev/null 2>&1
	return $?
}
function renew_ifaces_and_macs_list() {

	debug_print

	readarray -t IFACES_AND_MACS < <(ip link | grep -E "^[0-9]+" | cut -d ':' -f 2 | awk '{print $1}' | grep -E "^lo$" -v | grep "${interface}" -v)
	declare -gA ifaces_and_macs
	for iface_name in "${IFACES_AND_MACS[@]}"; do
		if [ -f "/sys/class/net/${iface_name}/address" ]; then
			mac_item=$(cat "/sys/class/net/${iface_name}/address" 2> /dev/null)
			if [ -n "${mac_item}" ]; then
				ifaces_and_macs[${iface_name}]=${mac_item}
			fi
		fi
	done

	declare -gA ifaces_and_macs_switched
	for iface_name in "${!ifaces_and_macs[@]}"; do
		ifaces_and_macs_switched[${ifaces_and_macs[${iface_name}]}]=${iface_name}
	done
}
function check_interface_coherence() {

	debug_print

	renew_ifaces_and_macs_list
	interface_auto_change=0

	interface_found=0
	for iface_name in "${!ifaces_and_macs[@]}"; do
		if [ "${interface}" = "${iface_name}" ]; then
			interface_found=1
			interface_mac=${ifaces_and_macs[${iface_name}]}
			break
		fi
	done

	if [ "${interface_found}" -eq 0 ]; then
		if [ -n "${interface_mac}" ]; then
			for iface_mac in "${ifaces_and_macs[@]}"; do
				iface_mac_tmp=${iface_mac:0:15}
				interface_mac_tmp=${interface_mac:0:15}
				if [ "${iface_mac_tmp}" = "${interface_mac_tmp}" ]; then
					interface=${ifaces_and_macs_switched[${iface_mac}]}
					phy_interface=$(physical_interface_finder "${interface}")
					check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
					interface_auto_change=1
					break
				fi
			done
		fi
	fi

	return ${interface_auto_change}
}
function check_airmon_compatibility() {

	debug_print

	if [ "${1}" = "interface" ]; then
		set_chipset "${interface}" "read_only"

		if iw phy "${phy_interface}" info 2> /dev/null | grep -iq 'interface combinations are not supported'; then
			interface_airmon_compatible=0
		else
			interface_airmon_compatible=1
		fi
	else
		set_chipset "${secondary_wifi_interface}" "read_only"

		if ! iw dev "${secondary_wifi_interface}" set bitrates legacy-2.4 1 > /dev/null 2>&1; then
			secondary_interface_airmon_compatible=0
		else
			secondary_interface_airmon_compatible=1
		fi
	fi
}
function add_contributing_footer_to_file() {

	debug_print

	{
	echo ""
	echo "---------------"
	echo ""
	echo "${footer_texts[${language},0]}"
	} >> "${1}"
}
function set_wps_mac_parameters() {

	debug_print

	six_wpsbssid_first_digits=${wps_bssid:0:8}
	six_wpsbssid_first_digits_clean=${six_wpsbssid_first_digits//:}
	six_wpsbssid_last_digits=${wps_bssid: -8}
	six_wpsbssid_last_digits_clean=${six_wpsbssid_last_digits//:}
	four_wpsbssid_last_digits=${wps_bssid: -5}
	four_wpsbssid_last_digits_clean=${four_wpsbssid_last_digits//:}
}
function check_json_option_on_wash() {

	debug_print

	wash -h 2>&1 | grep "\-j" > /dev/null
	return $?
}
function check_dual_scan_on_wash() {

	debug_print

	wash -h 2>&1 | grep "2ghz" > /dev/null
	return $?
}
function wash_json_scan() {

	debug_print

	rm -rf "${tmpdir}wps_json_data.txt" > /dev/null 2>&1
	rm -rf "${tmpdir}wps_fifo" > /dev/null 2>&1

	mkfifo "${tmpdir}wps_fifo"

	wash_band_modifier=""
	if [ "${wps_channel}" -gt 14 ]; then
		if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
			echo
			language_strings "${language}" 515 "red"
			language_strings "${language}" 115 "read"
			return 1
		else
			wash_band_modifier="-5"
		fi
	fi

	timeout -s SIGTERM 240 wash -i "${interface}" --scan -n 100 -j "${wash_band_modifier}" 2> /dev/null > "${tmpdir}wps_fifo" &
	wash_json_pid=$!
	tee "${tmpdir}wps_json_data.txt"< <(cat < "${tmpdir}wps_fifo") > /dev/null 2>&1 &

	while true; do
		sleep 5
		wash_json_capture_alive=$(ps uax | awk '{print $2}' | grep -E "^${wash_json_pid}$" 2> /dev/null)
		if [ -z "${wash_json_capture_alive}" ]; then
			break
		fi

		if grep "${1}" "${tmpdir}wps_json_data.txt" > /dev/null; then
			serial=$(grep "${1}" "${tmpdir}wps_json_data.txt" | awk -F '"wps_serial" : "' '{print $2}' | awk -F '"' '{print $1}' | sed 's/.*\(....\)/\1/' 2> /dev/null)
			kill "${wash_json_capture_alive}" &> /dev/null
			wait "${wash_json_capture_alive}" 2> /dev/null
			break
		fi
	done

	return 0
}
function calculate_computepin_algorithm_step1() {

	debug_print

	hex_to_dec=$(printf '%d\n' 0x"${six_wpsbssid_last_digits_clean}") 2> /dev/null
	computepin_pin=$((hex_to_dec % 10000000))
}
function calculate_computepin_algorithm_step2() {

	debug_print

	computepin_pin=$(printf '%08d\n' $((10#${computepin_pin} * 10 + checksum_digit)))
}
function calculate_easybox_algorithm() {

	debug_print

	hex_to_dec=($(printf "%04d" "0x${four_wpsbssid_last_digits_clean}" | sed 's/.*\(....\)/\1/;s/./& /g'))
	[[ ${four_wpsbssid_last_digits_clean} =~ ${four_wpsbssid_last_digits_clean//?/(.)} ]] && hexi=($(printf '%s\n' "${BASH_REMATCH[*]:1}"))

	c1=$(printf "%d + %d + %d + %d" "${hex_to_dec[0]}" "${hex_to_dec[1]}" "0x${hexi[2]}" "0x${hexi[3]}")
	c2=$(printf "%d + %d + %d + %d" "0x${hexi[0]}" "0x${hexi[1]}" "${hex_to_dec[2]}" "${hex_to_dec[3]}")

	K1=$((c1 % 16))
	K2=$((c2 % 16))
	X1=$((K1 ^ hex_to_dec[3]))
	X2=$((K1 ^ hex_to_dec[2]))
	X3=$((K1 ^ hex_to_dec[1]))
	Y1=$((K2 ^ 0x${hexi[1]}))
	Y2=$((K2 ^ 0x${hexi[2]}))
	Z1=$((0x${hexi[2]} ^ hex_to_dec[3]))
	Z2=$((0x${hexi[3]} ^ hex_to_dec[2]))

	easybox_pin=$(printf '%08d\n' "$((0x$X1$X2$Y1$Y2$Z1$Z2$X3))" | awk '{for(i=length; i!=0; i--) x=x substr($0, i, 1);} END {print x}' | cut -c -7 | awk '{for(i=length; i!=0; i--) x=x substr($0, i, 1);} END {print x}')
}
function calculate_arcadyan_algorithm() {

	debug_print

	local wan=""
	if [ "${four_wpsbssid_last_digits_clean}" = "0000" ]; then
		wan="fffe"
	elif [ "${four_wpsbssid_last_digits_clean}" = "0001" ]; then
		wan="ffff"
	else
		wan=$(printf "%04x" $((0x${four_wpsbssid_last_digits_clean} - 2)))
	fi

	K1=$(printf "%X\n" $(($((0x${serial:0:1} + 0x${serial:1:1} + 0x${wan:2:1} + 0x${wan:3:1})) % 16)))
	K2=$(printf "%X\n" $(($((0x${serial:2:1} + 0x${serial:3:1} + 0x${wan:0:1} + 0x${wan:1:1})) % 16)))
	D1=$(printf "%X\n" $((0x$K1 ^ 0x${serial:3:1})))
	D2=$(printf "%X\n" $((0x$K1 ^ 0x${serial:2:1})))
	D3=$(printf "%X\n" $((0x$K2 ^ 0x${wan:1:1})))
	D4=$(printf "%X\n" $((0x$K2 ^ 0x${wan:2:1})))
	D5=$(printf "%X\n" $((0x${serial:3:1} ^ 0x${wan:2:1})))
	D6=$(printf "%X\n" $((0x${serial:2:1} ^ 0x${wan:3:1})))
	D7=$(printf "%X\n" $((0x$K1 ^ 0x${serial:1:1})))

	arcadyan_pin=$(printf '%07d\n' $(($(printf '%d\n' "0x$D1$D2$D3$D4$D5$D6$D7") % 10000000)))
}
function pin_checksum_rule() {

	debug_print

	current_calculated_pin=$((10#${1} * 10))

	accum=0
	accum=$((accum + 3 * (current_calculated_pin/10000000 % 10)))
	accum=$((accum + current_calculated_pin/1000000 % 10))
	accum=$((accum + 3 * (current_calculated_pin/100000 % 10)))
	accum=$((accum + current_calculated_pin/10000 % 10))
	accum=$((accum + 3 * (current_calculated_pin/1000 % 10)))
	accum=$((accum + current_calculated_pin/100 % 10))
	accum=$((accum + 3 * (current_calculated_pin/10 % 10)))

	control_digit=$((accum % 10))
	checksum_digit=$((10 - control_digit))
	checksum_digit=$((checksum_digit % 10))
}
function check_and_set_common_algorithms() {

	debug_print

	echo
	language_strings "${language}" 388 "blue"
	declare -g calculated_pins=("${wps_default_generic_pin}")

	if ! check_if_type_exists_in_wps_data_array "${wps_bssid}" "ComputePIN"; then
		calculate_computepin_algorithm_step1
		pin_checksum_rule "${computepin_pin}"
		calculate_computepin_algorithm_step2
		calculated_pins+=("${computepin_pin}")
		fill_wps_data_array "${wps_bssid}" "ComputePIN" "${computepin_pin}"
	else
		calculated_pins+=("${wps_data_array["${wps_bssid}",'ComputePIN']}")
	fi

	if ! check_if_type_exists_in_wps_data_array "${wps_bssid}" "EasyBox"; then
		calculate_easybox_algorithm
		pin_checksum_rule "${easybox_pin}"
		easybox_pin=$(printf '%08d\n' $((current_calculated_pin + checksum_digit)))
		calculated_pins+=("${easybox_pin}")
		fill_wps_data_array "${wps_bssid}" "EasyBox" "${easybox_pin}"
	else
		calculated_pins+=("${wps_data_array["${wps_bssid}",'EasyBox']}")
	fi

	if ! check_if_type_exists_in_wps_data_array "${wps_bssid}" "Arcadyan"; then

		able_to_check_json_option_on_wash=0
		if [ "${wps_attack}" = "pindb_bully" ]; then
			if hash wash 2> /dev/null; then
				able_to_check_json_option_on_wash=1
			else
				echo
				language_strings "${language}" 492 "yellow"
				echo
			fi
		elif [ "${wps_attack}" = "pindb_reaver" ]; then
			able_to_check_json_option_on_wash=1
		fi

		if [ "${able_to_check_json_option_on_wash}" -eq 1 ]; then
			if check_json_option_on_wash; then
				ask_yesno 485 "no"
				if [ "${yesno}" = "y" ]; then
					echo
					language_strings "${language}" 489 "blue"

					serial=""
					if wash_json_scan "${wps_bssid}"; then
						if [ -n "${serial}" ]; then
							if [[ "${serial}" =~ ^[0-9]{4}$ ]]; then
								calculate_arcadyan_algorithm
								pin_checksum_rule "${arcadyan_pin}"
								arcadyan_pin="${arcadyan_pin}${checksum_digit}"
								calculated_pins=("${arcadyan_pin}" "${calculated_pins[@]}")
								fill_wps_data_array "${wps_bssid}" "Arcadyan" "${arcadyan_pin}"
								echo
								language_strings "${language}" 487 "yellow"
							else
								echo
								language_strings "${language}" 491 "yellow"
							fi
							echo
						else
							echo
							language_strings "${language}" 488 "yellow"
							echo
						fi
					fi
				fi
			else
				echo
				language_strings "${language}" 486 "yellow"
			fi
		fi
	else
		echo
		calculated_pins=("${wps_data_array["${wps_bssid}",'Arcadyan']}" "${calculated_pins[@]}")
		language_strings "${language}" 493 "yellow"
		echo
	fi

	if integrate_algorithms_pins; then
		language_strings "${language}" 389 "yellow"
	fi
}
function integrate_algorithms_pins() {

	debug_print

	some_calculated_pin_included=0
	for ((idx=${#calculated_pins[@]}-1; idx>=0; idx--)) ; do
		this_pin_already_included=0
		for item in "${pins_found[@]}"; do
			if [ "${item}" = "${calculated_pins[idx]}" ]; then
				this_pin_already_included=1
				break
			fi
		done

		if [ "${this_pin_already_included}" -eq 0 ]; then
			pins_found=("${calculated_pins[idx]}" "${pins_found[@]}")
			counter_pins_found=$((counter_pins_found + 1))
			some_calculated_pin_included=1
		fi
	done

	if [ "${some_calculated_pin_included}" -eq 1 ]; then
		return 0
	fi

	return 1
}
function search_in_pin_database() {

	debug_print

	bssid_found_in_db=0
	counter_pins_found=0
	declare -g pins_found=()
	for item in "${!PINDB[@]}"; do
		if [ "${item}" = "${six_wpsbssid_first_digits_clean}" ]; then
			bssid_found_in_db=1
			arrpins=("${PINDB[${item//[[:space:]]/ }]}")
			pins_found+=("${arrpins[0]}")
			counter_pins_found=$(echo "${pins_found[@]}" | wc -w)
			fill_wps_data_array "${wps_bssid}" "Database" "${pins_found}"
		fi
	done
}
function check_busy_ports() {

	debug_print

	IFS=' ' read -r -a tcp_ports <<< "${ports_needed["tcp"]}"
	IFS=' ' read -r -a udp_ports <<< "${ports_needed["udp"]}"

	if [[ -n "${tcp_ports[*]}" ]] && [[ "${#tcp_ports[@]}" -ge 1 ]]; then
		port_type="tcp"
		for tcp_port in "${tcp_ports[@]}"; do
			if ! check_tcp_udp_port "${tcp_port}" "${port_type}" "${interface}"; then
				busy_port="${tcp_port}"
				find_process_name_by_port "${tcp_port}" "${port_type}"
				echo
				language_strings "${language}" 698 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		done
	fi

	if [[ -n "${udp_ports[*]}" ]] && [[ "${#udp_ports[@]}" -ge 1 ]]; then
		port_type="udp"
		for udp_port in "${udp_ports[@]}"; do
			if ! check_tcp_udp_port "${udp_port}" "${port_type}" "${interface}"; then
				busy_port="${udp_port}"
				find_process_name_by_port "${udp_port}" "${port_type}"
				echo
				language_strings "${language}" 698 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		done
	fi

	return 0
}
function check_tcp_udp_port() {

	debug_print

	local port
	local port_type
	port=$(printf "%04x" "${1}")
	port_type="${2}"

	local network_interface
	local ip_address
	local hex_ip_address
	network_interface="${3}"
	ip_address=$(ip -4 -o addr show "${network_interface}" 2> /dev/null | awk '{print $4}' | cut -d "/" -f 1)

	if [ -n "${ip_address}" ]; then
		hex_ip_address=$(ip_dec_to_hex "${ip_address}")
	else
		hex_ip_address=""
	fi

	declare -a busy_ports=($(awk -v iplist="${hex_ip_address},00000000" 'BEGIN {split(iplist,a,","); for (i in a) ips[a[i]]} /local_address/ {next} {split($2,a,":"); if (a[1] in ips) ports[a[2] $4]} END {for (port in ports) print port}' "/proc/net/${port_type}" "/proc/net/${port_type}6"))

	for hexport in "${busy_ports[@]}"; do
		if [[ "${port_type}" == "tcp" || "${port_type}" == "tcp6" ]]; then
			if [ "${hexport}" = "${port}0A" ]; then
				return 1
			fi
		else
			if [[ "${hexport}" = "${port}07" ]] && [[ "${port}" != "0043" ]]; then
				return 1
			fi
		fi
	done

	return 0
}
function find_process_name_by_port() {

	debug_print

	local port
	port="${1}"
	local port_type
	port_type="${2}"

	local regexp_part1
	local regexp_part2
	regexp_part1="${port_type}\h.*?[0-9A-Za-z%\*]:${port}"
	regexp_part2='\h.*?\busers:\(\("\K[^"]+(?=")'

	local regexp
	regexp="${regexp_part1}${regexp_part2}"

	if hash ss 2> /dev/null; then
		blocking_process_name=$(ss -tupln | grep -oP "${regexp}")
	else
		blocking_process_name="${unknown_chipsetvar,,}"
	fi
}
function check_vif_support() {

	debug_print

	if iw "${phy_interface}" info | grep "Supported interface modes" -A 8 | grep "AP/VLAN" > /dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}
function check_interface_wifi_longname() {

	debug_print

	wifi_adapter="${1}"
	longname_patterns=("wlx[0-9a-fA-F]{12}")
	for pattern in "${longname_patterns[@]}"; do
		if [[ ${wifi_adapter} =~ $pattern ]]; then
			echo
			language_strings "${language}" 708 "yellow"
			echo
			language_strings "${language}" 709 "yellow"
			language_strings "${language}" 115 "read"
			return 1
		fi
	done

	return 0
}
function physical_interface_finder() {

	debug_print

	local phy_iface
	phy_iface=$(basename "$(readlink "/sys/class/net/${1}/phy80211")" 2> /dev/null)
	echo "${phy_iface}"
}
function check_supported_standards() {

	debug_print

	if iw phy "${1}" info | grep -Eq 'HT20/HT40' 2> /dev/null; then
		standard_80211n=1
	else
		standard_80211n=0
	fi

	if iw phy "${1}" info | grep -Eq 'VHT' 2> /dev/null; then
		standard_80211ac=1
	else
		standard_80211ac=0
	fi

	if iw phy "${1}" info | grep -Eq 'HE40/HE80' 2> /dev/null; then
		standard_80211ax=1
	else
		standard_80211ax=0
	fi

	if iw phy "${1}" info | grep -Eq 'EHT bw=20 MHz' 2> /dev/null; then
		standard_80211be=1
	else
		standard_80211be=0
	fi
}
function check_interface_supported_bands() {

	debug_print

	get_5ghz_band_info_from_phy_interface "${1}"
	case "$?" in
		"0")
			interfaces_band_info["${2},5Ghz_allowed"]=1
			interfaces_band_info["${2},text"]="${band_24ghz}, ${band_5ghz}"
		;;
		"1")
			interfaces_band_info["${2},5Ghz_allowed"]=0
			interfaces_band_info["${2},text"]="${band_24ghz}"
		;;
		"2")
			interfaces_band_info["${2},5Ghz_allowed"]=0
			interfaces_band_info["${2},text"]="${band_24ghz}, ${band_5ghz} (${red_color}${disabled_text[${language}]}${pink_color})"
		;;
	esac
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
function region_check() {

	debug_print

	country_code="$(iw reg get | awk 'FNR == 2 {print $2}' | cut -f 1 -d ":" 2> /dev/null)"
	[[ ! ${country_code} =~ ^[A-Z]{2}$|^99$ ]] && country_code="00"
}
function restore_et_interface() {

	debug_print

	echo
	language_strings "${language}" 299 "blue"

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
			desired_interface_name=""
			[[ ${new_interface} =~ ^You[[:space:]]already[[:space:]]have[[:space:]]a[[:space:]]([A-Za-z0-9]+)[[:space:]]device ]] && desired_interface_name="${BASH_REMATCH[1]}"
			if [ -n "${desired_interface_name}" ]; then
				echo
				language_strings "${language}" 435 "red"
				language_strings "${language}" 115 "read"
				return
			fi

			ifacemode="Monitor"

			[[ ${new_interface} =~ \]?([A-Za-z0-9]+)\)?$ ]] && new_interface="${BASH_REMATCH[1]}"
			if [ "${interface}" != "${new_interface}" ]; then
				interface=${new_interface}
				phy_interface=$(physical_interface_finder "${interface}")
				check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
				current_iface_on_messages="${interface}"
			fi
		else
			if set_mode_without_airmon "${interface}" "monitor"; then
				ifacemode="Monitor"
			fi
		fi
	fi

	control_routing_status "end"
}
function restore_wpa3_downgrade_interface() {

	debug_print

	echo
	language_strings "${language}" 299 "blue"

	disable_rfkill

	mac_spoofing_desired=0

	iw dev "${iface_monitor_downgrade_deauth}" del > /dev/null 2>&1

	if [ "${downgrade_initial_state}" = "Managed" ]; then
		set_mode_without_airmon "${interface}" "managed"
		ifacemode="Managed"
	else
		if [ "${interface_airmon_compatible}" -eq 1 ]; then
			new_interface=$(${airmon} start "${interface}" 2> /dev/null | grep monitor)
			desired_interface_name=""
			[[ ${new_interface} =~ ^You[[:space:]]already[[:space:]]have[[:space:]]a[[:space:]]([A-Za-z0-9]+)[[:space:]]device ]] && desired_interface_name="${BASH_REMATCH[1]}"
			if [ -n "${desired_interface_name}" ]; then
				echo
				language_strings "${language}" 435 "red"
				language_strings "${language}" 115 "read"
				return
			fi

			ifacemode="Monitor"

			[[ ${new_interface} =~ \]?([A-Za-z0-9]+)\)?$ ]] && new_interface="${BASH_REMATCH[1]}"
			if [ "${interface}" != "${new_interface}" ]; then
				interface=${new_interface}
				phy_interface=$(physical_interface_finder "${interface}")
				check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
				current_iface_on_messages="${interface}"
			fi
		else
			if set_mode_without_airmon "${interface}" "monitor"; then
				ifacemode="Monitor"
			fi
		fi
	fi
}
function check_interface_mode() {

	debug_print

	current_iface_on_messages="${1}"
	if ! check_interface_wifi "${1}"; then
		ifacemode="(Non wifi adapter)"
		return 0
	fi

	modemanaged=$(iw "${1}" info 2> /dev/null | grep type | awk '{print $2}')

	if [[ ${modemanaged^} = "Managed" ]]; then
		ifacemode="Managed"
		return 0
	fi

	modemonitor=$(iw "${1}" info 2> /dev/null | grep type | awk '{print $2}')

	if [[ ${modemonitor^} = "Monitor" ]]; then
		ifacemode="Monitor"
		return 0
	fi

	language_strings "${language}" 23 "red"
	language_strings "${language}" 115 "read"
	exit_code=1
	exit_script_option
}
function set_chipset() {

	debug_print

	chipset=""
	sedrule1="s/^[0-9a-f]\{1,4\} \|^ //Ig"
	sedrule2="s/ Network Connection.*//Ig"
	sedrule3="s/ Wireless.*//Ig"
	sedrule4="s/ PCI Express.*//Ig"
	sedrule5="s/ \(Gigabit\|Fast\) Ethernet.*//Ig"
	sedrule6="s/ \[.*//"
	sedrule7="s/ (.*//"
	sedrule8="s|802\.11a/b/g/n/ac.*||Ig"

	sedruleall="${sedrule1};${sedrule2};${sedrule3};${sedrule4};${sedrule5};${sedrule6};${sedrule7};${sedrule8}"

	if [ -f "/sys/class/net/${1}/device/modalias" ]; then
		bus_type=$(cut -f 1 -d ":" < "/sys/class/net/${1}/device/modalias")

		if [ "${bus_type}" = "usb" ]; then
			vendor_and_device=$(cut -b 6-14 < "/sys/class/net/${1}/device/modalias" | sed 's/^.//;s/p/:/')
			if hash lsusb 2> /dev/null; then
				if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
					requested_chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				else
					chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				fi
			fi

		elif [[ "${bus_type}" =~ pci|ssb|bcma|pcmcia ]]; then
			if [[ -f /sys/class/net/${1}/device/vendor ]] && [[ -f /sys/class/net/${1}/device/device ]]; then
		vendor_and_device=$(sed -e 's/0x//' "/sys/class/net/${1}/device/vendor"):$(sed -e 's/0x//' "/sys/class/net/${1}/device/device")
				if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
					requested_chipset=$(lspci -d "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				else
					chipset=$(lspci -d "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				fi
			else
				if hash ethtool 2> /dev/null; then
					ethtool_output=$(ethtool -i "${1}" 2>&1)
					vendor_and_device=$(printf "%s" "${ethtool_output}" | grep "bus-info" | cut -f 3 -d ":" | sed 's/^ //')
					if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
						requested_chipset=$(lspci | grep "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
					else
						chipset=$(lspci | grep "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
					fi
				fi
			fi
		fi
	elif [[ -f /sys/class/net/${1}/device/idVendor ]] && [[ -f /sys/class/net/${1}/device/idProduct ]]; then
		vendor_and_device=$(cat "/sys/class/net/${1}/device/idVendor"):$(cat "/sys/class/net/${1}/device/idProduct")
		if hash lsusb 2> /dev/null; then
			if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
				requested_chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
			else
				chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
			fi
		fi
	fi
}
function mdk_version_toggle() {

	debug_print

	if [ "${AIRGEDDON_MDK_VERSION}" = "mdk3" ]; then
		sed -ri "s:(AIRGEDDON_MDK_VERSION)=(mdk3):\1=mdk4:" "${rc_path}" 2> /dev/null
		AIRGEDDON_MDK_VERSION="mdk4"
	else
		sed -ri "s:(AIRGEDDON_MDK_VERSION)=(mdk4):\1=mdk3:" "${rc_path}" 2> /dev/null
		AIRGEDDON_MDK_VERSION="mdk3"
	fi

	set_mdk_version
}
function set_mdk_version() {

	debug_print

	if [ "${AIRGEDDON_MDK_VERSION}" = "mdk3" ]; then
		if ! hash mdk3 2> /dev/null; then
			echo
			language_strings "${language}" 636 "red"
			exit_code=1
			exit_script_option
		else
			mdk_command="mdk3"
		fi
	else
		mdk_command="mdk4"
	fi
}
function clean_env_vars() {

	debug_print

	unset AIRGEDDON_AUTO_UPDATE AIRGEDDON_SKIP_INTRO AIRGEDDON_BASIC_COLORS AIRGEDDON_EXTENDED_COLORS AIRGEDDON_AUTO_CHANGE_LANGUAGE AIRGEDDON_SILENT_CHECKS AIRGEDDON_PRINT_HINTS AIRGEDDON_5GHZ_ENABLED AIRGEDDON_FORCE_IPTABLES AIRGEDDON_FORCE_NETWORK_MANAGER_KILLING AIRGEDDON_MDK_VERSION AIRGEDDON_PLUGINS_ENABLED AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING AIRGEDDON_EVIL_TWIN_SOUNDS AIRGEDDON_DEVELOPMENT_MODE AIRGEDDON_DEBUG_MODE AIRGEDDON_WINDOWS_HANDLING
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
		rm -rf "${tmpdir}identities_certificates"* > /dev/null 2>&1
		rm -rf "${tmpdir}decloak"* > /dev/null 2>&1
		rm -rf "${tmpdir}pmkid"* > /dev/null 2>&1
		rm -rf "${tmpdir}nws"* > /dev/null 2>&1
		rm -rf "${tmpdir}clts"* > /dev/null 2>&1
		rm -rf "${tmpdir}wnws.txt" > /dev/null 2>&1
		rm -rf "${tmpdir}hctmp"* > /dev/null 2>&1
		rm -rf "${tmpdir}jtrtmp"* > /dev/null 2>&1
		rm -rf "${tmpdir}${aircrack_pot_tmp}" > /dev/null 2>&1
		rm -rf "${tmpdir}${et_processesfile}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_mana_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_mana_out}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_mana_log}" > /dev/null 2>&1
		rm -rf "${tmpdir}${mana_cap_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${mana_tmp_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_wpe_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${hostapd_wpe_log}" > /dev/null 2>&1
		rm -rf "${scriptfolder}${hostapd_wpe_default_log}" > /dev/null 2>&1
		rm -rf "${tmpdir}${dhcpd_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${dnsmasq_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${control_et_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${control_enterprise_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}parsed_file" > /dev/null 2>&1
		rm -rf "${tmpdir}${ettercap_file}"* > /dev/null 2>&1
		rm -rf "${tmpdir}${bettercap_file}"* > /dev/null 2>&1
		rm -rf "${tmpdir}${bettercap_config_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${bettercap_hook_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${beef_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${webserver_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${webserver_log}" > /dev/null 2>&1
		rm -rf "${tmpdir}${webdir}" > /dev/null 2>&1
		rm -rf "${tmpdir}${certsdir}" > /dev/null 2>&1
		rm -rf "${tmpdir}${enterprisedir}" > /dev/null 2>&1
		rm -rf "${tmpdir}${asleap_pot_tmp}" > /dev/null 2>&1
		rm -rf "${tmpdir}wps"* > /dev/null 2>&1
		rm -rf "${tmpdir}${wps_attack_script_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${wps_out_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${wep_attack_file}" > /dev/null 2>&1
		rm -rf "${tmpdir}${wep_key_handler}" > /dev/null 2>&1
		rm -rf "${tmpdir}${wep_data}"* > /dev/null 2>&1
		rm -rf "${tmpdir}${wepdir}" > /dev/null 2>&1
		rm -rf "${tmpdir}dos_pm"* > /dev/null 2>&1
		rm -rf "${tmpdir}${channelfile}" > /dev/null 2>&1
		rm -rf "${tmpdir}${wep_besside_log}" > /dev/null 2>&1
		rm -rf "${tmpdir}wep.cap" > /dev/null 2>&1
		rm -rf "${tmpdir}wps.cap" > /dev/null 2>&1
		rm -rf "${tmpdir}besside.log" > /dev/null 2>&1
		rm -rf "${tmpdir}decloak.log" > /dev/null 2>&1
		rm -rf "${tmpdir}agwpa3"* > /dev/null 2>&1
		rm -rf "${tmpdir}cookie_guzzler"* > /dev/null 2>&1
	fi

	if [ "${dhcpd_path_changed}" -eq 1 ]; then
		rm -rf "${dhcp_path}" > /dev/null 2>&1
	fi

	if [ "${beef_found}" -eq 1 ]; then
		rm -rf "${beef_path}${beef_file}" > /dev/null 2>&1
	fi
}
function clean_routing_rules() {

	debug_print

	control_routing_status "end"
	clean_initialize_iptables_nftables "end"

	if is_last_airgeddon_instance && [[ -n "${system_tmpdir}${routing_tmp_file}" ]]; then
		restore_iptables_nftables
		rm -rf "${system_tmpdir}${routing_tmp_file}" > /dev/null 2>&1
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
function restore_iptables_nftables() {

	debug_print

	if [ "${iptables_nftables}" -eq 1 ]; then
		"${iptables_cmd}" -f "${system_tmpdir}${routing_tmp_file}" 2> /dev/null
	else
		"${iptables_cmd}-restore" < "${system_tmpdir}${routing_tmp_file}" 2> /dev/null
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
function store_array() {

	debug_print

	local values=("${@:3}")
	for i in "${!values[@]}"; do
		eval "${1}[\$2|${i}]=\${values[i]}"
	done
}
function print_hint() {

	debug_print

	declare -A hints

	case "${current_menu}" in
		"main_menu")
			store_array hints main_hints "${main_hints[@]}"
			hintlength=${#main_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[main_hints|${randomhint}]}
		;;
		"dos_attacks_menu")
			store_array hints dos_hints "${dos_hints[@]}"
			hintlength=${#dos_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[dos_hints|${randomhint}]}
		;;
		"handshake_pmkid_decloaking_tools_menu")
			store_array hints handshake_pmkid_decloaking_hints "${handshake_pmkid_decloaking_hints[@]}"
			hintlength=${#handshake_pmkid_decloaking_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[handshake_pmkid_decloaking_hints|${randomhint}]}
		;;
		"dos_handshake_decloak_menu")
			store_array hints dos_handshake_decloak_hints "${dos_handshake_decloak_hints[@]}"
			hintlength=${#dos_handshake_decloak_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[dos_handshake_decloak_hints|${randomhint}]}
		;;
		"dos_info_gathering_enterprise_menu")
			store_array hints dos_info_gathering_enterprise_hints "${dos_info_gathering_enterprise_hints[@]}"
			hintlength=${#dos_info_gathering_enterprise_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[dos_info_gathering_enterprise_hints|${randomhint}]}
		;;
		"decrypt_menu")
			store_array hints decrypt_hints "${decrypt_hints[@]}"
			hintlength=${#decrypt_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[decrypt_hints|${randomhint}]}
		;;
		"personal_decrypt_menu")
			store_array hints personal_decrypt_hints "${personal_decrypt_hints[@]}"
			hintlength=${#personal_decrypt_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[personal_decrypt_hints|${randomhint}]}
		;;
		"enterprise_decrypt_menu")
			store_array hints enterprise_decrypt_hints "${enterprise_decrypt_hints[@]}"
			hintlength=${#enterprise_decrypt_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[enterprise_decrypt_hints|${randomhint}]}
		;;
		"select_interface_menu")
			store_array hints select_interface_hints "${select_interface_hints[@]}"
			hintlength=${#select_interface_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[select_interface_hints|${randomhint}]}
		;;
		"language_menu")
			store_array hints language_hints "${language_hints[@]}"
			hintlength=${#language_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[language_hints|${randomhint}]}
		;;
		"option_menu")
			store_array hints option_hints "${option_hints[@]}"
			hintlength=${#option_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[option_hints|${randomhint}]}
		;;
		"evil_twin_attacks_menu")
			store_array hints evil_twin_hints "${evil_twin_hints[@]}"
			hintlength=${#evil_twin_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[evil_twin_hints|${randomhint}]}
		;;
		"wpa3_dos_menu")
			store_array hints wpa3_dos_hints "${wpa3_dos_hints[@]}"
			hintlength=${#wpa3_dos_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[wpa3_dos_hints|${randomhint}]}
		;;
		"et_dos_menu")
			store_array hints evil_twin_dos_hints "${evil_twin_dos_hints[@]}"
			hintlength=${#evil_twin_dos_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[evil_twin_dos_hints|${randomhint}]}
		;;
		"wps_attacks_menu"|"offline_pin_generation_menu")
			store_array hints wps_hints "${wps_hints[@]}"
			hintlength=${#wps_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[wps_hints|${randomhint}]}
		;;
		"wep_attacks_menu")
			store_array hints wep_hints "${wep_hints[@]}"
			hintlength=${#wep_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[wep_hints|${randomhint}]}
		;;
		"beef_pre_menu")
			store_array hints beef_hints "${beef_hints[@]}"
			hintlength=${#beef_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[beef_hints|${randomhint}]}
		;;
		"enterprise_attacks_menu")
			store_array hints enterprise_hints "${enterprise_hints[@]}"
			hintlength=${#enterprise_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[enterprise_hints|${randomhint}]}
		;;
		"wpa3_attacks_menu")
			store_array hints wpa3_hints "${wpa3_hints[@]}"
			hintlength=${#wpa3_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[wpa3_hints|${randomhint}]}
		;;
	esac

	hookable_for_hints

	if "${AIRGEDDON_PRINT_HINTS:-true}"; then
		print_simple_separator
		language_strings "${language}" "${strtoprint}" "hint"
	fi

	print_simple_separator
}
function hookable_for_hints() {

	debug_print

	:
}
function initialize_instance_settings() {

	debug_print

	agpid_to_use="${BASHPID}"

	instance_setter
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		if hash tmux 2> /dev/null; then
			local current_tmux_display_name
			current_tmux_display_name=$(tmux display-message -p '#W')
			if [ "${current_tmux_display_name}" = "${tmux_main_window}" ]; then
				create_instance_orchestrator_file
				register_instance_pid
			fi
		fi
	else
		create_instance_orchestrator_file
		register_instance_pid
	fi
}
function instance_setter() {

	debug_print

	local create_dir=0
	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		if hash tmux 2> /dev/null; then
			local current_tmux_display_name
			current_tmux_display_name=$(tmux display-message -p '#W')
			if [ "${current_tmux_display_name}" = "${tmux_main_window}" ]; then
				create_dir=1
			fi
		fi
	else
		create_dir=1
	fi

	if [ "${create_dir}" -eq 1 ]; then
		local dir_number="1"
		airgeddon_instance_name="ag${dir_number}"
		local airgeddon_instance_dir="${airgeddon_instance_name}/"

		if [ -d "${system_tmpdir}${airgeddon_instance_dir}" ]; then
			while true; do
				dir_number=$((dir_number + 1))
				airgeddon_instance_name="ag${dir_number}"
				airgeddon_instance_dir="${airgeddon_instance_name}/"
				if [ ! -d "${system_tmpdir}${airgeddon_instance_dir}" ]; then
					break
				fi
			done
		fi

		tmpdir="${system_tmpdir}${airgeddon_instance_dir}"
		mkdir -p "${tmpdir}" > /dev/null 2>&1
	fi
}
function create_instance_orchestrator_file() {

	debug_print

	if [ ! -f "${system_tmpdir}${ag_orchestrator_file}" ]; then
		touch "${system_tmpdir}${ag_orchestrator_file}" > /dev/null 2>&1
	else
		local airgeddon_pid_alive=0
		local agpid=""

		readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat < "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
		for item in "${AIRGEDDON_PIDS[@]}"; do
			[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && agpid="${BASH_REMATCH[2]}"
			if ps -p "${agpid}" > /dev/null 2>&1; then
				airgeddon_pid_alive=1
				break
			fi
		done

		if [ "${airgeddon_pid_alive}" -eq 0 ]; then
			rm -rf "${system_tmpdir}${ag_orchestrator_file}" > /dev/null 2>&1
			touch "${system_tmpdir}${ag_orchestrator_file}" > /dev/null 2>&1
		fi
	fi
}
function delete_instance_orchestrator_file() {

	debug_print

	if [ -f "${system_tmpdir}${ag_orchestrator_file}" ]; then
		rm -rf "${system_tmpdir}${ag_orchestrator_file}" > /dev/null 2>&1
	fi
}
function register_instance_pid() {

	debug_print

	if [ -f "${system_tmpdir}${ag_orchestrator_file}" ]; then
		if ! grep -q "${agpid_to_use}" "${system_tmpdir}${ag_orchestrator_file}"; then
			{
			echo "${agpid_to_use}"
			} >> "${system_tmpdir}${ag_orchestrator_file}"
		fi
	fi
}
function detect_running_instances() {

	debug_print

	airgeddon_running_instances_counter=1

	readarray -t AIRGEDDON_PIDS 2> /dev/null < <(cat < "${system_tmpdir}${ag_orchestrator_file}" 2> /dev/null)
	for item in "${AIRGEDDON_PIDS[@]}"; do
		[[ "${item}" =~ ^(et)?([0-9]+)(rs[0-1])?$ ]] && agpid="${BASH_REMATCH[2]}"
		if [[ "${agpid}" != "${BASHPID}" ]] && ps -p "${agpid}" > /dev/null 2>&1; then
			airgeddon_running_instances_counter=$((airgeddon_running_instances_counter + 1))
		fi
	done

	return "${airgeddon_running_instances_counter}"
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
function manage_asking_for_captured_hashes_file() {

	debug_print

	if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
		if [ -n "${enteredpath}" ]; then
			echo
			language_strings "${language}" 186 "blue"
			ask_yesno 187 "yes"
			if [ "${yesno}" = "n" ]; then
				ask_capture_hash_file "${1}" "${2}"
			fi
		else
			ask_capture_hash_file "${1}" "${2}"
		fi
	elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
		if [ -n "${hashcathashfileenteredpath}" ]; then
			echo
			language_strings "${language}" 795 "blue"
			ask_yesno 800 "yes"
			if [ "${yesno}" = "n" ]; then
				ask_capture_hash_file "${1}" "${2}"
			fi
		else
			ask_capture_hash_file "${1}" "${2}"
		fi
	else
		if [ "${2}" = "hashcat" ]; then
			if [ -n "${hashcatenterpriseenteredpath}" ]; then
				echo
				language_strings "${language}" 600 "blue"
				ask_yesno 800 "yes"
				if [ "${yesno}" = "n" ]; then
					ask_capture_hash_file "${1}" "${2}"
				fi
			else
				ask_capture_hash_file "${1}" "${2}"
			fi
		elif [ "${2}" = "jtr"  ]; then
			if [ -n "${jtrenterpriseenteredpath}" ]; then
				echo
				language_strings "${language}" 609 "blue"
				ask_yesno 800 "yes"
				if [ "${yesno}" = "n" ]; then
					ask_capture_hash_file "${1}" "${2}"
				fi
			else
				ask_capture_hash_file "${1}" "${2}"
			fi
		fi
	fi
}
function manage_asking_for_dictionary_file() {

	debug_print

	if [ -n "${DICTIONARY}" ]; then
		echo
		language_strings "${language}" 183 "blue"
		ask_yesno 184 "yes"
		if [ "${yesno}" = "n" ]; then
			ask_dictionary
		fi
	else
		ask_dictionary
	fi
}
function manage_asking_for_rule_file() {

	debug_print

	if [ -n "${RULES}" ]; then
		echo
		language_strings "${language}" 239 "blue"
		ask_yesno 240 "yes"
		if [ "${yesno}" = "n" ]; then
			ask_rules
		fi
	else
		ask_rules
	fi
}
function check_mana_hashes() {

	debug_print

	mana_hash=""
	rm -rf "${tmpdir}${mana_cap_file}" > /dev/null 2>&1
	rm -rf "${tmpdir}${mana_tmp_file}" > /dev/null 2>&1

	while true; do
		if grep -Eqim1 '^MANA: Captured a WPA/2 handshake from:' "${tmpdir}${hostapd_mana_log}"; then
			if grep -Eqim1 '^MANA WPA2 HASHCAT' "${tmpdir}${hostapd_mana_log}"; then
				mana_hash=$(grep -Eim1 '^MANA WPA2 HASHCAT' "${tmpdir}${hostapd_mana_log}" | awk -F "\|" '{print $2}' 2> /dev/null | tr -d " ")
			else
				hcxhash2cap --hccapx="${tmpdir}${hostapd_mana_out}" -c "${tmpdir}${mana_cap_file}" > /dev/null
				hcxpcapngtool "${tmpdir}${mana_cap_file}" -o "${tmpdir}${mana_tmp_file}" > /dev/null
				mana_hash=$(head -n1 "${tmpdir}${mana_tmp_file}")
			fi
			break
		fi

		if ! ps -p "${hostapd_mana_pid}" > /dev/null 2>&1; then
			break
		fi

		sleep 3
	done
}
function check_valid_file_to_clean() {

	debug_print

	nets_from_file=$(echo "1" | timeout -s SIGTERM 3 aircrack-ng "${1}" 2> /dev/null | grep -E "WPA|WEP" | awk '{ saved = $1; $1 = ""; print substr($0, 2) }')

	if [ "${nets_from_file}" = "" ]; then
		return 1
	fi

	option_counter=0
	for item in ${nets_from_file}; do
		if [[ ${item} =~ ^[0-9a-fA-F]{2}: ]]; then
			option_counter=$((option_counter + 1))
		fi
	done

	if [ "${option_counter}" -le 1 ]; then
		return 1
	fi

	handshakefilesize=$(wc -c "${filetoclean}" 2> /dev/null | awk -F " " '{print$1}')
	if [ "${handshakefilesize}" -le 1024 ]; then
		return 1
	fi

	if ! echo "1" | timeout -s SIGTERM 3 aircrack-ng "${1}" 2> /dev/null | grep -E "1 handshake" > /dev/null; then
		return 1
	fi

	return 0
}
function check_essid_in_mdk_decloak_log() {

	debug_print

	local regexp
	if [ "${AIRGEDDON_MDK_VERSION}" = "mdk3" ]; then
		if ! grep -q "End of SSID list reached" "${tmpdir}decloak.log"; then
			regexp='SSID:[[:blank:]]\"([^\"]+)\"'
			[[ $(grep "${bssid}" "${tmpdir}decloak.log") =~ ${regexp} ]] && essid="${BASH_REMATCH[1]}"
		fi
	else
		regexp="Probe[[:blank:]]Response[[:blank:]]from[[:blank:]]target[[:blank:]]AP[[:blank:]]with[[:blank:]]SSID[[:blank:]]+([^[:blank:]]+.*[^[:blank:]]|[^[:blank:]])"
		[[ $(grep -m 1 "Probe Response from target AP with SSID" "${tmpdir}decloak.log") =~ ${regexp} ]] && essid="${BASH_REMATCH[1]}"
	fi

	if [ "${essid}" = "(Hidden Network)" ]; then
		return 1
	else
		return 0
	fi
}
function check_essid_in_capture_file() {

	debug_print

	while IFS=, read -r exp_bssid _ _ _ _ _ _ _ _ _ _ _ _ exp_essid _; do

		chars_bssid=${#exp_bssid}
		if [ "${chars_bssid}" -ge 17 ]; then
			if [ "${exp_bssid}" = "${bssid}" ]; then
					exp_essid="${exp_essid#"${exp_essid%%[![:space:]]*}"}"
					exp_essid="${exp_essid%"${exp_essid##*[![:space:]]}"}"
				if [[ -n "${exp_essid}" ]] && [[ ${exp_essid} != "" ]]; then
					essid="${exp_essid}"
					break
				fi
			fi
		fi
	done < "${tmpdir}decloak-01.csv"

	if [ "${essid}" = "(Hidden Network)" ]; then
		return 1
	else
		return 0
	fi
}
function check_certificates_in_capture_file() {

	debug_print

	local cert
	declare -ga certificates_array

	while read -r hexcert; do
		cert=$(printf "${hexcert}" 2> /dev/null | openssl x509 -inform DER -outform PEM 2> /dev/null)
		[[ -z "${cert}" ]] && continue
		certificates_array+=("$cert")
	done < <(tshark -r "${tmpdir}identities_certificates"*.cap -Y "(eap && wlan.addr == ${bssid} && tls.handshake.certificate)" -T fields -e tls.handshake.certificate 2> /dev/null | sort -u | tr -d ':' | sed 's/../\\x&/g')

	if [ "${#certificates_array[@]}" -eq 0 ]; then
		return 1
	else
		return 0
	fi
}
function check_identities_in_capture_file() {

	debug_print

	declare -ga identities_array
	readarray -t identities_array < <(tshark -r "${tmpdir}identities_certificates"*.cap -Y "(eap && wlan.addr == ${bssid} && eap.identity)" -T fields -e eap.identity 2> /dev/null | sort -u)

	if [ "${#identities_array[@]}" -eq 0 ]; then
		return 1
	else
		return 0
	fi
}
function check_bssid_in_captured_file() {

	debug_print

	local nets_from_file
	nets_from_file=$(echo "1" | timeout -s SIGTERM 3 aircrack-ng "${1}" 2> /dev/null | grep -E "WPA \([1-9][0-9]? handshake" | awk '{ saved = $1; $1 = ""; print substr($0, 2) }')

	if [ "${3}" = "also_pmkid" ]; then
		get_aircrack_version
		if compare_floats_greater_or_equal "${aircrack_version}" "${aircrack_pmkid_version}"; then
			local nets_from_file2
			nets_from_file2=$(echo "1" | timeout -s SIGTERM 3 aircrack-ng "${1}" 2> /dev/null | grep -E "WPA \([1-9][0-9]? handshake|handshake, with PMKID" | awk '{ saved = $1; $1 = ""; print substr($0, 2) }')
		fi
	fi

	if [ "${2}" != "silent" ]; then
		if [ ! -f "${1}" ]; then
			echo
			language_strings "${language}" 161 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi

		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "only_handshake" ]]; then
			if [ "${nets_from_file}" = "" ]; then
				echo
				language_strings "${language}" 216 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		fi

		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "also_pmkid" ]]; then
			if [[ "${nets_from_file}" = "" ]] && [[ "${nets_from_file2}" = "" ]]; then
				echo
				language_strings "${language}" 682 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		fi
	fi

	declare -A bssids_detected
	declare -A bssids_detected_pmkid

	local option_counter
	option_counter=0
	for item in ${nets_from_file}; do
		if [[ ${item} =~ ^[0-9a-fA-F]{2}: ]]; then
			option_counter=$((option_counter + 1))
			bssids_detected[${option_counter}]=${item}
		fi
	done

	if [[ "${3}" = "also_pmkid" ]] && [[ -n "${nets_from_file2}" ]]; then
		option_counter=0
		for item in ${nets_from_file2}; do
			if [[ ${item} =~ ^[0-9a-fA-F]{2}: ]]; then
				option_counter=$((option_counter + 1))
				bssids_detected_pmkid[${option_counter}]=${item}
			fi
		done
	fi

	local handshake_captured=0
	local pmkid_captured=0

	for targetbssid in "${bssids_detected[@]}"; do
		if [ "${bssid}" = "${targetbssid}" ]; then
			handshake_captured=1
			break
		fi
	done

	if [[ "${3}" = "also_pmkid" ]] && [[ -n "${nets_from_file2}" ]]; then
		for targetbssid in "${bssids_detected_pmkid[@]}"; do
			if [ "${bssid}" = "${targetbssid}" ]; then
				pmkid_captured=1
				break
			fi
		done
	fi

	if [[ "${handshake_captured}" = "1" ]] || [[ "${pmkid_captured}" = "1" ]]; then
		if [[ "${2}" = "showing_msgs_capturing" ]] || [[ "${2}" = "showing_msgs_checking" ]]; then
			if ! is_wpa2_handshake "${1}" "${bssid}" > /dev/null 2>&1; then
				echo
				language_strings "${language}" 700 "red"
				language_strings "${language}" 115 "read"
				return 2
			fi
		fi
	fi

	if [[ "${handshake_captured}" = "1" ]] && [[ "${pmkid_captured}" = "0" ]]; then
		if [ "${2}" = "showing_msgs_checking" ]; then
			language_strings "${language}" 322 "yellow"
		fi
		return 0
	elif [[ "${handshake_captured}" = "0" ]] && [[ "${pmkid_captured}" = "1" ]]; then
		if [[ "${2}" = "showing_msgs_capturing" ]] && [[ "${3}" = "also_pmkid" ]]; then
			echo
			language_strings "${language}" 680 "yellow"
		fi
		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "also_pmkid" ]]; then
			echo
			language_strings "${language}" 683 "yellow"
		fi
		return 0
	elif [[ "${handshake_captured}" = "1" ]] && [[ "${pmkid_captured}" = "1" ]]; then
		if [[ "${2}" = "showing_msgs_capturing" ]] && [[ "${3}" = "also_pmkid" ]]; then
			echo
			language_strings "${language}" 681 "yellow"
		fi
		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "also_pmkid" ]]; then
			echo
			language_strings "${language}" 683 "yellow"
		fi
		return 0
	else
		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "only_handshake" ]]; then
			echo
			language_strings "${language}" 323 "red"
			language_strings "${language}" 115 "read"
		fi
		if [[ "${2}" = "showing_msgs_checking" ]] && [[ "${3}" = "also_pmkid" ]]; then
			echo
			language_strings "${language}" 323 "red"
			language_strings "${language}" 115 "read"
		fi
		return 1
	fi
}
function validate_enterprise_jtr_file() {

	debug_print

	echo
	readarray -t JTR_LINES_TO_VALIDATE < <(cat "${1}" 2> /dev/null)

	for item in "${JTR_LINES_TO_VALIDATE[@]}"; do
		if [[ ! "${item}" =~ ^.+:\$NETNTLM\$[0-9a-fA-F]+\$[0-9a-fA-F]+ ]]; then
			language_strings "${language}" 607 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	done

	language_strings "${language}" 608 "blue"
	language_strings "${language}" 115 "read"
	return 0
}
function check_hashcat_hashes_format() {

	debug_print

	first_hash_line=""
	local plain_text_hash_matched=0
	local deprecated_hash_matched=0

	if [ ! -s "${1}" ]; then
		echo
		language_strings "${language}" 676 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	if hcxhashtool --info=stdout --hccapx-in="${1}" > /dev/null 2>&1; then
		deprecated_hash_matched=1
	else
		first_hash_line=$(head -n 1 "${1}" 2>/dev/null)

		if [[ -z "${first_hash_line}" ]]; then
			echo
			language_strings "${language}" 676 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	fi

	if [[ "${first_hash_line}" =~ ^WPA\*[0-9]{2}\*[0-9a-fA-F]{32}\*([0-9a-fA-F]{12}\*){2}[0-9a-fA-F]{2,64}\*.+$ ]]; then
		plain_text_hash_matched=1
	fi

	if [ "${plain_text_hash_matched}" -eq 1 ]; then
		echo
		language_strings "${language}" 675 "blue"
		language_strings "${language}" 115 "read"
		return 0
	elif [ "${deprecated_hash_matched}" -eq 1 ]; then
		echo
		language_strings "${language}" 675 "blue"
		echo
		language_strings "${language}" 798 "yellow"
		language_strings "${language}" 115 "read"

		if convert_legacy_hashcat_hash_to_new "${1}"; then
			echo
			language_strings "${language}" 799 "blue"
			language_strings "${language}" 115 "read"
			return 0
		else
			echo
			language_strings "${language}" 417 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	else
		echo
		language_strings "${language}" 676 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi
}
function convert_legacy_hashcat_hash_to_new() {

	debug_print

	if ! first_hash_line="$(hcxhashtool --hccapx-in="${1}" --info=stdout 2>/dev/null | awk -F': ' 'BEGIN{found=0} /^HASHLINE/ { s=$2; sub(/\r$/,"", s); print s; found=1; exit } END{ exit (found ? 0 : 1) }')" || [[ "${first_hash_line}" != WPA\*0[12]* ]]; then
		return 1
	fi

	return 0
}
function validate_enterprise_hashcat_file() {

	debug_print

	echo
	readarray -t HASHCAT_LINES_TO_VALIDATE < <(cat "${1}" 2> /dev/null)

	for item in "${HASHCAT_LINES_TO_VALIDATE[@]}"; do
		if [[ ! "${item}" =~ ^(.+)::::(.+):(.+)$ ]]; then
			language_strings "${language}" 601 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	done

	language_strings "${language}" 602 "blue"
	language_strings "${language}" 115 "read"
	return 0
}
function manage_hashcat_pot() {

	debug_print

	hashcat_output=$(cat "${tmpdir}${hashcat_output_file}")

	pass_decrypted_by_hashcat=0
	if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat3_version}"; then
		local regexp="Status\.+:[[:space:]]Cracked"
		if [[ ${hashcat_output} =~ ${regexp} ]]; then
			pass_decrypted_by_hashcat=1
		else
			if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
				if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat_hccapx_version}"; then
					if [ -f "${tmpdir}${hashcat_pot_tmp}" ]; then
						pass_decrypted_by_hashcat=1
					fi
				fi
			fi
		fi
	else
		local regexp="All hashes have been recovered"
		if [[ ${hashcat_output} =~ ${regexp} ]]; then
			pass_decrypted_by_hashcat=1
		fi
	fi

	if [ "${pass_decrypted_by_hashcat}" -eq 1 ]; then

		echo
		language_strings "${language}" 234 "yellow"
		ask_yesno 235 "yes"
		if [ "${yesno}" = "y" ]; then
			hashcat_potpath="${default_save_path}"

			local multiple_users=0
			if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
				hashcatpot_filename=$(sanitize_path "hashcat-${bssid}.txt")
				[[ $(cat "${tmpdir}${hashcat_pot_tmp}") =~ .+:(.+)$ ]] && hashcat_key="${BASH_REMATCH[1]}"
			elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
				hashcatpot_filename=$(sanitize_path "hashcat-decrypted-hash.txt")
				[[ $(cat "${tmpdir}${hashcat_pot_tmp}") =~ .+:(.+)$ ]] && hashcat_key="${BASH_REMATCH[1]}"
			else
				if [[ $(wc -l "${tmpdir}${hashcat_pot_tmp}" 2> /dev/null | awk '{print $1}') -gt 1 ]]; then
					multiple_users=1
					hashcatpot_filename=$(sanitize_path "hashcat-enterprise_user-multiple_users.txt")
					local enterprise_users=()
					local hashcat_keys=()
					readarray -t DECRYPTED_MULTIPLE_USER_PASS < <(uniq "${tmpdir}${hashcat_pot_tmp}" | sort 2> /dev/null)
					for item in "${DECRYPTED_MULTIPLE_USER_PASS[@]}"; do
						[[ "${item}" =~ ^([^:]+:?[^:]+) ]] && enterprise_users+=("${BASH_REMATCH[1]}")
						[[ "${item}" =~ .+:(.+)$ ]] && hashcat_keys+=("${BASH_REMATCH[1]}")
					done
				else
					local enterprise_user
					[[ $(cat "${hashcatenterpriseenteredpath}") =~ ^([^:]+:?[^:]+) ]] && enterprise_user="${BASH_REMATCH[1]}"
					hashcatpot_filename=$(sanitize_path "hashcat-enterprise_user-${enterprise_user}.txt")
					[[ $(cat "${tmpdir}${hashcat_pot_tmp}") =~ .+:(.+)$ ]] && hashcat_key="${BASH_REMATCH[1]}"
				fi
			fi
			hashcat_potpath="${hashcat_potpath}${hashcatpot_filename}"

			validpath=1
			while [[ "${validpath}" != "0" ]]; do
				read_path "hashcatpot"
			done

			{
			echo ""
			date +%Y-%m-%d
			echo "${hashcat_texts[${language},1]}"
			echo ""
			} >> "${potenteredpath}"

			if [ "${1}" = "personal_handshake_pmkid_capture" ]; then
				{
				echo "BSSID: ${bssid}"
				} >> "${potenteredpath}"
			elif [ "${1}" = "personal_handshake_pmkid_hash" ]; then
				{
				echo "Hash: ${first_hash_line}"
				} >> "${potenteredpath}"
			elif [ "${1}" = "enterprise" ]; then
				if [ "${multiple_users}" -eq 1 ]; then
					{
					echo "${hashcat_texts[${language},0]}:"
					} >> "${potenteredpath}"
				else
					{
					echo "${hashcat_texts[${language},2]}: ${enterprise_user}"
					} >> "${potenteredpath}"
				fi
			fi

			if [ "${multiple_users}" -eq 1 ]; then
				{
				echo ""
				echo "---------------"
				echo ""
				} >> "${potenteredpath}"

				for ((x=0; x<${#enterprise_users[@]}; x++)); do
					{
					echo "${enterprise_users[${x}]} / ${hashcat_keys[${x}]}"
					} >> "${potenteredpath}"
				done
			else
				{
				echo ""
				echo "---------------"
				echo ""
				echo "${hashcat_key}"
				} >> "${potenteredpath}"
			fi

			add_contributing_footer_to_file "${potenteredpath}"

			echo
			language_strings "${language}" 236 "blue"
			language_strings "${language}" 115 "read"
		fi
	fi
}
function manage_jtr_pot() {

	debug_print

	jtr_pot=$(cat "${tmpdir}${jtr_pot_tmp}")

	pass_decrypted_by_jtr=0

	if [[ ${jtr_pot} =~ ^\$NETNTLM\$[^:]+:.+$ ]]; then
		pass_decrypted_by_jtr=1
	fi

	if [ "${pass_decrypted_by_jtr}" -eq 1 ]; then

		echo
		language_strings "${language}" 234 "yellow"
		ask_yesno 235 "yes"
		if [ "${yesno}" = "y" ]; then
			jtr_potpath="${default_save_path}"

			local multiple_users=0

			if [[ $(wc -l "${tmpdir}${jtr_pot_tmp}" 2> /dev/null | awk '{print $1}') -gt 1 ]]; then
				multiple_users=1
				jtrpot_filename=$(sanitize_path "jtr-enterprise_user-multiple_users.txt")
				local enterprise_users=()
				local jtr_keys=()
				readarray -t DECRYPTED_MULTIPLE_PASS < <(uniq "${tmpdir}${jtr_pot_tmp}" | sort 2> /dev/null)
				for item in "${DECRYPTED_MULTIPLE_PASS[@]}"; do
					[[ "${item}" =~ ^\$NETNTLM\$[^:]+:(.+)$ ]] && jtr_keys+=("${BASH_REMATCH[1]}")
					[[ $(grep -E "^${BASH_REMATCH[1]}" "${tmpdir}${jtr_output_file}") =~ ^"${BASH_REMATCH[1]}"[[:blank:]]+\((.+)\) ]] && enterprise_users+=("${BASH_REMATCH[1]}")
				done
			else
				local enterprise_user
				[[ $(cat "${jtrenterpriseenteredpath}") =~ ^([^:\$]+:?[^:\$]+) ]] && enterprise_user="${BASH_REMATCH[1]}"
				jtrpot_filename=$(sanitize_path "jtr-enterprise_user-${enterprise_user}.txt")
				[[ "${jtr_pot}" =~ ^\$NETNTLM\$[^:]+:(.+)$ ]] && jtr_key="${BASH_REMATCH[1]}"
			fi
			jtr_potpath="${jtr_potpath}${jtrpot_filename}"

			validpath=1
			while [[ "${validpath}" != "0" ]]; do
				read_path "jtrpot"
			done

			{
			echo ""
			date +%Y-%m-%d
			echo "${jtr_texts[${language},1]}"
			echo ""
			} >> "${jtrpotenteredpath}"

			if [ "${multiple_users}" -eq 1 ]; then
				{
				echo "${jtr_texts[${language},0]}"
				} >> "${jtrpotenteredpath}"
			else
				{
				echo "${jtr_texts[${language},2]}: ${enterprise_user}"
				} >> "${jtrpotenteredpath}"
			fi

			if [ "${multiple_users}" -eq 1 ]; then
				{
				echo ""
				echo "---------------"
				echo ""
				} >> "${jtrpotenteredpath}"

				for ((x=0; x<${#enterprise_users[@]}; x++)); do
					{
					echo "${enterprise_users[${x}]} / ${jtr_keys[${x}]}"
					} >> "${jtrpotenteredpath}"
				done
			else
				{
				echo ""
				echo "---------------"
				echo ""
				echo "${jtr_key}"
				} >> "${jtrpotenteredpath}"
			fi

			add_contributing_footer_to_file "${jtrpotenteredpath}"

			echo
			language_strings "${language}" 547 "blue"
			language_strings "${language}" 115 "read"
		fi
	fi
}
function manage_aircrack_pot() {

	debug_print

	pass_decrypted_by_aircrack=0
	if [ -f "${tmpdir}${aircrack_pot_tmp}" ]; then
		pass_decrypted_by_aircrack=1
	fi

	if [ "${pass_decrypted_by_aircrack}" -eq 1 ]; then

		echo
		language_strings "${language}" 234 "yellow"
		ask_yesno 235 "yes"
		if [ "${yesno}" = "y" ]; then
			aircrack_potpath="${default_save_path}"
			aircrackpot_filename=$(sanitize_path "aircrack-${bssid}.txt")
			aircrack_potpath="${aircrack_potpath}${aircrackpot_filename}"

			validpath=1
			while [[ "${validpath}" != "0" ]]; do
				read_path "aircrackpot"
			done

			aircrack_key=$(cat "${tmpdir}${aircrack_pot_tmp}")
			{
			echo ""
			date +%Y-%m-%d
			echo "${aircrack_texts[${language},0]}"
			echo ""
			echo "BSSID: ${bssid}"
			echo ""
			echo "---------------"
			echo ""
			echo "${aircrack_key}"
			} >> "${aircrackpotenteredpath}"

			add_contributing_footer_to_file "${aircrackpotenteredpath}"

			echo
			language_strings "${language}" 440 "blue"
			language_strings "${language}" 115 "read"
		fi
	fi
}
function manage_mana_pot() {

	debug_print

	if [ -n "${mana_hash}" ]; then
		echo
		language_strings "${language}" 530 "yellow"

		ask_yesno 785 "yes"
		if [ "${yesno}" = "y" ]; then
			downgrade_potpath="${default_save_path}"
			downgradepot_filename=$(sanitize_path "wpa3-downgrade-hash-${bssid}.txt")
			downgrade_potpath="${downgrade_potpath}${downgradepot_filename}"

			validpath=1
			while [[ "${validpath}" != "0" ]]; do
				read_path "downgradepot"
			done

			{
			echo "${mana_hash}"
			} >> "${downgradepotenteredpath}"

			echo
			language_strings "${language}" 786 "blue"
			language_strings "${language}" 115 "read"
		fi
	else
		echo
		language_strings "${language}" 788 "red"
		language_strings "${language}" 115 "read"
	fi
}
function manage_asleap_pot() {

	debug_print

	asleap_output=$(cat "${tmpdir}${asleap_pot_tmp}")

	if [[ "${asleap_output}" =~ password:[[:blank:]]+(.*) ]]; then

		local asleap_decrypted_password="${BASH_REMATCH[1]}"
		local write_to_file=0

		language_strings "${language}" 234 "yellow"

		if [ "${1}" != "offline_menu" ]; then
			echo
			local write_to_file=1
			asleap_attack_finished=1
			path_to_asleap_trophy="${enterprise_completepath}enterprise_asleap_decrypted_${bssid}_password.txt"
		else
			ask_yesno 235 "yes"
			if [ "${yesno}" = "y" ]; then
				local write_to_file=1
				asleap_potpath="${default_save_path}"
				asleappot_filename=$(sanitize_path "asleap_decrypted_password.txt")
				asleap_potpath="${asleap_potpath}${asleappot_filename}"

				validpath=1
				while [[ "${validpath}" != "0" ]]; do
					read_path "asleappot"
				done

				path_to_asleap_trophy="${asleapenteredpath}"
			fi
		fi

		if [ "${write_to_file}" = "1" ]; then
			rm -rf "${path_to_asleap_trophy}" > /dev/null 2>&1

			{
			echo ""
			date +%Y-%m-%d
			echo "${asleap_texts[${language},1]}"
			echo ""
			} >> "${path_to_asleap_trophy}"

			if [ "${1}" != "offline_menu" ]; then
				{
				echo "ESSID: ${essid}"
				echo "BSSID: ${bssid}"
				} >> "${path_to_asleap_trophy}"
			fi

			{
			echo "${asleap_texts[${language},2]}: ${enterprise_asleap_challenge}"
			echo "${asleap_texts[${language},0]}: ${enterprise_asleap_response}"
			echo ""
			echo "---------------"
			echo ""
			} >> "${path_to_asleap_trophy}"

			if [ "${1}" != "offline_menu" ]; then
				{
				echo "${enterprise_username} / ${asleap_decrypted_password}"
				} >> "${path_to_asleap_trophy}"
			else
				{
				echo "${asleap_decrypted_password}"
				} >> "${path_to_asleap_trophy}"
			fi

			add_contributing_footer_to_file "${path_to_asleap_trophy}"

			language_strings "${language}" 539 "blue"
			language_strings "${language}" 115 "read"
		fi
	else
		if [ "${1}" != "offline_menu" ]; then
			language_strings "${language}" 540 "red"

			ask_yesno 541 "no"
			if [ "${yesno}" = "n" ]; then
				asleap_attack_finished=1
			fi
		else
			language_strings "${language}" 540 "red"
			language_strings "${language}" 115 "read"
		fi
	fi
}
function manage_wep_besside_pot() {

	debug_print

	local wep_besside_pass_cracked=0
	if grep -q "Got key" "${tmpdir}${wep_besside_log}" 2> /dev/null; then
		sed -ri '1,/Got key/{/Got key/!d; s/.*(Got key)/\1/}' "${tmpdir}${wep_besside_log}" 2> /dev/null
		readarray -t LINES_TO_PARSE < <(cat < "${tmpdir}${wep_besside_log}" 2> /dev/null)
		for item in "${LINES_TO_PARSE[@]}"; do
			if [[ "${item}" =~ Got[[:blank:]]key[[:blank:]]for.*\[([0-9A-Fa-f:]+)\].*IVs ]]; then
				wep_hex_key="${BASH_REMATCH[1]}"
				wep_ascii_key=$(echo "${wep_hex_key}" | awk 'RT{printf "%c", strtonum("0x"RT)}' RS='[0-9A-Fa-f]{2}')
				wep_besside_pass_cracked=1
				break
			fi
		done
	fi

	if [ "${wep_besside_pass_cracked}" -eq 1 ]; then
		echo "" > "${weppotenteredpath}"
		{
		date +%Y-%m-%d
		echo -e "${wep_texts[${language},1]}"
		echo ""
		echo -e "BSSID: ${bssid}"
		echo -e "${wep_texts[${language},2]}: ${channel}"
		echo -e "ESSID: ${essid}"
		echo ""
		echo "---------------"
		echo ""
		echo -e "ASCII: ${wep_ascii_key}"
		echo -en "${wep_texts[${language},3]}:"
		echo -en " ${wep_hex_key}"
		echo ""
		echo ""
		echo "---------------"
		echo ""
		echo "${footer_texts[${language},0]}"
		} >> "${weppotenteredpath}"

		echo
		language_strings "${language}" 162 "yellow"
		echo
		language_strings "${language}" 724 "blue"
		language_strings "${language}" 115 "read"
	fi
}
function manage_ettercap_log() {

	debug_print

	ettercap_log=0
	ask_yesno 302 "yes"
	if [ "${yesno}" = "y" ]; then
		ettercap_log=1
		default_ettercap_logpath="${default_save_path}"
		default_ettercaplogfilename=$(sanitize_path "evil_twin_captured_passwords-${essid}.txt")
		rm -rf "${tmpdir}${ettercap_file}"* > /dev/null 2>&1
		tmp_ettercaplog="${tmpdir}${ettercap_file}"
		default_ettercap_logpath="${default_ettercap_logpath}${default_ettercaplogfilename}"
		validpath=1
		while [[ "${validpath}" != "0" ]]; do
			read_path "ettercaplog"
		done
	fi
}
function manage_bettercap_log() {

	debug_print

	bettercap_log=0
	ask_yesno 302 "yes"
	if [ "${yesno}" = "y" ]; then
		bettercap_log=1
		default_bettercap_logpath="${default_save_path}"
		default_bettercaplogfilename=$(sanitize_path "evil_twin_captured_passwords-bettercap-${essid}.txt")
		rm -rf "${tmpdir}${bettercap_file}"* > /dev/null 2>&1
		tmp_bettercaplog="${tmpdir}${bettercap_file}"
		default_bettercap_logpath="${default_bettercap_logpath}${default_bettercaplogfilename}"
		validpath=1
		while [[ "${validpath}" != "0" ]]; do
			read_path "bettercaplog"
		done
	fi
}
function manage_wps_log() {

	debug_print

	wps_potpath="${default_save_path}"

	if [ -z "${wps_essid}" ]; then
		wpspot_filename=$(sanitize_path "wps_captured_key-${wps_bssid}.txt")
	else
		wpspot_filename=$(sanitize_path "wps_captured_key-${wps_essid}.txt")
	fi
	wps_potpath="${wps_potpath}${wpspot_filename}"

	validpath=1
	while [[ "${validpath}" != "0" ]]; do
		read_path "wpspot"
	done
}
function manage_wep_log() {

	debug_print

	wep_potpath="${default_save_path}"
	weppot_filename=$(sanitize_path "wep_captured_key-${essid}.txt")
	wep_potpath="${wep_potpath}${weppot_filename}"

	validpath=1
	while [[ "${validpath}" != "0" ]]; do
		read_path "weppot"
	done
}
function manage_enterprise_log() {

	debug_print

	enterprise_potpath="${default_save_path}"
	enterprisepot_suggested_dirname=$(sanitize_path "enterprise_captured-${essid}")
	enterprise_potpath="${enterprise_potpath}${enterprisepot_suggested_dirname}/"

	validpath=1
	while [[ "${validpath}" != "0" ]]; do
		read_path "enterprisepot"
	done
}
function manage_enterprise_certs() {

	debug_print

	enterprisecertspath="${default_save_path}"
	enterprisecerts_suggested_dirname="enterprise_certs"
	enterprisecertspath="${enterprisecertspath}${enterprisecerts_suggested_dirname}/"

	validpath=1
	while [[ "${validpath}" != "0" ]]; do
		read_path "certificates"
	done
}
function save_enterprise_certs() {

	debug_print

	if [ ! -d "${enterprisecerts_completepath}" ]; then
		mkdir -p "${enterprisecerts_completepath}" > /dev/null 2>&1
	fi

	cp "${tmpdir}${certsdir}server.pem" "${enterprisecerts_completepath}" 2> /dev/null
	cp "${tmpdir}${certsdir}ca.pem" "${enterprisecerts_completepath}" 2> /dev/null
	cp "${tmpdir}${certsdir}server.key" "${enterprisecerts_completepath}" 2> /dev/null

	echo
	language_strings "${language}" 644 "blue"
	language_strings "${language}" 115 "read"
}
function manage_captive_portal_log() {

	debug_print

	default_et_captive_portal_logpath="${default_save_path}"
	default_et_captive_portallogfilename=$(sanitize_path "evil_twin_captive_portal_password-${essid}.txt")
	default_et_captive_portal_logpath="${default_et_captive_portal_logpath}${default_et_captive_portallogfilename}"
	validpath=1
	while [[ "${validpath}" != "0" ]]; do
		read_path "et_captive_portallog"
	done
}
function handle_enterprise_log() {

	debug_print

	if [ -f "${tmpdir}${enterprisedir}${enterprise_successfile}" ]; then

		enterprise_attack_result_code=$(cat < "${tmpdir}${enterprisedir}${enterprise_successfile}" 2> /dev/null)
		echo
		if [ "${enterprise_attack_result_code}" -eq 0 ]; then
			language_strings "${language}" 530 "yellow"
			parse_from_enterprise "hashes"
		elif [ "${enterprise_attack_result_code}" -eq 1 ]; then
			language_strings "${language}" 531 "yellow"
			parse_from_enterprise "passwords"
		elif [ "${enterprise_attack_result_code}" -eq 2 ]; then
			language_strings "${language}" 532 "yellow"
			parse_from_enterprise "both"
		fi

		echo
		language_strings "${language}" 533 "blue"
		language_strings "${language}" 115 "read"
	else
		echo
		language_strings "${language}" 529 "red"
		language_strings "${language}" 115 "read"
	fi
}
function parse_from_enterprise() {

	debug_print

	local line_number
	local username
	local john_hashes=()
	local hashcat_hashes=()
	local passwords=()
	local line_to_check
	local text_to_check
	unset enterprise_captured_challenges_responses
	declare -gA enterprise_captured_challenges_responses

	readarray -t CAPTURED_USERNAMES < <(grep -n -E "username:" "${tmpdir}${hostapd_wpe_log}" | sort -k 2,3 | uniq --skip-fields=1 2> /dev/null)
	for item in "${CAPTURED_USERNAMES[@]}"; do
		[[ "${item}" =~ ([0-9]+):.*username:[[:blank:]]+(.*) ]] && line_number="${BASH_REMATCH[1]}" && username="${BASH_REMATCH[2]}"
		line_to_check=$((line_number + 1))
		text_to_check=$(sed "${line_to_check}q;d" "${tmpdir}${hostapd_wpe_log}" 2> /dev/null)

		if [[ "${text_to_check}" =~ challenge:[[:blank:]]+(.*) ]]; then
			enterprise_captured_challenges_responses["${username}"]="${BASH_REMATCH[1]}"
			line_to_check=$((line_number + 2))
			text_to_check=$(sed "${line_to_check}q;d" "${tmpdir}${hostapd_wpe_log}" 2> /dev/null)
			[[ "${text_to_check}" =~ response:[[:blank:]]+(.*) ]] && enterprise_captured_challenges_responses["${username}"]+=" / ${BASH_REMATCH[1]}"

			line_to_check=$((line_number + 3))
			text_to_check=$(sed "${line_to_check}q;d" "${tmpdir}${hostapd_wpe_log}" 2> /dev/null)
			[[ "${text_to_check}" =~ jtr[[:blank:]]NETNTLM:[[:blank:]]+(.*) ]] && john_hashes+=("${BASH_REMATCH[1]}")

			line_to_check=$((line_number + 4))
			text_to_check=$(sed "${line_to_check}q;d" "${tmpdir}${hostapd_wpe_log}" 2> /dev/null)
			[[ "${text_to_check}" =~ hashcat[[:blank:]]NETNTLM:[[:blank:]]+(.*) ]] && hashcat_hashes+=("${BASH_REMATCH[1]}")
		fi

		if [[ "${text_to_check}" =~ password:[[:blank:]]+(.*) ]]; then
			passwords+=("${username} / ${BASH_REMATCH[1]}")
		fi
	done

	prepare_enterprise_trophy_dir

	case ${1} in
		"hashes")
			write_enterprise_hashes_file "hashcat" "${hashcat_hashes[@]}"
			write_enterprise_hashes_file "john" "${john_hashes[@]}"
		;;
		"passwords")
			write_enterprise_passwords_file "${passwords[@]}"
		;;
		"both")
			write_enterprise_hashes_file "hashcat" "${hashcat_hashes[@]}"
			write_enterprise_hashes_file "john" "${john_hashes[@]}"
			write_enterprise_passwords_file "${passwords[@]}"
		;;
	esac

	enterprise_username="${username}"
}
function prepare_enterprise_trophy_dir() {

	debug_print

	if [ ! -d "${enterprise_completepath}" ]; then
		mkdir -p "${enterprise_completepath}" > /dev/null 2>&1
	fi
}
function write_enterprise_hashes_file() {

	debug_print

	local values=("${@:2}")
	rm -rf "${enterprise_completepath}enterprise_captured_${1}_${bssid}_hashes.txt" > /dev/null 2>&1

	for item in "${values[@]}"; do
		{
		echo "${item}"
		} >> "${enterprise_completepath}enterprise_captured_${1}_${bssid}_hashes.txt"
	done
}
function write_enterprise_passwords_file() {

	debug_print

	local values=("${@:1}")
	rm -rf "${enterprise_completepath}enterprise_captured_${bssid}_passwords.txt" > /dev/null 2>&1

	{
	echo ""
	date +%Y-%m-%d
	echo "${enterprise_texts[${language},11]}"
	echo ""
	echo "ESSID: ${essid}"
	echo "BSSID: ${bssid}"
	echo ""
	echo "---------------"
	echo ""
	} >> "${enterprise_completepath}enterprise_captured_${bssid}_passwords.txt"

	for item in "${values[@]}"; do
		{
		echo "${item}"
		} >> "${enterprise_completepath}enterprise_captured_${bssid}_passwords.txt"
	done

	add_contributing_footer_to_file "${enterprise_completepath}enterprise_captured_${bssid}_passwords.txt"
}
function restore_spoofed_macs() {

	debug_print

	for item in "${!original_macs[@]}"; do
		ip link set "${item}" down > /dev/null 2>&1
		ip link set dev "${item}" address "${original_macs[${item}]}" > /dev/null 2>&1
		ip link set "${item}" up > /dev/null 2>&1
	done
}
function parse_ettercap_log() {

	debug_print

	echo
	language_strings "${language}" 304 "blue"

	readarray -t CAPTUREDPASS < <(etterlog -L -p -i "${tmp_ettercaplog}.eci" 2> /dev/null | grep -E -i "USER:|PASS:")

	{
	echo ""
	date +%Y-%m-%d
	echo "${et_misc_texts[${language},8]}"
	echo ""
	echo "BSSID: ${bssid}"
	echo "${et_misc_texts[${language},1]}: ${channel}"
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
		language_strings "${language}" 305 "yellow"
	else
		language_strings "${language}" 306 "blue"
		cp "${tmpdir}parsed_file" "${ettercap_logpath}" > /dev/null 2>&1
	fi

	rm -rf "${tmpdir}parsed_file" > /dev/null 2>&1
	language_strings "${language}" 115 "read"
}
function parse_bettercap_log() {

	debug_print

	echo
	language_strings "${language}" 304 "blue"

	if compare_floats_greater_or_equal "${bettercap_version}" "${bettercap2_version}"; then
		sed -Ei 's/\x1b\[[0-9;]*m.+\x1b\[[0-9;]K//g' "${tmp_bettercaplog}" 2> /dev/null
		sed -Ei 's/\x1b\[[0-9;]*m|\x1b\[J|\x1b\[[0-9;]K|\x8|\xd//g' "${tmp_bettercaplog}" 2> /dev/null
		sed -Ei 's/.*»//g' "${tmp_bettercaplog}" 2> /dev/null
		sed -Ei 's/^[[:blank:]]*//g' "${tmp_bettercaplog}" 2> /dev/null
		sed -Ei '/^$/d' "${tmp_bettercaplog}" 2> /dev/null
	fi

	local regexp='USER|UNAME|PASS|CREDITCARD|COOKIE|PWD|USUARIO|CONTRASE|CORREO|MAIL|NET.SNIFF.HTTP.REQUEST.*POST|HTTP\].*POST'
	local regexp2='USER-AGENT|COOKIES|BEEFHOOK'
	readarray -t BETTERCAPLOG < <(cat < "${tmp_bettercaplog}" 2> /dev/null | grep -E -i "${regexp}" | grep -E -vi "${regexp2}")

	{
	echo ""
	date +%Y-%m-%d
	echo "${et_misc_texts[${language},8]}"
	echo ""
	echo "BSSID: ${bssid}"
	echo "${et_misc_texts[${language},1]}: ${channel}"
	echo "ESSID: ${essid}"
	echo ""
	echo "---------------"
	echo ""
	} >> "${tmpdir}parsed_file"

	pass_counter=0
	captured_cookies=()
	for cpass in "${BETTERCAPLOG[@]}"; do
		if [[ ${cpass^^} =~ ${regexp^^} ]]; then
			repeated_cookie=0
			for item in "${captured_cookies[@]}"; do
				if [ "${item}" = "${cpass}" ]; then
					repeated_cookie=1
					break
				fi
			done
			if [ "${repeated_cookie}" -eq 0 ]; then
				captured_cookies+=("${cpass}")
				echo "${cpass}" >> "${tmpdir}parsed_file"
				pass_counter=$((pass_counter + 1))
			fi
		else
			echo "${cpass}" >> "${tmpdir}parsed_file"
			pass_counter=$((pass_counter + 1))
		fi
	done

	add_contributing_footer_to_file "${tmpdir}parsed_file"

	if [ "${pass_counter}" -eq 0 ]; then
		language_strings "${language}" 305 "yellow"
	else
		language_strings "${language}" 399 "blue"
		cp "${tmpdir}parsed_file" "${bettercap_logpath}" > /dev/null 2>&1
	fi

	rm -rf "${tmpdir}parsed_file" > /dev/null 2>&1
	language_strings "${language}" 115 "read"
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
function kill_wpa3_downgrade_attack_processes() {

	debug_print

	kill "${hostapd_mana_pid}" &> /dev/null
	kill "${downgrade_dos_pid}" &> /dev/null

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		kill_tmux_windows
	fi
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
function recover_current_channel() {

	debug_print

	local recovered_channel
	recovered_channel=$(cat "${tmpdir}${channelfile}" 2> /dev/null)
	if [ -n "${recovered_channel}" ]; then
		channel="${recovered_channel}"
	fi
}
function convert_cap_to_hashcat_format() {

	debug_print

	rm -rf "${tmpdir}hctmp"* > /dev/null 2>&1
	if [ "${hccapx_needed}" -eq 0 ]; then
		echo "1" | timeout -s SIGTERM 3 aircrack-ng "${enteredpath}" -J "${tmpdir}${hashcat_tmp_simple_name_file}" -b "${bssid}" > /dev/null 2>&1
		return 0
	else
		if [ "${hcx_conversion_needed}" -eq 1 ]; then
			if hash hcxpcapngtool 2> /dev/null; then
				hcxpcapngtool -o "${tmpdir}${hashcat_tmp_file}" "${enteredpath}" > /dev/null 2>&1
				return 0
			else
				echo
				language_strings "${language}" 703 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		else
			hccapx_converter_found=0
			if hash ${hccapx_tool} 2> /dev/null; then
				hccapx_converter_found=1
				hccapx_converter_path="${hccapx_tool}"
			else
				for item in "${possible_hccapx_converter_known_locations[@]}"; do
					if [ -f "${item}" ]; then
						hccapx_converter_found=1
						hccapx_converter_path="${item}"
						break
					fi
				done
			fi

			if [ "${hccapx_converter_found}" -eq 1 ]; then
				hashcat_tmp_file="${hashcat_tmp_simple_name_file}.hccapx"
				"${hccapx_converter_path}" "${enteredpath}" "${tmpdir}${hashcat_tmp_file}" > /dev/null 2>&1
				return 0
			else
				echo
				language_strings "${language}" 436 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		fi
	fi
}
function check_file_exists() {

	debug_print

	if [[ ! -f $(readlink -f "${1}") ]] || [[ -z "${1}" ]]; then
		language_strings "${language}" 161 "red"
		return 1
	fi
	return 0
}
function validate_path() {

	debug_print

	lastcharmanualpath=${1: -1}

	if [[ "${2}" = "enterprisepot" ]] || [[ "${2}" = "certificates" ]]; then
		dirname=$(dirname "${1}")

		if [ -d "${dirname}" ]; then
			if ! check_write_permissions "${dirname}"; then
				language_strings "${language}" 157 "red"
				return 1
			fi
		else
			if ! dir_permission_check "${1}"; then
				language_strings "${language}" 526 "red"
				return 1
			fi
		fi

		if [ "${lastcharmanualpath}" != "/" ]; then
			pathname="${1}/"
		fi
	else
		dirname=${1%/*}

		if [[ ! -d "${dirname}" ]] || [[ "${dirname}" = "." ]]; then
			language_strings "${language}" 156 "red"
			return 1
		fi

		if ! check_write_permissions "${dirname}"; then
			language_strings "${language}" 157 "red"
			return 1
		fi
	fi

	if [[ "${lastcharmanualpath}" = "/" ]] || [[ -d "${1}" ]] || [[ "${2}" = "enterprisepot" ]] || [[ "${2}" = "certificates" ]]; then
		if [ "${lastcharmanualpath}" != "/" ]; then
			pathname="${1}/"
		else
			pathname="${1}"
		fi

		case ${2} in
			"downgradepot")
				suggested_filename="${downgradepot_filename}"
				downgradepotenteredpath+="${downgradepot_filename}"
			;;
			"wpa3pot")
				suggested_filename="${wpa3pot_filename}"
				wpa3potenteredpath+="${wpa3pot_filename}"
			;;
			"handshake")
				enteredpath="${pathname}${standardhandshake_filename}"
				suggested_filename="${standardhandshake_filename}"
			;;
			"pmkid")
				enteredpath="${pathname}${standardpmkid_filename}"
				suggested_filename="${standardpmkid_filename}"
			;;
			"pmkidcap")
				enteredpath="${pathname}${standardpmkidcap_filename}"
				suggested_filename="${standardpmkidcap_filename}"
			;;
			"aircrackpot")
				suggested_filename="${aircrackpot_filename}"
				aircrackpotenteredpath+="${aircrackpot_filename}"
			;;
			"jtrpot")
				suggested_filename="${jtrpot_filename}"
				jtrpotenteredpath+="${jtrpot_filename}"
			;;
			"hashcatpot")
				suggested_filename="${hashcatpot_filename}"
				potenteredpath+="${hashcatpot_filename}"
			;;
			"asleappot")
				suggested_filename="${asleappot_filename}"
				asleapenteredpath+="${asleappot_filename}"
			;;
			"ettercaplog")
				suggested_filename="${default_ettercaplogfilename}"
				ettercap_logpath="${ettercap_logpath}${default_ettercaplogfilename}"
			;;
			"bettercaplog")
				suggested_filename="${default_bettercaplogfilename}"
				bettercap_logpath="${bettercap_logpath}${default_bettercaplogfilename}"
			;;
			"writeethandshake")
				et_handshake="${pathname}${standardhandshake_filename}"
				suggested_filename="${standardhandshake_filename}"
			;;
			"et_captive_portallog")
				suggested_filename="${default_et_captive_portallogfilename}"
				et_captive_portal_logpath+="${default_et_captive_portallogfilename}"
			;;
			"wpspot")
				suggested_filename="${wpspot_filename}"
				wpspotenteredpath+="${wpspot_filename}"
			;;
			"weppot")
				suggested_filename="${weppot_filename}"
				weppotenteredpath+="${weppot_filename}"
			;;
			"enterprisepot")
				enterprise_potpath="${pathname}"
				enterprise_basepath=$(dirname "${enterprise_potpath}")

				if [ "${enterprise_basepath}" != "." ]; then
					enterprise_dirname=$(basename "${enterprise_potpath}")
				fi

				if [ "${enterprise_basepath}" != "/" ]; then
					enterprise_basepath+="/"
				fi

				if [ "${enterprise_dirname}" != "${enterprisepot_suggested_dirname}" ]; then
					enterprise_completepath="${enterprise_potpath}${enterprisepot_suggested_dirname}/"
				else
					enterprise_completepath="${enterprise_potpath}"
					if [ "${enterprise_potpath: -1}" != "/" ]; then
						enterprise_completepath+="/"
					fi
				fi

				echo
				language_strings "${language}" 158 "yellow"
				return 0
			;;
			"certificates")
				enterprisecertspath="${pathname}"
				enterprisecerts_basepath=$(dirname "${enterprisecertspath}")

				if [ "${enterprisecerts_basepath}" != "/" ]; then
					enterprisecerts_basepath+="/"
				fi

				enterprisecerts_completepath="${enterprisecertspath}"
				if [ "${enterprisecertspath: -1}" != "/" ]; then
					enterprisecerts_completepath+="/"
				fi

				echo
				language_strings "${language}" 158 "yellow"
				return 0
			;;
		esac

		echo
		language_strings "${language}" 155 "yellow"
		return 0
	fi

	echo
	language_strings "${language}" 158 "yellow"
	return 0
}
function dir_permission_check() {

	debug_print

	if [ -e "${1}" ]; then
		if [ -d "${1}" ] && check_write_permissions "${1}" && [ -x "${1}" ]; then
			return 0
		else
			return 1
		fi
	else
		dir_permission_check "$(dirname "${1}")"
		return $?
	fi
}
function check_write_permissions() {

	debug_print

	if [ -w "${1}" ]; then
		return 0
	fi
	return 1
}
function fix_autocomplete_chars() {

	debug_print

	local var
	var=${1//\\/$''}

	echo "${var}"
}
function read_and_clean_path() {

	debug_print

	local var
	settings="$(shopt -p extglob)"
	shopt -s extglob

	echo -en '> '
	var=$(read -re _var; echo -n "${_var}")
	var=$(fix_autocomplete_chars "${var}")
	local regexp='^[ '"'"']*(.*[^ '"'"'])[ '"'"']*$'
	[[ ${var} =~ ${regexp} ]] && var="${BASH_REMATCH[1]}"
	eval "${1}=\$var"

	eval "${settings}"
}
function sanitize_path() {

	debug_print

	local sanitized
	sanitized=$(echo "${1}" | sed 's/[^A-Za-z0-9._:\\-]/_/g')

	if [ -z "${sanitized}" ]; then
		sanitized="airgeddon_fallback_filename"
	fi

	echo "${sanitized}"
}
function is_wpa2_handshake() {

	debug_print

	bash -c "aircrack-ng -a 2 -b \"${2}\" -w \"${1}\" \"${1}\" > /dev/null 2>&1"
	return $?
}
function set_wash_parameterization() {

	debug_print

	fcs=""
	declare -gA wash_ifaces_already_set
	readarray -t WASH_OUTPUT < <(timeout -s SIGTERM 2 wash -i "${interface}" 2> /dev/null)

	for item in "${WASH_OUTPUT[@]}"; do
		if [[ ${item} =~ ^\[\!\].*bad[[:space:]]FCS ]]; then
			fcs=" -C "
			break
		fi
	done

	wash_ifaces_already_set[${interface}]=${fcs}
}
function check_if_type_exists_in_wps_data_array() {

	debug_print

	[[ -n "${wps_data_array["${1}","${2}"]:+not set}" ]]
}
function check_if_pin_exists_in_wps_data_array() {

	debug_print

	[[ "${wps_data_array["${1}","${2}"]}" =~ (^| )"${3}"( |$) ]]
}
function fill_wps_data_array() {

	debug_print

	if ! check_if_pin_exists_in_wps_data_array "${1}" "${2}" "${3}"; then

		if [ "${2}" != "Database" ]; then
			wps_data_array["${1}","${2}"]="${3}"
		else
			if [ "${wps_data_array["${1}","${2}"]}" = "" ]; then
				wps_data_array["${1}","${2}"]="${3}"
			else
				wps_data_array["${1}","${2}"]="${wps_data_array["${1}","${2}"]} ${3}"
			fi
		fi
	fi
}
function detect_internet_interface() {

	debug_print

	if [ "${internet_interface_selected}" -eq 1 ]; then
		return 0
	fi

	if [ -n "${internet_interface}" ]; then
		echo
		language_strings "${language}" 285 "blue"
		ask_yesno 284 "yes"
		if [ "${yesno}" = "n" ]; then
			if ! select_secondary_interface "internet"; then
				return 1
			fi
		fi
	else
		if ! select_secondary_interface "internet"; then
			return 1
		fi
	fi

	validate_et_internet_interface
	return $?
}
function time_loop() {

	debug_print

	echo -ne " "
	for ((j=1; j<=4; j++)); do
		echo -ne "."
		sleep 0.035
	done
}
function iptables_nftables_detection() {

	debug_print

	if ! "${AIRGEDDON_FORCE_IPTABLES:-false}"; then
		if hash nft 2> /dev/null; then
			iptables_nftables=1
		else
			iptables_nftables=0
		fi
	else
		if ! hash iptables 2> /dev/null && ! hash iptables-legacy 2> /dev/null; then
			echo
			language_strings "${language}" 615 "red"
			exit_code=1
			exit_script_option
		else
			iptables_nftables=0
		fi
	fi

	if [ "${iptables_nftables}" -eq 0 ]; then
		if hash iptables-legacy 2> /dev/null && ! hash iptables 2> /dev/null; then
			iptables_cmd="iptables-legacy"
		elif hash iptables 2> /dev/null && ! hash iptables-legacy 2> /dev/null; then
			iptables_cmd="iptables"
		elif hash iptables 2> /dev/null && hash iptables-legacy 2> /dev/null; then
			iptables_cmd="iptables"
		fi
	else
		iptables_cmd="nft"
	fi
}
function airmon_fix() {

	debug_print

	airmon="airmon-ng"

	if hash airmon-zc 2> /dev/null; then
		airmon="airmon-zc"
	fi
}
function set_hashcat_parameters() {

	debug_print

	hashcat_cmd_fix=""
	hashcat_charset_fix_needed=0
	if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat3_version}"; then

		hashcat_charset_fix_needed=1

		if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat4_version}"; then
			hashcat_cmd_fix=" -D 2,1 --force"
		else
			hashcat_cmd_fix=" --weak-hash-threshold 0 -D 2,1 --force"
		fi

		if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat_hccapx_version}"; then
			hccapx_needed=1
		fi

		if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat_hcx_conversion_version}"; then
			hcx_conversion_needed=1
		fi

		if compare_floats_greater_or_equal "${hashcat_version}" "${hashcat_2500_deprecated_version}"; then
			hashcat_handshake_cracking_plugin="22000"
		fi
	fi
}
function check_right_arping() {

	debug_print

	if arping 2> /dev/null | grep -Eq "^ARPing"; then
		return 0
	fi
	return 1
}
function validate_jtr() {

	debug_print

	if john -h 2> /dev/null | grep -qi '\-\-pot' 2> /dev/null; then
		return 0
	fi
	return 1
}
function get_aircrack_version() {

	debug_print

	aircrack_version=$(aircrack-ng --help | grep -i "aircrack-ng" | head -n 1 | awk '{print $2}')
	echo -e "    \r\033[1A"
	[[ ${aircrack_version} =~ ^([0-9]{1,2}\.[0-9]{1,2})\.?([0-9]+|.+)? ]] && aircrack_version="${BASH_REMATCH[1]}"
}
function get_jtr_version() {

	debug_print

	jtr_version=$(john | grep -Po '(?<=version )[0-9\.]+|(?<=John the Ripper )\d+\.\d+\.\d+')
}
function get_hashcat_version() {

	debug_print

	hashcat_version=$(hashcat -V 2> /dev/null)
	hashcat_version=${hashcat_version#"v"}
}
function get_hcxdumptool_version() {

	debug_print

	hcxdumptool_version=$(hcxdumptool --version | awk 'NR == 1 {print $2}')
}
function get_beef_version() {

	debug_print

	beef_version=$(grep "version" "${beef_path}${beef_default_cfg_file}" 2> /dev/null | grep -oE "[0-9.]+")
}
function get_bettercap_version() {

	debug_print

	bettercap_version=$(bettercap -v 2> /dev/null | grep -E "^bettercap [0-9]" | awk '{print $2}')
	if [ -z "${bettercap_version}" ]; then
		bettercap_version=$(bettercap -eval "q" 2> /dev/null | grep -E "bettercap v[0-9\.]*" | awk '{print $2}')
		bettercap_version=${bettercap_version#"v"}
	fi
}
function get_hostapd_version() {

	debug_print

	hostapd_version=$(hostapd -v 2>&1 | grep -oiP '^hostapd v\K[0-9]+\.[0-9]+')
}
function get_hostapd_wpe_version() {

	debug_print

	hostapd_wpe_version=$(hostapd-wpe -v 2>&1 | grep -oiP '^hostapd-WPE v\K[0-9]+\.[0-9]+')
}
function get_bully_version() {

	debug_print

	bully_version=$(bully -V 2> /dev/null)
	bully_version=${bully_version#"v"}
	bully_version=${bully_version%"-"*}
}
function get_reaver_version() {

	debug_print

	reaver_version=$(reaver -h 2>&1 > /dev/null | grep -E "^Reaver v[0-9]" | awk '{print $2}' | grep -Eo "v[0-9\.]+")
	if [ -z "${reaver_version}" ]; then
		reaver_version=$(reaver -h 2> /dev/null | grep -E "^Reaver v[0-9]" | awk '{print $2}' | grep -Eo "v[0-9\.]+")
	fi
	reaver_version=${reaver_version#"v"}
}
function set_bully_verbosity() {

	debug_print

	if compare_floats_greater_or_equal "${bully_version}" "${minimum_bully_verbosity4_version}"; then
		bully_verbosity="4"
	else
		bully_verbosity="3"
	fi
}
function validate_bully_pixiewps_version() {

	debug_print

	if compare_floats_greater_or_equal "${bully_version}" "${minimum_bully_pixiewps_version}"; then
		return 0
	fi
	return 1
}
function validate_reaver_pixiewps_version() {

	debug_print

	if compare_floats_greater_or_equal "${reaver_version}" "${minimum_reaver_pixiewps_version}"; then
		return 0
	fi
	return 1
}
function validate_reaver_nullpin_version() {

	debug_print

	if compare_floats_greater_or_equal "${reaver_version}" "${minimum_reaver_nullpin_version}"; then
		return 0
	fi
	return 1
}
function validate_wash_dualscan_version() {

	debug_print

	if compare_floats_greater_or_equal "${reaver_version}" "${minimum_wash_dualscan_version}"; then
		return 0
	fi
	return 1
}
function validate_aircrack_wpa3_version() {

	debug_print

	if compare_floats_greater_or_equal "${aircrack_version}" "${aircrack_wpa3_version}"; then
		return 0
	fi
	return 1
}
function validate_hashcat_pmkid_version() {

	debug_print

	if compare_floats_greater_or_equal "${hashcat_version}" "${minimum_hashcat_pmkid_version}"; then
		return 0
	fi
	return 1
}
function vm_detection() {

	debug_print

	_readfile() { [ -r "${1}" ] && tr -d '\0' < "${1}"; }
	_lowercase() { printf '%s' "$*" | tr '[:upper:]' '[:lower:]'; }

	local mac
	local dmi
	dmi="$(_readfile /sys/class/dmi/id/product_name) $(_readfile /sys/class/dmi/id/sys_vendor) $(_readfile /sys/class/dmi/id/bios_vendor) $(_readfile /sys/class/dmi/id/board_vendor) $(_readfile /sys/class/dmi/id/chassis_vendor)"
	dmi="${dmi,,}"

	case "${dmi}" in
		*virtualbox*|*innotek*gmbh*)
			is_vm=1
			vm_vendor="VirtualBox"
		;;
		*vmware*)
			is_vm=1
			vm_vendor="VMware"
		;;
		*kvm*|*qemu*|*bochs*|*"red hat"*|*rhev*)
			is_vm=1
			vm_vendor="Qemu"
		;;
	esac

	if [[ "${is_vm}" -eq 0 ]] && grep -qiE 'hypervisor' /proc/cpuinfo 2>/dev/null; then
		is_vm=1
	fi

	if [[ "${is_vm}" -eq 1 ]] && [[ "${vm_vendor}" = "" ]]; then
		for f in /sys/class/net/*/address; do
			[ -e "$f" ] || continue
			mac=$(cat "$f" 2>/dev/null | tr '[:lower:]' '[:upper:]')
			case "${mac}" in
				08:00:27:*)
					vm_vendor="VirtualBox"
					break
				;;
				00:05:69:*|00:0C:29:*|00:1C:14:*|00:50:56:*)
					vm_vendor="VMware"
					break
				;;
				52:54:00:*)
					vm_vendor="Qemu"
					break
				;;
			esac
		done
	fi

	if [ "${is_vm}" -eq 1 ]; then
		return 0
	else
		return 1
	fi
}
function set_script_paths() {

	debug_print

	if [ -z "${scriptfolder}" ]; then
		scriptfolder=${0}

		if ! [[ ${0} =~ ^/.*$ ]]; then
			if ! [[ ${0} =~ ^.*/.*$ ]]; then
				scriptfolder="./"
			fi
		fi
		scriptfolder="${scriptfolder%/*}/"
		scriptfolder="$(readlink -f "${scriptfolder}")"
		scriptfolder="${scriptfolder%/}/"
		scriptname="${0##*/}"
	fi

	user_homedir=$(env | grep ^HOME | awk -F = '{print $2}' 2> /dev/null)
	lastcharuser_homedir=${user_homedir: -1}
	if [ "${lastcharuser_homedir}" != "/" ]; then
		user_homedir="${user_homedir}/"
	fi

	plugins_paths=(
					"${scriptfolder}${plugins_dir}"
					"${user_homedir}.airgeddon/${plugins_dir}"
				)
}
function set_default_save_path() {

	debug_print

	if [ "${is_docker}" -eq 1 ]; then
		default_save_path="${docker_io_dir}"
	else
		default_save_path="${user_homedir}"
	fi
}
function set_absolute_path() {

	debug_print

	local string_path
	string_path=$(readlink -f "${1}")
	if [ -d "${string_path}" ]; then
		string_path="${string_path%/}/"
	fi
	echo "${string_path}"
}
function check_pins_database_file() {

	debug_print

	if [ -f "${scriptfolder}${known_pins_dbfile}" ]; then
		language_strings "${language}" 376 "yellow"
		echo
		language_strings "${language}" 287 "blue"
		if check_repository_access; then
			get_local_pin_dbfile_checksum "${scriptfolder}${known_pins_dbfile}"
			if ! get_remote_pin_dbfile_checksum; then
				echo
				language_strings "${language}" 381 "yellow"
			else
				echo
				if [ "${local_pin_dbfile_checksum}" != "${remote_pin_dbfile_checksum}" ]; then
					language_strings "${language}" 383 "yellow"
					echo
					if download_pins_database_file; then
						language_strings "${language}" 377 "yellow"
						pin_dbfile_checked=1
					else
						language_strings "${language}" 378 "yellow"
					fi
				else
					language_strings "${language}" 382 "yellow"
					pin_dbfile_checked=1
				fi
			fi
		else
			echo
			language_strings "${language}" 375 "yellow"
			ask_for_pin_dbfile_download_retry
		fi
		return 0
	else
		language_strings "${language}" 374 "yellow"
		echo
		if hash curl 2> /dev/null; then
			language_strings "${language}" 287 "blue"
			if ! check_repository_access; then
				echo
				language_strings "${language}" 375 "yellow"
				return 1
			else
				echo
				if download_pins_database_file; then
					language_strings "${language}" 377 "yellow"
					pin_dbfile_checked=1
					return 0
				else
					language_strings "${language}" 378 "yellow"
					return 1
				fi
			fi
		else
			language_strings "${language}" 414 "yellow"
			return 1
		fi
	fi
}
function update_options_config_file() {

	debug_print

	case "${1}" in
		"getdata")
			readarray -t OPTION_VARS < <(grep "AIRGEDDON_" "${rc_path}" 2> /dev/null)
		;;
		"writedata")
			local option_name
			local option_value
			for item in "${OPTION_VARS[@]}"; do
				option_name="${item%=*}"
				option_value="${item#*=}"
				for item2 in "${ordered_options_env_vars[@]}"; do
					if [ "${item2}" = "${option_name}" ]; then
						sed -ri "s:(${option_name})=(.+):\1=${option_value}:" "${rc_path}" 2> /dev/null
					fi
				done
			done
		;;
	esac
}
function download_options_config_file() {

	debug_print

	local options_config_file_downloaded=0
	options_config_file=$(timeout -s SIGTERM 15 curl -L ${urlscript_options_config_file} 2> /dev/null)

	if [[ -n "${options_config_file}" ]] && [[ "${options_config_file}" != "${curl_404_error}" ]]; then
		options_config_file_downloaded=1
	else
		http_proxy_detect
		if [ "${http_proxy_set}" -eq 1 ]; then

			options_config_file=$(timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_options_config_file} 2> /dev/null)
			if [[ -n "${options_config_file}" ]] && [[ "${options_config_file}" != "${curl_404_error}" ]]; then
				options_config_file_downloaded=1
			fi
		fi
	fi

	if [ "${options_config_file_downloaded}" -eq 1 ]; then
		rm -rf "${rc_path}" 2> /dev/null
		echo "${options_config_file}" > "${rc_path}"
		return 0
	else
		return 1
	fi
}
function download_pins_database_file() {

	debug_print

	local pindb_file_downloaded=0
	remote_pindb_file=$(timeout -s SIGTERM 15 curl -L ${urlscript_pins_dbfile} 2> /dev/null)

	if [[ -n "${remote_pindb_file}" ]] && [[ "${remote_pindb_file}" != "${curl_404_error}" ]]; then
		pindb_file_downloaded=1
	else
		http_proxy_detect
		if [ "${http_proxy_set}" -eq 1 ]; then

			remote_pindb_file=$(timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_pins_dbfile} 2> /dev/null)
			if [[ -n "${remote_pindb_file}" ]] && [[ "${remote_pindb_file}" != "${curl_404_error}" ]]; then
				pindb_file_downloaded=1
			fi
		fi
	fi

	if [ "${pindb_file_downloaded}" -eq 1 ]; then
		rm -rf "${scriptfolder}${known_pins_dbfile}" 2> /dev/null
		echo "${remote_pindb_file}" > "${scriptfolder}${known_pins_dbfile}"
		return 0
	else
		return 1
	fi
}
function ask_for_pin_dbfile_download_retry() {

	debug_print

	ask_yesno 380 "no"
	if [ "${yesno}" = "n" ]; then
		pin_dbfile_checked=1
	fi
}
function get_local_pin_dbfile_checksum() {

	debug_print

	local_pin_dbfile_checksum=$(md5sum "${1}" | awk '{print $1}')
}
function get_remote_pin_dbfile_checksum() {

	debug_print

	remote_pin_dbfile_checksum=$(timeout -s SIGTERM 15 curl -L ${urlscript_pins_dbfile_checksum} 2> /dev/null | head -n 1)

	if [[ -n "${remote_pin_dbfile_checksum}" ]] && [[ "${remote_pin_dbfile_checksum}" != "${curl_404_error}" ]]; then
		return 0
	else
		http_proxy_detect
		if [ "${http_proxy_set}" -eq 1 ]; then

			remote_pin_dbfile_checksum=$(timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_pins_dbfile_checksum} 2> /dev/null | head -n 1)
			if [[ -n "${remote_pin_dbfile_checksum}" ]] && [[ "${remote_pin_dbfile_checksum}" != "${curl_404_error}" ]]; then
				return 0
			fi
		fi
	fi
	return 1
}
function non_linux_os_check() {

	debug_print

	case "${OSTYPE}" in
		solaris*)
			distro="Solaris"
		;;
		darwin*)
			distro="Mac OSX"
		;;
		bsd*)
			distro="FreeBSD"
		;;
	esac
}
function detect_distro_phase1() {

	debug_print

	local possible_distro=""
	for i in "${known_compatible_distros[@]}"; do
		if uname -a | grep -i "${i}" > /dev/null; then
			possible_distro="${i^}"
			if [ "${possible_distro}" != "Arch" ]; then
				if [[ "$(uname -a)" =~ [Rr]pi ]]; then
					distro="Raspberry Pi OS"
				else
					distro="${i^}"
				fi
				break
			else
				if uname -a | grep -i "aarch64" > /dev/null; then
					continue
				else
					distro="${i^}"
					break
				fi
			fi
		fi
	done

	for i in "${known_incompatible_distros[@]}"; do
		if uname -a | grep -i "${i}" > /dev/null; then
			distro="${i^}"
			break
		fi
	done
}
function detect_distro_phase2() {

	debug_print

	if [ "${distro}" = "Unknown Linux" ]; then
		if [ -f "${osversionfile_dir}centos-release" ]; then
			distro="CentOS"
		elif [ -f "${osversionfile_dir}fedora-release" ]; then
			distro="Fedora"
		elif [ -f "${osversionfile_dir}gentoo-release" ]; then
			distro="Gentoo"
		elif [ -f "${osversionfile_dir}cachyos-release" ]; then
			distro="CachyOS"
		elif [ -f "${osversionfile_dir}openmandriva-release" ]; then
			distro="OpenMandriva"
		elif [ -f "${osversionfile_dir}redhat-release" ]; then
			distro="Red Hat"
		elif [ -f "${osversionfile_dir}SuSE-release" ]; then
			distro="SuSE"
		elif [ -f "${osversionfile_dir}debian_version" ]; then
			distro="Debian"
			if [ -f "${osversionfile_dir}os-release" ]; then
				extra_os_info="$(grep "PRETTY_NAME" < "${osversionfile_dir}os-release")"
				if [[ "${extra_os_info}" =~ [Rr]aspbian ]]; then
					distro="Raspbian"
					is_arm=1
				elif [[ "${extra_os_info}" =~ [Pp]arrot ]]; then
					distro="Parrot arm"
					is_arm=1
				elif [[ "${extra_os_info}" =~ [Dd]ebian ]] && [[ "$(uname -a)" =~ [Rr]aspberry|[Rr]pi ]]; then
					distro="Raspberry Pi OS"
					is_arm=1
				fi
			fi
		fi
	elif [ "${distro}" = "Arch" ]; then
		if [ -f "${osversionfile_dir}os-release" ]; then
			extra_os_info="$(grep "PRETTY_NAME" < "${osversionfile_dir}os-release")"
			extra_os_info2="$(grep -i "blackarch" < "${osversionfile_dir}issue")"
			if [[ "${extra_os_info}" =~ [Bb]lack[Aa]rch ]] || [[ "${extra_os_info2}" =~ [Bb]lack[Aa]rch ]]; then
				distro="BlackArch"
			fi
		fi
	elif [ "${distro}" = "Ubuntu" ]; then
		if [ -f "${osversionfile_dir}os-release" ]; then
			extra_os_info="$(grep "PRETTY_NAME" < "${osversionfile_dir}os-release")"
			if [[ "${extra_os_info}" =~ [Mm]int ]]; then
				distro="Mint"
			fi
		fi
	fi

	detect_arm_architecture
}
function detect_arm_architecture() {

	debug_print

	distro_already_known=0
	if uname -m | grep -Ei "arm|aarch64" > /dev/null; then

		is_arm=1
		if [ "${distro}" != "Unknown Linux" ]; then
			for item in "${known_arm_compatible_distros[@]}"; do
				if [ "${distro}" = "${item}" ]; then
					distro_already_known=1
				fi
			done
		fi

		if [ "${distro_already_known}" -eq 0 ]; then
			if [ "${distro: -3}" != "arm" ]; then
				distro="${distro} arm"
			fi
		fi
	fi
}
function special_distro_features() {

	debug_print

	case ${distro} in
		"Wifislax")
			networkmanager_cmd="service restart networkmanager"
			xratio=7
			yratio=15.1
			ywindow_edge_lines=1
			ywindow_edge_pixels=-14
		;;
		"Backbox")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6
			yratio=14.2
			ywindow_edge_lines=1
			ywindow_edge_pixels=15
		;;
		"Ubuntu"|"Mint")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=18
		;;
		"Kali"|"Kali arm")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=18
		;;
		"Debian")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=14
		;;
		"SuSE")
			networkmanager_cmd="service NetworkManager restart"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=18
		;;
		"CentOS")
			networkmanager_cmd="service NetworkManager restart"
			xratio=6.2
			yratio=14.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=10
		;;
		"Parrot"|"Parrot arm")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=10
		;;
		"Arch"|"CachyOS")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=13.9
			ywindow_edge_lines=2
			ywindow_edge_pixels=16
		;;
		"Fedora")
			networkmanager_cmd="service NetworkManager restart"
			xratio=6
			yratio=14.1
			ywindow_edge_lines=2
			ywindow_edge_pixels=16
		;;
		"Gentoo")
			networkmanager_cmd="service NetworkManager restart"
			xratio=6.2
			yratio=14.6
			ywindow_edge_lines=1
			ywindow_edge_pixels=-10
		;;
		"Pentoo")
			networkmanager_cmd="rc-service NetworkManager restart"
			xratio=6.2
			yratio=14.6
			ywindow_edge_lines=1
			ywindow_edge_pixels=-10
		;;
		"Red Hat")
			networkmanager_cmd="service NetworkManager restart"
			xratio=6.2
			yratio=15.3
			ywindow_edge_lines=1
			ywindow_edge_pixels=10
		;;
		"Cyborg")
			networkmanager_cmd="service network-manager restart"
			xratio=6.2
			yratio=14.5
			ywindow_edge_lines=2
			ywindow_edge_pixels=10
		;;
		"BlackArch")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=8
			yratio=18
			ywindow_edge_lines=1
			ywindow_edge_pixels=1
		;;
		"Raspbian|Raspberry Pi OS")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=14
			ywindow_edge_lines=1
			ywindow_edge_pixels=20
		;;
		"OpenMandriva")
			networkmanager_cmd="systemctl restart NetworkManager.service"
			xratio=6.2
			yratio=14
			ywindow_edge_lines=2
			ywindow_edge_pixels=-10
		;;
	esac
}
function check_if_kill_needed() {

	debug_print

	nm_min_main_version="1"
	nm_min_subversion="0"
	nm_min_subversion2="12"

	if ! hash NetworkManager 2> /dev/null; then
		check_kill_needed=0
	else
		nm_system_version=$(NetworkManager --version 2> /dev/null)

		if [ "${nm_system_version}" != "" ]; then

			[[ ${nm_system_version} =~ ^([0-9]{1,2})\.([0-9]{1,2})\.?(([0-9]+)|.+)? ]] && nm_main_system_version="${BASH_REMATCH[1]}" && nm_system_subversion="${BASH_REMATCH[2]}" && nm_system_subversion2="${BASH_REMATCH[3]}"

			[[ ${nm_system_subversion2} =~ [a-zA-Z] ]] && nm_system_subversion2="0"

			if [ "${nm_main_system_version}" -lt ${nm_min_main_version} ]; then
				check_kill_needed=1
			elif [ "${nm_main_system_version}" -eq ${nm_min_main_version} ]; then

				if [ "${nm_system_subversion}" -lt ${nm_min_subversion} ]; then
					check_kill_needed=1
				elif [ "${nm_system_subversion}" -eq ${nm_min_subversion} ]; then

					if [ "${nm_system_subversion2}" -lt ${nm_min_subversion2} ]; then
						check_kill_needed=1
					fi
				fi
			fi
		else
			check_kill_needed=1
		fi
	fi
}
function check_root_permissions() {

	debug_print

	user=$(whoami)

	if [ "${user}" = "root" ]; then
		if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
			echo
			language_strings "${language}" 484 "yellow"
		fi
	else
		echo
		language_strings "${language}" 223 "red"
		exit_code=1
		exit_script_option
	fi
}
function check_compatibility() {

	debug_print

	local term_width
	local column_width
	local columns
	term_width=$(tput cols 2> /dev/null || echo 80)
	column_width=26
	columns=$(( term_width / column_width ))
	(( columns < 1 )) && columns=1

	if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
		echo
		language_strings "${language}" 108 "blue"
		language_strings "${language}" 115 "read"
		echo
		language_strings "${language}" 109 "blue"
	fi

	essential_toolsok=1
	local ok_essential_tools=()
	local error_essential_tools=()

	for i in "${essential_tools_names[@]}"; do
		if hash "${i}" 2> /dev/null; then
			ok_essential_tools+=("${i}")
		else
			error_essential_tools+=("${i}")
			essential_toolsok=0
		fi
	done

	if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
		counter=0
		for i in "${ok_essential_tools[@]}"; do
			printf "%-14s" "${i}"
			time_loop
			printf " "; printf "${green_color}Ok${normal_color}"
			((counter++))
			if (( counter % columns == 0 )); then
				echo
			else
				printf "    "
			fi
		done
		if (( counter % columns != 0 )); then
			echo
		fi

		for i in "${error_essential_tools[@]}"; do
			printf "%-14s" "${i}"
			time_loop
			printf " "; printf "${red_color}Error${normal_color}"
			echo -n " (${possible_package_names_text[${language}]} : ${possible_package_names[${i}]})"
			echo
		done
	fi

	if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
		echo
		language_strings "${language}" 218 "blue"
	fi

	optional_toolsok=1
	local ok_optional_tools=()
	local error_optional_tools=()

	for i in "${!optional_tools[@]}"; do
		if hash "${i}" 2> /dev/null; then
			if [ "${i}" = "beef" ]; then
				detect_fake_beef
				if [ "${fake_beef_found}" -eq 1 ]; then
					error_optional_tools+=("${i}")
					optional_toolsok=0
					continue
				fi
			fi
			optional_tools[${i}]=1
			ok_optional_tools+=("${i}")
		else
			error_optional_tools+=("${i}")
			optional_toolsok=0
		fi
	done

	if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
		counter=0
		for i in "${ok_optional_tools[@]}"; do
			printf "%-14s" "${i}"
			time_loop
			printf " "; printf "${green_color}Ok${normal_color}"
			((counter++))
			if (( counter % columns == 0 )); then
				echo
			else
				printf "    "
			fi
		done
		if (( counter % columns != 0 )); then
			echo
		fi

		for i in "${error_optional_tools[@]}"; do
			printf "%-14s" "${i}"
			time_loop
			printf " "; printf "${red_color}Error${normal_color}"
			echo -n " (${possible_package_names_text[${language}]} : ${possible_package_names[${i}]})"
			echo
		done
	fi

	update_toolsok=1
	if "${AIRGEDDON_AUTO_UPDATE:-true}"; then
		if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
			echo
			language_strings "${language}" 226 "blue"
		fi

		local ok_update_tools=()
		local error_update_tools=()

		for i in "${update_tools[@]}"; do
			if hash "${i}" 2> /dev/null; then
				ok_update_tools+=("${i}")
			else
				error_update_tools+=("${i}")
				update_toolsok=0
			fi
		done

		if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
			counter=0
			for i in "${ok_update_tools[@]}"; do
				printf "%-14s" "${i}"
				time_loop
				printf " "; printf "${green_color}Ok${normal_color}"
				((counter++))
				if (( counter % columns == 0 )); then
					echo
				else
					printf "    "
				fi
			done
			if (( counter % columns != 0 )); then
				echo
			fi

			for i in "${error_update_tools[@]}"; do
				printf "%-14s" "${i}"
				time_loop
				printf " "; printf "${red_color}Error${normal_color}"
				echo -n " (${possible_package_names_text[${language}]} : ${possible_package_names[${i}]})"
				echo
			done
		fi
	fi

	if [ "${essential_toolsok}" -eq 0 ]; then
		echo
		language_strings "${language}" 111 "red"
		echo
		if "${AIRGEDDON_SILENT_CHECKS:-true}"; then
			language_strings "${language}" 581 "blue"
			echo
		fi
		language_strings "${language}" 115 "read"
		return
	fi

	compatible=1

	if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
		if [ "${optional_toolsok}" -eq 0 ]; then
			echo
			language_strings "${language}" 219 "yellow"

			if [ "${fake_beef_found}" -eq 1 ]; then
				echo
				language_strings "${language}" 401 "red"
				echo
			fi
			return
		fi

		echo
		language_strings "${language}" 110 "yellow"
	fi
}
function check_bash_version() {

	debug_print

	bashversion="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
	if compare_floats_greater_or_equal "${bashversion}" ${minimum_bash_version_required}; then
		if ! "${AIRGEDDON_SILENT_CHECKS:-false}"; then
			echo
			language_strings "${language}" 221 "yellow"
		fi
	else
		echo
		language_strings "${language}" 222 "red"
		exit_code=1
		exit_script_option
	fi
}
function check_update_tools() {

	debug_print

	if "${AIRGEDDON_AUTO_UPDATE:-true}"; then
		if [ "${is_docker}" -eq 1 ]; then
			echo
			language_strings "${language}" 422 "blue"
			language_strings "${language}" 115 "read"
		else
			if [ "${update_toolsok}" -eq 1 ]; then
				autoupdate_check
			else
				echo
				language_strings "${language}" 225 "yellow"
				language_strings "${language}" 115 "read"
			fi
		fi
	fi
}
function update_ui_layout_on_keypress() {

	debug_print

	animated_flying_saucer_window_correction
}
function check_window_size_for_intro() {

	debug_print

	window_width=$(tput cols)
	window_height=$(tput lines)

	if [ "${window_width}" -lt 69 ]; then
		return 1
	elif [[ "${window_width}" -ge 69 ]] && [[ "${window_width}" -le 80 ]]; then
		if [ "${window_height}" -lt 20 ]; then
			return 1
		fi
	else
		if [ "${window_height}" -lt 19 ]; then
			return 1
		fi
	fi

	return 0
}
function graphics_prerequisites() {

	debug_print

	if [ "${is_docker}" -eq 0 ]; then
		if hash loginctl 2> /dev/null && [[ ! "$(loginctl 2>&1)" =~ not[[:blank:]]been[[:blank:]]booted[[:blank:]]with[[:blank:]]systemd|Host[[:blank:]]is[[:blank:]]down ]]; then
			graphics_system=$(loginctl show-session "$(loginctl 2> /dev/null | awk 'FNR == 2 {print $1}')" -p Type 2> /dev/null | awk -F "=" '{print $2}')
		else
			if [ -z "${XDG_SESSION_TYPE}" ]; then
				if [ -n "${XDG_CURRENT_DESKTOP}" ]; then
					graphics_system="x11"
				fi
			else
				graphics_system="${XDG_SESSION_TYPE}"
			fi
		fi
	else
		graphics_system="${XDG_SESSION_TYPE}"
	fi
}
function check_graphics_system() {

	debug_print

	case "${graphics_system}" in
		"x11"|"wayland")
			if hash xset 2> /dev/null; then
				if ! xset -q > /dev/null 2>&1; then
					xterm_ok=0
				fi
			fi
		;;
		"tty"|*)
			if [ -z "${XAUTHORITY}" ]; then
				xterm_ok=0
				if hash xset 2> /dev/null; then
					if xset -q > /dev/null 2>&1; then
						xterm_ok=1
					fi
				fi
			fi
		;;
	esac
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
function set_windows_sizes() {

	debug_print

	set_xsizes
	set_ysizes
	set_ypositions

	g1_topleft_window="${xwindow}x${ywindowhalf}+0+0"
	g1_bottomleft_window="${xwindow}x${ywindowhalf}+0-0"
	g1_topright_window="${xwindow}x${ywindowhalf}-0+0"
	g1_bottomright_window="${xwindow}x${ywindowhalf}-0-0"

	g2_stdleft_window="${xwindow}x${ywindowone}+0+0"
	g2_stdright_window="${xwindow}x${ywindowone}-0+0"

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

	g5_left1="${xwindow}x${ywindowseventh}+0+0"
	g5_left2="${xwindow}x${ywindowseventh}+0+${second_of_seven_position}"
	g5_left3="${xwindow}x${ywindowseventh}+0+${third_of_seven_position}"
	g5_left4="${xwindow}x${ywindowseventh}+0+${fourth_of_seven_position}"
	g5_left5="${xwindow}x${ywindowseventh}+0+${fifth_of_seven_position}"
	g5_left6="${xwindow}x${ywindowseventh}+0+${sixth_of_seven_position}"
	g5_left7="${xwindow}x${ywindowseventh}+0+${seventh_of_seven_position}"
	g5_topright_window="${xwindow}x${ywindowhalf}-0+0"
	g5_bottomright_window="${xwindow}x${ywindowhalf}-0-0"
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
function recalculate_windows_sizes() {

	debug_print

	detect_screen_resolution
	set_windows_sizes
}
function docker_detection() {

	debug_print

	if [ -f /.dockerenv ]; then
		is_docker=1
	fi
}
function initialize_sounds() {

	debug_print

	able_to_play_sounds=0
	if "${AIRGEDDON_EVIL_TWIN_SOUNDS:-true}"; then
		if hash play 2> /dev/null; then
			able_to_play_sounds=1
		fi
	fi
}
function initialize_extended_colorized_output() {

	debug_print

	colorize=""
	if "${AIRGEDDON_BASIC_COLORS:-true}" && "${AIRGEDDON_EXTENDED_COLORS:-true}"; then
		if hash ccze 2> /dev/null; then
			colorize="| ccze -A"
		fi
	fi
}
function remap_colors() {

	debug_print

	if ! "${AIRGEDDON_BASIC_COLORS:-true}"; then
		green_color="${normal_color}"
		green_color_title="${normal_color}"
		red_color="${normal_color}"
		red_color_slim="${normal_color}"
		blue_color="${normal_color}"
		cyan_color="${normal_color}"
		brown_color="${normal_color}"
		yellow_color="${normal_color}"
		pink_color="${normal_color}"
		white_color="${normal_color}"
	else
		initialize_colors
	fi
}
function initialize_colors() {

	debug_print

	normal_color="\e[1;0m"
	green_color="\033[1;32m"
	green_color_title="\033[0;32m"
	red_color="\033[1;31m"
	red_color_slim="\033[0;031m"
	blue_color="\033[1;34m"
	cyan_color="\033[1;36m"
	brown_color="\033[0;33m"
	yellow_color="\033[1;33m"
	pink_color="\033[1;35m"
	white_color="\e[1;97m"
}
function kill_tmux_session() {

	debug_print

	if hash tmux 2> /dev/null; then
		tmux kill-session -t "${1}"
		return 0
	else
		return 1
	fi
}
function initialize_tmux() {

	debug_print

	if [ "${1}" = "true" ]; then
		if [ -n "${2}" ]; then
			airgeddon_uid="${2}"
		else
			exit ${exit_code}
		fi
	else
		airgeddon_uid="${BASHPID}"
	fi

	session_name="airgeddon${airgeddon_uid}"

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		if hash tmux 2> /dev/null; then
			transfer_to_tmux
			if ! check_inside_tmux; then
				exit_code=1
				exit ${exit_code}
			fi
		fi
	fi
}
function start_airgeddon_from_tmux() {

	debug_print

	tmux rename-window -t "${session_name}" "${tmux_main_window}"
	tmux send-keys -t "${session_name}:${tmux_main_window}" "clear;cd ${scriptfolder};bash ${scriptname} \"true\" \"${airgeddon_uid}\"" ENTER
	sleep 0.2
	if [ "${1}" = "normal" ]; then
		tmux attach -t "${session_name}"
	else
		tmux switch-client -t "${session_name}"
	fi
}
function create_tmux_session() {

	debug_print

	session_name="${1}"

	if [ "${2}" = "true" ]; then
		tmux new-session -d -s "${1}"
		start_airgeddon_from_tmux "normal"
	else
		tmux new-session -d -s "${1}"
		start_airgeddon_from_tmux "nested"
	fi
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
function check_inside_tmux() {

	debug_print

	local parent_pid
	local parent_window
	parent_pid=$(ps -o ppid= ${PPID} 2> /dev/null | tr -d ' ')
	parent_window="$(ps --no-headers -p "${parent_pid}" -o comm= 2> /dev/null)"
	if [[ "${parent_window}" =~ tmux ]]; then
		return 0
	fi
	return 1
}
function transfer_to_tmux() {

	debug_print

	if ! check_inside_tmux; then
		create_tmux_session "${session_name}" "true"
	else
		local active_session
		active_session=$(tmux display-message -p '#S')
		if [ "${active_session}" != "${session_name}" ]; then
			tmux_error=1
		fi
	fi
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
function wait_for_process() {

	debug_print

	local running_process
	local running_process_pid
	local running_process_cmd_line
	running_process_cmd_line=$(echo "${1}" | tr -d '"')

	while [ -z "${running_process_pid}" ]; do
		running_process_pid=$(ps --no-headers auxww | grep "${running_process_cmd_line}" | grep -v "grep ${running_process_cmd_line}" | awk '{print $2}' | tr '\n' ':')
		if [ -n "${running_process_pid}" ]; then
			running_process_pid="${running_process_pid%%:*}"
			running_process="${running_process_pid}"
		fi
	done

	while [ -n "${running_process}" ]; do
		running_process=$(ps auxww | grep "${running_process_pid}" | grep -v "grep ${running_process_pid}")
		sleep 0.2
	done

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		tmux kill-window -t "${session_name}:${2}"
	fi
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
function parse_plugins() {

	plugins_enabled=()

	shopt -s nullglob
	for path in "${plugins_paths[@]}"; do
		if [ -d "${path}" ]; then
			for file in "${path}"*.sh; do
				if [ "${file}" != "${path}plugin_template.sh" ]; then

					plugin_short_name="${file##*/}"
					plugin_short_name="${plugin_short_name%.sh*}"

					if grep -q -E "^plugin_enabled=1$" "${file}"; then

						#shellcheck source=./plugins/missing_dependencies.sh
						source "${file}" "$@"

						validate_plugin_requirements
						plugin_validation_result=$?
						if [ "${plugin_validation_result}" -eq 0 ]; then
							plugins_enabled+=("${plugin_short_name}")
						fi
					fi
				fi
			done
		fi
	done
	shopt -u nullglob
}
function validate_plugin_requirements() {

	if [ -n "${plugin_minimum_ag_affected_version}" ]; then
		if compare_floats_greater_than "${plugin_minimum_ag_affected_version}" "${airgeddon_version}"; then
			return 1
		fi
	fi

	if [ -n "${plugin_maximum_ag_affected_version}" ]; then
		if compare_floats_greater_than "${airgeddon_version}" "${plugin_maximum_ag_affected_version}"; then
			return 1
		fi
	fi

	if [ "${plugin_distros_supported[0]}" != "*" ]; then

		for item in "${plugin_distros_supported[@]}"; do
			if [ "${item}" = "${distro}" ]; then
				return 0
			fi
		done

		return 2
	fi

	return 0
}
function apply_plugin_functions_rewriting() {

	declare -A function_hooks

	local original_function
	local action
	local is_hookable

	for plugin in "${plugins_enabled[@]}"; do
		for current_function in $(compgen -A 'function' "${plugin}_" | grep -e "[override|prehook|posthook]"); do
			original_function=$(echo ${current_function} | sed "s/^${plugin}_\(override\)*\(prehook\)*\(posthook\)*_//")
			action=$(echo ${current_function} | sed "s/^${plugin}_\(override\)*\(prehook\)*\(posthook\)*_.*$/\1\2\3/")

			if ! declare -F ${original_function} &> /dev/null; then
				echo
				language_strings "${language}" 659 "red"
				exit_code=1
				exit_script_option
			fi

			is_hookable=false
			if [[ "${original_function}" == *"hookable"* ]]; then
				is_hookable=true
			fi

			if [[ "${is_hookable}" == false ]] && [[ -n "${function_hooks[${original_function},${action}]}" ]]; then
				echo
				language_strings "${language}" 661 "red"
				exit_code=1
				exit_script_option
			fi

			if ! printf '%s\n' "${hooked_functions[@]}" | grep -x -q "${original_function}"; then
				hooked_functions+=("${original_function}")
			fi

			if [[ "${is_hookable}" == true ]]; then
				function_hooks[${original_function},${action},${plugin}]=1
			else
				function_hooks[${original_function},${action}]=${plugin}
			fi
		done
	done

	local function_modifications
	local arguments
	local actions=("prehook" "override" "posthook")
	local hook_found

	for current_function in "${hooked_functions[@]}"; do
		arguments="${current_function} "
		function_modifications=$(declare -f ${current_function} | sed "1c${current_function}_original ()")

		for action in "${actions[@]}"; do
			hook_found=false

			if [[ "${current_function}" == *"hookable"* ]]; then
				for plugin_key in "${!function_hooks[@]}"; do
					if [[ "${plugin_key}" == "${current_function},${action},"* ]]; then
						hook_found=true
						plugin_name="${plugin_key##*,}"
						function_name="${plugin_name}_${action}_${current_function}"
						function_modifications+=$'\n'"$(declare -f ${function_name} | sed "1c${current_function}_${action}_${plugin_name} ()")"
					fi
				done
			else
				if [[ -n "${function_hooks[${current_function},${action}]}" ]]; then
					hook_found=true
					plugin_name="${function_hooks[${current_function},${action}]}"
					function_name="${plugin_name}_${action}_${current_function}"
					function_modifications+=$'\n'"$(declare -f ${function_name} | sed "1c${current_function}_${action} ()")"
				fi
			fi

			if [[ "$hook_found" == true ]]; then
				arguments+="true "
			else
				arguments+="false "
			fi
		done

		arguments+="\"\${@}\""
		function_modifications+=$'\n'"${current_function} () {"$'\n'" plugin_function_call_handler ${arguments}"$'\n'"}"
		eval "${function_modifications}"
	done
}
function plugin_function_call_handler() {

	local function_name=${1}
	local prehook_enabled=${2}
	local override_enabled=${3}
	local posthook_enabled=${4}
	local is_hookable=false
	local function_call="${function_name}_original"

	if [[ "${function_name}" == *"hookable"* ]]; then
		is_hookable=true
	fi

	if [ "${prehook_enabled}" = true ]; then
		if [[ "${is_hookable}" == true ]]; then
			for hook_func in $(declare -F | awk '{print $3}' | grep -E "_prehook_${function_name}$"); do
				${hook_func} "${@:5}"
			done
		else
			local prehook_funcion_name="${function_name}_prehook"
			${prehook_funcion_name} "${@:5}"
		fi
	fi

	if [ "${override_enabled}" = true ]; then
		if [[ "${is_hookable}" == true ]]; then
			for hook_func in $(declare -F | awk '{print $3}' | grep -E "_override_${function_name}$"); do
				${hook_func} "${@:5}"
			done
			return $?
		else
			function_call="${function_name}_override"
		fi
	fi

	${function_call} "${@:5}"
	local result=$?

	if [ "${posthook_enabled}" = true ]; then
		if [[ "${is_hookable}" == true ]]; then
			for hook_func in $(declare -F | awk '{print $3}' | grep -E "_posthook_${function_name}$"); do
				${hook_func} ${result}
				result=$?
			done
		else
			local posthook_funcion_name="${function_name}_posthook"
			${posthook_funcion_name} ${result}
			result=$?
		fi
	fi

	return ${result}
}
function airmonzc_security_check() {

	debug_print

	if [ "${airmon}" = "airmon-zc" ]; then
		if ! hash ethtool 2> /dev/null; then
			echo
			language_strings "${language}" 247 "red"
			echo
			language_strings "${language}" 115 "read"
			exit_code=1
			exit_script_option
		fi
	fi
}
function compare_floats_greater_than() {

	debug_print

	awk -v n1="${1}" -v n2="${2}" 'BEGIN{if (n1>n2) exit 0; exit 1}'
}
function compare_floats_greater_or_equal() {

	debug_print

	awk -v n1="${1}" -v n2="${2}" 'BEGIN{if (n1>=n2) exit 0; exit 1}'
}
function download_last_version() {

	debug_print

	rewrite_script_with_custom_beef "search"

	local script_file_downloaded=0

	if download_language_strings_file; then

		get_current_permanent_language

		if timeout -s SIGTERM 15 curl -L ${urlscript_directlink} -s -o "${0}"; then
			script_file_downloaded=1
		else
			http_proxy_detect
			if [ "${http_proxy_set}" -eq 1 ]; then

				if timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_directlink} -s -o "${0}"; then
					script_file_downloaded=1
				fi
			fi
		fi
	fi

	if [ "${script_file_downloaded}" -eq 1 ]; then

		download_pins_database_file

		update_options_config_file "getdata"
		download_options_config_file
		update_options_config_file "writedata"

		echo
		language_strings "${language}" 214 "yellow"

		if [ -n "${beef_custom_path}" ]; then
			rewrite_script_with_custom_beef "set" "${beef_custom_path}"
		fi

		sed -ri "s:^([l]anguage)=\"[a-zA-Z]+\":\1=\"${current_permanent_language}\":" "${scriptfolder}${scriptname}" 2> /dev/null

		language_strings "${language}" 115 "read"
		chmod +x "${scriptfolder}${scriptname}" > /dev/null 2>&1
		exec "${scriptfolder}${scriptname}"
	else
		language_strings "${language}" 5 "yellow"
	fi
}
function check_repository_access() {

	debug_print

	if hash curl 2> /dev/null; then

		if check_url_curl "https://${repository_hostname}"; then
			return 0
		fi
	fi
	return 1
}
function check_internet_access() {

	debug_print

	for item in "${ips_to_check_internet[@]}"; do
		if ping -c 1 "${item}" -W 1 > /dev/null 2>&1; then
			return 0
		fi
	done

	if hash curl 2> /dev/null; then
		if check_url_curl "https://${repository_hostname}"; then
			return 0
		fi
	fi

	if hash wget 2> /dev/null; then
		if check_url_wget "https://${repository_hostname}"; then
			return 0
		fi
	fi

	return 1
}
function check_url_curl() {

	debug_print

	if timeout -s SIGTERM 15 curl -s "${1}" > /dev/null 2>&1; then
		return 0
	fi

	http_proxy_detect
	if [ "${http_proxy_set}" -eq 1 ]; then
		timeout -s SIGTERM 15 curl -s --proxy "${http_proxy}" "${1}" > /dev/null 2>&1
		return $?
	fi
	return 1
}
function check_url_wget() {

	debug_print

	if timeout -s SIGTERM 15 wget -q --spider "${1}" > /dev/null 2>&1; then
		return 0
	fi

	http_proxy_detect
	if [ "${http_proxy_set}" -eq 1 ]; then
		timeout -s SIGTERM 15 wget -q --spider -e "use_proxy=yes" -e "http_proxy=${http_proxy}" "${1}" > /dev/null 2>&1
		return $?
	fi
	return 1
}
function http_proxy_detect() {

	debug_print

	http_proxy=$(env | grep -i HTTP_PROXY | head -n 1 | awk -F "=" '{print $2}')

	if [ -n "${http_proxy}" ]; then
		http_proxy_set=1
	else
		http_proxy_set=0
	fi
}
function check_default_route() {

	debug_print

	local target_ip=""

	for item in "${ips_to_check_internet[@]}"; do
		if [ -n "${item}" ]; then
			target_ip="${item}"

			if (set -o pipefail && ip -4 route get "${target_ip}" 2> /dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}' | grep -Fx "${1}" > /dev/null); then
				return 0
			fi
		fi
	done

	return 1
}
function autoupdate_check() {

	debug_print

	echo
	language_strings "${language}" 210 "blue"
	echo

	if check_repository_access; then
		local version_checked=0
		airgeddon_last_version=$(timeout -s SIGTERM 15 curl -L ${urlscript_directlink} 2> /dev/null | grep "airgeddon_version=" | head -n 1 | cut -d "\"" -f 2)

		if [ -n "${airgeddon_last_version}" ]; then
			version_checked=1
		else
			http_proxy_detect
			if [ "${http_proxy_set}" -eq 1 ]; then

				airgeddon_last_version=$(timeout -s SIGTERM 15 curl --proxy "${http_proxy}" -L ${urlscript_directlink} 2> /dev/null | grep "airgeddon_version=" | head -n 1 | cut -d "\"" -f 2)
				if [ -n "${airgeddon_last_version}" ]; then
					version_checked=1
				else
					language_strings "${language}" 5 "yellow"
				fi
			else
				language_strings "${language}" 5 "yellow"
			fi
		fi

		if [ "${version_checked}" -eq 1 ]; then
			if compare_floats_greater_than "${airgeddon_last_version}" "${airgeddon_version}"; then
				language_strings "${language}" 213 "yellow"
				download_last_version
			else
				language_strings "${language}" 212 "yellow"
			fi
		fi
	else
		language_strings "${language}" 211 "yellow"
	fi

	language_strings "${language}" 115 "read"
}
function autodetect_language() {

	debug_print

	[[ $(locale | grep LANG) =~ ^(.*)=\"?([a-zA-Z]+)_(.*)$ ]] && lang="${BASH_REMATCH[2]}"

	for lgkey in "${!lang_association[@]}"; do
		if [[ "${lang}" = "${lgkey}" ]] && [[ "${language}" != "${lang_association[${lgkey}]}" ]]; then
			autochanged_language=1
			language=${lang_association[${lgkey}]}
			break
		fi
	done
}
function detect_rtl_language() {

	debug_print

	for item in "${rtl_languages[@]}"; do
		if [ "${language}" = "${item}" ]; then
			is_rtl_language=1
			printf "\e[8h"
			break
		else
			is_rtl_language=0
			printf "\e[8l"
		fi
	done
}
function remove_warnings() {

	debug_print

	echo "${clean_handshake_dependencies[@]}" > /dev/null 2>&1
	echo "${aircrack_crunch_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${aireplay_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${mdk_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${hashcat_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${hashcat_hash_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${et_onlyap_dependencies[@]}" > /dev/null 2>&1
	echo "${et_sniffing_dependencies[@]}" > /dev/null 2>&1
	echo "${et_sniffing_sslstrip2_dependencies[@]}" > /dev/null 2>&1
	echo "${et_sniffing_sslstrip2_beef_dependencies[@]}" > /dev/null 2>&1
	echo "${et_captive_portal_dependencies[@]}" > /dev/null 2>&1
	echo "${wash_scan_dependencies[@]}" > /dev/null 2>&1
	echo "${bully_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${reaver_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${bully_pixie_dust_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${reaver_pixie_dust_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${wep_attack_allinone_dependencies[@]}" > /dev/null 2>&1
	echo "${wep_attack_besside_dependencies[@]}" > /dev/null 2>&1
	echo "${enterprise_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${enterprise_identities_dependencies[@]}" > /dev/null 2>&1
	echo "${enterprise_certificates_analysis_dependencies[@]}" > /dev/null 2>&1
	echo "${asleap_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${john_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${johncrunch_attacks_dependencies[@]}" > /dev/null 2>&1
	echo "${enterprise_certificates_dependencies[@]}" > /dev/null 2>&1
	echo "${pmkid_dependencies[@]}" > /dev/null 2>&1
	echo "${wpa3_downgrade_attack_dependencies[@]}" > /dev/null 2>&1
	echo "${is_arm}" > /dev/null 2>&1
}
function print_simple_separator() {

	debug_print

	echo_blue "---------"
}
function print_large_separator() {

	debug_print

	echo_blue "-------------------------------------------------------"
}
function check_pending_of_translation() {

	debug_print

	if [[ "${1}" =~ ^${escaped_pending_of_translation}([[:space:]])(.*)$ ]]; then
		text="${cyan_color}${pending_of_translation} ${2}${BASH_REMATCH[2]}"
		return 1
	elif [[ "${1}" =~ ^${hintvar}[[:space:]](\\033\[[0-9];[0-9]{1,2}m)?(${escaped_pending_of_translation})[[:space:]](.*) ]]; then
		text="${cyan_color}${pending_of_translation} ${brown_color}${hintvar} ${pink_color}${BASH_REMATCH[3]}"
		return 1
	elif [[ "${1}" =~ ^(\*+)[[:space:]]${escaped_pending_of_translation}[[:space:]]([^\*]+)(\*+)$ ]]; then
		text="${2}${BASH_REMATCH[1]}${cyan_color} ${pending_of_translation} ${2}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
		return 1
	elif [[ "${1}" =~ ^(\-+)[[:space:]]\(${escaped_pending_of_translation}[[:space:]]([^\-]+)(\-+)$ ]]; then
		text="${2}${BASH_REMATCH[1]} (${cyan_color}${pending_of_translation} ${2}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
		return 1
	fi

	return 0
}
function under_construction_message() {

	debug_print

	echo
	echo_red "${under_construction[$language]^}..."
	language_strings "${language}" 115 "read"
}
function last_echo() {

	debug_print

	if ! check_pending_of_translation "${1}" "${2}"; then
		echo -e "${2}${text}${normal_color}"
	else
		echo -e "${2}$*${normal_color}"
	fi
}
function echo_green() {

	debug_print

	last_echo "${1}" "${green_color}"
}
function echo_blue() {

	debug_print

	last_echo "${1}" "${blue_color}"
}
function echo_yellow() {

	debug_print

	last_echo "${1}" "${yellow_color}"
}
function echo_red() {

	debug_print

	last_echo "${1}" "${red_color}"
}
function echo_red_slim() {

	debug_print

	last_echo "${1}" "${red_color_slim}"
}
function echo_green_title() {

	debug_print

	last_echo "${1}" "${green_color_title}"
}
function echo_pink() {

	debug_print

	last_echo "${1}" "${pink_color}"
}
function echo_cyan() {

	debug_print

	last_echo "${1}" "${cyan_color}"
}
function echo_brown() {

	debug_print

	last_echo "${1}" "${brown_color}"
}
function echo_white() {

	debug_print

	last_echo "${1}" "${white_color}"
}
