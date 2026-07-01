"""
WFSAT Dashboard - UI mockup (no real detection/response logic, mock data only)
Run: streamlit run dashboard/app.py
"""
import datetime as dt
import random

import altair as alt
import pandas as pd
import plotly.express as px
import streamlit as st

st.set_page_config(page_title="WFSAT Dashboard", layout="wide", initial_sidebar_state="expanded")

# ---------------------------------------------------------------------------
# Mock data
# ---------------------------------------------------------------------------

ATTACK_TYPES = ["Deauth Flood", "Evil Twin", "Beacon Flood", "ARP Spoofing", "KARMA Attack"]

DEFAULT_LOG_LIMIT = 20

AP_ROWS = [
    {"ssid": "HomeWiFi_5G", "bssid": "AA:11:22:33:44:01", "channel": 6, "rssi": -42, "enc": "WPA2", "status": "정상", "pkt_rate": 210},
    {"ssid": "HomeWiFi_5G", "bssid": "AA:11:22:33:44:99", "channel": 6, "rssi": -38, "enc": "OPEN", "status": "의심", "pkt_rate": 95},
    {"ssid": "CafeFreeNet", "bssid": "BB:22:33:44:55:02", "channel": 11, "rssi": -55, "enc": "WPA2", "status": "정상", "pkt_rate": 140},
    {"ssid": "OfficeAP", "bssid": "CC:33:44:55:66:03", "channel": 1, "rssi": -61, "enc": "WPA3", "status": "정상", "pkt_rate": 88},
    {"ssid": "OfficeAP", "bssid": "CC:33:44:55:66:E1", "channel": 1, "rssi": -33, "enc": "WPA2", "status": "공격중", "pkt_rate": 612},
    {"ssid": "Guest_Lobby", "bssid": "DD:44:55:66:77:04", "channel": 3, "rssi": -70, "enc": "WPA2", "status": "정상", "pkt_rate": 47},
]

STATUS_COLOR = {"정상": "#d4edda", "의심": "#fff3cd", "공격중": "#f8d7da"}


def make_log_rows(n=18):
    rows = []
    now = dt.datetime.now()
    states = ["신규", "대응중", "종료"]
    for i in range(n):
        ts = now - dt.timedelta(seconds=i * 37)
        rows.append({
            "시간": ts.strftime("%H:%M:%S"),
            "공격 유형": random.choice(ATTACK_TYPES),
            "발신지 MAC/BSSID": f"{'CC:33:44:55:66:E1' if i % 4 == 0 else 'AA:11:22:33:44:99'}",
            "상태": states[0] if i == 0 else random.choice(states),
        })
    return pd.DataFrame(rows)


LOG_DF = make_log_rows()

GUIDE_TEXT = {
    "Deauth Flood": """
**탐지 근거**: 동일 BSSID에서 reason code 7 deauth 프레임이 짧은 시간 내 비정상적으로 다수 발생.

**권장 대응**
- 공격중인 채널 회피 후 재연결 유도
- 클라이언트 단에서 802.11w(PMF) 활성화 확인
- AP 펌웨어 최신 업데이트 여부 점검
""",
    "Evil Twin": """
**탐지 근거**: 동일 SSID, 상이한 BSSID의 AP가 동시에 강한 신호로 존재 + 인증 방식 불일치(OPEN vs WPA2).

**권장 대응**
- 사용자에게 신뢰할 수 없는 AP 접속 경고
- WPA3 전환 및 인증서 기반 검증(802.1X) 고려
- MAC 주소 화이트리스트 관리
""",
    "Beacon Flood": """
**탐지 근거**: 짧은 시간 내 다수의 위조 SSID 비콘 프레임 수신, 동일 OUI 패턴 반복.

**권장 대응**
- 비콘 필터링 활성화
- 채널 점유 모니터링 강화
""",
    "ARP Spoofing": """
**탐지 근거**: 동일 IP에 대해 서로 다른 MAC 주소의 ARP 응답이 반복적으로 수신됨.

**권장 대응**
- 정적 ARP 테이블 적용 검토
- 네트워크 분리(VLAN) 강화
""",
    "KARMA Attack": """
**탐지 근거**: 클라이언트의 PNL(Preferred Network List) probe 요청에 대해 모든 SSID에 응답하는 비정상 AP 탐지.

**권장 대응**
- 클라이언트 자동 접속 기능 비활성화
- MAC 랜더마이징 활성화
""",
}

