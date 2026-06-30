#!/usr/bin/env bash
# et_check_deps.sh - 프로젝트(et_scan.sh / et_sniffing_attack.sh)가 필요로 하는
#                     외부 도구의 설치 여부와 버전을 점검하고, 누락되었거나
#                     최소 버전 미달이면 apt로 설치/업데이트한다.
#
# 버전 추출(get_*_version) / 비교(compare_floats_greater_or_equal) 방식은
# airgeddon(airgeddon/sh/utils.sh)의 패턴을 참고해 이식했다.
#
# 사용법: sudo ./et_check_deps.sh [--check-only]
#   --check-only : 설치/업그레이드 없이 점검 결과만 출력

set -u

CHECK_ONLY=0
[ "${1:-}" = "--check-only" ] && CHECK_ONLY=1

# ------------------------------------------------------------------
# 점검 대상: "도구명|패키지명|최소버전|버전확인커맨드|버전추출정규식"
# 버전을 신뢰성 있게 비교할 수 없는 도구는 최소버전을 비워두면
# 설치 여부만 확인한다.
# ------------------------------------------------------------------
DEPS=(
	"airodump-ng|aircrack-ng|1.6|airodump-ng --help|[0-9]+\.[0-9]+(\.[0-9]+)?"
	"aireplay-ng|aircrack-ng|1.6|aireplay-ng --help|[0-9]+\.[0-9]+(\.[0-9]+)?"
	"iw|iw|5.4|iw --version|[0-9]+\.[0-9]+"
	"hostapd|hostapd|2.9|hostapd -v|[0-9]+\.[0-9]+"
	"ettercap|ettercap-graphical|0.8.3|ettercap -v|[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?"
	"etterlog|ettercap-graphical||etterlog -v|"
	"mdk4|mdk4|4.0|mdk4 --help|[0-9]+\.[0-9]+"
	"dnsmasq|dnsmasq|2.79|dnsmasq --version|[0-9]+\.[0-9]+"
	"curl|curl||curl --version|"
)

function compare_floats_greater_or_equal() {
	awk -v n1="${1}" -v n2="${2}" 'BEGIN{if (n1>=n2) exit 0; exit 1}'
}

# $1: 버전 확인 커맨드(공백 포함 문자열), $2: 추출 정규식
function get_tool_version() {
	local cmd="${1}" regex="${2}"
	[ -z "${regex}" ] && return 0
	# shellcheck disable=SC2086
	${cmd} 2>&1 | grep -oiP "${regex}" | head -n1
}

function apt_install() {
	local pkg="${1}"
	if [ "${CHECK_ONLY}" -eq 1 ]; then
		return 0
	fi
	echo "    -> apt install 진행: ${pkg}"
	DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkg}" > /dev/null 2>&1
	return $?
}

if [ "${CHECK_ONLY}" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
	echo "[!] 설치/업그레이드를 진행하려면 root 권한이 필요합니다 (sudo로 실행하세요)." >&2
	echo "    점검만 하려면: ./et_check_deps.sh --check-only" >&2
	exit 1
fi

if [ "${CHECK_ONLY}" -eq 0 ]; then
	echo "[*] 패키지 목록 갱신 중 (apt-get update)..."
	apt-get update > /dev/null 2>&1
fi

printf '\n%-14s %-22s %-10s %-12s %s\n' "TOOL" "PACKAGE" "REQUIRED" "INSTALLED" "STATUS"
printf '%0.s-' {1..75}; echo

ok_count=0
fixed_count=0
fail_count=0

for entry in "${DEPS[@]}"; do
	IFS='|' read -r tool pkg min_ver ver_cmd ver_regex <<< "${entry}"

	if ! command -v "${tool}" > /dev/null 2>&1; then
		status="MISSING"
	else
		installed_ver=$(get_tool_version "${ver_cmd}" "${ver_regex}")
		if [ -n "${min_ver}" ] && [ -n "${installed_ver}" ]; then
			if compare_floats_greater_or_equal "${installed_ver}" "${min_ver}"; then
				status="OK"
			else
				status="OUTDATED"
			fi
		else
			status="OK"
		fi
	fi

	display_ver="${installed_ver:-N/A}"
	printf '%-14s %-22s %-10s %-12s %s\n' "${tool}" "${pkg}" "${min_ver:-any}" "${display_ver}" "${status}"

	case "${status}" in
		OK)
			ok_count=$((ok_count + 1))
			;;
		MISSING|OUTDATED)
			if [ "${CHECK_ONLY}" -eq 1 ]; then
				fail_count=$((fail_count + 1))
				continue
			fi
			if apt_install "${pkg}"; then
				fixed_count=$((fixed_count + 1))
			else
				echo "    [!] ${pkg} 설치 실패 - 수동 설치 필요" >&2
				fail_count=$((fail_count + 1))
			fi
			;;
	esac
done

printf '%0.s-' {1..75}; echo
echo "[*] 정상: ${ok_count} / 설치-업그레이드: ${fixed_count} / 실패-미해결: ${fail_count}"

if [ "${fail_count}" -gt 0 ]; then
	if [ "${CHECK_ONLY}" -eq 1 ]; then
		echo "[!] --check-only 모드입니다. 'sudo ./et_check_deps.sh'로 실행하면 자동 설치를 시도합니다." >&2
	fi
	exit 1
fi

echo "[+] 모든 의존성이 요구 버전을 충족합니다."
exit 0
