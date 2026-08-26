# wfsat
capstone project main repository

## 사용 방법

### 1. 의존성 점검/설치 — `et_check_deps.sh`
프로젝트 실행에 필요한 도구(aircrack-ng, hostapd, ettercap, mdk4, dnsmasq, iw 등)의 설치 여부와 버전을 점검한다.
```bash
sudo ./et_check_deps.sh          # 점검 후 누락/구버전 도구 자동 설치
./et_check_deps.sh --check-only  # 설치 없이 점검만 (root 불필요)
```

### 2. AP 스캔 — `et_scan.sh`
무선 인터페이스를 모니터 모드로 전환해 주변 AP를 스캔하고, 선택한 AP 정보를 `et_config.conf`에 저장한다.
```bash
sudo ./et_scan.sh
```
- 인터페이스가 여러 개면 번호 선택 프롬프트가 뜸
- 스캔 후 AP 목록에서 대상 선택 → `bssid`/`essid`/`channel`/`phy_interface`가 설정 파일에 자동 반영됨

### 3. 이블트윈/스니핑 공격 — `et_sniffing_attack.sh`
`et_scan.sh`로 저장된 설정을 기반으로 가짜 AP를 띄우고 트래픽을 스니핑한다.
```bash
sudo ./et_sniffing_attack.sh
```
- 사전에 `et_scan.sh` 실행으로 `et_config.conf`에 대상 AP 정보가 채워져 있어야 함
- 공격 진행 중 이벤트는 `et_logger.sh`를 통해 `et_config.conf`의 `log_dir`(기본 `/tmp/et_logs`)에 JSONL/요약 JSON으로 기록됨

### 4. 대시보드 UI — `dashboard/app.py`
탐지/대응 현황을 보여주는 Streamlit 화면(목업, 더미 데이터 기반).
```bash
pip install -r dashboard/requirements.txt
streamlit run dashboard/app.py
```



# 1. venv 모듈이 없으면 먼저 설치
sudo apt install python3 python3-venv -y

# 2. 프로젝트 폴더에 가상환경 생성 (.venv 디렉토리 생성됨)
python3 -m venv .venv

# 3. 가상환경 활성화 (프롬프트 앞에 (.venv) 표시됨)
source .venv/bin/activate

# 4. 가상환경 안의 pip로 패키지 설치 (sudo 붙이지 말 것)
pip install -r dashboard/requirements.txt

# 5. 대시보드 실행
streamlit run dashboard/app.py

# 6. 끝나면 가상환경 비활성화
deactivate

# 대쉬보드 활성화
python3 -m http.server 8080 --directory dashboard_html