# ---------------------------------------------------------------------------
# Sidebar - 공격 유형 필터 (신규)
# ---------------------------------------------------------------------------

with st.sidebar:
    st.title("WFSAT")
    st.caption("Wireless Frame Security Analysis Tool")
    st.divider()
    st.subheader("🎯 공격 유형 필터")
    st.selectbox(
        "공격 유형 선택",
        ["전체"] + ATTACK_TYPES,
        index=0,
        key="selected_attack_type",
    )

selected_attack_type = st.session_state.get("selected_attack_type", "전체")

# ---------------------------------------------------------------------------
# 전체 현황 (헤더 - 탭 공통)
# ---------------------------------------------------------------------------

st.title("📡 WFSAT 실시간 모니터링 대시보드")
st.caption(f"현재 필터: **{selected_attack_type}**")

c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("탐지된 AP 수", len(AP_ROWS), "+1")
c2.metric("활성 경고 수", "2", "+1")
c3.metric("초당 패킷 처리량", "1,284 pkt/s", "-3%")
c4.metric("인터페이스 1 (AP 호스팅)", "정상", "wlan0")
c5.metric("인터페이스 2 (캡처)", "정상", "wlan1mon")

st.divider()

# ---------------------------------------------------------------------------
# 탭 구성: 공격 시나리오 / 모니터링·대응 / 대응 이력 / 통계·연구
# ---------------------------------------------------------------------------

tab_scenario, tab_monitor, tab_history, tab_stats = st.tabs(
    ["공격 시나리오", "모니터링·대응", "대응 이력", "통계·연구"]
)

# ---------------------------------------------------------------------------
# 탭 1. 공격 시나리오
# [이전: placeholder 그대로 - 선택된 공격 유형에 반응하도록 분기 추가]
# ---------------------------------------------------------------------------

with tab_scenario:
    if selected_attack_type == "전체":
        st.info("사이드바에서 공격 유형을 선택하세요")
    else:
        st.subheader(selected_attack_type)
        st.info("공격 실행 컨트롤 (구현 예정)")

# ---------------------------------------------------------------------------
# 탭 2. 모니터링·대응
# [이전: ①AP현황 ~ ⑤대응가이드 섹션 전부 이 탭으로 이동]
# ---------------------------------------------------------------------------

