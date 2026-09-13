#!/usr/bin/env bash
# ============================================================
# et_stop.sh - 실행 중인 공격을 중지한다.
#   기본: beacon flood + sniffing attack 중지 (각 스크립트의 정리 트랩이
#         인터페이스/방화벽/설정을 자동 복구).
#   인자 "all": 실습용 피해 AP(lab_victim_ap.sh)까지 함께 중지.
#
# 사용 예:
#   sudo bash et_stop.sh          # 공격만 중지 (피해 AP 유지)
#   sudo bash et_stop.sh all      # 피해 AP 포함 전부 중지
# ============================================================
set -u

_mode="${1:-}"
_stopped=0

if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
	echo "[!] Root 권한이 필요합니다. sudo 로 실행하세요." >&2
	exit 1
fi

# 스크립트 프로세스에 TERM 을 보내면 해당 스크립트의 cleanup 트랩이 돌며 정리된다.
_term_script() {
	local pat="$1" name="$2"
	if pgrep -f "${pat}" > /dev/null 2>&1; then
		pkill -TERM -f "${pat}" 2>/dev/null
		echo "[*] 중지 요청: ${name}"
		_stopped=1
	fi
}

_term_script "et_beacon_flood.sh" "Beacon Flood"
_term_script "et_sniffing_attack.sh" "Evil Twin 스니핑 공격"
if [ "${_mode}" = "all" ]; then
	_term_script "lab_victim_ap.sh" "실습용 피해 AP"
fi

# 트랩이 놓칠 수 있는 공격 도구를 직접 정리
for _t in mdk4 mdk3; do
	if pgrep -x "${_t}" > /dev/null 2>&1; then
		pkill -TERM -x "${_t}" 2>/dev/null
		echo "[*] ${_t} 종료"
		_stopped=1
	fi
done

sleep 1

if [ "${_stopped}" -eq 0 ]; then
	echo "[*] 실행 중인 공격이 없습니다."
else
	echo "[+] 중지 요청 완료. (인터페이스/방화벽/설정은 각 스크립트가 자동 복구합니다)"
fi
