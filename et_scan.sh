#!/usr/bin/env bash
# ============================================================
# et_scan.sh - Scan for nearby APs and save selection to
#              et_config.conf, ready for et_sniffing_attack.sh
# ============================================================

# --- Load config ---
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_config_file="${_script_dir}/et_config.conf"

if [ ! -f "${_config_file}" ]; then
    echo "[!] Config file not found: ${_config_file}" >&2
    exit 1
fi
# shellcheck source=et_config.conf
# Windows에서 편집된 파일은 줄 끝이 \r\n(CRLF)으로 저장됨.
# 그냥 source하면 변수 값에 \r이 포함되어 iw 등 명령이 실패함.
# tr -d '\r'로 \r을 제거한 뒤 소싱하면 어떤 OS에서 편집해도 정상 동작.
source <(tr -d '\r' < "${_config_file}")

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Root privileges required. Run with sudo." >&2
    exit 1
fi

# --- Config defaults ---
scan_duration="${SCAN_DURATION:-15}"
tmpdir="/tmp/et_scan_$$/"
mkdir -p "${tmpdir}"
airodump_pid=""

# ============================================================
# Helper: write a value back into et_config.conf via awk
# Safe for ESSIDs with special characters (quotes, slashes, etc.)
# ============================================================
function update_config_value() {
    local key="$1"
    local value="$2"
    local tmp="${tmpdir}conf_update.tmp"
    awk -v k="${key}" -v v="${value}" '
        $0 ~ ("^" k "=") { print k "=\"" v "\""; next }
        { print }
    ' "${_config_file}" > "${tmp}" && mv "${tmp}" "${_config_file}"
}

# ============================================================
# Cleanup: restore interface to managed mode
# ============================================================
function _scan_cleanup() {
    # Kill airodump-ng if still running
    if [ -n "${airodump_pid}" ] && kill -0 "${airodump_pid}" 2>/dev/null; then
        kill "${airodump_pid}" > /dev/null 2>&1
        wait "${airodump_pid}" 2>/dev/null
    fi

    echo "[*] Restoring ${interface} to managed mode..."
    ip link set "${interface}" down > /dev/null 2>&1
    iw "${interface}" set type managed > /dev/null 2>&1
    ip link set "${interface}" up > /dev/null 2>&1

    rm -rf "${tmpdir}"
}

trap '_scan_cleanup' EXIT