with tab_monitor:
    # [이전: ①AP / 네트워크 현황 섹션 - 공격 유형 필터와 무관, 변경 없음]
    st.subheader("📶 AP / 네트워크 현황")

    ap_df = pd.DataFrame(AP_ROWS).rename(columns={
        "ssid": "SSID", "bssid": "BSSID", "channel": "채널",
        "rssi": "RSSI(dBm)", "enc": "암호화", "status": "상태", "pkt_rate": "패킷/s",
    })

    def highlight_status(row):
        color = STATUS_COLOR.get(row["상태"], "")
        return [f"background-color: {color}"] * len(row)

    col_table, col_pie = st.columns([2, 1])

    with col_table:
        st.dataframe(
            ap_df.style.apply(highlight_status, axis=1),
            use_container_width=True,
            hide_index=True,
        )

    with col_pie:
        st.markdown("**AP별 초당 패킷 처리량 비중**")
        pie_df = pd.DataFrame(AP_ROWS)
        pie_df["label"] = pie_df["ssid"] + " (" + pie_df["bssid"].str[-5:] + ")"
        pie_df["share"] = pie_df["pkt_rate"] / pie_df["pkt_rate"].sum()
        pie_df["slice_text"] = pie_df.apply(
            lambda r: r["label"] if r["share"] >= 0.5 else "", axis=1
        )
        fig = px.pie(
            pie_df,
            names="label",
            values="pkt_rate",
            color="status",
            color_discrete_map={"정상": "#5cb85c", "의심": "#f0ad4e", "공격중": "#d9534f"},
            hole=0.35,
        )
        fig.update_traces(
            text=pie_df["slice_text"],
            textinfo="text",
            textposition="inside",
            hovertemplate="<b>%{label}</b><br>패킷/s: %{value}<br>비중: %{percent}<extra></extra>",
        )
        fig.update_layout(showlegend=False, margin=dict(t=10, b=10, l=10, r=10), height=320)
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # [이전: ②실시간 탐지 로그 섹션 - "공격 유형" 컬럼 기준 필터링 추가]
    st.subheader("🪵 실시간 탐지 로그")

    if selected_attack_type == "전체":
        filtered_log_df = LOG_DF
    else:
        filtered_log_df = LOG_DF[LOG_DF["공격 유형"] == selected_attack_type]

    status_badge = {"신규": "🔴", "대응중": "🟡", "종료": "🟢"}
    log_display = filtered_log_df.head(DEFAULT_LOG_LIMIT).copy()
    log_display["상태"] = log_display["상태"].map(lambda s: f"{status_badge.get(s,'')} {s}")
    st.dataframe(log_display, use_container_width=True, hide_index=True)

    st.divider()

    # [이전: ③공격 분석 패널 섹션 - 필터링된 로그 목록에서 선택하도록 변경,
    #  선택 상태(sel_idx)는 session_state["selected_log_idx"]로 유지]
    st.subheader("🔍 공격 분석 패널")

    if filtered_log_df.empty:
        st.warning(f"'{selected_attack_type}' 유형의 로그가 없습니다.")
    else:
        if st.session_state.get("selected_log_idx") not in filtered_log_df.index:
            st.session_state["selected_log_idx"] = filtered_log_df.index[0]

        sel_idx = st.selectbox(
            "분석할 로그 항목 선택",
            options=filtered_log_df.index,
            format_func=lambda i: f"[{LOG_DF.loc[i,'시간']}] {LOG_DF.loc[i,'공격 유형']} ← {LOG_DF.loc[i,'발신지 MAC/BSSID']}",
            key="selected_log_idx",
        )
        sel_row = LOG_DF.loc[sel_idx]
        attack_type = sel_row["공격 유형"]

        col_a, col_b = st.columns([1, 1])

        with col_a:
            st.markdown("**패킷 필드 / 시퀀스 분석**")
            pkt_df = pd.DataFrame([
                {"필드": "Frame Type", "정상값": "Management", "탐지값": "Management", "비정상 여부": ""},
                {"필드": "Subtype", "정상값": "0x0C (Deauth)", "탐지값": "0x0C (Deauth)", "비정상 여부": ""},
                {"필드": "Reason Code", "정상값": "1~3 (정상 해제)", "탐지값": "7 (Class3 from nonassoc)", "비정상 여부": "⚠️"},
                {"필드": "전송 주기", "정상값": "1회성", "탐지값": "120 frames / 2s", "비정상 여부": "⚠️"},
                {"필드": "Source BSSID", "정상값": "등록된 AP", "탐지값": "CC:33:44:55:66:E1 (미등록 OUI)", "비정상 여부": "⚠️"},
            ])
            st.dataframe(pkt_df, use_container_width=True, hide_index=True)

            st.markdown("**탐지 근거**")
            st.info(GUIDE_TEXT.get(attack_type, "").split("**권장 대응**")[0].replace("**탐지 근거**:", "").strip())

        with col_b:
            st.markdown("**패킷 타임라인**")
            timeline_df = pd.DataFrame({
                "t": list(range(20)),
                "deauth_frames": [random.randint(0, 3) for _ in range(10)] + [random.randint(15, 40) for _ in range(10)],
            })
            timeline_chart = (
                alt.Chart(timeline_df)
                .mark_line(point=True)
                .encode(
                    x=alt.X("t:Q", title="t (초)"),
                    y=alt.Y("deauth_frames:Q", title="deauth_frames", scale=alt.Scale(domainMin=0)),
                )
                .properties(height=260)
                .interactive()
            )
            st.altair_chart(timeline_chart, use_container_width=True)
            st.caption("초 단위 deauth 프레임 수 — 10초 시점부터 급증 (공격 시작 추정 구간)")

        st.divider()

        # [이전: ④대처 가이드 문서 섹션 - 변경 없음]
        st.subheader("📘 대처 가이드 문서")
        st.caption(f"현재 선택된 공격 유형: **{attack_type}**")
        st.markdown(GUIDE_TEXT.get(attack_type, "가이드 정보 없음"))

        with st.expander("일반 보안 강화 권장사항"):
            st.markdown("""
- PMF(802.11w / Protected Management Frames) 활성화
- WPA2 → WPA3 전환
- 클라이언트 MAC 주소 랜더마이징 사용
- 정기적인 펌웨어/드라이버 업데이트
""")

