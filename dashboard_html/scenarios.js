(function () {
  "use strict";

  const link = (from, to, type, label) => ({ from, to, type, label });
  const packet = (from, to, label, tone) => ({ from, to, label, tone });
  const event = (type, tone, source, detail, status) => ({ type, tone, source, detail, status });

  const commonGlossary = [
    { term: "SSID", description: "사람에게 보이는 와이파이 이름입니다." },
    { term: "BSSID", description: "각 AP 무선 인터페이스를 식별하는 MAC 주소입니다." },
    { term: "관리 프레임", description: "연결·인증·탐색처럼 와이파이 연결 자체를 관리하는 프레임입니다." },
    { term: "기준선", description: "공격이 없을 때의 정상 패킷 속도와 연결 상태입니다." }
  ];

  const scenarios = [
    {
      id: "evil-twin",
      icon: "👥",
      shortName: "이블 트윈",
      title: "이블 트윈 공격",
      english: "Evil Twin",
      layer: "Rogue AP · 인증",
      summary: "정상 AP와 같은 이름을 사용하는 가짜 AP가 더 강한 신호와 약한 보안 설정으로 사용자의 연결을 가로채는 과정을 확인합니다.",
      learning: {
        estimatedMinutes: 4,
        objectives: ["SSID와 BSSID의 차이 이해하기", "보안 하향이 위험 신호인 이유 찾기", "신뢰 AP 검증 방법 익히기"],
        checkpoint: {
          prompt: "이블 트윈을 찾을 때 가장 강한 근거는 무엇인가요?",
          options: [
            { id: "a", label: "같은 SSID의 신호가 더 강해졌습니다." },
            { id: "b", label: "같은 SSID가 미등록 BSSID와 OPEN 보안 방식으로 나타났습니다." },
            { id: "c", label: "정상 AP가 주기적으로 Beacon을 전송합니다." }
          ],
          correctOptionId: "b",
          explanation: "와이파이 이름만 같다고 같은 AP는 아닙니다. 등록되지 않은 BSSID와 WPA2에서 OPEN으로 바뀐 보안 설정이 함께 보이면 이블 트윈의 강한 근거입니다.",
          reviewPhaseIndex: 1
        }
      },
      technical: "동일하거나 정규화 후 동일한 SSID가 서로 다른 BSSID, 암호화 방식, 제조사 OUI로 관측되면 Rogue AP 후보가 됩니다. Deauth 이후 해당 AP로 재연결하는 시퀀스는 위험도를 높입니다.",
      baseAps: 4,
      nodes: [
        { id: "client", role: "client", icon: "📱", label: "사용자 기기", detail: "8C:F5:A3:11:02:44" },
        { id: "real-ap", role: "real-ap", icon: "📡", label: "진짜 AP", detail: "Campus_WiFi · WPA2" },
        { id: "attacker", role: "attacker", icon: "📶", label: "가짜 AP", detail: "Campus_WiFi · OPEN" },
        { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: "SSID/BSSID 비교" }
      ],
      defense: { name: "PMF + WPA3/802.1X", description: "관리 프레임 보호와 인증서 기반 네트워크 검증을 함께 사용하면 강제 연결 해제와 가짜 AP 접속을 줄일 수 있습니다.", before: "가짜 AP로 이동", after: "신뢰 AP만 연결" },
      glossary: [
        { term: "Rogue AP", description: "관리자의 허가 없이 설치되거나 공격자가 만든 무선 AP입니다." },
        { term: "OUI", description: "MAC 주소 앞부분으로 장비 제조사를 구분할 때 사용합니다." },
        { term: "RSSI", description: "수신 신호 세기를 나타내며 0에 가까울수록 강합니다." }
      ],
      signature: {
        type: "ap-compare",
        title: "정상 AP vs 가짜 AP",
        caption: "이름(SSID)은 같아도 주소·보안·신호가 어떻게 다른지 나란히 비교하세요.",
        fields: [
          { key: "ssid", label: "SSID", real: "Campus_WiFi", fake: "Campus_WiFi", verdict: "trap" },
          { key: "bssid", label: "BSSID", real: "AA:11:22:33:44:01", fake: "AA:11:22:33:44:99", verdict: "differ" },
          { key: "security", label: "보안", real: "WPA2", fake: "OPEN", verdict: "downgrade" },
          { key: "rssi", label: "신호(RSSI)", real: "-58 dBm", fake: "-32 dBm", verdict: "fake-stronger" }
        ],
        phases: [
          { fakePresent: false, connectedTo: "real", fakeStatus: "idle", note: "같은 이름을 쓰는 신뢰 AP 하나만 존재합니다." },
          { fakePresent: true, connectedTo: "real", fakeStatus: "rogue", note: "같은 SSID·다른 BSSID의 Open AP가 더 강한 신호로 등장합니다." },
          { fakePresent: true, connectedTo: null, fakeStatus: "attacking", note: "가짜 AP가 Deauth로 정상 연결을 끊어 재검색을 유도합니다." },
          { fakePresent: true, connectedTo: "fake", fakeStatus: "rogue", note: "기기가 이름이 같고 신호가 강한 가짜 AP에 연결됩니다." },
          { fakePresent: true, connectedTo: "real", fakeStatus: "blocked", note: "SSID·BSSID·보안 불일치로 가짜 AP를 차단하고 신뢰 AP로 복원합니다." }
        ]
      },
      phases: [
        { label: "정상 상태", kicker: "TRUSTED NETWORK", title: "사용자는 암호화된 진짜 AP에 연결되어 있습니다", description: "등록된 BSSID와 WPA2 보안 설정이 기준 정보와 일치합니다.", plain: "한 개의 신뢰할 수 있는 AP만 같은 이름을 사용하고 있습니다.", severity: "neutral", rate: 46, alerts: 0, evidence: ["등록 BSSID와 일치", "WPA2 암호화 사용", "동일 SSID 중복 없음"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("real-ap", "client", "normal", "WPA2 연결"), link("real-ap", "sensor", "normal", "기준 정보")], packet: packet("real-ap", "client", "DATA", "normal"), event: event("Association", "normal", "AA:11:22:33:44:01", "등록 AP 연결 유지", "정상"), packetFields: { "SSID": "Campus_WiFi", "BSSID": "AA:11:22:33:44:01", "Security": "WPA2" } },
        { label: "공격 준비", kicker: "ROGUE AP ONLINE", title: "같은 이름의 가짜 AP가 등장합니다", description: "공격자는 진짜 AP의 SSID를 복제하고 더 강한 신호로 Open AP를 송출합니다.", plain: "겉으로는 이름이 같지만 주소와 잠금 방식이 다른 가짜 와이파이가 생겼습니다.", severity: "medium", rate: 78, alerts: 3, aps: 5, evidence: ["동일 SSID의 새 BSSID 관측", "WPA2와 OPEN 보안 방식 불일치", "미등록 OUI와 비정상적으로 강한 RSSI"], states: { client: "normal", "real-ap": "normal", attacker: "danger", sensor: "warning" }, links: [link("real-ap", "client", "normal", "기존 연결"), link("attacker", "client", "warning", "동일 SSID Beacon"), link("attacker", "sensor", "warning", "중복 식별")], packet: packet("attacker", "client", "BEACON", "warning"), event: event("Rogue Beacon", "warning", "AA:11:22:33:44:99", "Campus_WiFi · OPEN · -32 dBm", "의심"), packetFields: { "SSID": "Campus_WiFi", "BSSID": "AA:11:22:33:44:99", "Security": "OPEN" } },
        { label: "공격 진행", kicker: "FORCED ROAMING", title: "사용자가 진짜 AP에서 강제로 떨어집니다", description: "가짜 AP 측에서 Deauth 프레임을 보내 정상 연결을 끊고 재검색을 유도합니다.", plain: "사용자의 연결을 끊어서 더 강해 보이는 가짜 와이파이를 다시 선택하게 만듭니다.", severity: "high", rate: 392, alerts: 27, aps: 5, evidence: ["가짜 AP 등장 직후 Deauth 급증", "진짜 AP BSSID를 도용한 발신자", "클라이언트 재검색 Probe 반복"], states: { client: "warning", "real-ap": "warning", attacker: "danger", sensor: "warning" }, links: [link("attacker", "client", "attack", "위조 Deauth"), link("real-ap", "client", "inactive", "연결 해제"), link("client", "sensor", "warning", "재검색")], packet: packet("attacker", "client", "DEAUTH", "attack"), event: event("Deauth", "attack", "AA:11:22:33:44:99", "정상 AP 연결 해제 유도", "위험"), packetFields: { "Subtype": "Deauthentication", "Reason": "7", "Target": "8C:F5:A3:11:02:44" } },
        { label: "영향 발생", kicker: "ROGUE ASSOCIATION", title: "사용자 기기가 가짜 AP로 연결됩니다", description: "동일 SSID와 강한 신호를 본 기기가 Open 방식의 가짜 AP에 연결됩니다.", plain: "기기는 이름이 같고 신호가 강한 AP를 믿었지만 실제로는 공격자의 장비입니다.", severity: "critical", rate: 218, alerts: 41, aps: 5, evidence: ["클라이언트가 미등록 BSSID에 Association", "암호화가 WPA2에서 OPEN으로 변경", "DHCP 응답 출처가 Rogue AP로 이동"], states: { client: "danger", "real-ap": "offline", attacker: "danger", sensor: "danger" }, links: [link("attacker", "client", "attack", "가짜 AP 연결"), link("real-ap", "client", "inactive", "정상 경로 단절"), link("sensor", "attacker", "warning", "Rogue 확인")], packet: packet("client", "attacker", "ASSOC", "attack"), event: event("Rogue Association", "attack", "8C:F5:A3:11:02:44", "OPEN AP로 연결 변경", "심각"), packetFields: { "Association": "AA:11:22:33:44:99", "Encryption": "OPEN", "Gateway": "192.168.2.1" } },
        { label: "탐지·대응", kicker: "TRUST RESTORED", title: "BSSID·암호화 불일치로 이블 트윈을 차단합니다", description: "센서는 SSID만 보지 않고 등록 BSSID와 보안 방식, 연결 순서를 함께 비교합니다.", plain: "와이파이 이름이 같아도 주소와 잠금 방식이 다르면 같은 네트워크가 아니라는 점을 확인했습니다.", severity: "resolved", rate: 74, alerts: 1, aps: 5, evidence: ["SSID 동일·BSSID 불일치", "WPA2 대비 OPEN 보안 하향", "Deauth 후 Rogue Association 시퀀스 확인"], states: { client: "defense", "real-ap": "defense", attacker: "danger", sensor: "defense" }, links: [link("real-ap", "client", "defense", "신뢰 AP 재연결"), link("sensor", "attacker", "defense", "Rogue 차단")], packet: packet("real-ap", "client", "802.1X", "defense"), event: event("Evil Twin Detected", "defense", "WFSAT", "SSID/BSSID/보안 불일치", "대응 완료"), packetFields: { "Detection": "Evil Twin", "Confidence": "98%", "Action": "Rogue BSSID block" } }
      ]
    },
    {
      id: "beacon-flood",
      icon: "📣",
      shortName: "비콘 플러드",
      title: "비콘 플러드 공격",
      english: "Beacon Flood",
      layer: "802.11 Beacon",
      summary: "공격자가 수많은 가짜 SSID와 BSSID의 Beacon을 뿌려 주변 AP 목록과 무선 채널을 혼잡하게 만드는 모습을 확인합니다.",
      learning: {
        estimatedMinutes: 3,
        objectives: ["정상 Beacon 주기 기억하기", "가짜 SSID·BSSID 급증 찾기", "비율 제한과 OUI 필터의 역할 이해하기"],
        checkpoint: {
          prompt: "비콘 플러드에서 정상 AP 증가와 공격을 구분하는 핵심 단서는 무엇인가요?",
          options: [
            { id: "a", label: "짧은 시간에 랜덤한 SSID와 BSSID가 대량으로 생깁니다." },
            { id: "b", label: "등록 AP 한 대가 같은 SSID로 계속 Beacon을 보냅니다." },
            { id: "c", label: "클라이언트 한 대가 데이터 프레임을 전송합니다." }
          ],
          correctOptionId: "a",
          explanation: "고유 SSID·BSSID 수와 Beacon 비율이 동시에 급증하고 랜덤 OUI가 많아지면 정상 AP 추가보다 대량 생성 공격에 가깝습니다.",
          reviewPhaseIndex: 2
        }
      },
      technical: "짧은 시간에 고유 SSID/BSSID 수, Beacon 비율, 새 OUI 비율이 함께 급증하는지 분석합니다. 실제 AP의 일반적인 Beacon 간격과 비교하면 대량 생성 패턴을 구별할 수 있습니다.",
      baseAps: 4,
      nodes: [
        { id: "client", role: "client", icon: "📱", label: "사용자 기기", detail: "AP 목록 표시" },
        { id: "real-ap", role: "real-ap", icon: "📡", label: "정상 AP", detail: "4개 · 안정 상태" },
        { id: "attacker", role: "attacker", icon: "📣", label: "Beacon 생성기", detail: "랜덤 SSID/BSSID" },
        { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: "Beacon rate 분석" }
      ],
      defense: { name: "Beacon 임계값·OUI 필터", description: "단위 시간당 새 SSID/BSSID 수와 랜덤 OUI 패턴을 제한해 가짜 AP를 숨기고 정상 AP를 우선 표시합니다.", before: "가짜 AP 42개 노출", after: "정상 AP 4개 유지" },
      glossary: [
        { term: "Beacon", description: "AP가 자신의 이름과 기능을 주기적으로 알리는 관리 프레임입니다." },
        { term: "Beacon Interval", description: "AP가 Beacon을 보내는 시간 간격입니다." },
        { term: "채널 점유", description: "한 무선 채널이 프레임 전송으로 사용되는 비율입니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "NORMAL BEACONS", title: "주변 AP 네 개가 일정한 간격으로 자신을 알립니다", description: "AP 목록과 Beacon 비율이 안정적으로 유지됩니다.", plain: "평소에는 실제 AP 몇 개만 일정한 속도로 이름을 알립니다.", severity: "neutral", rate: 38, alerts: 0, evidence: ["고유 SSID 4개", "Beacon 간격 약 100ms", "등록 OUI 비율 100%"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("real-ap", "client", "normal", "Beacon"), link("real-ap", "sensor", "normal", "4 AP")], packet: packet("real-ap", "client", "BEACON", "normal"), event: event("Beacon", "normal", "정상 AP", "4개 SSID 안정 관측", "정상"), packetFields: { "Unique SSID": "4", "Interval": "100ms", "Beacon Rate": "38 pkt/s" } },
        { label: "공격 준비", kicker: "FAKE IDENTITY SET", title: "공격 도구가 가짜 SSID와 BSSID 목록을 만듭니다", description: "랜덤 이름과 주소를 가진 Beacon 전송 준비가 시작됩니다.", plain: "공격자가 존재하지 않는 와이파이 이름을 빠르게 만들고 있습니다.", severity: "low", rate: 64, alerts: 0, aps: 7, evidence: ["짧은 간격으로 새 BSSID 등장", "로컬 관리 MAC 주소 비율 증가", "SSID 문자열 패턴 반복"], states: { client: "normal", "real-ap": "normal", attacker: "warning", sensor: "normal" }, links: [link("real-ap", "client", "normal", "정상 Beacon"), link("attacker", "sensor", "warning", "새 BSSID")], packet: packet("attacker", "sensor", "BEACON", "warning"), event: event("New BSSID", "warning", "02:11:xx:xx:xx:01", "미등록 SSID 3개 등장", "관찰"), packetFields: { "Unique SSID": "7", "Local MAC": "3", "Rate": "64 pkt/s" } },
        { label: "공격 진행", kicker: "BEACON BURST", title: "수십 개의 가짜 AP가 동시에 나타납니다", description: "공격자는 초당 수백 개의 Beacon을 전송해 AP 목록을 채웁니다.", plain: "와이파이 목록이 갑자기 가짜 이름으로 가득 차기 시작합니다.", severity: "high", rate: 742, alerts: 36, aps: 42, evidence: ["5초 동안 신규 SSID 38개", "Beacon 비율이 기준선의 19배", "BSSID가 연속적으로 변경됨"], states: { client: "warning", "real-ap": "normal", attacker: "danger", sensor: "warning" }, links: [link("attacker", "client", "attack", "가짜 Beacon 폭주"), link("attacker", "sensor", "attack", "742 pkt/s"), link("real-ap", "client", "normal", "정상 Beacon")], packet: packet("attacker", "client", "BEACON×", "attack"), event: event("Beacon Flood", "attack", "02:11:xx:xx:xx:xx", "신규 SSID 38개 / 5s", "위험"), packetFields: { "Unique SSID": "42", "Beacon Rate": "742 pkt/s", "New BSSID": "38 / 5s" } },
        { label: "영향 발생", kicker: "CHANNEL CONGESTION", title: "AP 목록과 무선 채널이 혼잡해집니다", description: "사용자는 정상 AP를 찾기 어렵고 기기의 스캔 처리량과 채널 점유율이 증가합니다.", plain: "가짜 와이파이가 너무 많아 진짜 네트워크를 찾기 어렵고 연결도 느려집니다.", severity: "critical", rate: 918, alerts: 51, aps: 63, evidence: ["채널 점유율 87%", "정상 AP 검색 지연 4.2초", "클라이언트 CPU·배터리 사용 증가"], states: { client: "warning", "real-ap": "warning", attacker: "danger", sensor: "danger" }, links: [link("attacker", "client", "attack", "Beacon Noise"), link("attacker", "sensor", "attack", "채널 혼잡"), link("real-ap", "client", "warning", "정상 신호 가림")], packet: packet("attacker", "client", "63 SSID", "attack"), event: event("Channel Busy", "attack", "CH 6", "점유율 87% · 스캔 지연", "심각"), packetFields: { "Channel Utilization": "87%", "Scan Delay": "4.2s", "Visible AP": "63" } },
        { label: "탐지·대응", kicker: "NOISE FILTERED", title: "가짜 Beacon을 묶어 정상 AP만 강조합니다", description: "센서는 새 BSSID 생성 속도와 OUI 패턴을 이용해 공격 Beacon을 필터링합니다.", plain: "가짜 와이파이 묶음을 숨기고 사용자가 신뢰할 수 있는 AP만 보도록 정리했습니다.", severity: "resolved", rate: 57, alerts: 1, aps: 4, evidence: ["생성 속도 기반 59개 BSSID 그룹화", "랜덤 OUI 패턴 일치", "등록 AP 4개를 별도 신뢰 표시"], states: { client: "defense", "real-ap": "defense", attacker: "danger", sensor: "defense" }, links: [link("real-ap", "client", "defense", "신뢰 Beacon"), link("sensor", "attacker", "defense", "필터 적용")], packet: packet("real-ap", "client", "TRUSTED", "defense"), event: event("Flood Filtered", "defense", "WFSAT", "59개 가짜 BSSID 그룹 차단", "대응 완료"), packetFields: { "Detection": "Beacon Flood", "Filtered": "59 BSSID", "Trusted AP": "4" } }
      ]
    },
    {
      id: "auth-dos",
      icon: "🚧",
      shortName: "인증 DoS",
      title: "인증 요청 서비스 거부",
      english: "Authentication DoS",
      layer: "802.11 Authentication",
      summary: "공격자가 수많은 가짜 MAC 주소로 인증 요청을 보내 AP의 처리 자원을 고갈시키고 정상 사용자의 연결을 방해하는 과정을 봅니다.",
      learning: {
        estimatedMinutes: 3,
        objectives: ["인증 요청과 정상 연결의 차이 보기", "랜덤 MAC 요청 폭증이 AP에 미치는 영향 이해하기", "요청 비율 제한의 목적 알기"],
        checkpoint: {
          prompt: "인증 요청 서비스 거부 공격의 대표적인 관측 패턴은 무엇인가요?",
          options: [
            { id: "a", label: "한 사용자가 정상적으로 인증을 한 번 완료합니다." },
            { id: "b", label: "AP가 정해진 간격으로 Beacon을 보냅니다." },
            { id: "c", label: "많은 랜덤 MAC 주소가 짧은 시간에 인증 요청을 반복합니다." }
          ],
          correctOptionId: "c",
          explanation: "수많은 가짜 송신자가 인증 요청을 반복하면 AP의 인증 처리 큐가 차고 정상 사용자의 요청이 지연되거나 거부될 수 있습니다.",
          reviewPhaseIndex: 2
        }
      },
      technical: "Authentication request 비율, 고유 source MAC 수, 응답 지연과 Association 실패율을 함께 분석합니다. 연속적으로 바뀌는 MAC에서 같은 AP로 요청이 몰리면 공격 가능성이 큽니다.",
      baseAps: 3,
      nodes: [
        { id: "client", role: "client", icon: "💻", label: "정상 사용자", detail: "연결 요청 대기" },
        { id: "real-ap", role: "real-ap", icon: "📡", label: "테스트 AP", detail: "인증 처리 큐" },
        { id: "attacker", role: "attacker", icon: "🚧", label: "가짜 클라이언트", detail: "랜덤 MAC 생성" },
        { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: "Auth rate 분석" }
      ],
      defense: { name: "요청 속도 제한", description: "동일 AP로 들어오는 인증 요청 속도와 MAC 생성 패턴을 제한하고 비정상 source를 임시 차단합니다.", before: "정상 인증 실패", after: "정상 요청 우선 처리" },
      glossary: [
        { term: "Authentication", description: "무선 기기가 AP에 연결하기 전 신원을 확인하는 초기 단계입니다." },
        { term: "DoS", description: "서비스 자원을 소모시켜 정상 사용자가 이용하지 못하게 하는 공격입니다." },
        { term: "Rate Limit", description: "짧은 시간에 허용하는 요청 수를 제한하는 방어 방식입니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "NORMAL AUTH", title: "소수의 사용자가 순서대로 인증합니다", description: "AP의 인증 처리 큐와 응답 시간이 안정적입니다.", plain: "사용자가 연결을 요청하면 AP가 바로 응답할 수 있는 상태입니다.", severity: "neutral", rate: 19, alerts: 0, evidence: ["인증 요청 2~4회/초", "응답 시간 18ms", "고유 MAC 증가율 안정"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("client", "real-ap", "normal", "Auth Request"), link("real-ap", "sensor", "normal", "정상 응답")], packet: packet("client", "real-ap", "AUTH", "normal"), event: event("Authentication", "normal", "8C:F5:A3:11:02:44", "Open System 인증 성공", "정상"), packetFields: { "Auth Rate": "3 req/s", "Response": "18ms", "Result": "Success" } },
        { label: "공격 준비", kicker: "MAC ROTATION", title: "공격자가 수백 개의 가짜 MAC을 생성합니다", description: "각 요청이 다른 기기처럼 보이도록 source 주소가 빠르게 바뀝니다.", plain: "한 공격자가 수많은 새 기기인 것처럼 신분을 계속 바꾸고 있습니다.", severity: "medium", rate: 84, alerts: 5, evidence: ["로컬 관리 MAC 비율 증가", "MAC 주소가 일정 패턴으로 회전", "동일 장비 특성의 요청 반복"], states: { client: "normal", "real-ap": "normal", attacker: "warning", sensor: "warning" }, links: [link("client", "real-ap", "normal", "정상 요청"), link("attacker", "sensor", "warning", "MAC Rotation")], packet: packet("attacker", "sensor", "MAC++", "warning"), event: event("MAC Rotation", "warning", "02:AA:xx:xx:xx:xx", "고유 source 62개 / 5s", "의심"), packetFields: { "Unique Source": "62 / 5s", "Local MAC": "94%", "Target": "CC:33:44:55:66:03" } },
        { label: "공격 진행", kicker: "AUTH REQUEST FLOOD", title: "가짜 인증 요청이 AP로 폭주합니다", description: "랜덤 MAC에서 생성된 요청이 인증 처리 큐를 빠르게 채웁니다.", plain: "가짜 사용자들이 한꺼번에 줄을 서서 AP가 정상 사용자를 처리하지 못하게 합니다.", severity: "high", rate: 634, alerts: 44, evidence: ["인증 요청 521회/초", "고유 source MAC 410개", "정상 범위 대비 173배 증가"], states: { client: "warning", "real-ap": "danger", attacker: "danger", sensor: "warning" }, links: [link("attacker", "real-ap", "attack", "Auth Flood"), link("client", "real-ap", "warning", "정상 요청 지연"), link("attacker", "sensor", "attack", "521 req/s")], packet: packet("attacker", "real-ap", "AUTH×", "attack"), event: event("Auth Flood", "attack", "02:AA:xx:xx:xx:xx", "521 req/s · 410 sources", "위험"), packetFields: { "Auth Rate": "521 req/s", "Unique Source": "410", "Queue": "96%" } },
        { label: "영향 발생", kicker: "SERVICE EXHAUSTED", title: "정상 사용자의 인증이 지연되거나 실패합니다", description: "AP의 처리 큐가 가득 차고 정상 요청의 응답 시간이 크게 늘어납니다.", plain: "정상 사용자가 와이파이에 연결하려 해도 AP가 너무 바빠 응답하지 못합니다.", severity: "critical", rate: 802, alerts: 71, evidence: ["정상 인증 실패율 81%", "평균 응답 시간 2.8초", "Association 재시도 19회"], states: { client: "offline", "real-ap": "danger", attacker: "danger", sensor: "danger" }, links: [link("attacker", "real-ap", "attack", "큐 포화"), link("client", "real-ap", "inactive", "인증 실패"), link("sensor", "real-ap", "warning", "자원 고갈")], packet: packet("attacker", "real-ap", "AUTH×", "attack"), event: event("Auth Timeout", "attack", "정상 사용자", "응답 2.8s · 실패율 81%", "심각"), packetFields: { "Failure Rate": "81%", "Response": "2.8s", "Retry": "19" } },
        { label: "탐지·대응", kicker: "RATE LIMITED", title: "비정상 요청을 제한해 인증 서비스를 복구합니다", description: "센서는 source 다양성과 요청 속도를 기준으로 공격 그룹을 묶고 제한합니다.", plain: "가짜 사용자들의 요청 속도를 줄여 정상 사용자가 다시 연결할 수 있게 했습니다.", severity: "resolved", rate: 42, alerts: 1, evidence: ["랜덤 MAC 군집 식별", "인증 요청 임계값 초과 source 제한", "정상 인증 응답 24ms로 회복"], states: { client: "defense", "real-ap": "defense", attacker: "danger", sensor: "defense" }, links: [link("client", "real-ap", "defense", "정상 Auth"), link("sensor", "attacker", "defense", "Rate Limit")], packet: packet("client", "real-ap", "AUTH OK", "defense"), event: event("Rate Limit", "defense", "WFSAT", "비정상 source 군집 제한", "대응 완료"), packetFields: { "Detection": "Authentication DoS", "Blocked Group": "410 MAC", "Response": "24ms" } }
      ]
    },
    {
      id: "wids-confusion",
      icon: "🌀",
      shortName: "WIDS 혼란",
      title: "WIDS/WIPS 혼란 공격",
      english: "WIDS Confusion",
      layer: "관리 프레임 이상",
      summary: "서로 모순되는 주소와 상태를 가진 관리 프레임을 대량으로 전송해 무선 침입 탐지 센서의 판단을 흐리는 과정을 확인합니다.",
      learning: {
        estimatedMinutes: 4,
        objectives: ["단일 경고가 오탐일 수 있음을 이해하기", "모순된 주소·상태 전이 찾기", "여러 신호를 함께 분석하는 이유 알기"],
        checkpoint: {
          prompt: "WIDS 혼란 공격을 안정적으로 판별하려면 어떤 방식이 적절한가요?",
          options: [
            { id: "a", label: "경고 프레임 하나만 보고 즉시 공격으로 확정합니다." },
            { id: "b", label: "주소, 채널, 시간 순서와 상태 전이를 함께 비교합니다." },
            { id: "c", label: "모든 관리 프레임을 정상으로 처리합니다." }
          ],
          correctOptionId: "b",
          explanation: "혼란 공격은 서로 모순되는 신호로 센서를 속입니다. 따라서 단일 프레임보다 주소·채널·시계열·상태 전이의 일관성을 함께 봐야 합니다.",
          reviewPhaseIndex: 3
        }
      },
      technical: "불가능한 상태 전이, BSSID/채널 불일치, sequence 재사용, 비정상 subtype 조합과 source 회전 속도를 함께 분석합니다. 단일 프레임보다 연속된 모순 패턴이 핵심입니다.",
      baseAps: 5,
      nodes: [
        { id: "client", role: "client", icon: "💻", label: "정상 단말", detail: "정상 상태 전이" },
        { id: "real-ap", role: "real-ap", icon: "📡", label: "정상 AP", detail: "고정 BSSID/채널" },
        { id: "attacker", role: "attacker", icon: "🌀", label: "혼란 프레임 생성기", detail: "모순 상태·주소" },
        { id: "sensor", role: "sensor", icon: "🛡️", label: "WIDS 센서", detail: "상관분석 엔진" }
      ],
      defense: { name: "상태 전이 상관분석", description: "개별 경고 개수보다 동일 송신 특성과 불가능한 연결 순서를 묶어 하나의 공격 캠페인으로 처리합니다.", before: "수백 개 경고 생성", after: "공격 캠페인 1건" },
      glossary: [
        { term: "WIDS", description: "무선 환경의 이상 프레임과 침입을 탐지하는 시스템입니다." },
        { term: "WIPS", description: "탐지를 넘어 차단·격리 대응까지 수행하는 무선 보호 시스템입니다." },
        { term: "상태 전이", description: "탐색→인증→연결처럼 정상적으로 이어지는 연결 단계입니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "CONSISTENT STATE", title: "AP와 단말의 연결 상태가 순서대로 이어집니다", description: "BSSID, 채널, sequence와 연결 단계가 서로 일치합니다.", plain: "정상 통신은 ‘탐색하고 인증한 뒤 연결’처럼 순서가 자연스럽습니다.", severity: "neutral", rate: 36, alerts: 0, evidence: ["정상 상태 전이", "BSSID와 채널 정보 일치", "sequence 연속성 유지"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("client", "real-ap", "normal", "정상 시퀀스"), link("real-ap", "sensor", "normal", "일관된 상태")], packet: packet("client", "real-ap", "ASSOC", "normal"), event: event("State Update", "normal", "정상 단말", "Auth → Association", "정상"), packetFields: { "State": "Authenticated → Associated", "Channel": "6", "Sequence": "882" } },
        { label: "공격 준비", kicker: "CRAFTED FRAMES", title: "공격자가 모순된 관리 프레임 조합을 준비합니다", description: "존재하지 않는 BSSID와 어긋난 채널·sequence가 생성됩니다.", plain: "공격자가 앞뒤가 맞지 않는 연결 기록을 여러 장 만들어 센서를 속이려 합니다.", severity: "medium", rate: 91, alerts: 7, evidence: ["미등록 BSSID 증가", "동일 sequence 재사용", "채널 정보 불일치"], states: { client: "normal", "real-ap": "normal", attacker: "warning", sensor: "warning" }, links: [link("client", "real-ap", "normal", "정상 통신"), link("attacker", "sensor", "warning", "모순 프레임")], packet: packet("attacker", "sensor", "SEQ?", "warning"), event: event("Malformed State", "warning", "02:FE:xx:xx:xx:01", "Association without Auth", "의심"), packetFields: { "State": "Association without Auth", "Channel": "6 / 11 mismatch", "Sequence": "1024 reused" } },
        { label: "공격 진행", kicker: "ALERT STORM", title: "서로 다른 가짜 사건이 센서로 쏟아집니다", description: "주소와 유형을 바꾼 모순 프레임이 대량 전송되어 경고를 폭발시킵니다.", plain: "센서가 진짜 공격을 찾기 어렵도록 수백 개의 가짜 사건을 동시에 만들고 있습니다.", severity: "high", rate: 588, alerts: 184, evidence: ["20개 subtype 조합 급증", "가짜 BSSID 126개", "1초 동안 모순 상태 184건"], states: { client: "normal", "real-ap": "warning", attacker: "danger", sensor: "danger" }, links: [link("attacker", "sensor", "attack", "Alert Storm"), link("attacker", "real-ap", "attack", "State Confusion"), link("client", "real-ap", "normal", "정상 신호")], packet: packet("attacker", "sensor", "ALERT×", "attack"), event: event("Alert Storm", "attack", "02:FE:xx:xx:xx:xx", "모순 상태 184건 / 1s", "위험"), packetFields: { "Invalid State": "184 / 1s", "Fake BSSID": "126", "Subtype Mix": "20" } },
        { label: "영향 발생", kicker: "SENSOR OVERLOAD", title: "중요 경고가 가짜 경고 사이에 묻힙니다", description: "센서 자원과 분석가의 주의가 분산되어 실제 Deauth 이벤트의 우선순위가 낮아집니다.", plain: "가짜 경보가 너무 많아 진짜 위험 경보를 놓칠 수 있는 상태입니다.", severity: "critical", rate: 731, alerts: 246, evidence: ["경고 큐 사용률 94%", "실제 Deauth 분류 지연 3.7초", "중복 경고가 전체의 88%"], states: { client: "warning", "real-ap": "warning", attacker: "danger", sensor: "danger" }, links: [link("attacker", "sensor", "attack", "센서 과부하"), link("real-ap", "sensor", "warning", "진짜 경고 지연"), link("client", "real-ap", "warning", "위험 노출")], packet: packet("attacker", "sensor", "NOISE", "attack"), event: event("Sensor Overload", "attack", "WIDS Queue", "사용률 94% · 지연 3.7s", "심각"), packetFields: { "Alert Queue": "94%", "Duplicate": "88%", "Detection Delay": "3.7s" } },
        { label: "탐지·대응", kicker: "CAMPAIGN CORRELATION", title: "가짜 경고를 하나의 공격 캠페인으로 묶습니다", description: "송신 특성, 시간 간격, 상태 모순을 상관분석해 중복 경고를 압축합니다.", plain: "수백 개의 가짜 사건이 사실은 한 공격자에게서 나온 공격이라는 것을 알아냈습니다.", severity: "resolved", rate: 61, alerts: 1, evidence: ["동일 RF 특성으로 source 군집화", "상태 전이 위반 패턴 일치", "246개 경고를 캠페인 1건으로 축약"], states: { client: "defense", "real-ap": "defense", attacker: "danger", sensor: "defense" }, links: [link("real-ap", "sensor", "defense", "정상 우선"), link("sensor", "attacker", "defense", "군집 차단")], packet: packet("sensor", "attacker", "GROUP", "defense"), event: event("Campaign Grouped", "defense", "WFSAT", "246 alerts → 1 campaign", "대응 완료"), packetFields: { "Detection": "WIDS Confusion", "Grouped Alerts": "246", "Campaign": "1" } }
      ]
    },
    {
      id: "karma",
      icon: "🎭",
      shortName: "KARMA",
      title: "KARMA 공격",
      english: "KARMA Attack",
      layer: "Probe Response",
      summary: "클라이언트가 예전에 사용한 와이파이를 찾는 Probe Request에 공격자의 AP가 모두 응답해 자동 연결을 유도하는 과정을 확인합니다.",
      learning: {
        estimatedMinutes: 4,
        objectives: ["Probe Request가 노출하는 정보 이해하기", "모든 SSID에 응답하는 AP 찾기", "자동 연결을 줄이는 습관 익히기"],
        checkpoint: {
          prompt: "KARMA AP를 의심할 수 있는 행동은 무엇인가요?",
          options: [
            { id: "a", label: "하나의 등록된 SSID에만 정상적으로 응답합니다." },
            { id: "b", label: "클라이언트가 묻는 여러 저장 SSID에 같은 AP가 모두 응답합니다." },
            { id: "c", label: "암호화된 데이터 프레임을 전달합니다." }
          ],
          correctOptionId: "b",
          explanation: "서로 다른 저장 네트워크 이름에 같은 AP가 연속으로 응답하면 클라이언트가 찾는 모든 네트워크인 척하는 KARMA 동작일 가능성이 큽니다.",
          reviewPhaseIndex: 2
        }
      },
      technical: "통제된 여러 SSID로 Probe를 보냈을 때 하나의 BSSID가 서로 무관한 이름에 반복 응답하는지 확인합니다. 광고하지 않던 SSID에 즉시 Probe Response를 보내는 패턴이 핵심입니다.",
      baseAps: 4,
      nodes: [
        { id: "client", role: "client", icon: "📱", label: "사용자 기기", detail: "저장 네트워크 탐색" },
        { id: "real-ap", role: "real-ap", icon: "☁️", label: "저장된 네트워크", detail: "Cafe_Free_WiFi" },
        { id: "attacker", role: "attacker", icon: "🎭", label: "KARMA AP", detail: "모든 SSID에 응답" },
        { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: "Probe 상관분석" }
      ],
      defense: { name: "자동 연결 해제·MAC 랜덤화", description: "저장된 Open 네트워크의 자동 연결을 끄고 Probe에 기기 고유 정보가 노출되지 않도록 MAC 랜덤화를 사용합니다.", before: "Rogue AP 자동 연결", after: "사용자 확인 후 연결" },
      glossary: [
        { term: "Probe Request", description: "클라이언트가 주변에 특정 와이파이가 있는지 묻는 관리 프레임입니다." },
        { term: "PNL", description: "기기에 저장된 선호 네트워크 목록입니다." },
        { term: "MAC 랜덤화", description: "탐색 과정에서 실제 MAC 대신 임시 주소를 사용하는 기능입니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "PASSIVE DISCOVERY", title: "기기는 주변 AP의 Beacon을 기다립니다", description: "저장된 네트워크가 실제로 있을 때만 연결을 시도합니다.", plain: "기기가 먼저 와이파이 이름을 공개하지 않고 주변의 안내 신호를 기다리는 안전한 상태입니다.", severity: "neutral", rate: 22, alerts: 0, evidence: ["Directed Probe 거의 없음", "등록 AP에만 연결", "MAC 랜덤화 활성"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("real-ap", "client", "normal", "Beacon"), link("client", "sensor", "normal", "수동 탐색")], packet: packet("real-ap", "client", "BEACON", "normal"), event: event("Passive Scan", "normal", "사용자 기기", "Beacon 기반 네트워크 탐색", "정상"), packetFields: { "Probe": "Wildcard only", "MAC": "Randomized", "Auto Join": "Disabled" } },
        { label: "공격 준비", kicker: "PNL DISCLOSURE", title: "기기가 저장된 네트워크 이름을 질문합니다", description: "자동 연결 설정 때문에 주변에 Cafe_Free_WiFi가 있는지 Probe Request로 묻습니다.", plain: "기기가 예전에 연결했던 와이파이 이름을 주변에 소리 내어 물어봅니다.", severity: "medium", rate: 47, alerts: 2, evidence: ["특정 SSID가 포함된 Directed Probe", "동일 기기에서 여러 저장 SSID 노출", "Open 네트워크 자동 연결 설정"], states: { client: "warning", "real-ap": "idle", attacker: "warning", sensor: "warning" }, links: [link("client", "attacker", "warning", "Cafe_Free_WiFi?"), link("client", "sensor", "warning", "PNL 노출")], packet: packet("client", "attacker", "PROBE?", "warning"), event: event("Directed Probe", "warning", "DA:7A:xx:xx:12:34", "Cafe_Free_WiFi 탐색", "의심"), packetFields: { "SSID": "Cafe_Free_WiFi", "Probe Type": "Directed", "Privacy": "PNL exposed" } },
        { label: "공격 진행", kicker: "ANY SSID RESPONSE", title: "KARMA AP가 모든 질문에 ‘여기 있다’고 답합니다", description: "실제로 광고하지 않던 여러 SSID 요청에 동일 BSSID가 즉시 Probe Response를 전송합니다.", plain: "공격자의 AP가 어떤 와이파이 이름을 물어봐도 자기 자신이 그 와이파이라고 거짓말합니다.", severity: "high", rate: 188, alerts: 18, aps: 7, evidence: ["한 BSSID가 7개 SSID에 응답", "Probe 후 평균 4ms 안에 응답", "응답 SSID가 사전 Beacon 목록에 없음"], states: { client: "warning", "real-ap": "idle", attacker: "danger", sensor: "warning" }, links: [link("client", "attacker", "warning", "여러 Probe"), link("attacker", "client", "attack", "모든 SSID 응답"), link("attacker", "sensor", "attack", "응답 상관관계")], packet: packet("attacker", "client", "YES!", "attack"), event: event("KARMA Response", "attack", "DE:AD:BE:EF:00:01", "7개 SSID에 동일 BSSID 응답", "위험"), packetFields: { "Responded SSID": "7", "BSSID": "DE:AD:BE:EF:00:01", "Latency": "4ms" } },
        { label: "영향 발생", kicker: "AUTO ASSOCIATION", title: "기기가 공격자의 AP에 자동 연결됩니다", description: "저장된 Open 네트워크와 이름이 같다고 판단한 기기가 인증 없이 연결됩니다.", plain: "기기는 익숙한 와이파이라고 착각해 사용자의 확인 없이 공격자에게 연결됩니다.", severity: "critical", rate: 126, alerts: 29, aps: 7, evidence: ["미등록 BSSID에 Association", "Open 네트워크 자동 연결", "Gateway와 DNS가 공격자 주소로 변경"], states: { client: "danger", "real-ap": "idle", attacker: "danger", sensor: "danger" }, links: [link("client", "attacker", "attack", "자동 연결"), link("attacker", "sensor", "warning", "Rogue Gateway")], packet: packet("client", "attacker", "ASSOC", "attack"), event: event("Auto Association", "attack", "사용자 기기", "KARMA AP 연결 완료", "심각"), packetFields: { "Association": "DE:AD:BE:EF:00:01", "Security": "OPEN", "Gateway": "10.0.0.1" } },
        { label: "탐지·대응", kicker: "ACTIVE PROBE TEST", title: "통제 Probe로 모든 이름에 응답하는 AP를 확인합니다", description: "센서는 존재하지 않는 테스트 SSID를 질문해 Rogue AP가 거짓 응답하는지 검증합니다.", plain: "센서가 가짜 질문을 던졌는데도 공격 AP가 ‘내가 그 와이파이야’라고 답해 정체가 드러났습니다.", severity: "resolved", rate: 35, alerts: 1, aps: 4, evidence: ["무작위 테스트 SSID 3개 모두 응답", "동일 BSSID·응답 타이밍 일치", "자동 연결 해제 후 재접속 차단"], states: { client: "defense", "real-ap": "normal", attacker: "danger", sensor: "defense" }, links: [link("sensor", "attacker", "defense", "통제 Probe"), link("client", "sensor", "defense", "자동 연결 해제")], packet: packet("sensor", "attacker", "TEST", "defense"), event: event("KARMA Detected", "defense", "WFSAT", "무작위 SSID 응답 검증", "대응 완료"), packetFields: { "Detection": "KARMA", "Test SSID": "3 / 3 responded", "Action": "Auto Join disabled" } }
      ]
    },
    {
      id: "arp-spoofing",
      icon: "🔀",
      shortName: "ARP 스푸핑",
      title: "ARP 스푸핑 공격",
      english: "ARP Spoofing",
      layer: "LAN · ARP",
      summary: "공격자가 게이트웨이의 IP 주소를 자신의 MAC 주소와 연결하도록 속여 클라이언트 트래픽이 공격자를 경유하게 만드는 과정을 확인합니다.",
      learning: {
        estimatedMinutes: 4,
        objectives: ["IP 주소와 MAC 주소의 역할 구분하기", "게이트웨이 MAC 변경을 이상 징후로 찾기", "ARP 검증 방어의 목적 이해하기"],
        checkpoint: {
          prompt: "ARP 스푸핑을 가장 직접적으로 보여 주는 변화는 무엇인가요?",
          options: [
            { id: "a", label: "게이트웨이 IP에 연결된 MAC 주소가 갑자기 공격자 주소로 바뀝니다." },
            { id: "b", label: "AP가 정상 Beacon을 전송합니다." },
            { id: "c", label: "클라이언트 IP 주소가 그대로 유지됩니다." }
          ],
          correctOptionId: "a",
          explanation: "게이트웨이 IP는 그대로인데 대응하는 MAC 주소가 미등록 장치로 바뀌면 트래픽 경로를 공격자에게 돌리는 ARP 스푸핑의 핵심 징후입니다.",
          reviewPhaseIndex: 2
        }
      },
      technical: "동일 IP에 대해 MAC 매핑이 변경되는지, 요청하지 않은 ARP Reply와 Gratuitous ARP가 급증하는지, gateway MAC의 OUI가 바뀌는지를 분석합니다.",
      baseAps: 1,
      nodes: [
        { id: "client", role: "client", icon: "💻", label: "피해 클라이언트", detail: "192.168.10.24" },
        { id: "real-ap", role: "real-ap", icon: "🌐", label: "게이트웨이", detail: "192.168.10.1" },
        { id: "attacker", role: "attacker", icon: "🔀", label: "중간자 공격자", detail: "192.168.10.77" },
        { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: "ARP 테이블 감시" }
      ],
      defense: { name: "정적 ARP·DAI", description: "중요 게이트웨이 매핑을 고정하거나 스위치의 Dynamic ARP Inspection으로 허가되지 않은 ARP Reply를 차단합니다.", before: "트래픽 공격자 경유", after: "게이트웨이 직접 통신" },
      glossary: [
        { term: "ARP", description: "같은 네트워크에서 IP 주소에 해당하는 MAC 주소를 찾는 프로토콜입니다." },
        { term: "Gratuitous ARP", description: "요청 없이 자신의 IP–MAC 정보를 알리는 ARP 메시지입니다." },
        { term: "중간자 공격", description: "두 장치 사이에 끼어 통신을 엿보거나 바꾸는 공격입니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "DIRECT ROUTE", title: "클라이언트가 게이트웨이와 직접 통신합니다", description: "ARP 테이블에는 게이트웨이 IP와 실제 라우터 MAC이 연결되어 있습니다.", plain: "노트북의 인터넷 트래픽이 공격자를 거치지 않고 공유기로 바로 이동합니다.", severity: "neutral", rate: 32, alerts: 0, evidence: ["게이트웨이 MAC이 기준값과 일치", "ARP Reply 빈도 안정", "트래픽 경로 변경 없음"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("client", "real-ap", "normal", "직접 통신"), link("client", "sensor", "normal", "ARP 기준선")], packet: packet("client", "real-ap", "DATA", "normal"), event: event("ARP Entry", "normal", "192.168.10.1", "Gateway → AA:BB:CC:00:00:01", "정상"), packetFields: { "IP": "192.168.10.1", "MAC": "AA:BB:CC:00:00:01", "Route": "Direct" } },
        { label: "공격 준비", kicker: "NETWORK DISCOVERY", title: "공격자가 피해자와 게이트웨이를 찾습니다", description: "ARP 요청과 응답을 관찰해 네트워크의 주요 IP·MAC 관계를 수집합니다.", plain: "공격자가 누구의 주소를 속여야 하는지 주변 장치 목록을 확인합니다.", severity: "low", rate: 49, alerts: 0, evidence: ["짧은 범위 ARP Scan", "새 장치가 다수 IP를 질의", "아직 MAC 매핑 변경 없음"], states: { client: "normal", "real-ap": "normal", attacker: "warning", sensor: "normal" }, links: [link("client", "real-ap", "normal", "직접 통신"), link("attacker", "sensor", "warning", "ARP Scan"), link("attacker", "real-ap", "warning", "Who has?")], packet: packet("attacker", "real-ap", "ARP?", "warning"), event: event("ARP Scan", "warning", "192.168.10.77", "24개 IP 연속 질의", "관찰"), packetFields: { "Operation": "Request", "Scanned IP": "24", "Interval": "12ms" } },
        { label: "공격 진행", kicker: "POISONED REPLY", title: "위조 ARP Reply가 게이트웨이 주소를 덮어씁니다", description: "공격자는 ‘게이트웨이 IP는 내 MAC 주소’라는 거짓 정보를 반복 전송합니다.", plain: "공격자가 노트북의 주소록에서 공유기 주소를 자기 주소로 바꿉니다.", severity: "high", rate: 176, alerts: 16, evidence: ["동일 IP의 MAC 매핑 변경", "요청하지 않은 ARP Reply 반복", "Gateway OUI가 알려진 제조사와 불일치"], states: { client: "warning", "real-ap": "normal", attacker: "danger", sensor: "warning" }, links: [link("attacker", "client", "attack", "위조 ARP Reply"), link("client", "real-ap", "warning", "매핑 변경 중"), link("attacker", "sensor", "attack", "Unsolicited Reply")], packet: packet("attacker", "client", "ARP REPLY", "attack"), event: event("ARP Mapping Change", "attack", "192.168.10.77", "Gateway MAC → DE:AD:BE:EF:77:01", "위험"), packetFields: { "Claimed IP": "192.168.10.1", "Claimed MAC": "DE:AD:BE:EF:77:01", "Unsolicited": "Yes" } },
        { label: "영향 발생", kicker: "MAN-IN-THE-MIDDLE", title: "모든 트래픽이 공격자를 거쳐 전달됩니다", description: "클라이언트는 공격자 MAC으로 프레임을 보내고 공격자는 이를 게이트웨이에 중계합니다.", plain: "인터넷은 계속 되는 것처럼 보이지만 모든 데이터가 공격자 컴퓨터를 먼저 지나갑니다.", severity: "critical", rate: 348, alerts: 29, evidence: ["기본 게이트웨이 MAC 변경 유지", "트래픽의 next hop이 공격자 MAC", "ARP Reply가 2초마다 재주입"], states: { client: "danger", "real-ap": "warning", attacker: "danger", sensor: "danger" }, links: [link("client", "attacker", "attack", "트래픽 탈취"), link("attacker", "real-ap", "attack", "중계"), link("sensor", "attacker", "warning", "MITM 추적")], packet: packet("client", "attacker", "DATA", "attack"), event: event("MITM Route", "attack", "피해 클라이언트", "Next hop → 공격자 MAC", "심각"), packetFields: { "Next Hop": "DE:AD:BE:EF:77:01", "Forwarding": "Enabled", "Refresh": "2s" } },
        { label: "탐지·대응", kicker: "MAPPING RESTORED", title: "신뢰 매핑을 복원하고 위조 Reply를 차단합니다", description: "센서는 변경 전후 MAC과 Reply 흐름을 근거로 공격을 판정하고 정상 게이트웨이 정보를 복구합니다.", plain: "주소록을 원래대로 되돌리고 공격자의 거짓 주소 안내를 더 이상 받지 않습니다.", severity: "resolved", rate: 39, alerts: 1, evidence: ["게이트웨이 IP의 MAC 변경 감지", "정상 OUI·기준 MAC으로 복원", "Unsolicited ARP 차단"], states: { client: "defense", "real-ap": "defense", attacker: "danger", sensor: "defense" }, links: [link("client", "real-ap", "defense", "직접 경로 복구"), link("sensor", "attacker", "defense", "ARP 차단")], packet: packet("client", "real-ap", "STATIC", "defense"), event: event("ARP Restored", "defense", "WFSAT", "신뢰 Gateway MAC 복원", "대응 완료"), packetFields: { "Detection": "ARP Spoofing", "Restored MAC": "AA:BB:CC:00:00:01", "Policy": "Static ARP" } }
      ]
    },
    {
      id: "handshake",
      icon: "🤝",
      shortName: "핸드셰이크",
      title: "WPA 핸드셰이크·PMKID 수집",
      english: "WPA Handshake / PMKID",
      layer: "EAPOL · WPA 인증",
      summary: "클라이언트가 AP에 연결할 때 오가는 EAPOL 4단계 메시지와 PMKID가 어떻게 캡처되고 검증되는지 시퀀스로 살펴봅니다.",
      learning: {
        estimatedMinutes: 5,
        objectives: ["4-way Handshake의 의미 이해하기", "캡처와 비밀번호 유출을 구분하기", "강한 암호와 WPA3-SAE의 이점 알기"],
        checkpoint: {
          prompt: "완전한 WPA 핸드셰이크가 캡처되었다는 설명으로 옳은 것은 무엇인가요?",
          options: [
            { id: "a", label: "와이파이 비밀번호가 즉시 평문으로 노출됐다는 뜻입니다." },
            { id: "b", label: "암호화가 자동으로 해제되어 모든 트래픽을 읽을 수 있습니다." },
            { id: "c", label: "인증 교환이 기록됐으며 약한 비밀번호는 오프라인 추측 위험이 있습니다." }
          ],
          correctOptionId: "c",
          explanation: "핸드셰이크 캡처 자체는 비밀번호 유출이 아닙니다. 다만 짧고 흔한 비밀번호는 캡처 데이터를 이용한 오프라인 추측에 취약할 수 있습니다.",
          reviewPhaseIndex: 4
        }
      },
      technical: "EAPOL-Key message의 ACK, MIC, Install, Secure 플래그와 replay counter를 조합해 M1~M4 순서를 판별합니다. RSN 정보의 PMKID 필드도 별도로 확인합니다.",
      baseAps: 3,
      nodes: [
        { id: "client", role: "client", icon: "💻", label: "연결 클라이언트", detail: "Supplicant" },
        { id: "real-ap", role: "real-ap", icon: "📡", label: "WPA2 AP", detail: "Authenticator" },
        { id: "attacker", role: "attacker", icon: "📻", label: "패킷 수집자", detail: "모니터 모드" },
        { id: "sensor", role: "sensor", icon: "🧩", label: "WFSAT 분석기", detail: "EAPOL 시퀀스" }
      ],
      defense: { name: "강한 암호·WPA3 SAE", description: "복잡한 비밀번호를 사용하고 오프라인 사전 대입에 강한 WPA3-SAE로 전환합니다. PMF를 함께 사용해 강제 재연결도 줄입니다.", before: "오프라인 추측 가능", after: "SAE로 재사용 공격 완화" },
      glossary: [
        { term: "EAPOL", description: "WPA 연결 과정에서 키 정보를 교환하는 프레임입니다." },
        { term: "4-way Handshake", description: "AP와 클라이언트가 암호화 키를 확인하는 네 단계 교환입니다." },
        { term: "PMKID", description: "AP가 키 캐시를 식별하기 위해 사용하는 값으로 일부 환경에서 캡처될 수 있습니다." }
      ],
      phases: [
        { label: "정상 상태", kicker: "ENCRYPTED SESSION", title: "클라이언트가 암호화된 세션으로 통신합니다", description: "이미 인증이 완료되어 일반 데이터 프레임만 관측됩니다.", plain: "현재 연결은 암호화되어 있고 새 인증 메시지는 오가지 않습니다.", severity: "neutral", rate: 51, alerts: 0, evidence: ["EAPOL 프레임 없음", "데이터 프레임 Protected bit 활성", "연결 상태 안정"], states: { client: "normal", "real-ap": "normal", attacker: "idle", sensor: "normal" }, links: [link("client", "real-ap", "normal", "암호화 Data"), link("real-ap", "sensor", "normal", "정상 세션")], packet: packet("client", "real-ap", "DATA", "normal"), event: event("Encrypted Data", "normal", "연결 클라이언트", "Protected data frame", "정상"), packetFields: { "Protected": "1", "EAPOL": "None", "Association": "Active" } },
        { label: "공격 준비", kicker: "CAPTURE READY", title: "수집자가 타겟 채널에서 EAPOL을 기다립니다", description: "모니터 인터페이스가 AP 채널과 BSSID로 필터링됩니다.", plain: "분석기가 새로 연결하는 순간에만 나오는 인증 메시지를 기다리고 있습니다.", severity: "low", rate: 58, alerts: 0, evidence: ["BSSID 화이트리스트 필터 적용", "EAPOL 표시 필터 활성", "아직 핸드셰이크 없음"], states: { client: "normal", "real-ap": "normal", attacker: "warning", sensor: "normal" }, links: [link("client", "real-ap", "normal", "기존 연결"), link("attacker", "sensor", "warning", "캡처 대기")], packet: packet("real-ap", "sensor", "BEACON", "warning"), event: event("Capture Armed", "warning", "wlan1mon", "BSSID·CH 6 필터 적용", "대기"), packetFields: { "Filter": "EAPOL or PMKID", "Channel": "6", "BSSID": "CC:33:44:55:66:03" } },
        { label: "공격 진행", kicker: "RECONNECTION TRIGGER", title: "재연결 과정에서 EAPOL 메시지가 시작됩니다", description: "격리 실습에서 클라이언트를 재연결하면 AP가 M1을 보내고 키 교환이 진행됩니다.", plain: "기기가 와이파이에 다시 연결하면서 서로 암호를 알고 있는지 확인하는 네 번의 대화가 시작됩니다.", severity: "medium", rate: 132, alerts: 6, evidence: ["EAPOL M1·M2 순서 확인", "replay counter가 정상 증가", "AP와 등록 클라이언트 주소 일치"], states: { client: "warning", "real-ap": "warning", attacker: "warning", sensor: "warning" }, links: [link("real-ap", "client", "warning", "EAPOL M1"), link("client", "real-ap", "warning", "EAPOL M2"), link("real-ap", "sensor", "warning", "시퀀스 캡처")], packet: packet("real-ap", "client", "M1", "warning"), event: event("EAPOL M1/M2", "warning", "WPA2 AP", "Replay counter 15 → 16", "수집 중"), packetFields: { "EAPOL": "M1, M2", "Replay Counter": "15 → 16", "MIC": "M2 present" } },
        { label: "영향 발생", kicker: "HANDSHAKE CAPTURED", title: "M1부터 M4까지 완전한 교환이 수집됩니다", description: "분석기는 플래그와 replay counter를 이용해 완전한 핸드셰이크임을 확인합니다.", plain: "네 단계의 인증 대화가 모두 기록되어 나중에 비밀번호 강도를 시험할 수 있는 상태입니다.", severity: "high", rate: 146, alerts: 12, evidence: ["M1·M2·M3·M4 모두 존재", "AP–클라이언트 쌍 일치", "MIC와 replay counter 검증 통과"], states: { client: "normal", "real-ap": "normal", attacker: "danger", sensor: "danger" }, links: [link("client", "real-ap", "warning", "EAPOL M1–M4"), link("real-ap", "sensor", "attack", "Handshake Capture"), link("attacker", "sensor", "attack", "PCAP 저장")], packet: packet("client", "real-ap", "M4", "attack"), event: event("Handshake Complete", "attack", "WFSAT", "EAPOL M1–M4 검증 완료", "위험"), packetFields: { "EAPOL": "M1 M2 M3 M4", "MIC": "Valid structure", "PCAP": "session-008.pcap" } },
        { label: "탐지·대응", kicker: "PASSWORD RISK", title: "캡처 사실과 비밀번호 위험을 구분해 설명합니다", description: "핸드셰이크 캡처 자체는 비밀번호 유출이 아니지만 약한 암호는 오프라인 추측에 노출될 수 있습니다.", plain: "인증 대화가 기록됐다고 바로 암호가 풀린 것은 아니지만, 짧고 흔한 비밀번호는 위험합니다.", severity: "resolved", rate: 54, alerts: 1, evidence: ["완전한 핸드셰이크 캡처 확인", "실제 자격증명 값은 저장하지 않음", "WPA3-SAE와 강한 암호 권고"], states: { client: "defense", "real-ap": "defense", attacker: "warning", sensor: "defense" }, links: [link("client", "real-ap", "defense", "WPA3-SAE"), link("sensor", "attacker", "defense", "캡처 경고")], packet: packet("client", "real-ap", "SAE", "defense"), event: event("Security Guidance", "defense", "WFSAT", "WPA3-SAE·강한 암호 권고", "대응 완료"), packetFields: { "Finding": "Handshake captured", "Credential Stored": "No", "Recommendation": "WPA3-SAE" } }
      ]
    }
  ];

  scenarios.forEach((scenario) => {
    scenario.glossary = [...scenario.glossary, ...commonGlossary].slice(0, 6);
    scenario.phases.forEach((phase, index) => {
      phase.index = index;
      phase.aps = typeof phase.aps === "number" ? phase.aps : scenario.baseAps;
      phase.sensor = phase.severity === "resolved" ? "방어 적용" : phase.severity === "critical" ? "경고" : "정상";
      phase.apsDelta = phase.aps === scenario.baseAps ? "기준선과 동일" : `기준선보다 +${phase.aps - scenario.baseAps}`;
      phase.alertsDelta = phase.alerts === 0 ? "활성 경고 없음" : phase.alerts === 1 && phase.severity === "resolved" ? "공격 세션 1건 정리" : `현재 단계 누적 ${phase.alerts}건`;
      phase.rateDelta = index < 2 ? "정상 범위" : index === 4 ? "대응 후 안정화" : `기준선 대비 ${Math.max(2, Math.round(phase.rate / scenario.phases[0].rate))}배`;
      phase.sensorDelta = phase.severity === "resolved" ? "탐지·대응 정책 활성" : phase.severity === "critical" ? "즉시 확인 필요" : "wlan1mon · 교육 모드";
    });
  });

  window.WFSAT_SCENARIOS = scenarios;
})();
