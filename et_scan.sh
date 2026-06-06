#!/usr/bin/env bash
# ============================================================
# et_scan.sh - 주변 AP를 스캔하고 선택 결과를
#              et_config.conf에 저장, et_sniffing_attack.sh에서 사용
# ============================================================

# --- 설정 파일 로드 ---
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

# --- 루트 권한 확인 ---
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Root privileges required. Run with sudo." >&2
    exit 1
fi

# --- 설정 기본값 ---
scan_duration="${SCAN_DURATION:-15}"
tmpdir="/tmp/et_scan_$$/"
mkdir -p "${tmpdir}"
airodump_pid=""

# ============================================================
# 헬퍼: awk를 이용해 et_config.conf에 값을 다시 씀
# 특수 문자(따옴표, 슬래시 등)가 포함된 ESSID에도 안전
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
# 정리: 인터페이스를 managed 모드로 복원
# ============================================================
function _scan_cleanup() {
    # airodump-ng가 실행 중이면 종료
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
    echo "[*] Available WiFi interfaces:"
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
        echo "[!] No WiFi interfaces found." >&2
        exit 1
    fi

    echo
    if [ "${j}" -eq 1 ]; then
        echo "[*] Only one interface found — auto-selecting: ${_ifaces[1]}"
        interface="${_ifaces[1]}"
    else
        printf "[?] Select interface number (1-%d): " "${j}"
        read -r _sel_iface
        while [[ ! "${_sel_iface}" =~ ^[0-9]+$ ]] || \
              [ "${_sel_iface}" -lt 1 ] || [ "${_sel_iface}" -gt "${j}" ]; do
            echo "[!] Invalid input. Enter a number between 1 and ${j}."
            printf "[?] Select interface number (1-%d): " "${j}"
            read -r _sel_iface
        done
        interface="${_ifaces[${_sel_iface}]}"
    fi

    echo "[*] Selected interface: ${interface}"
    # 선택한 인터페이스를 et_config.conf에 저장
    update_config_value "interface" "${interface}"
    echo "[+] Interface saved to et_config.conf."
    echo
fi

# ============================================================
# phy 인터페이스 감지 (iw dev <iface> info에서 wiphy 번호 추출)
# ============================================================
if [ -z "${phy_interface}" ]; then
    phy_num=$(iw dev "${interface}" info 2>/dev/null | awk '/wiphy/{print $2}')
    if [ -z "${phy_num}" ]; then
        echo "[!] Cannot detect physical interface (wiphy) for '${interface}'." >&2
        echo "    Verify that '${interface}' is an actual WiFi adapter." >&2
        exit 1
    fi
    phy_interface="phy${phy_num}"
fi
echo "[*] Physical interface : ${phy_interface}"

# ============================================================
# 모니터 모드 활성화
# ============================================================
echo "[*] Enabling monitor mode on ${interface}..."

# 간섭 프로세스 종료 (NetworkManager, wpa_supplicant)
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
# airodump-ng 스캔 실행
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
# CSV 출력 파싱
# ============================================================
if [ ! -f "${tmpdir}nws-01.csv" ]; then
    echo "[!] No scan data was collected." >&2
    echo "    Make sure airodump-ng is installed and ${interface} supports monitor mode." >&2
    exit 1
fi

# AP 섹션이 끝나는 위치 찾기 ("Station MAC" 헤더 바로 앞 줄)
_station_line=$(awk '/^[[:space:]]*(Station[s]?|Client[es]?)/{print NR; exit}' \
    "${tmpdir}nws-01.csv" 2>/dev/null)

if [ -n "${_station_line}" ] && [ "${_station_line}" -gt 3 ]; then
    head -n $((_station_line - 1)) "${tmpdir}nws-01.csv" > "${tmpdir}nws.csv"
else
    cp "${tmpdir}nws-01.csv" "${tmpdir}nws.csv"
fi

# CSV 필드 위치 (1부터 시작, 콤마 구분):
#  1=BSSID  2=FirstSeen  3=LastSeen  4=Channel  5=Speed  6=Privacy
#  7=Cipher  8=Auth  9=Power  10=Beacons  11=IVs  12=LAN_IP
#  13=ID-length  14=ESSID  15=Key

rm -f "${tmpdir}nws.txt"

while IFS=, read -r exp_mac _ _ exp_channel _ exp_enc _ exp_auth exp_power \
                    _ _ _ exp_idlength exp_essid _; do

    # 헤더/빈 줄 건너뜀 — 유효한 BSSID는 정확히 17자 (XX:XX:XX:XX:XX:XX)
    exp_mac="${exp_mac// /}"
    [ "${#exp_mac}" -lt 17 ] && continue

    # 신호 세기 정규화: airodump는 음수 dBm으로 보고, 0~100%로 변환
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

    # ID-length 필드로 ESSID 추출 (airodump가 추가한 앞쪽 공백 제거)
    exp_idlength="${exp_idlength// /}"
    exp_essid="${exp_essid:1:${exp_idlength}}"

    # 채널 정규화
    exp_channel="${exp_channel// /}"
    [[ ! "${exp_channel}" =~ ^-?[0-9]+$ ]] && exp_channel=0
    [ "${exp_channel}" = "-1" ] && exp_channel=0

    # 숨겨진 네트워크 표시
    [ -z "${exp_essid}" ] && exp_essid="(Hidden Network)"

    # ENC/auth 필드 공백 제거
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

# 신호 세기 기준 정렬 — 신호가 강한 AP 우선 (3번째 필드 내림차순)
sort -t "," -k 3 -rn "${tmpdir}nws.txt" > "${tmpdir}wnws.txt"

# ============================================================
# AP 목록 출력
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
# 사용자 선택
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
# et_config.conf에 값 저장
# ============================================================
echo
echo "[*] Updating ${_config_file}..."
update_config_value "bssid"          "${sel_bssid}"
update_config_value "essid"          "${sel_essid}"
update_config_value "channel"        "${sel_channel}"
update_config_value "phy_interface"  "${phy_interface}"

echo "[+] Config updated successfully."

# ============================================================
# 인터넷 인터페이스 자동 감지 (기본 라우트 기준)
# ============================================================
echo
echo "[*] Detecting internet interface..."
_inet_iface=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
if [ -n "${_inet_iface}" ] && [ "${_inet_iface}" != "${interface}" ]; then
    update_config_value "internet_interface" "${_inet_iface}"
    echo "[+] Internet interface saved: ${_inet_iface}"
else
    echo "[!] Could not auto-detect internet interface. Set manually in et_config.conf."
fi

echo
echo "    Run  sudo ./et_sniffing_attack.sh  to start the attack."

# EXIT 트랩이 자동으로 인터페이스를 복원하고 tmpdir을 정리함
exit 0