# ============================================================
# WiFi 어댑터 선택
# ============================================================
if [ -z "${interface}" ]; then
    echo "[*] 사용 가능한 WiFi 인터페이스 목록:"
    echo

    # /sys/class/net 에서 wireless 디렉토리가 있는 인터페이스만 추출
    declare -a _ifaces
    j=0
    for _iface in /sys/class/net/*/; do
        _name=$(basename "${_iface}")
        if [ -d "/sys/class/net/${_name}/wireless" ]; then
            j=$((j + 1))
            _ifaces[$j]="${_name}"
            printf "    %d) %s\n" "${j}" "${_name}"
        fi
    done

    if [ "${j}" -eq 0 ]; then
        echo "[!] WiFi 인터페이스를 찾을 수 없습니다." >&2
        exit 1
    fi

    echo
    if [ "${j}" -eq 1 ]; then
        echo "[*] 인터페이스가 하나뿐이라 자동 선택합니다: ${_ifaces[1]}"
        interface="${_ifaces[1]}"
    else
        printf "[?] 인터페이스 번호 선택 (1-%d): " "${j}"
        read -r _sel_iface
        while [[ ! "${_sel_iface}" =~ ^[0-9]+$ ]] || \
              [ "${_sel_iface}" -lt 1 ] || [ "${_sel_iface}" -gt "${j}" ]; do
            echo "[!] 잘못된 입력입니다. 1~${j} 사이의 숫자를 입력하세요."
            printf "[?] 인터페이스 번호 선택 (1-%d): " "${j}"
            read -r _sel_iface
        done
        interface="${_ifaces[${_sel_iface}]}"
    fi

    echo "[*] 선택된 인터페이스: ${interface}"
    # 선택한 인터페이스를 et_config.conf에 저장
    update_config_value "interface" "${interface}"
    echo "[+] et_config.conf에 interface 저장 완료."
    echo
fi

# ============================================================
# phy 인터페이스 감지 (iw dev <iface> info에서 wiphy 번호 추출)
# ============================================================
if [ -z "${phy_interface}" ]; then
    phy_num=$(iw dev "${interface}" info 2>/dev/null | awk '/wiphy/{print $2}')
    if [ -z "${phy_num}" ]; then
        echo "[!] '${interface}'의 물리 인터페이스(wiphy)를 감지할 수 없습니다." >&2
        echo "    '${interface}'이 실제로 존재하는 WiFi 어댑터인지 확인하세요." >&2
        exit 1
    fi
    phy_interface="phy${phy_num}"
fi
echo "[*] Physical interface : ${phy_interface}"

# ============================================================
# Enable monitor mode
# ============================================================
echo "[*] Enabling monitor mode on ${interface}..."

# Kill processes that may interfere (NetworkManager, wpa_supplicant)
airmon-ng check kill > /dev/null 2>&1

ip link set "${interface}" down > /dev/null 2>&1
iw "${interface}" set type monitor > /dev/null 2>&1
ip link set "${interface}" up > /dev/null 2>&1

_mode=$(iw "${interface}" info 2>/dev/null | awk '/type/{print $2}')
if [[ "${_mode,,}" != "monitor" ]]; then
    echo "[!] Failed to set ${interface} to monitor mode." >&2
    echo "    Current mode: ${_mode:-unknown}" >&2
    exit 1
fi
echo "[+] Monitor mode enabled."

# ============================================================
# Run airodump-ng scan
# ============================================================
echo "[*] Scanning for APs (${scan_duration}s)..."
rm -f "${tmpdir}nws"*

airodump-ng -w "${tmpdir}nws" --output-format csv "${interface}" > /dev/null 2>&1 &
airodump_pid=$!

_interrupted=0
for i in $(seq 1 "${scan_duration}"); do
    if ! kill -0 "${airodump_pid}" 2>/dev/null; then
        _interrupted=1
        break
    fi
    printf "\r[*] Scanning... %2d / %d seconds" "${i}" "${scan_duration}"
    sleep 1
done
printf "\n"

kill "${airodump_pid}" > /dev/null 2>&1
wait "${airodump_pid}" 2>/dev/null
airodump_pid=""

echo "[+] Scan complete."

# ============================================================
# Parse CSV output
# ============================================================
if [ ! -f "${tmpdir}nws-01.csv" ]; then
    echo "[!] No scan data was collected." >&2
    echo "    Make sure airodump-ng is installed and ${interface} supports monitor mode." >&2
    exit 1
fi

# Find where the AP section ends (the line before "Station MAC" header)
_station_line=$(awk '/^[[:space:]]*(Station[s]?|Client[es]?)/{print NR; exit}' \
    "${tmpdir}nws-01.csv" 2>/dev/null)

if [ -n "${_station_line}" ] && [ "${_station_line}" -gt 3 ]; then
    head -n $((_station_line - 1)) "${tmpdir}nws-01.csv" > "${tmpdir}nws.csv"
else
    cp "${tmpdir}nws-01.csv" "${tmpdir}nws.csv"
fi

# CSV field positions (1-indexed, comma-separated):
#  1=BSSID  2=FirstSeen  3=LastSeen  4=Channel  5=Speed  6=Privacy
#  7=Cipher  8=Auth  9=Power  10=Beacons  11=IVs  12=LAN_IP
#  13=ID-length  14=ESSID  15=Key

rm -f "${tmpdir}nws.txt"

while IFS=, read -r exp_mac _ _ exp_channel _ exp_enc _ exp_auth exp_power \
                    _ _ _ exp_idlength exp_essid _; do

    # Skip header/blank lines — valid BSSIDs are exactly 17 chars (XX:XX:XX:XX:XX:XX)
    exp_mac="${exp_mac// /}"
    [ "${#exp_mac}" -lt 17 ] && continue

    # Normalize signal power: airodump reports negative dBm, convert to 0-100%
    exp_power="${exp_power// /}"
    if [[ "${exp_power}" =~ ^-[0-9]+$ ]]; then
        if [ "${exp_power}" -eq -1 ]; then
            exp_power=0
        else
            exp_power=$((exp_power + 100))
            [ "${exp_power}" -lt 0 ] && exp_power=0
        fi
    fi
    [[ ! "${exp_power}" =~ ^[0-9]+$ ]] && exp_power=0

    # Extract ESSID using the ID-length field (strips leading space added by airodump)
    exp_idlength="${exp_idlength// /}"
    exp_essid="${exp_essid:1:${exp_idlength}}"

    # Normalize channel
    exp_channel="${exp_channel// /}"
    [[ ! "${exp_channel}" =~ ^-?[0-9]+$ ]] && exp_channel=0
    [ "${exp_channel}" = "-1" ] && exp_channel=0

    # Label hidden networks
    [ -z "${exp_essid}" ] && exp_essid="(Hidden Network)"

    # Trim whitespace from ENC/auth fields
    exp_enc=$(echo "${exp_enc}" | awk '{print $1}')
    exp_auth="${exp_auth// /}"

    printf '%s,%s,%s,%s,%s,%s\n' \
        "${exp_mac}" "${exp_channel}" "${exp_power}" \
        "${exp_essid}" "${exp_enc}" "${exp_auth}" >> "${tmpdir}nws.txt"

done < <(tail -n +3 "${tmpdir}nws.csv")

if [ ! -s "${tmpdir}nws.txt" ]; then
    echo "[!] No APs found in scan results." >&2
    echo "    Try increasing SCAN_DURATION (e.g. SCAN_DURATION=30 sudo ./et_scan.sh)" >&2
    exit 1
fi

# Sort by signal strength — strongest AP first (numeric descending on field 3)
sort -t "," -k 3 -rn "${tmpdir}nws.txt" > "${tmpdir}wnws.txt"

# ============================================================
# Display AP list
# ============================================================
echo
printf '%0.s=' {1..80}; echo
printf ' %-4s  %-17s  %-4s  %-5s  %-7s  %s\n' \
    "Num" "BSSID" "CH" "Sig%" "ENC" "ESSID"
printf '%0.s=' {1..80}; echo

declare -a _bssids _channels _essids
i=0

while IFS=, read -r exp_mac exp_channel exp_power exp_essid exp_enc exp_auth; do
    i=$((i + 1))
    _bssids[$i]="${exp_mac}"
    _channels[$i]="${exp_channel}"
    _essids[$i]="${exp_essid}"

    _disp_ch="${exp_channel}"
    [ "${_disp_ch}" = "0" ] && _disp_ch="-"

    printf ' %-4d  %-17s  %-4s  %3s%%  %-7s  %s\n' \
        "${i}" "${exp_mac}" "${_disp_ch}" "${exp_power}" "${exp_enc}" "${exp_essid}"
done < "${tmpdir}wnws.txt"

printf '%0.s=' {1..80}; echo
echo

if [ "${i}" -eq 0 ]; then
    echo "[!] No APs to display." >&2
    exit 1
fi

# ============================================================
# User selection
# ============================================================
if [ "${i}" -eq 1 ]; then
    echo "[*] Only one AP found — selecting automatically."
    selected=1
else
    printf "[?] Select AP number (1-%d): " "${i}"
    read -r selected
    while [[ ! "${selected}" =~ ^[0-9]+$ ]] || \
          [ "${selected}" -lt 1 ] || [ "${selected}" -gt "${i}" ]; do
        echo "[!] Invalid selection. Enter a number between 1 and ${i}."
        printf "[?] Select AP number (1-%d): " "${i}"
        read -r selected
    done
fi

sel_bssid="${_bssids[$selected]}"
sel_channel="${_channels[$selected]}"
sel_essid="${_essids[$selected]}"

echo
echo "[*] Selected AP:"
echo "    ESSID   : ${sel_essid}"
echo "    BSSID   : ${sel_bssid}"
echo "    Channel : ${sel_channel}"
echo "    phy     : ${phy_interface}"

# ============================================================
# Save values to et_config.conf
# ============================================================
echo
echo "[*] Updating ${_config_file}..."
update_config_value "bssid"          "${sel_bssid}"
update_config_value "essid"          "${sel_essid}"
update_config_value "channel"        "${sel_channel}"
update_config_value "phy_interface"  "${phy_interface}"

# Auto-detect the internet-facing uplink (default-route interface) if not
# already set. This is the NIC that shares internet to the fake AP (e.g. eth0),
# and is distinct from the monitor-mode wireless interface above.
if [ -z "${internet_interface}" ]; then
    _inet_iface=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
    if [ -n "${_inet_iface}" ] && [ "${_inet_iface}" != "${interface}" ]; then
        update_config_value "internet_interface" "${_inet_iface}"
        echo "    internet_interface auto-detected: ${_inet_iface}"
    else
        echo "[!] Could not auto-detect internet_interface (uplink NIC)."
        echo "    Set it manually in ${_config_file}, e.g. internet_interface=\"eth0\""
    fi
fi

echo "[+] Config updated successfully."
echo
echo "    Run  sudo ./et_sniffing_attack.sh  to start the attack."

# EXIT trap will restore the interface and clean up tmpdir automatically
exit 0