# ---------------------------------------------------------------------------
# 탭 3. 대응 이력 (placeholder - 다음 단계에서 구현 예정)
# ---------------------------------------------------------------------------

with tab_history:
    # 다음 단계 예정 로직 (지금은 주석만 남김):
    # if selected_attack_type == "전체":
    #     전체 대응 이력을 시간순으로 표시
    # else:
    #     대응 이력을 "공격 유형" == selected_attack_type 기준으로 필터링해서 표시
    st.info("대응 이력 (구현 예정)")

# ---------------------------------------------------------------------------
# 탭 4. 통계·연구
# [이전: ⑥연구 / 통계 패널 섹션 전부 이 탭으로 이동]
# ---------------------------------------------------------------------------

with tab_stats:
    st.subheader("📊 연구 / 통계 패널")

    t1, t2, t3 = st.tabs(["오탐 검증", "탐지 성공 케이스", "시간대별 공격 빈도"])

    with t1:
        # [이전: 오탐 검증 서브탭 - 변경 없음]
        fp_df = pd.DataFrame([
            {"테스트 시나리오": "공격 패턴 (Deauth Flood)", "샘플 수": 200, "정탐": 196, "오탐": 4, "정확도": "98.0%"},
            {"테스트 시나리오": "정상 멀티 AP 환경 (메시 네트워크)", "샘플 수": 150, "정탐(정상 판정)": 147, "오탐(공격 오판)": 3, "정확도": "98.0%"},
            {"테스트 시나리오": "정상 핸드오버(로밍)", "샘플 수": 120, "정탐(정상 판정)": 118, "오탐(공격 오판)": 2, "정확도": "98.3%"},
        ])
        st.dataframe(fp_df, use_container_width=True, hide_index=True)

    with t2:
        # [이전: 탐지 성공 케이스 서브탭 - st.bar_chart -> Altair로 변경하여
        #  selected_attack_type 막대를 강조 색상으로 표시]
        success_df = pd.DataFrame({
            "공격 유형": ATTACK_TYPES,
            "탐지 성공": [42, 18, 25, 11, 9],
        })
        success_df["강조"] = success_df["공격 유형"].apply(
            lambda a: "선택됨" if selected_attack_type != "전체" and a == selected_attack_type else "일반"
        )
        success_chart = (
            alt.Chart(success_df)
            .mark_bar()
            .encode(
                x=alt.X("공격 유형:N", sort=None, title="공격 유형"),
                y=alt.Y("탐지 성공:Q"),
                color=alt.Color(
                    "강조:N",
                    scale=alt.Scale(domain=["일반", "선택됨"], range=["#4c78a8", "#d62728"]),
                    legend=None,
                ),
            )
            .properties(height=300)
        )
        st.altair_chart(success_chart, use_container_width=True)

    with t3:
        # [이전: 시간대별 공격 빈도 서브탭 - 변경 없음]
        hour_df = pd.DataFrame({
            "시간대": [f"{h:02d}시" for h in range(24)],
            "공격 빈도": [random.randint(0, 5) if h < 7 or h > 22 else random.randint(2, 15) for h in range(24)],
        }).set_index("시간대")
        st.line_chart(hour_df, height=300)

    st.caption("ℹ️ 본 패널의 데이터는 화면 레이아웃 확인용 더미 데이터입니다.")
