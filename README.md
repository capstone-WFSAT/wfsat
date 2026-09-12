# wfsat

sudo python3 wifi.py                    → 스캔+공격 모드 (WPA3 타겟 있으면 다운그레이드 시도)

sudo python3 wifi.py --pmkid-passive    → PMKID 패시브 캡처 전용 모드      deauth 공격을 하지 않고 클라이언트 재연결 시 pmkid를 확인

sudo bash ../wfsat/et_captive_portal_attack

sudo bash ../wfsat/exec_et_sniffing_attack
