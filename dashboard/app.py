"""WFSAT educational dashboard candidate (mock data, no attack execution)."""

from html import escape

import pandas as pd
import plotly.graph_objects as go
import streamlit as st


st.set_page_config(
    page_title="WFSAT Learning Lab",
    page_icon="📡",
    layout="wide",
    initial_sidebar_state="expanded",
)


st.markdown(
    """
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;600;700;800;900&display=swap');

    :root {
        --ink: #17233c;
        --muted: #60708a;
        --line: #dbe4f0;
        --surface: #ffffff;
        --canvas: #f4f7fb;
        --primary: #315efb;
        --primary-soft: #eaf0ff;
        --success: #087f5b;
        --success-soft: #eaf8f2;
        --warning: #a95708;
        --warning-soft: #fff5e8;
        --danger: #c33a4a;
        --danger-soft: #fff0f2;
        --accent: #6f5bd3;
        --accent-strong: #49399d;
        --accent-soft: rgba(239, 236, 255, 0.78);
        --glass-surface: rgba(255, 255, 255, 0.74);
        --glass-line: rgba(174, 190, 214, 0.52);
        --glass-shadow: 0 16px 42px rgba(34, 55, 91, 0.09);
    }

    html {
        font-size: 16px;
        -webkit-text-size-adjust: 100%;
        text-size-adjust: 100%;
    }

    body, .stApp, [data-testid="stAppViewContainer"] {
        color: var(--ink);
        background:
            radial-gradient(circle at 8% 0%, rgba(49, 94, 251, 0.11), transparent 30rem),
            radial-gradient(circle at 92% 8%, rgba(111, 91, 211, 0.12), transparent 27rem),
            var(--canvas);
        font-family: "Noto Sans KR", Arial, sans-serif;
        font-size: 1rem;
        line-height: 1.58;
        font-synthesis: none;
    }

    button, input, textarea, select { font-family: "Noto Sans KR", Arial, sans-serif !important; }

    *, *::before, *::after { box-sizing: border-box; }
    [data-testid="stHeader"] { background: rgba(244, 247, 251, 0.74); backdrop-filter: blur(18px) saturate(135%); -webkit-backdrop-filter: blur(18px) saturate(135%); }
    [data-testid="stMetric"], [data-baseweb="tab-list"], [data-testid="stExpander"],
    .hero, .mode-result, .info-card, .stage-detail, .defense-card, .simulation-card {
        -webkit-backdrop-filter: blur(18px) saturate(130%);
    }

    .stApp p, .stApp li, .stApp h1, .stApp h2, .stApp h3, .stApp label, .stApp button {
        word-break: keep-all;
        line-break: strict;
        text-wrap: pretty;
    }

    .block-container {
        width: min(100%, 1720px);
        max-width: 1720px;
        margin-inline: auto;
        padding: 1.6rem 2rem 4rem;
    }

    section[data-testid="stSidebar"] {
        background: rgba(255, 255, 255, 0.76);
        border-right: 1px solid var(--glass-line);
        backdrop-filter: blur(22px) saturate(135%);
        -webkit-backdrop-filter: blur(22px) saturate(135%);
        resize: none !important;
    }

    section[data-testid="stSidebar"][aria-expanded="true"] {
        width: 20.5rem !important;
        min-width: 20.5rem !important;
        max-width: 20.5rem !important;
    }

    [data-testid="stSidebarContent"] {
        width: 100% !important;
        max-width: 100% !important;
        padding: 1.6rem 1.2rem 2rem;
    }

    section[data-testid="stSidebar"] > div:not([data-testid="stSidebarContent"]),
    section[data-testid="stSidebar"] [style*="col-resize"] {
        display: none !important;
        pointer-events: none !important;
    }

    h1 { font-size: clamp(2rem, 3vw, 3rem) !important; line-height: 1.16 !important; letter-spacing: -0.035em; }
    h2 { font-size: clamp(1.5rem, 2.2vw, 2.05rem) !important; line-height: 1.24 !important; letter-spacing: -0.025em; }
    h3 { font-size: 1.25rem !important; line-height: 1.34 !important; }
    p, li, label, [data-testid="stCaptionContainer"] { font-size: 1rem; line-height: 1.6; }
    [data-testid="stCaptionContainer"] { color: var(--muted); }

    [data-testid="stHorizontalBlock"] { flex-wrap: wrap; gap: 0.9rem; }
    [data-testid="column"] { min-width: min(100%, 12rem); flex: 1 1 12rem !important; }

    [data-testid="stMetric"] {
        min-height: 7.7rem;
        padding: 1rem 1.1rem;
        background: var(--glass-surface);
        border: 1px solid var(--glass-line);
        border-radius: 1rem;
        box-shadow: var(--glass-shadow);
        backdrop-filter: blur(18px) saturate(130%);
    }

    [data-testid="stMetricLabel"] p { color: var(--muted); font-size: 0.92rem !important; font-weight: 750; }
    [data-testid="stMetricValue"] { color: var(--ink); font-size: 1.55rem !important; font-weight: 850; }
    [data-testid="stMetricDelta"] { font-size: 0.82rem; }

    .stButton > button {
        min-height: 3.2rem;
        padding: 0.65rem 1rem;
        border-radius: 0.8rem;
        border-color: #b9c7da;
        font-size: 0.96rem;
        font-weight: 780;
        line-height: 1.35;
        white-space: normal;
        background: rgba(255, 255, 255, 0.58);
        border-color: var(--glass-line);
        box-shadow: 0 8px 22px rgba(34, 55, 91, 0.06);
        backdrop-filter: blur(16px) saturate(135%);
        -webkit-backdrop-filter: blur(16px) saturate(135%);
    }

    [data-testid="stSidebar"] .stButton > button {
        min-height: 4.15rem;
        align-items: flex-start;
        justify-content: flex-start;
        text-align: left;
        gap: 0.65rem;
        padding: 0.62rem 0.78rem;
    }

    [data-testid="stSidebar"] .stButton > button p {
        margin: 0;
        color: var(--muted);
        font-size: 0.78rem !important;
        font-weight: 550;
        line-height: 1.35;
        text-align: left;
        white-space: pre;
        overflow: hidden;
    }

    [data-testid="stSidebar"] .stButton > button p strong {
        color: var(--ink);
        font-size: 1rem;
        font-weight: 900;
        line-height: 1.55;
    }

    [data-testid="stSidebar"] .stButton > button[kind="primary"] p,
    [data-testid="stSidebar"] .stButton > button[kind="primary"] p strong {
        color: #ffffff;
    }

    .stButton > button[kind="primary"] {
        background: linear-gradient(135deg, rgba(49, 94, 251, 0.96), rgba(84, 118, 248, 0.88));
        border-color: var(--primary);
        box-shadow: 0 8px 20px rgba(49, 94, 251, 0.2);
    }

    [data-baseweb="tab-list"] {
        gap: 0.45rem;
        padding: 0.4rem;
        background: rgba(225, 233, 245, 0.72);
        border-radius: 0.9rem;
        border: 1px solid rgba(178, 193, 215, 0.42);
        backdrop-filter: blur(18px) saturate(130%);
    }

    [data-baseweb="tab"] { min-height: 3.2rem; padding: 0.65rem 1rem; border-radius: 0.7rem; }
    [data-baseweb="tab"] p { font-size: 1rem !important; font-weight: 780; }
    [aria-selected="true"][data-baseweb="tab"] { background: rgba(255, 255, 255, 0.82); box-shadow: 0 4px 14px rgba(27, 45, 78, 0.08); }

    [data-testid="stDataFrame"] {
        overflow: hidden;
        border: 1px solid var(--line);
        border-radius: 0.9rem;
        background: var(--glass-surface);
        backdrop-filter: blur(18px) saturate(130%);
        -webkit-backdrop-filter: blur(18px) saturate(130%);
    }

    [data-testid="stAlert"] { border-radius: 0.85rem; padding: 0.95rem 1.1rem; backdrop-filter: blur(16px) saturate(130%); -webkit-backdrop-filter: blur(16px) saturate(130%); }
    [data-testid="stExpander"] { background: var(--glass-surface); border: 1px solid var(--glass-line); border-radius: 0.9rem; backdrop-filter: blur(18px) saturate(130%); }

    .brand-lockup { display: flex; align-items: center; gap: 0.8rem; margin-bottom: 0.45rem; }
    .brand-icon { display: grid; place-items: center; width: 3.2rem; height: 3.2rem; flex: 0 0 3.2rem; border-radius: 0.9rem; background: var(--primary); color: #fff; font-size: 1.65rem; }
    .brand-name { margin: 0; font-size: 1.45rem; line-height: 1.1; font-weight: 900; letter-spacing: -0.02em; }
    .brand-copy { margin: 0.16rem 0 0; color: var(--muted); font-size: 0.68rem; white-space: nowrap; }
    .sidebar-kicker { margin: 1.2rem 0 0.45rem; color: var(--muted); font-size: 0.76rem; font-weight: 850; letter-spacing: 0.08em; }
    .sidebar-note { margin: 0.8rem 0 0; padding: 0.75rem; background: rgba(255, 245, 232, 0.68); border: 1px solid rgba(224, 180, 121, 0.46); border-radius: 0.75rem; color: #74420d; font-size: 0.78rem; line-height: 1.5; backdrop-filter: blur(16px) saturate(130%); -webkit-backdrop-filter: blur(16px) saturate(130%); }

    .st-key-hero_panel { position: relative; }
    .hero {
        display: grid;
        grid-template-columns: minmax(0, 1.25fr) minmax(18rem, 0.75fr);
        align-items: center;
        gap: 1.15rem;
        padding: 1.25rem 1.35rem;
        margin: 0.75rem 0 1rem;
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.86) 0%, rgba(237, 243, 255, 0.78) 100%);
        border: 1px solid rgba(176, 197, 239, 0.62);
        border-radius: 1.15rem;
        box-shadow: var(--glass-shadow);
        backdrop-filter: blur(22px) saturate(135%);
        -webkit-backdrop-filter: blur(22px) saturate(135%);
    }

    .hero-main { display: flex; align-items: center; gap: 1.15rem; min-width: 0; }
    .hero-icon { display: grid; place-items: center; width: 4rem; height: 4rem; flex: 0 0 4rem; border-radius: 1rem; background: var(--primary); font-size: 2rem; box-shadow: 0 10px 24px rgba(49, 94, 251, 0.2); }
    .hero-eyebrow { margin: 0 0 0.15rem; color: var(--primary); font-size: 0.78rem; font-weight: 900; letter-spacing: 0.1em; }
    .hero-title { margin: 0; color: var(--ink); font-size: clamp(1.7rem, 2.8vw, 2.5rem); line-height: 1.16; letter-spacing: -0.035em; font-weight: 900; }
    .hero-meta { margin: 0.28rem 0 0; color: var(--muted); font-size: 0.94rem; }
    .hero-objectives { padding-left: 1.15rem; border-left: 1px solid #cddcff; }
    .hero-objectives__title { min-height: 1.35rem; margin: 0 0 0.42rem; padding-right: 8.8rem; color: var(--primary); font-size: 0.94rem; font-weight: 900; letter-spacing: 0.035em; }
    .hero-objectives__list { margin: 0; padding: 0 2.75rem 0 1.05rem; }
    .hero-objectives__list li { margin: 0.2rem 0; color: #34435c; font-size: 0.9rem; line-height: 1.45; }

    .st-key-advanced_learning_mode { position: absolute; z-index: 8; top: 0.92rem; right: 1.35rem; width: max-content; margin: 0; }
    .st-key-advanced_learning_mode [data-testid="stWidgetLabel"] p { font-size: 0.74rem !important; font-weight: 850; white-space: nowrap; }
    .st-key-theme_toggle { position: absolute; z-index: 9; top: 2.68rem; right: 1.2rem; width: 2.5rem !important; height: 2.5rem !important; min-width: 2.5rem !important; max-width: 2.5rem !important; min-height: 2.5rem !important; max-height: 2.5rem !important; margin: 0 !important; padding: 0 !important; aspect-ratio: 1 / 1 !important; background: transparent !important; }
    .st-key-theme_toggle > div,
    .st-key-theme_toggle [data-testid="stElementContainer"],
    .st-key-theme_toggle .stButton { display: block; width: 2.5rem !important; height: 2.5rem !important; min-width: 2.5rem !important; max-width: 2.5rem !important; min-height: 2.5rem !important; max-height: 2.5rem !important; margin: 0 !important; padding: 0 !important; aspect-ratio: 1 / 1 !important; background: transparent !important; }
    .st-key-theme_toggle .stButton > button { position: relative; width: 2.5rem !important; height: 2.5rem !important; min-width: 2.5rem !important; max-width: 2.5rem !important; min-height: 2.5rem !important; max-height: 2.5rem !important; aspect-ratio: 1 / 1 !important; }
    .st-key-theme_toggle .stButton > button,
    .st-key-theme_toggle .stButton > button:hover,
    .st-key-theme_toggle .stButton > button:focus,
    .st-key-theme_toggle .stButton > button:active {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 2.5rem !important;
        padding: 0 !important;
        background: rgba(255, 255, 255, 0.38) !important;
        border: 1px solid rgba(159, 176, 201, 0.5) !important;
        border-radius: 0.66rem !important;
        color: var(--ink) !important;
        box-shadow: 0 7px 18px rgba(34, 55, 91, 0.08) !important;
        outline: none !important;
        backdrop-filter: blur(18px) saturate(145%);
        -webkit-backdrop-filter: blur(18px) saturate(145%);
    }
    .st-key-theme_toggle .stButton > button p { width: 0 !important; height: 0 !important; margin: 0 !important; overflow: hidden !important; color: transparent !important; -webkit-text-fill-color: transparent !important; font-size: 0 !important; }
    .st-key-theme_toggle .stButton > button::after {
        content: "";
        position: absolute;
        top: 50%;
        left: 50%;
        width: 1.28rem;
        height: 1.28rem;
        transform: translate(-50%, -50%);
        z-index: 2;
        background-color: #17233c;
        -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Ccircle cx='12' cy='12' r='4' fill='black'/%3E%3Cg stroke='black' stroke-width='1.8' stroke-linecap='round'%3E%3Cpath d='M12 1.5v3'/%3E%3Cpath d='M12 19.5v3'/%3E%3Cpath d='M1.5 12h3'/%3E%3Cpath d='M19.5 12h3'/%3E%3Cpath d='m4.58 4.58 2.12 2.12'/%3E%3Cpath d='m17.3 17.3 2.12 2.12'/%3E%3Cpath d='m19.42 4.58-2.12 2.12'/%3E%3Cpath d='m6.7 17.3-2.12 2.12'/%3E%3C/g%3E%3C/svg%3E") center / contain no-repeat;
        mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Ccircle cx='12' cy='12' r='4' fill='black'/%3E%3Cg stroke='black' stroke-width='1.8' stroke-linecap='round'%3E%3Cpath d='M12 1.5v3'/%3E%3Cpath d='M12 19.5v3'/%3E%3Cpath d='M1.5 12h3'/%3E%3Cpath d='M19.5 12h3'/%3E%3Cpath d='m4.58 4.58 2.12 2.12'/%3E%3Cpath d='m17.3 17.3 2.12 2.12'/%3E%3Cpath d='m19.42 4.58-2.12 2.12'/%3E%3Cpath d='m6.7 17.3-2.12 2.12'/%3E%3C/g%3E%3C/svg%3E") center / contain no-repeat;
        pointer-events: none;
    }

    .hero--advanced { background: linear-gradient(135deg, rgba(255, 255, 255, 0.84) 0%, rgba(239, 236, 255, 0.8) 58%, rgba(232, 239, 255, 0.78) 100%); border-color: rgba(111, 91, 211, 0.56); }
    .hero--advanced .hero-objectives { border-color: rgba(111, 91, 211, 0.48); }
    .hero--advanced .hero-objectives__title { color: var(--accent-strong); }

    .section-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin: 1.1rem 0 0.75rem; }
    .section-heading h2 { margin: 0; }
    .section-heading p { margin: 0.25rem 0 0; color: var(--muted); }
    .status-pill { display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.45rem 0.72rem; border-radius: 999px; background: var(--success-soft); color: var(--success); font-size: 0.78rem; font-weight: 850; white-space: nowrap; }

    .mode-result { margin: 0.75rem 0 1rem; padding: 0.85rem 1rem; border-radius: 0.85rem; background: var(--glass-surface); border: 1px solid var(--glass-line); border-left: 4px solid var(--primary); backdrop-filter: blur(18px) saturate(130%); }
    .mode-result strong { color: var(--primary); }
    .mode-result p { margin: 0; font-size: 0.88rem; }
    .mode-result--advanced { background: var(--accent-soft); border-color: rgba(111, 91, 211, 0.48); border-left-color: var(--accent); }
    .mode-result--advanced strong { color: var(--accent-strong); }

    .advanced-panel { margin: 0.9rem 0; padding: 1rem; border: 1px solid rgba(111, 91, 211, 0.48); background: var(--accent-soft); border-radius: 0.95rem; color: #40366f; box-shadow: 0 14px 36px rgba(75, 61, 145, 0.09); backdrop-filter: blur(20px) saturate(135%); -webkit-backdrop-filter: blur(20px) saturate(135%); }
    .advanced-panel h3 { margin: 0 0 0.45rem; color: var(--accent-strong); }
    .advanced-panel p, .advanced-panel li { color: #40366f; font-size: 0.88rem; }
    .advanced-panel ul { margin: 0; padding-left: 1.1rem; }

    .advanced-stage-panel { margin: 0.8rem 0 1rem; padding: 1rem; border: 1px solid rgba(111, 91, 211, 0.48); border-radius: 1rem; background: var(--accent-soft); color: #40366f; box-shadow: 0 14px 36px rgba(75, 61, 145, 0.09); backdrop-filter: blur(20px) saturate(135%); -webkit-backdrop-filter: blur(20px) saturate(135%); }
    .advanced-stage-panel__header { display: flex; align-items: center; justify-content: space-between; gap: 0.8rem; margin-bottom: 0.7rem; }
    .advanced-stage-panel__header h3 { margin: 0; color: var(--accent-strong); font-size: 1.1rem !important; }
    .advanced-stage-panel__badge { padding: 0.28rem 0.5rem; border-radius: 999px; background: linear-gradient(135deg, #5d49bd, #8874df); color: #ffffff; font-size: 0.7rem; font-weight: 850; white-space: nowrap; }
    .advanced-stage-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.65rem; }
    .advanced-stage-cell { padding: 0.75rem; border: 1px solid rgba(111, 91, 211, 0.32); border-radius: 0.75rem; background: rgba(255, 255, 255, 0.5); backdrop-filter: blur(16px) saturate(130%); -webkit-backdrop-filter: blur(16px) saturate(130%); }
    .advanced-stage-cell__label { margin: 0 0 0.25rem; color: var(--accent-strong); font-size: 0.72rem; font-weight: 900; letter-spacing: 0.04em; }
    .advanced-stage-cell__body { margin: 0; color: #40366f; font-size: 0.85rem; line-height: 1.55; }

    .attack-summary-grid { display: grid; grid-template-columns: 1.3fr 1fr 1fr; gap: 0.85rem; margin: 0.8rem 0 1rem; }
    .info-card { min-height: 100%; padding: 1rem 1.05rem; background: var(--glass-surface); border: 1px solid var(--glass-line); border-radius: 0.95rem; box-shadow: 0 12px 32px rgba(34, 55, 91, 0.06); backdrop-filter: blur(18px) saturate(130%); }
    .info-card__label { margin: 0 0 0.38rem; color: var(--muted); font-size: 0.9rem; font-weight: 850; letter-spacing: 0.045em; }
    .info-card__title { margin: 0 0 0.4rem; font-size: 1.18rem; font-weight: 850; }
    .info-card__body { margin: 0; color: var(--muted); font-size: 0.98rem; line-height: 1.55; }
    .attack-summary-grid--advanced .info-card { background: rgba(242, 239, 255, 0.68); border-color: rgba(111, 91, 211, 0.44); }

    .st-key-advanced_pager {
        margin: 0.85rem 0 1.15rem;
        padding: 0.85rem 1rem;
        min-height: 6.75rem;
        border: 1px solid rgba(111, 91, 211, 0.44);
        border-radius: 1rem;
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.68), rgba(239, 236, 255, 0.7));
        box-shadow: var(--glass-shadow);
        backdrop-filter: blur(22px) saturate(140%);
        -webkit-backdrop-filter: blur(22px) saturate(140%);
    }
    .st-key-advanced_pager [data-testid="stHorizontalBlock"] { min-height: 5.05rem; flex-wrap: nowrap; align-items: center; gap: 0.8rem; }
    .st-key-advanced_pager [data-testid="column"] { min-width: 0 !important; }
    .st-key-advanced_pager [data-testid="column"]:nth-child(2) [data-testid="stVerticalBlock"] { gap: 0 !important; }
    .st-key-advanced_pager .stButton > button { min-height: 2.8rem; border-color: rgba(111, 91, 211, 0.42); background: rgba(255, 255, 255, 0.48); color: var(--accent-strong); white-space: nowrap; }
    .st-key-advanced_pager .stButton > button:not(:disabled):hover { border-color: var(--accent); background: rgba(243, 240, 255, 0.86); }
    .st-key-advanced_pager [data-testid="stProgress"] { margin: 0 !important; }
    .advanced-pager__title { margin: 0.42rem 0 0 !important; color: var(--muted); font-size: 0.8rem; line-height: 1.25; text-align: center; }
    .st-key-advanced_pager [data-testid="stProgress"] > div > div { background: linear-gradient(90deg, var(--primary), var(--accent)) !important; }

    .chip-row { display: flex; flex-wrap: wrap; gap: 0.45rem; margin-top: 0.75rem; }
    .chip { padding: 0.4rem 0.64rem; border: 1px solid var(--glass-line); border-radius: 999px; background: rgba(255, 255, 255, 0.46); color: #43526b; font-size: 0.88rem; font-weight: 750; backdrop-filter: blur(14px) saturate(130%); -webkit-backdrop-filter: blur(14px) saturate(130%); }

    .st-key-flow_nav { margin: 0.5rem 0 0.8rem; }
    .st-key-flow_nav [data-testid="stHorizontalBlock"] { flex-wrap: nowrap; gap: 0.55rem; }
    .st-key-flow_nav [data-testid="column"] { min-width: 0 !important; flex: 1 1 0 !important; }
    .st-key-flow_nav .stButton > button { min-height: 3.1rem; padding: 0.5rem 0.35rem; font-size: 0.9rem; white-space: nowrap; }
    .st-key-flow_nav .stButton > button[kind="tertiary"] { background: var(--success-soft); border: 1px solid #8bcbb4; color: var(--success); box-shadow: none; }
    .st-key-flow_nav .stButton > button[kind="primary"] { box-shadow: 0 7px 18px rgba(49, 94, 251, 0.18); }

    .stage-detail { padding: 1.2rem; margin: 0.9rem 0; background: var(--glass-surface); border: 1px solid var(--glass-line); border-radius: 1rem; box-shadow: var(--glass-shadow); backdrop-filter: blur(18px) saturate(130%); -webkit-backdrop-filter: blur(18px) saturate(130%); }
    .stage-detail__head { display: flex; align-items: flex-start; gap: 0.9rem; margin-bottom: 0.9rem; }
    .stage-detail__icon { display: grid; place-items: center; width: 3.35rem; height: 3.35rem; flex: 0 0 3.35rem; border-radius: 0.9rem; background: var(--primary-soft); font-size: 1.55rem; }
    .stage-detail h3 { margin: 0 0 0.2rem; font-size: 1.28rem !important; }
    .stage-detail p { margin: 0; color: var(--muted); }
    .detail-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.75rem; }
    .detail-cell { padding: 0.85rem; border-top: 1px solid var(--line); }
    .detail-cell__label { margin: 0 0 0.22rem; color: var(--muted); font-size: 0.72rem; font-weight: 850; letter-spacing: 0.06em; }
    .detail-cell__body { margin: 0; color: var(--ink); font-size: 0.88rem; line-height: 1.55; }

    .defense-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); gap: 0.8rem; }
    .defense-card { padding: 1rem; background: var(--glass-surface); border: 1px solid var(--glass-line); border-radius: 0.95rem; backdrop-filter: blur(18px) saturate(130%); -webkit-backdrop-filter: blur(18px) saturate(130%); }
    .defense-card__top { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
    .defense-card__priority { padding: 0.25rem 0.5rem; border-radius: 999px; background: var(--primary-soft); color: var(--primary); font-size: 0.7rem; font-weight: 850; }
    .defense-card h3 { margin: 0.55rem 0 0.3rem; font-size: 1.05rem !important; }
    .defense-card p { margin: 0; color: var(--muted); font-size: 0.86rem; }
    .verify { margin-top: 0.7rem !important; padding-top: 0.65rem; border-top: 1px solid #edf1f6; color: #34435c !important; }

    .simulation-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.85rem; margin: 0.8rem 0; }
    .simulation-card { padding: 1.1rem; background: var(--glass-surface); border: 1px solid var(--glass-line); border-radius: 1rem; box-shadow: var(--glass-shadow); backdrop-filter: blur(18px) saturate(130%); -webkit-backdrop-filter: blur(18px) saturate(130%); }
    .simulation-card__top { display: flex; align-items: center; justify-content: space-between; gap: 0.6rem; }
    .simulation-card__icon { font-size: 1.7rem; }
    .simulation-card__status { padding: 0.28rem 0.52rem; border-radius: 999px; background: var(--warning-soft); color: var(--warning); font-size: 0.72rem; font-weight: 850; white-space: nowrap; }
    .simulation-card h3 { margin: 0.55rem 0 0.35rem; font-size: 1.15rem !important; }
    .simulation-card p { margin: 0; color: var(--muted); font-size: 0.9rem; }
    .simulation-card__list { margin: 0.75rem 0 0; padding-left: 1.1rem; }
    .simulation-card__list li { margin: 0.2rem 0; color: #34435c; font-size: 0.86rem; }
    .simulation-card--advanced { border-color: rgba(111, 91, 211, 0.48); box-shadow: inset 0 3px 0 var(--accent), 0 12px 32px rgba(75, 61, 145, 0.09); }
    .simulation-phases { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 0.65rem; margin: 0.8rem 0 1rem; }
    .simulation-phase { padding: 0.8rem; border: 1px solid var(--glass-line); border-radius: 0.85rem; background: rgba(255, 255, 255, 0.5); backdrop-filter: blur(16px) saturate(130%); -webkit-backdrop-filter: blur(16px) saturate(130%); }
    .simulation-phase__number { color: var(--primary); font-size: 0.74rem; font-weight: 900; }
    .simulation-phase strong { display: block; margin-top: 0.2rem; color: var(--ink); font-size: 0.9rem; }
    .simulation-phase p { margin: 0.25rem 0 0; color: var(--muted); font-size: 0.78rem; line-height: 1.45; }

    .source-list { margin: 0; padding-left: 1.15rem; }
    .source-list li { margin-bottom: 0.35rem; font-size: 0.88rem; }

    @media (max-width: 1250px) {
        .simulation-phases { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }

    @media (max-width: 900px) {
        .block-container { padding: 1.2rem 1rem 3rem; }
        .attack-summary-grid, .detail-grid, .simulation-grid, .advanced-stage-grid { grid-template-columns: 1fr; }
        .hero { align-items: flex-start; }
    }

    @media (max-width: 680px) {
        html { font-size: 15px; }
        [data-testid="column"] { min-width: 100%; }
        .hero { grid-template-columns: 1fr; }
        .hero-icon { width: 3.4rem; height: 3.4rem; flex-basis: 3.4rem; }
        .hero-objectives { padding: 0.8rem 0 0; border-top: 1px solid #cddcff; border-left: 0; }
        .hero-objectives__title { padding-right: 0; }
        .st-key-advanced_learning_mode { position: static; margin: -0.25rem 0 0.75rem; }
        .st-key-theme_toggle { position: static; margin: -0.55rem 0 0.75rem auto; }
        .st-key-advanced_pager { padding: 0.75rem; }
        .st-key-advanced_pager [data-testid="stHorizontalBlock"] { gap: 0.45rem; }
        .st-key-advanced_pager [data-testid="column"]:first-child,
        .st-key-advanced_pager [data-testid="column"]:last-child { flex: 0 0 2.8rem !important; }
        .st-key-advanced_pager [data-testid="column"]:first-child .stButton > button p,
        .st-key-advanced_pager [data-testid="column"]:last-child .stButton > button p { font-size: 0 !important; }
        .st-key-advanced_pager [data-testid="column"]:first-child .stButton > button p::after { content: "←"; font-size: 1.15rem; }
        .st-key-advanced_pager [data-testid="column"]:last-child .stButton > button p::after { content: "→"; font-size: 1.15rem; }
        .simulation-phases { grid-template-columns: 1fr; }
        .status-pill { display: none; }
    }
    </style>
    """,
    unsafe_allow_html=True,
)


ATTACK_LIBRARY = {
    "evil_twin": {
        "label": "Evil Twin",
        "icon": "👥",
        "subtitle": "신뢰 AP를 닮은 위조 AP",
        "category": "AP 위장 · 자격 증명 위험",
        "difficulty": "중급 → 심화",
        "summary": "신뢰 AP와 동일하거나 유사한 SSID를 내세운 위조 AP가 사용자의 수동 선택이나 자동 연결을 유도하는 무선 위장 시나리오입니다.",
        "overview": "SSID는 사람이 읽는 네트워크 이름일 뿐 신뢰의 증거가 아닙니다. 승인된 BSSID와 OUI, 보안 모드, 802.1X 서버 인증서, 채널과 신호 변화까지 기준선과 비교해야 하며, 정상적인 다중 AP 구성과 위조 AP도 구분해야 합니다.",
        "impact": "잘못 연결되면 비인가 네트워크를 통한 트래픽 관찰, 피싱형 captive portal 노출, 인증서 경고 무시와 자격 증명 입력 위험이 커집니다. 연결만으로 자격 증명이 자동 탈취되는 것은 아니지만 사용자 판단과 인증 설정이 약하면 기밀성·무결성·가용성에 연쇄적인 영향을 줄 수 있습니다.",
        "prerequisites": ["802.11 AP·STA 관계", "SSID와 BSSID 차이", "WPA2/WPA3 인증 개요"],
        "objectives": ["정상 AP 기준선 만들기", "위조 AP의 불일치 식별", "사용자·네트워크 방어를 연결해 설명"],
        "steps": [
            {"title": "정상 기준선 수집", "icon": "📋", "summary": "승인된 AP의 식별 정보를 먼저 고정합니다.", "detail": "SSID뿐 아니라 BSSID, 보안 모드, 채널, 인증서 지문과 신호 변화를 기준선으로 기록합니다.", "evidence": "승인 AP 목록 · BSSID/OUI · RSN 정보 요소", "defense": "자산 목록과 인증서 신뢰 기준을 사전에 배포합니다."},
            {"title": "위조 AP 출현", "icon": "📡", "summary": "동일 SSID를 가진 다른 송신원이 관찰됩니다.", "detail": "같은 이름이라도 BSSID, 암호화 방식, 채널, vendor OUI가 기준선과 다르면 위장 가능성을 검토합니다.", "evidence": "동일 SSID + 상이 BSSID/보안 설정", "defense": "WIDS/WIPS에서 rogue·evil twin 상관분석을 활성화합니다."},
            {"title": "클라이언트 선택 유도", "icon": "🧲", "summary": "강한 신호나 연결 단절이 잘못된 AP 선택을 유도할 수 있습니다.", "detail": "자동 연결 정책과 과거 저장 네트워크가 선택에 영향을 줍니다. Deauth는 결합될 수 있지만 Evil Twin의 필수 조건은 아닙니다.", "evidence": "로밍 이벤트 · 재연결 급증 · 신호 급변", "defense": "자동 연결을 제한하고 PMF로 위조 연결 해제의 영향을 줄입니다."},
            {"title": "인증·포털 노출", "icon": "🪪", "summary": "사용자가 위조 인증서나 captive portal을 마주할 수 있습니다.", "detail": "HTTPS 인증서 경고와 802.1X 서버 인증서 검증 실패는 중요한 학습 신호입니다. 자격 증명을 입력하지 않아야 합니다.", "evidence": "인증서 불일치 · 예상 밖 portal · DNS 변화", "defense": "EAP-TLS 또는 서버 인증서 검증을 강제하고 사용자 경고 교육을 병행합니다."},
            {"title": "탐지·격리·검증", "icon": "🛡️", "summary": "위조 AP를 분류하고 영향 범위를 확인합니다.", "detail": "관측 장비에서 위치·채널·연결 클라이언트를 확인하고 승인 절차에 따라 격리한 뒤 재연결 여부를 검증합니다.", "evidence": "rogue AP 경보 · 연관 클라이언트 · 사후 로그", "defense": "무선 침입 대응 절차와 사용자 신고 경로를 정기적으로 훈련합니다."},
        ],
        "signals": [
            {"관측 신호": "동일 SSID, 다른 BSSID", "해석": "위조 가능성. 다중 AP 구성인지 자산 목록과 대조", "신뢰도": "중간"},
            {"관측 신호": "OPEN ↔ WPA2/WPA3 불일치", "해석": "보안 설정 복제 실패 또는 의도적 유인", "신뢰도": "높음"},
            {"관측 신호": "인증서 발급자·SAN 불일치", "해석": "Enterprise 인증 위장 가능성", "신뢰도": "높음"},
            {"관측 신호": "비정상적으로 강한 RSSI", "해석": "근거리 위조 AP 가능성이나 단독 증거는 아님", "신뢰도": "낮음"},
        ],
        "defenses": [
            {"priority": "핵심", "title": "802.1X 서버 인증 검증", "description": "클라이언트가 신뢰 CA와 서버 이름을 검증하도록 강제합니다.", "verification": "임의 인증서 AP 연결이 차단되는지 확인"},
            {"priority": "핵심", "title": "EAP-TLS 우선", "description": "가능하면 비밀번호 입력형보다 상호 인증 기반 EAP-TLS를 사용합니다.", "verification": "관리 단말에 인증서 기반 프로필만 배포됐는지 점검"},
            {"priority": "탐지", "title": "Rogue AP 상관분석", "description": "SSID·BSSID·OUI·보안 모드·유선망 연결 정보를 함께 분석합니다.", "verification": "테스트 위조 AP에 경보가 발생하는지 검증"},
            {"priority": "사용자", "title": "자동 연결·경고 정책", "description": "공용망 자동 연결을 끄고 인증서·portal 경고 무시를 금지합니다.", "verification": "교육 시나리오에서 올바른 사용자 판단 측정"},
        ],
        "advanced": [
            "Rogue AP는 비인가 AP 전체를 뜻하고, Evil Twin은 신뢰 네트워크를 모방한다는 공격 의도가 포함됩니다.",
            "PMF는 위조 Deauth/Disassociation의 영향을 줄이지만 동일 SSID 위조 AP의 존재 자체를 제거하지는 않습니다.",
            "Airgeddon의 단일 어댑터 Evil Twin 흐름은 VIF 지원 여부와 드라이버·커널 동작에 영향을 받을 수 있습니다.",
        ],
        "sources": [
            ("Airgeddon FAQ · Evil Twin/VIF/MFP", "https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/FAQ%20%26%20Troubleshooting"),
            ("Cisco Adaptive Wireless IPS", "https://www.cisco.com/c/en/us/products/collateral/wireless/adaptive-wireless-ips-software/data_sheet_c78-501388.pdf"),
        ],
    },
    "deauth": {
        "label": "Deauthentication",
        "icon": "📴",
        "subtitle": "관리 프레임 위조 기반 연결 단절",
        "category": "802.11 관리 프레임 · DoS",
        "difficulty": "초중급 → 심화",
        "summary": "보호되지 않은 Deauthentication·Disassociation 관리 프레임을 위조하거나 반복 전송해 AP와 클라이언트의 연결 상태를 강제로 바꾸는 가용성 공격 시나리오입니다.",
        "overview": "관리 프레임의 개수만 세어서는 정상 로밍, AP 재부팅과 공격을 구분하기 어렵습니다. 송신 주소와 reason code, sequence 변화, 시간당 밀도, RF 관측 위치, 실제 association 상태와 사용자 서비스 영향을 같은 시간축에서 확인해야 합니다.",
        "impact": "단말의 재인증과 DHCP 재시도가 반복되면서 처리량 저하, 지연 증가, 음성·영상 세션 중단과 로밍 실패가 발생할 수 있습니다. 단독 DoS로 끝날 수도 있지만 Evil Twin 연결 유도처럼 다른 공격의 보조 단계로 결합될 가능성도 함께 평가해야 합니다.",
        "prerequisites": ["관리 프레임 종류", "AP Association 상태", "PMF/MFP 기본 개념"],
        "objectives": ["정상 연결 해제와 flood 구분", "reason code의 한계 이해", "PMF 검증 절차 설계"],
        "steps": [
            {"title": "연결 상태 기준선", "icon": "🔗", "summary": "정상 association과 연결 해제 빈도를 확인합니다.", "detail": "AP·클라이언트 쌍, 채널, 정상 로밍 시 발생하는 관리 프레임 빈도를 먼저 기록합니다.", "evidence": "association 상태 · 평시 deauth 빈도", "defense": "정상 변화량을 알아야 탐지 임계치를 조정할 수 있습니다."},
            {"title": "비정상 프레임 유입", "icon": "⚡", "summary": "짧은 구간에 연결 해제 프레임이 집중됩니다.", "detail": "송신 주소가 실제 AP처럼 보이더라도 위조 가능성이 있으므로 sequence와 RF 관측 위치를 함께 비교합니다.", "evidence": "초당 deauth 수 · 송신 MAC · reason code", "defense": "WIDS/WIPS에 시간창 기반 flood 탐지를 적용합니다."},
            {"title": "클라이언트 상태 전이", "icon": "🔄", "summary": "보호되지 않은 클라이언트가 프레임을 수용하고 재연결합니다.", "detail": "단절·재인증·재연결이 반복되며 처리량과 지연이 악화됩니다. 단일 reason code만으로 공격을 확정하지 않습니다.", "evidence": "재인증 반복 · 처리량 저하 · 연결 시간 감소", "defense": "클라이언트와 AP 모두 PMF 협상 상태를 확인합니다."},
            {"title": "서비스 영향 분석", "icon": "📉", "summary": "단절 빈도와 사용자 영향을 상관분석합니다.", "detail": "관리 프레임 급증 시점과 세션 끊김, DHCP 재시도, 애플리케이션 오류를 시간축으로 겹쳐 봅니다.", "evidence": "프레임·세션·애플리케이션 타임라인", "defense": "무선·인증·애플리케이션 로그의 시간 동기화를 유지합니다."},
            {"title": "PMF 적용 검증", "icon": "🛡️", "summary": "보호 모드에서 위조 프레임 수용 여부를 확인합니다.", "detail": "격리된 시험망에서 PMF Required와 Capable의 차이를 비교하고 레거시 단말 호환성까지 기록합니다.", "evidence": "RSN capabilities · PMF 협상 · 연결 유지", "defense": "가능하면 WPA3 또는 PMF Required 정책으로 전환합니다."},
        ],
        "signals": [
            {"관측 신호": "짧은 시간의 deauth 급증", "해석": "flood 가능성. 유지보수·AP 재부팅 여부 확인", "신뢰도": "높음"},
            {"관측 신호": "reason code 7 반복", "해석": "비연결 STA 관련 신호지만 단독 확정 근거는 아님", "신뢰도": "중간"},
            {"관측 신호": "AP와 다른 RF 위치의 동일 MAC", "해석": "송신 주소 위조 가능성", "신뢰도": "높음"},
            {"관측 신호": "재인증·DHCP 요청 동시 증가", "해석": "실제 서비스 영향과 연결된 정황", "신뢰도": "높음"},
        ],
        "defenses": [
            {"priority": "핵심", "title": "PMF Required", "description": "Deauth, Disassociation, Robust Action 프레임 위조 방어를 강화합니다.", "verification": "보호 협상된 단말이 위조 프레임에도 연결을 유지하는지 확인"},
            {"priority": "전환", "title": "WPA3 우선", "description": "순수 WPA3 환경은 PMF를 기본 요구합니다. 혼합 모드는 단말별 보호 상태를 확인합니다.", "verification": "레거시·혼합 모드 단말의 PMF 협상률 측정"},
            {"priority": "탐지", "title": "상태 기반 WIPS", "description": "프레임 수뿐 아니라 인증·연결 상태와 송신 위치를 결합합니다.", "verification": "정상 로밍과 flood의 오탐률 비교"},
            {"priority": "운영", "title": "무선 로그 시간 동기화", "description": "AP, WLC, 인증 서버, 클라이언트 이벤트를 같은 시간축으로 분석합니다.", "verification": "사건 타임라인의 시각 오차 점검"},
        ],
        "advanced": [
            "IEEE 802.11w 계열의 PMF/MFP는 특정 robust management frame의 위조·변조 방지를 목표로 합니다.",
            "PMF Capable은 선택적이므로 레거시 클라이언트가 보호 없이 연결될 수 있습니다. Required와 동일하지 않습니다.",
            "WPA2/WPA3 transition 환경에서는 클라이언트별 협상 결과가 달라 동일 AP에서도 영향이 다를 수 있습니다.",
        ],
        "sources": [
            ("Cisco 802.11w Management Frame Protection", "https://www.cisco.com/c/en/us/td/docs/wireless/controller/9800/17-16/config-guide/b_wl_17_16_cg/m_vewlc_802_11w.pdf"),
            ("Airgeddon FAQ · DoS/MFP", "https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/FAQ%20%26%20Troubleshooting"),
        ],
    },
    "beacon_flood": {
        "label": "Beacon Flood",
        "icon": "📣",
        "subtitle": "대량 위조 Beacon으로 무선 환경 교란",
        "category": "관리 프레임 · 스캔/가용성",
        "difficulty": "초중급 → 심화",
        "summary": "짧은 시간에 다수의 위조 Beacon과 가상 SSID를 만들어 주변 단말의 스캔 결과와 무선 관측 체계를 혼란시키는 관리 프레임 기반 공격 시나리오입니다.",
        "overview": "SSID의 절대 개수만으로는 행사장이나 고밀도 환경을 공격으로 오인할 수 있습니다. 신규 SSID 생성 속도, BSSID와 OUI의 생성 규칙, beacon interval, 채널 분포, capability·RSN·vendor 정보 요소의 반복성과 센서별 RF 위치를 함께 분석해야 합니다.",
        "impact": "클라이언트의 스캔 목록과 관리 화면이 불필요한 항목으로 채워지고 WIDS 경보 처리량이 증가해 운영자의 판단이 늦어질 수 있습니다. 프레임 밀도가 충분히 높으면 management airtime과 스캔 지연에도 영향을 주지만, 실제 서비스 저하 여부는 채널 점유와 사용자 품질 지표로 별도 검증해야 합니다.",
        "prerequisites": ["Beacon 역할", "SSID/BSSID/OUI", "채널과 airtime"],
        "objectives": ["정상 Beacon 기준선 구성", "생성 패턴·시간 밀도 분석", "WIPS 임계치와 오탐 관리"],
        "steps": [
            {"title": "Beacon 기준선", "icon": "📏", "summary": "정상 AP의 주기와 정보 요소를 기록합니다.", "detail": "승인 BSSID별 채널, beacon interval, capability, RSN 정보 요소와 평시 SSID 수를 기준선으로 만듭니다.", "evidence": "승인 BSSID · interval · RSN IE", "defense": "무선 자산 목록과 RF 기준선을 최신 상태로 유지합니다."},
            {"title": "가상 SSID 급증", "icon": "🫧", "summary": "짧은 시간에 새로운 SSID·BSSID가 대량 출현합니다.", "detail": "이름이 무작위이거나 BSSID가 순차 생성되는지, 동일 OUI·정보 요소가 반복되는지 확인합니다.", "evidence": "신규 SSID 속도 · BSSID 패턴 · OUI 반복", "defense": "신규 BSSID 생성률과 비정상 패턴에 임계치를 둡니다."},
            {"title": "스캔·airtime 영향", "icon": "📶", "summary": "클라이언트와 분석 화면의 스캔 비용이 증가합니다.", "detail": "채널별 management frame 비중과 scan latency를 함께 관찰합니다. SSID가 많다는 사실만으로 공격을 확정하지 않습니다.", "evidence": "management airtime · 스캔 지연 · 채널 점유", "defense": "채널별 영향과 실제 사용자 품질을 상관분석합니다."},
            {"title": "패턴 기반 분류", "icon": "🧩", "summary": "반복되는 프레임 특성으로 flood 군집을 분류합니다.", "detail": "sequence 증가, interval, vendor IE, 송신 위치를 묶어 하나의 발생원인지 여러 정상 AP인지 구분합니다.", "evidence": "프레임 지문 · sequence · 센서 위치", "defense": "단일 카운트보다 다중 특성 규칙으로 오탐을 줄입니다."},
            {"title": "격리 후 회복 검증", "icon": "✅", "summary": "비정상 Beacon 감소와 스캔 회복을 확인합니다.", "detail": "승인된 대응 절차 뒤 신규 SSID 속도, 채널 점유, 단말 스캔 시간을 다시 측정해 기준선 복귀를 판단합니다.", "evidence": "사후 SSID rate · airtime · scan latency", "defense": "사건 전후 지표를 동일 뷰에서 비교합니다."},
        ],
        "signals": [
            {"관측 신호": "신규 SSID 생성률 급증", "해석": "Beacon flood 가능성. 행사장·테스트랩 여부 확인", "신뢰도": "중간"},
            {"관측 신호": "순차·반복 BSSID 패턴", "해석": "자동 생성 도구의 공통 특성 가능성", "신뢰도": "높음"},
            {"관측 신호": "동일 vendor IE 반복", "해석": "하나의 송신원이 다수 AP를 모사할 가능성", "신뢰도": "높음"},
            {"관측 신호": "management airtime 증가", "해석": "실제 RF 자원 영향 정황", "신뢰도": "높음"},
        ],
        "defenses": [
            {"priority": "기준선", "title": "승인 BSSID 인벤토리", "description": "장소·채널·OUI를 포함한 정상 자산 목록을 유지합니다.", "verification": "승인 AP 변경이 탐지 정책에 즉시 반영되는지 점검"},
            {"priority": "탐지", "title": "생성률·지문 기반 WIPS", "description": "SSID 개수, BSSID 패턴, 정보 요소 반복을 결합합니다.", "verification": "고밀도 정상 환경과 flood 데이터의 오탐률 비교"},
            {"priority": "운영", "title": "채널별 RF 분석", "description": "관리 프레임 비중과 실제 airtime 영향을 측정합니다.", "verification": "사건 전후 scan latency와 채널 점유 비교"},
            {"priority": "대응", "title": "발생원 위치 추정", "description": "여러 센서의 RSSI·도착 시간을 활용해 물리적 대응 범위를 좁힙니다.", "verification": "센서 간 관측 일관성과 현장 조사 결과 대조"},
        ],
        "advanced": [
            "Beacon은 AP 존재와 capability를 알리는 broadcast management frame이며 SSID 외에도 다양한 information element를 포함합니다.",
            "정상 고밀도 환경에서도 SSID가 많을 수 있으므로 절대 개수보다 생성 속도와 프레임 지문이 중요합니다.",
            "Beacon Protection 지원 여부와 일반적인 PMF 보호 범위를 혼동하지 않도록 프레임 종류별 보호 조건을 따로 학습해야 합니다.",
        ],
        "sources": [
            ("Cisco Wireless IPS · Beacon flood detection", "https://www.cisco.com/c/en/us/td/docs/wireless/mse/3350/7-5/wIPS_Configuration/Guide/MSE_wIPS_7_5.pdf"),
            ("Airgeddon source · DoS menu", "https://github.com/v1s1t0r1sh3r3/airgeddon"),
        ],
    },
    "handshake": {
        "label": "Handshake / PMKID",
        "icon": "🔑",
        "subtitle": "Airgeddon 기반 인증 흔적 보안 감사",
        "category": "WPA 인증 · 오프라인 감사",
        "difficulty": "중급 → 고급",
        "summary": "승인된 격리 실습망에서 WPA 4-way Handshake 또는 구현별 PMKID 인증 흔적의 의미를 검증하고 공유 비밀 정책의 위험을 평가하는 보안 감사 시나리오입니다.",
        "overview": "4-way Handshake는 PSK 평문을 전송하지 않고 양측이 PMK를 보유했음을 확인하면서 세션 키를 파생합니다. 캡처 자체와 침해 성공을 구분해야 하며, AP·STA 식별자와 필요한 메시지, nonce와 MIC 메타데이터가 일관된지 먼저 확인한 뒤 비밀값 강도와 인증 방식을 평가해야 합니다.",
        "impact": "검증 가능한 인증 흔적과 약한 PSK가 함께 존재하면 공격자가 네트워크와 추가로 통신하지 않고 후보 비밀값을 비교할 수 있어 탐지가 늦어질 수 있습니다. 위험은 캡처 여부만이 아니라 비밀번호 엔트로피, 재사용, WPA2 혼합 모드와 레거시 단말 비율에 따라 달라집니다.",
        "prerequisites": ["WPA2-PSK/PMK 개요", "EAPOL 4-way Handshake", "salt·KDF·오프라인 검증"],
        "objectives": ["캡처와 침해를 구분", "완전성 검증 이해", "강한 인증 정책 설계"],
        "steps": [
            {"title": "승인 범위·환경 확인", "icon": "⚖️", "summary": "실습 대상과 권한을 먼저 고정합니다.", "detail": "격리된 소유 네트워크, 허가된 장비, 저장·폐기 규칙을 확인하고 실습 식별자를 기록합니다.", "evidence": "승인서 · 대상 BSSID · 실습 세션 ID", "defense": "권한 없는 캡처와 실제 자격 증명 사용을 금지합니다."},
            {"title": "인증 교환 관찰", "icon": "🤝", "summary": "EAPOL 교환 또는 구현별 PMKID 노출을 관찰합니다.", "detail": "Airgeddon은 관련 도구 흐름을 묶는 오케스트레이터입니다. 공격명이 아니라 실습 도구라는 점을 구분합니다.", "evidence": "EAPOL 메시지 · PMKID 포함 여부 · BSSID", "defense": "WPA3-SAE와 강한 인증 정책의 차이를 비교합니다."},
            {"title": "캡처 완전성 검증", "icon": "🧪", "summary": "분석 가능한 인증 흔적인지 먼저 확인합니다.", "detail": "AP·STA 식별자와 필요한 교환이 일치하는지 확인합니다. 불완전 캡처를 성공으로 오판하지 않습니다.", "evidence": "메시지 쌍 · nonce/MIC 메타데이터 · 일관된 AP/STA", "defense": "감사 기록에는 성공 여부보다 검증 근거를 남깁니다."},
            {"title": "오프라인 위험 모델", "icon": "🧠", "summary": "약한 PSK가 왜 위험한지 계산 구조를 이해합니다.", "detail": "평문이 노출되는 것이 아니라 후보 비밀값으로 계산한 결과를 캡처와 비교할 수 있다는 점을 개념적으로 학습합니다.", "evidence": "KDF 입력 · MIC/PMKID 비교 구조 · 정책 강도", "defense": "충분히 길고 무작위인 PSK 또는 802.1X/WPA3-SAE를 사용합니다."},
            {"title": "정책 개선·재검증", "icon": "🛡️", "summary": "인증 방식을 개선하고 같은 기준으로 재평가합니다.", "detail": "PSK 교체, WPA3-SAE 또는 802.1X 전환, 혼합 모드 축소 뒤 캡처 가능성과 오프라인 위험을 다시 평가합니다.", "evidence": "보안 모드 · PSK 정책 · 사후 감사 결과", "defense": "비밀값 순환과 레거시 호환성 종료 계획을 함께 관리합니다."},
        ],
        "signals": [
            {"관측 신호": "EAPOL 4-way 교환", "해석": "정상 연결에서도 발생. 캡처 자체는 공격 확정 증거가 아님", "신뢰도": "낮음"},
            {"관측 신호": "비정상 재연결과 EAPOL 반복", "해석": "강제 재연결 또는 품질 문제 가능성", "신뢰도": "중간"},
            {"관측 신호": "PMKID가 포함된 인증 흔적", "해석": "구현·구성에 따른 오프라인 감사 표면", "신뢰도": "중간"},
            {"관측 신호": "약한 PSK 정책", "해석": "오프라인 추측 성공 가능성을 키우는 핵심 위험", "신뢰도": "높음"},
        ],
        "defenses": [
            {"priority": "핵심", "title": "길고 무작위인 PSK", "description": "사전·조직명·전화번호 패턴을 피하고 충분한 엔트로피를 확보합니다.", "verification": "정책 검사와 승인된 오프라인 강도 감사 수행"},
            {"priority": "전환", "title": "WPA3-SAE", "description": "가능한 환경에서 WPA2-PSK 의존과 오프라인 추측 위험을 줄입니다.", "verification": "순수 WPA3와 transition 단말 비율 측정"},
            {"priority": "기업", "title": "802.1X/EAP-TLS", "description": "공유 비밀 대신 단말별 인증서와 수명주기 관리를 사용합니다.", "verification": "폐기된 인증서의 접속 차단과 발급 이력 점검"},
            {"priority": "운영", "title": "혼합 모드 축소", "description": "레거시 호환 때문에 남은 WPA2 경로를 계획적으로 제거합니다.", "verification": "WPA2 연결 단말과 예외 목록을 정기 검토"},
        ],
        "advanced": [
            "4-way Handshake의 목적은 양측이 PMK를 보유함을 확인하고 세션 키를 파생하는 것이며 PSK 평문을 전송하지 않습니다.",
            "PMKID 노출 조건은 AP·구현·구성에 따라 다르므로 802.11r 하나만으로 단정하지 않습니다.",
            "Airgeddon은 airmon-ng, airodump-ng, aircrack-ng 등 여러 도구를 점검·연결하는 감사 오케스트레이터입니다.",
        ],
        "sources": [
            ("Airgeddon · Installation and workflow", "https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Installation%20%26%20Usage"),
            ("Airgeddon · Essential tools", "https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Essential-Tools"),
            ("Hashcat official repository", "https://github.com/hashcat/hashcat"),
        ],
    },
}


ADVANCED_LEARNING = {
    "evil_twin": {
        "summary": "식별자 복제와 인증 신뢰 실패를 분리해 Evil Twin의 성립 조건을 분석합니다.",
        "overview": "심화 과정에서는 SSID 중복만으로 공격을 판정하지 않습니다. 802.11 정보 요소와 BSSID 군집, 802.1X 서버 인증서 체인, 유선망 연결 정보와 RF 위치를 결합해 정상적인 ESS 확장 구성과 의도적인 위장을 구분합니다. 각 증거가 독립적인지, 공격자가 복제할 수 있는 값인지도 함께 평가합니다.",
        "impact": "위험도는 위조 AP의 존재보다 클라이언트가 어떤 인증 절차로 연결됐고 어떤 신뢰 검증을 생략했는지에 따라 달라집니다. EAP 서버 인증서 검증 실패, captive portal을 통한 자격 증명 수집, DNS·게이트웨이 변경과 트래픽 중간 경로 형성을 별개의 침해 가설로 나누어 확인합니다.",
        "prerequisites": ["RSN·802.11 정보 요소", "802.1X/EAP 인증서 검증", "로밍 선택과 802.11k/v/r", "WIDS 증거 상관분석"],
        "objectives": ["복제 가능한 식별자와 신뢰 근거 구분", "정상 다중 AP와 위조 AP의 대안 가설 비교", "인증·RF·유선 증거를 결합한 검증 설계"],
        "stage_focus": [
            {"protocol": "SSID, BSSID, RSN IE와 vendor IE가 각각 무엇을 표현하는지 구분하고, OUI나 BSSID도 단독 신뢰 근거가 될 수 없음을 확인합니다.", "analysis": "동일 SSID를 제공하는 정상 AP 군집의 채널·보안 모드·인증서 공통성과 예외를 먼저 기록해 기준선 자체의 불확실성을 계산합니다.", "design": "자산 목록에 BSSID만 저장하지 않고 ESS, 위치, 인증서 지문, 유선 스위치 포트와 변경 이력을 함께 연결합니다."},
            {"protocol": "Probe·Beacon·Association 과정에서 노출되는 capability와 RSN 정보를 비교하되, 공격자가 복제 가능한 필드는 낮은 신뢰도로 취급합니다.", "analysis": "상이한 보안 모드, 로컬 관리 MAC, 비정상 OUI를 조합하고 합법적인 AP 교체나 임시 장비라는 반례를 검토합니다.", "design": "RF 센서와 유선 인프라의 관측을 상관분석해 단일 경보가 아니라 다중 증거 기반 신뢰도 점수를 만듭니다."},
            {"protocol": "클라이언트 선택은 RSSI뿐 아니라 저장 프로필, 로밍 정책과 802.11k/v/r 지원 상태의 영향을 받습니다.", "analysis": "재연결 증가가 위조 Deauth 때문인지 음영 지역, AP 장애나 정상 로밍 때문인지 시간축과 클라이언트별 상태로 구분합니다.", "design": "자동 연결 제한, PMF와 관리형 무선 프로필을 함께 배포하고 단말별 예외와 로밍 품질을 회귀 검증합니다."},
            {"protocol": "802.1X에서는 서버 인증서 체인과 서버 이름 검증이 핵심이며, captive portal과 EAP 인증을 같은 절차로 해석하지 않습니다.", "analysis": "인증서 경고, 예상 밖 DNS·게이트웨이, portal 전환을 각각 수집하고 자격 증명 입력이 실제로 발생했는지 분리해 판단합니다.", "design": "EAP-TLS 또는 엄격한 서버 인증서 검증을 강제하고 실패 시 사용자가 우회할 수 없는 관리형 프로필을 설계합니다."},
            {"protocol": "공격 AP의 무선 존재, 클라이언트 연결과 자격 증명 노출은 서로 다른 사건 단계이므로 각각의 완료 조건을 정의합니다.", "analysis": "위치·채널·연결 클라이언트·인증 로그를 결합하고 증거가 부족하면 공격 확정 대신 관찰 상태를 유지합니다.", "design": "격리 권한, 사용자 통지, 증거 보존, 재연결 확인과 사후 기준선 갱신을 포함한 대응 플레이북을 검증합니다."},
        ],
    },
    "deauth": {
        "summary": "802.11 상태 전이와 PMF 협상 결과를 기준으로 연결 해제 프레임의 진위와 영향을 분석합니다.",
        "overview": "심화 과정에서는 Deauthentication과 Disassociation이 상태 머신에서 어떤 전이를 유발하는지 확인하고, 송신 MAC과 reason code처럼 위조 가능한 값과 RF 위치·시퀀스·클라이언트 상태처럼 상관분석이 필요한 값을 구분합니다. PMF Capable과 Required의 차이, 혼합 모드에서 단말별 보호 상태도 함께 다룹니다.",
        "impact": "프레임 급증이 실제 서비스 중단으로 이어졌는지 association, 재인증, DHCP와 애플리케이션 지표를 연결해 검증합니다. 공격 탐지율만 높이면 정상 로밍과 유지보수를 오탐할 수 있으므로 사용자 영향, 보호 협상과 대안 가설을 포함한 임계치 설계가 필요합니다.",
        "prerequisites": ["802.11 인증·연결 상태 머신", "Robust Management Frame", "RSN MFPC·MFPR 비트", "시간창·상태 기반 탐지"],
        "objectives": ["관리 프레임과 상태 전이의 인과관계 설명", "PMF 협상 결과별 보호 범위 비교", "정상 로밍을 보존하는 탐지·검증 기준 설계"],
        "stage_focus": [
            {"protocol": "Authentication, Association과 데이터 전송 상태를 구분하고 정상 로밍·절전·AP 재시작에서 발생하는 해제 프레임을 기준선에 포함합니다.", "analysis": "평균 빈도만 보지 않고 클라이언트 유형, 채널, 시간대와 로밍 이벤트별 분포를 비교해 정상 범위를 설정합니다.", "design": "AP·WLC·인증 서버·클라이언트의 시각을 동기화하고 동일 세션을 추적할 수 있는 식별자를 로그에 유지합니다."},
            {"protocol": "주소와 reason code는 관측 힌트일 뿐 진위 보장이 아니며, 보호 비트와 PMF 협상 상태를 함께 확인해야 합니다.", "analysis": "sequence 불연속, 동일 MAC의 상이한 RF 위치와 짧은 시간창의 밀도를 결합해 단순 AP 장애라는 반례와 비교합니다.", "design": "절대 프레임 수보다 AP·STA 상태에 맞지 않는 프레임 비율과 사용자 영향에 가중치를 둔 탐지 규칙을 설계합니다."},
            {"protocol": "MFPC는 보호 기능 지원, MFPR은 보호 사용 요구를 의미하며 혼합 환경에서는 같은 SSID에서도 단말별 결과가 다를 수 있습니다.", "analysis": "연결이 끊긴 단말과 유지된 단말의 RSN capability, 보안 모드와 드라이버 버전을 비교해 보호 실패 원인을 좁힙니다.", "design": "PMF Required 전환 전 레거시 호환성 목록과 예외 종료 일정을 만들고 다운그레이드 경로를 지속적으로 측정합니다."},
            {"protocol": "관리 프레임 사건과 DHCP·TCP·애플리케이션 오류는 계층이 다르므로 공통 시간축에서 인과 순서를 확인합니다.", "analysis": "프레임 증가가 선행했는지, 이미 발생한 RF 품질 저하의 결과인지 구분하고 지연·손실·세션 복구 시간을 계산합니다.", "design": "서비스 수준 지표와 보안 경보를 연결해 탐지 민감도를 높이면서도 사용자 영향이 없는 이벤트는 우선순위를 낮춥니다."},
            {"protocol": "WPA3와 PMF Required, transition mode의 협상 차이를 패킷과 AP 설정 양쪽에서 확인합니다.", "analysis": "보호된 단말의 연결 유지뿐 아니라 비보호 단말 차단, 로밍 성공률과 운영 영향까지 회귀 시험합니다.", "design": "격리 시험 결과를 정책 변경 승인 기준으로 사용하고 펌웨어·드라이버 업데이트 뒤 동일 시나리오를 반복 검증합니다."},
        ],
    },
    "beacon_flood": {
        "summary": "Beacon 정보 요소의 지문과 생성률을 사용해 고밀도 정상 환경과 자동 생성형 Flood를 구분합니다.",
        "overview": "심화 과정에서는 Beacon의 TSF, interval, capability, RSN과 vendor IE를 구조적으로 비교합니다. SSID 수가 아닌 시간당 신규 BSSID 생성률, 주소 엔트로피, IE 해시의 반복성과 다중 센서의 RF 관측을 특징으로 만들어 동일 발생원 군집과 정상 AP 집합을 구분합니다.",
        "impact": "논리적인 스캔 목록 혼잡과 실제 RF 자원 고갈을 분리해 평가합니다. management airtime, 채널 점유와 scan latency가 사용자 연결·로밍 품질에 미친 영향을 측정하고, 경보 폭증으로 분석 인력이 지연되는 운영 영향도 별도의 위험으로 포함합니다.",
        "prerequisites": ["Beacon frame과 TSF·interval", "Information Element 파싱", "BSSID 엔트로피·프레임 지문", "RF airtime과 다중 센서 분석"],
        "objectives": ["Beacon 구조에서 안정·변동 특성 분리", "생성률·지문 기반 군집과 오탐 분석", "RF 영향과 운영 영향을 함께 검증"],
        "stage_focus": [
            {"protocol": "Beacon의 timestamp, interval, capability와 RSN·vendor IE를 구분하고 정상 AP별로 변동 가능한 필드를 정의합니다.", "analysis": "장비 교체, 임시 SSID와 고밀도 행사를 기준선 예외로 기록해 단순 개수 임계치가 만드는 오탐을 측정합니다.", "design": "승인 BSSID 인벤토리에 위치·채널·IE 지문과 유효 기간을 포함하고 변경 승인 이벤트와 자동 동기화합니다."},
            {"protocol": "자동 생성형 Beacon은 BSSID·SSID와 일부 IE를 반복 또는 순차 변경할 수 있으므로 필드별 엔트로피를 비교합니다.", "analysis": "신규 생성률, 주소 간 거리와 IE 해시 중복률을 결합하고 테스트랩이나 이동형 AP라는 대안 가설을 확인합니다.", "design": "짧은·긴 시간창을 함께 사용해 순간 급증과 지속 공격을 분리하고 장소별 동적 임계치를 적용합니다."},
            {"protocol": "Beacon은 주기적으로 airtime을 사용하지만 논리적 SSID 증가가 곧바로 서비스 중단을 뜻하지는 않습니다.", "analysis": "채널별 management airtime, 스캔 지연과 연결 성공률을 비교해 실제 RF 영향의 크기와 범위를 계산합니다.", "design": "보안 경보와 무선 품질 지표를 같은 대시보드에 배치하고 영향이 확인된 채널부터 대응 우선순위를 높입니다."},
            {"protocol": "Sequence, interval, IE 조합과 센서별 RSSI는 송신원 군집을 추정하는 특징이며 각각 측정 오차를 가집니다.", "analysis": "단일 특징이 아닌 다중 특성으로 군집을 만들고 정상 AP가 같은 칩셋 지문을 공유할 가능성을 반례로 검토합니다.", "design": "규칙의 근거와 신뢰도를 기록하고 검증 데이터셋에서 정밀도·재현율과 장소별 오탐률을 함께 평가합니다."},
            {"protocol": "대응 뒤 Beacon 생성률과 airtime이 기준선으로 돌아오는지 동일한 수집 조건에서 비교해야 합니다.", "analysis": "센서 위치나 채널 변경으로 보이지 않게 된 것을 제거 성공으로 오판하지 않도록 다중 센서의 사후 증거를 확인합니다.", "design": "격리·현장 조사·복구 측정과 탐지 임계치 갱신을 하나의 사건 기록으로 남겨 다음 평가에 재사용합니다."},
        ],
    },
    "handshake": {
        "summary": "WPA 키 파생과 인증 교환의 완전성을 검증해 캡처 가능성과 실제 비밀값 위험을 분리합니다.",
        "overview": "심화 과정에서는 4-way Handshake의 ANonce·SNonce, replay counter와 MIC가 AP·STA 식별자와 일관되는지 확인합니다. WPA2-PSK의 PMK 파생 구조, PMKID가 관찰되는 구현 조건과 WPA3-SAE의 오프라인 추측 저항성을 비교하되 캡처 자체를 침해 성공으로 해석하지 않습니다.",
        "impact": "오프라인 검증 위험은 완전한 인증 흔적, 후보 비밀값의 품질과 재사용, 연산 비용이 함께 결정합니다. WPA2/WPA3 transition과 약한 PSK가 남은 예외 단말은 전체 정책의 우회 경로가 될 수 있으므로 인증 방식별 자산 비율과 전환 계획까지 위험 모델에 포함합니다.",
        "prerequisites": ["PMK·PTK와 키 파생 입력", "EAPOL-Key M1~M4", "Nonce·MIC·replay counter", "WPA3-SAE·802.1X 비교"],
        "objectives": ["인증 흔적의 완전성과 침해 성공 구분", "키 파생 구조와 오프라인 위험 조건 설명", "인증 전환과 레거시 제거 검증 설계"],
        "stage_focus": [
            {"protocol": "감사 범위에는 대상 BSSID·STA, 채널, 시간, 증거 보존과 폐기 조건이 포함되어야 재현 가능한 실험이 됩니다.", "analysis": "실제 사용자 비밀값이나 비인가 트래픽이 섞이지 않았는지 확인하고 데이터 최소화 원칙을 적용합니다.", "design": "승인 정보와 실습 세션 ID를 모든 관측 이벤트에 연결하고 만료 시 캡처와 파생 데이터를 자동 폐기합니다."},
            {"protocol": "4-way Handshake는 nonce와 주소 정보를 이용해 PTK를 파생하고 MIC로 키 보유를 확인하며 PSK 평문을 전송하지 않습니다.", "analysis": "M1~M4의 역할과 replay counter를 구분하고 재전송이나 로밍에서 발생한 정상 EAPOL 반복을 공격과 혼동하지 않습니다.", "design": "관측기는 메시지 존재 여부뿐 아니라 AP·STA 쌍, 순서와 재전송 상태를 구조화된 이벤트로 저장합니다."},
            {"protocol": "분석 가능한 흔적은 주소, nonce, MIC와 메시지 관계가 일관되어야 하며 일부 프레임 존재만으로 완전성을 보장하지 않습니다.", "analysis": "서로 다른 세션의 메시지가 섞이거나 replay counter가 맞지 않는 경우를 실패로 분류하고 판정 근거를 남깁니다.", "design": "완전성 검사 규칙을 자동화하되 원본 프레임 참조와 실패 사유를 보존해 도구별 판정 차이를 검증합니다."},
            {"protocol": "WPA2-PSK에서는 SSID와 후보 비밀값으로 파생한 결과를 관측된 인증 값과 비교할 수 있어 비밀값 품질이 핵심이 됩니다.", "analysis": "비밀번호 길이만이 아니라 예측 가능성, 조직 내 재사용과 사전 기반 패턴을 평가하고 성공 시간 단정에는 하드웨어·후보 집합 가정을 명시합니다.", "design": "실제 비밀번호를 노출하지 않는 정책 검사와 승인된 강도 평가를 사용하고 결과를 위험 등급으로만 보존합니다."},
            {"protocol": "WPA3-SAE는 수동 캡처 기반 오프라인 추측에 대한 성질이 WPA2-PSK와 다르며 802.1X/EAP-TLS는 공유 비밀 의존을 줄입니다.", "analysis": "transition mode와 레거시 SSID가 남긴 WPA2 연결 경로를 찾아 전환 완료율과 예외 단말의 위험을 측정합니다.", "design": "PSK 교체만으로 끝내지 않고 WPA3-SAE 또는 EAP-TLS 전환, 예외 만료와 사후 인증 흔적 재평가를 계획합니다."},
        ],
    },
}


def choose_attack(attack_key: str) -> None:
    if st.session_state.get("selected_attack") != attack_key:
        st.session_state[f"step_{attack_key}"] = 0
    st.session_state["selected_attack"] = attack_key


def toggle_theme() -> None:
    st.session_state["dark_mode"] = not st.session_state.get("dark_mode", False)


def move_learning_step(attack_key: str, direction: int) -> None:
    last_step = len(ATTACK_LIBRARY[attack_key]["steps"]) - 1
    current = st.session_state.get(f"step_{attack_key}", 0)
    st.session_state[f"step_{attack_key}"] = max(0, min(current + direction, last_step))


def render_flow(attack_key: str, attack: dict, current_step: int) -> None:
    with st.container(key="flow_nav"):
        jump_columns = st.columns(len(attack["steps"]))
        for index, column in enumerate(jump_columns):
            if index < current_step:
                button_type = "tertiary"
                label = f"✓ {index + 1}단계"
            elif index == current_step:
                button_type = "primary"
                label = f"● {index + 1}단계"
            else:
                button_type = "secondary"
                label = f"{index + 1}단계"
            with column:
                if st.button(
                    label,
                    key=f"jump_{attack_key}_{index}",
                    type=button_type,
                    width="stretch",
                ):
                    st.session_state[f"step_{attack_key}"] = index
                    st.rerun()


def render_advanced_pager(attack_key: str, attack: dict, current_step: int) -> None:
    step_count = len(attack["steps"])
    with st.container(key="advanced_pager"):
        previous_column, progress_column, next_column = st.columns([1, 3.2, 1])
        with previous_column:
            st.button(
                "← 이전 단계",
                key=f"advanced_previous_{attack_key}",
                help="바로 이전 심화 학습 단계로 이동합니다.",
                disabled=current_step == 0,
                width="stretch",
                on_click=move_learning_step,
                args=(attack_key, -1),
            )
        with progress_column:
            st.progress((current_step + 1) / step_count)
            st.markdown(
                f'<p class="advanced-pager__title">현재 · {current_step + 1}단계 {escape(attack["steps"][current_step]["title"])}</p>',
                unsafe_allow_html=True,
            )
        with next_column:
            st.button(
                "다음 단계 →",
                key=f"advanced_next_{attack_key}",
                help="바로 다음 심화 학습 단계로 이동합니다.",
                disabled=current_step == step_count - 1,
                width="stretch",
                on_click=move_learning_step,
                args=(attack_key, 1),
            )


def render_stage_detail(step: dict, current_step: int, advanced_focus=None) -> None:
    st.markdown(
        f"""
        <section class="stage-detail">
          <div class="stage-detail__head">
            <div class="stage-detail__icon">{step['icon']}</div>
            <div>
              <h3>{current_step + 1}단계 · {escape(step['title'])}</h3>
              <p>{escape(step['summary'])}</p>
            </div>
          </div>
          <div class="detail-grid">
            <div class="detail-cell"><p class="detail-cell__label">진행 설명</p><p class="detail-cell__body">{escape(step['detail'])}</p></div>
            <div class="detail-cell"><p class="detail-cell__label">관찰할 증거</p><p class="detail-cell__body">{escape(step['evidence'])}</p></div>
            <div class="detail-cell"><p class="detail-cell__label">방어 연결</p><p class="detail-cell__body">{escape(step['defense'])}</p></div>
          </div>
        </section>
        """,
        unsafe_allow_html=True,
    )

    if advanced_focus:
        st.markdown(
            f"""
            <section class="advanced-stage-panel">
              <div class="advanced-stage-panel__header"><h3>🧠 {current_step + 1}단계 심화 분석</h3><span class="advanced-stage-panel__badge">ADVANCED MODE</span></div>
              <div class="advanced-stage-grid">
                <article class="advanced-stage-cell"><p class="advanced-stage-cell__label">프로토콜·성립 조건</p><p class="advanced-stage-cell__body">{escape(advanced_focus['protocol'])}</p></article>
                <article class="advanced-stage-cell"><p class="advanced-stage-cell__label">판단·대안 가설</p><p class="advanced-stage-cell__body">{escape(advanced_focus['analysis'])}</p></article>
                <article class="advanced-stage-cell"><p class="advanced-stage-cell__label">방어 설계·검증</p><p class="advanced-stage-cell__body">{escape(advanced_focus['design'])}</p></article>
              </div>
            </section>
            """,
            unsafe_allow_html=True,
        )


st.session_state.setdefault("selected_attack", "evil_twin")
st.session_state.setdefault("advanced_learning_mode", False)
st.session_state.setdefault("learning_level", "일반 학습")
st.session_state.setdefault("dark_mode", False)
for attack_key in ATTACK_LIBRARY:
    st.session_state.setdefault(f"step_{attack_key}", 0)


if st.session_state["dark_mode"]:
    st.markdown(
        """
        <style id="wfsat-dark-theme">
        :root {
            --ink: #edf3ff;
            --muted: #aab8cf;
            --line: #334155;
            --surface: #111827;
            --canvas: #0b1220;
            --primary: #6d8dff;
            --primary-soft: #1e2e55;
            --success: #5dd6a7;
            --success-soft: #123c33;
            --warning: #f1b46a;
            --warning-soft: #3b2a18;
            --accent: #a996ff;
            --accent-strong: #d1c8ff;
            --accent-soft: rgba(61, 48, 108, 0.56);
            --glass-surface: rgba(17, 24, 39, 0.72);
            --glass-line: rgba(91, 109, 140, 0.5);
            --glass-shadow: 0 18px 48px rgba(0, 0, 0, 0.24);
            color-scheme: dark;
        }
        body, .stApp, [data-testid="stAppViewContainer"] {
            background:
                radial-gradient(circle at 8% 0%, rgba(77, 111, 226, 0.18), transparent 30rem),
                radial-gradient(circle at 92% 8%, rgba(135, 111, 230, 0.16), transparent 27rem),
                var(--canvas);
        }
        [data-testid="stHeader"] { background: rgba(11, 18, 32, 0.7); }
        section[data-testid="stSidebar"], [data-testid="stSidebarContent"] { background: rgba(17, 24, 39, 0.78); }
        .stButton > button[kind="secondary"] { background: rgba(24, 35, 56, 0.66); border-color: rgba(91, 109, 140, 0.62); color: var(--ink); }
        .stButton > button[kind="secondary"] p, .stButton > button[kind="secondary"] p strong { color: var(--ink); }
        [data-testid="stSidebar"] .stButton > button[kind="secondary"] p { color: var(--muted); }
        [data-testid="stSidebar"] .stButton > button[kind="secondary"] p strong { color: var(--ink); }
        [data-baseweb="tab-list"] { background: rgba(23, 34, 56, 0.68); border-color: rgba(91, 109, 140, 0.44); }
        [data-baseweb="tab"] p { color: #cbd7eb; }
        [aria-selected="true"][data-baseweb="tab"] { background: rgba(48, 65, 96, 0.72); }
        [aria-selected="true"][data-baseweb="tab"] p { color: #ffffff; }
        [data-testid="stDataFrame"], [data-testid="stExpander"] { background: var(--glass-surface); border-color: var(--glass-line); }
        .hero { background: linear-gradient(135deg, rgba(17, 24, 39, 0.76) 0%, rgba(24, 41, 74, 0.7) 100%); border-color: #385486; }
        .hero-objectives { border-color: #385486; }
        .hero-objectives__list li { color: #d6e1f2; }
        .st-key-advanced_learning_mode [data-testid="stWidgetLabel"] p { color: #edf3ff !important; }
        .st-key-advanced_learning_mode [data-baseweb="checkbox"] > div:first-child,
        .st-key-advanced_learning_mode input[role="switch"] + div,
        .st-key-advanced_learning_mode input[type="checkbox"] + div {
            background: #273650 !important;
            background-color: #273650 !important;
            border: 2px solid #8c9bb3 !important;
            border-radius: 999px !important;
            box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.08), 0 3px 10px rgba(0, 0, 0, 0.24) !important;
        }
        .st-key-advanced_learning_mode [data-baseweb="checkbox"] > div:first-child:has(input:checked),
        .st-key-advanced_learning_mode input[role="switch"]:checked + div,
        .st-key-advanced_learning_mode input[type="checkbox"]:checked + div {
            background: linear-gradient(135deg, #7564db, #927ff0) !important;
            background-color: #7564db !important;
            border-color: #c3b8ff !important;
        }
        .st-key-advanced_learning_mode input[role="switch"] + div::before,
        .st-key-advanced_learning_mode input[role="switch"] + div::after,
        .st-key-advanced_learning_mode input[type="checkbox"] + div::before,
        .st-key-advanced_learning_mode input[type="checkbox"] + div::after {
            background-color: #f8fafc !important;
            border-color: #f8fafc !important;
            box-shadow: 0 2px 7px rgba(0, 0, 0, 0.3) !important;
        }
        .st-key-advanced_learning_mode [data-testid="stWidgetLabel"] {
            background: transparent !important;
            border: 0 !important;
            box-shadow: none !important;
        }
        .st-key-advanced_learning_mode [data-testid="stWidgetLabel"] p {
            color: #f4f7ff !important;
            -webkit-text-fill-color: #f4f7ff !important;
            text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
        }
        .st-key-advanced_learning_mode [data-testid="stTooltipIcon"] {
            display: inline-flex !important;
            align-items: center !important;
            justify-content: center !important;
            color: #dbe5f5 !important;
            background: rgba(39, 54, 80, 0.82) !important;
            border: 1px solid #8292ac !important;
            border-radius: 50% !important;
        }
        .st-key-advanced_learning_mode [data-testid="stTooltipIcon"] *,
        .st-key-advanced_learning_mode [data-testid="stTooltipIcon"] svg {
            color: #dbe5f5 !important;
            fill: #dbe5f5 !important;
        }
        .st-key-theme_toggle .stButton > button,
        .st-key-theme_toggle .stButton > button:hover,
        .st-key-theme_toggle .stButton > button:focus,
        .st-key-theme_toggle .stButton > button:active { overflow: hidden !important; isolation: isolate; background: #263653 !important; background-color: #263653 !important; background-image: none !important; border: 1px solid #405273 !important; color: #ffffff !important; box-shadow: inset 0 0 0 999px #263653, 0 8px 22px rgba(0, 0, 0, 0.3) !important; }
        .st-key-theme_toggle .stButton > button::before {
            content: "";
            position: absolute;
            inset: 0;
            z-index: 1;
            border-radius: 0.6rem;
            background: linear-gradient(145deg, #263653 0%, #111a2c 100%);
            pointer-events: none;
        }
        .st-key-theme_toggle .stButton > button p { color: #ffffff !important; -webkit-text-fill-color: #ffffff !important; }
        .st-key-theme_toggle .stButton > button::after { background-color: #ffffff !important; }
        .hero-title, .info-card__title, .stage-detail h3, .defense-card h3, .simulation-card h3 { color: var(--ink); }
        .status-pill { background: var(--success-soft); color: var(--success); }
        .mode-result, .info-card, .stage-detail, .defense-card, .simulation-card { background: var(--glass-surface); border-color: var(--glass-line); }
        .chip, .simulation-phase { background: rgba(24, 35, 56, 0.62); border-color: rgba(91, 109, 140, 0.58); color: #d6e1f2; }
        .detail-cell { border-color: var(--line); }
        .detail-cell__body, .simulation-phase strong, .simulation-card__list li { color: var(--ink); }
        .verify { color: #d6e1f2 !important; border-color: var(--line); }
        .st-key-flow_nav .stButton > button[kind="tertiary"] { background: var(--success-soft); border-color: #27795e; color: var(--success); }
        .sidebar-note { background: rgba(59, 42, 24, 0.64); border-color: rgba(110, 74, 37, 0.72); color: #f5c78f; }
        .source-list a { color: #9ab4ff; }
        .hero.hero--advanced { background: linear-gradient(135deg, rgba(17, 24, 39, 0.78) 0%, rgba(48, 39, 88, 0.68) 58%, rgba(24, 41, 74, 0.74) 100%); border-color: rgba(169, 150, 255, 0.58); }
        .hero--advanced .hero-objectives { border-color: rgba(169, 150, 255, 0.5); }
        .hero--advanced .hero-objectives__title { color: var(--accent-strong); }
        .mode-result--advanced { background: var(--accent-soft); border-color: rgba(169, 150, 255, 0.46); border-left-color: var(--accent); }
        .mode-result--advanced strong { color: var(--accent-strong); }
        .advanced-panel, .advanced-stage-panel { background: var(--accent-soft); border-color: rgba(169, 150, 255, 0.46); color: #e9e4ff; }
        .advanced-panel h3, .advanced-stage-panel__header h3 { color: var(--accent-strong); }
        .advanced-panel p, .advanced-panel li, .advanced-stage-cell__body { color: #e9e4ff; }
        .advanced-stage-cell { background: rgba(16, 22, 34, 0.48); border-color: rgba(169, 150, 255, 0.34); }
        .advanced-stage-cell__label { color: var(--accent-strong); }
        .attack-summary-grid--advanced .info-card { background: rgba(48, 39, 88, 0.58); border-color: rgba(169, 150, 255, 0.46); }
        .simulation-card--advanced { border-color: rgba(169, 150, 255, 0.5); box-shadow: inset 0 3px 0 var(--accent), var(--glass-shadow); }
        .st-key-advanced_pager { background: linear-gradient(135deg, rgba(17, 24, 39, 0.68), rgba(48, 39, 88, 0.58)); border-color: rgba(169, 150, 255, 0.48); }
        .st-key-advanced_pager .stButton > button { background: rgba(17, 24, 39, 0.48); border-color: rgba(169, 150, 255, 0.44); color: var(--accent-strong); }
        .st-key-advanced_pager .stButton > button:not(:disabled):hover { background: rgba(62, 49, 108, 0.7); border-color: var(--accent); }
        [data-testid="stWidgetLabel"] p { color: var(--ink) !important; }
        </style>
        """,
        unsafe_allow_html=True,
    )


with st.sidebar:
    st.markdown(
        """
        <div class="brand-lockup">
          <div class="brand-icon">📡</div>
          <div><p class="brand-name">WFSAT</p><p class="brand-copy">Wireless Security Learning Lab</p></div>
        </div>
        """,
        unsafe_allow_html=True,
    )
    st.markdown('<p class="sidebar-kicker">ATTACK LIBRARY · 4 TRACKS</p>', unsafe_allow_html=True)
    for key, item in ATTACK_LIBRARY.items():
        st.button(
            f"**{item['label']}**\n{item['subtitle']}",
            key=f"sidebar_{key}",
            type="primary" if st.session_state["selected_attack"] == key else "secondary",
            icon=item["icon"],
            width="stretch",
            on_click=choose_attack,
            args=(key,),
        )

    st.markdown(
        """
        <div class="sidebar-note">
          <strong>교육·방어 목적 전용</strong><br>
          현재 후보에는 실제 공격 실행 기능이 없습니다. 향후에도 소유하거나 명시적으로 허가받은 격리 실습망에서만 연결하도록 설계합니다.
        </div>
        """,
        unsafe_allow_html=True,
    )


selected_key = st.session_state["selected_attack"]
selected = ATTACK_LIBRARY[selected_key]
selected_advanced = ADVANCED_LEARNING[selected_key]
current_step = st.session_state[f"step_{selected_key}"]
current_step = max(0, min(current_step, len(selected["steps"]) - 1))
st.session_state[f"step_{selected_key}"] = current_step


with st.container(key="hero_panel"):
    advanced_learning_mode = st.toggle(
        "심화 학습 모드",
        key="advanced_learning_mode",
        help="학습 내용의 깊이를 전환하는 설정입니다. 끄면 처음 접하는 학생을 위한 일반 학습, 켜면 프로토콜 조건·대안 가설·방어 검증 설계까지 다루는 심화 학습이 표시됩니다.",
    )
    st.button(
        "☀",
        key="theme_toggle",
        help="라이트 모드와 다크 모드를 전환합니다.",
        on_click=toggle_theme,
    )
    learning_level = "심화 학습" if advanced_learning_mode else "일반 학습"
    st.session_state["learning_level"] = learning_level
    hero_objectives = selected_advanced["objectives"] if advanced_learning_mode else selected["objectives"]
    objective_title = "심화 학습 목표" if advanced_learning_mode else "핵심 학습 목표"
    st.markdown(
        f"""
        <section class="hero {'hero--advanced' if advanced_learning_mode else ''}">
          <div class="hero-main">
            <div class="hero-icon">{selected['icon']}</div>
            <div>
              <p class="hero-eyebrow">WFSAT · INTERACTIVE ATTACK LEARNING</p>
              <h1 class="hero-title">{escape(selected['label'])}</h1>
              <p class="hero-meta">{escape(selected['subtitle'])} · {escape(selected['category'])}</p>
            </div>
          </div>
          <aside class="hero-objectives">
            <p class="hero-objectives__title">🎯 {objective_title}</p>
            <ul class="hero-objectives__list">{''.join(f'<li>{escape(objective)}</li>' for objective in hero_objectives)}</ul>
          </aside>
        </section>
        """,
        unsafe_allow_html=True,
    )


quick_columns = st.columns(4)
for column, (key, item) in zip(quick_columns, ATTACK_LIBRARY.items()):
    with column:
        st.button(
            f"{item['icon']}  {item['label']}",
            key=f"quick_{key}",
            type="primary" if selected_key == key else "secondary",
            width="stretch",
            on_click=choose_attack,
            args=(key,),
        )


tab_learn, tab_detect, tab_defense, tab_simulation = st.tabs(
    ["🧭 공격 학습", "🔎 탐지 분석", "🛡️ 방어 설계", "🧪 실제 시뮬레이션"]
)


with tab_learn:
    st.markdown(
        f'<div class="section-heading"><div><h2>공격 흐름을 따라가며 학습하세요</h2><p>원하는 단계를 직접 선택하면 진행 설명·관측 증거·방어 연결이 함께 바뀝니다.</p></div><span class="status-pill">{escape(learning_level)} · 5단계</span></div>',
        unsafe_allow_html=True,
    )
    render_flow(selected_key, selected, current_step)
    render_stage_detail(
        selected["steps"][current_step],
        current_step,
        selected_advanced["stage_focus"][current_step] if advanced_learning_mode else None,
    )

    if not advanced_learning_mode:
        st.markdown(
            '<div class="mode-result"><p><strong>일반 학습 결과</strong> · 공격의 전체 흐름을 설명하고, 대표 증거와 필수 방어를 연결할 수 있게 됩니다.</p></div>',
            unsafe_allow_html=True,
        )
        st.markdown(
            f"""
            <div class="attack-summary-grid">
              <article class="info-card"><p class="info-card__label">전체 설명</p><p class="info-card__title">{escape(selected['summary'])}</p><p class="info-card__body">{escape(selected['overview'])}</p></article>
              <article class="info-card"><p class="info-card__label">예상 영향</p><p class="info-card__title">무엇이 위험한가</p><p class="info-card__body">{escape(selected['impact'])}</p></article>
              <article class="info-card"><p class="info-card__label">선행 지식</p><p class="info-card__title">시작 전 확인</p><div class="chip-row">{''.join(f'<span class="chip">{escape(x)}</span>' for x in selected['prerequisites'])}</div></article>
            </div>
            """,
            unsafe_allow_html=True,
        )
    else:
        advanced_items = "".join(f"<li>{escape(note)}</li>" for note in selected["advanced"])
        st.markdown(
            f"""
            <div class="mode-result mode-result--advanced"><p><strong>심화 학습 결과</strong> · 탐지 근거의 전제와 반례를 설명하고, 구현 제약을 고려한 방어 검증 절차를 설계할 수 있게 됩니다.</p></div>
            <section class="advanced-panel">
              <h3>🧠 {escape(selected['label'])} 심화 분석</h3>
              <p>현재 단계의 현상만 보는 대신 프로토콜 조건, 오탐 가능성, 구현 환경의 한계를 함께 검토합니다.</p>
              <ul>{advanced_items}</ul>
            </section>
            <div class="attack-summary-grid attack-summary-grid--advanced">
              <article class="info-card"><p class="info-card__label">심화 전체 설명</p><p class="info-card__title">{escape(selected_advanced['summary'])}</p><p class="info-card__body">{escape(selected_advanced['overview'])}</p></article>
              <article class="info-card"><p class="info-card__label">심화 위험 모델</p><p class="info-card__title">조건별 영향을 비교</p><p class="info-card__body">{escape(selected_advanced['impact'])}</p></article>
              <article class="info-card"><p class="info-card__label">심화 선행 지식</p><p class="info-card__title">분석 전에 알아야 할 개념</p><div class="chip-row">{''.join(f'<span class="chip">{escape(x)}</span>' for x in selected_advanced['prerequisites'])}</div></article>
            </div>
            """,
            unsafe_allow_html=True,
        )
        render_advanced_pager(selected_key, selected, current_step)


with tab_detect:
    st.markdown('<div class="section-heading"><div><h2>탐지 신호를 단독으로 믿지 마세요</h2><p>패킷, RF, 연결 상태와 사용자 영향을 함께 해석합니다.</p></div><span class="status-pill">교육용 관측 데이터</span></div>', unsafe_allow_html=True)
    signal_df = pd.DataFrame(selected["signals"])
    st.dataframe(signal_df, width="stretch", hide_index=True)

    chart_col, explanation_col = st.columns([1.4, 1])
    with chart_col:
        x_values = list(range(20))
        baseline = [2, 3, 2, 4, 3, 2, 4, 3, 2, 3]
        event_values = {
            "evil_twin": [5, 7, 10, 14, 18, 22, 25, 27, 28, 30],
            "deauth": [8, 14, 21, 34, 38, 42, 37, 44, 40, 46],
            "beacon_flood": [12, 20, 33, 48, 66, 81, 93, 106, 118, 126],
            "handshake": [5, 9, 15, 12, 19, 16, 22, 18, 14, 10],
        }[selected_key]
        chart_paper = "rgba(0,0,0,0)"
        chart_plot = "rgba(24,35,56,0.34)" if st.session_state["dark_mode"] else "rgba(255,255,255,0.38)"
        chart_text = "#edf3ff" if st.session_state["dark_mode"] else "#17233c"
        chart_grid = "#334155" if st.session_state["dark_mode"] else "#dbe4f0"
        figure = go.Figure()
        figure.add_trace(go.Scatter(x=x_values, y=baseline + event_values, mode="lines+markers", line=dict(color="#315efb", width=4), marker=dict(size=8), name="관측 지표"))
        figure.add_vrect(x0=9.5, x1=19, fillcolor="#fff0f2", opacity=0.7, line_width=0, annotation_text="이상 구간", annotation_position="top left")
        figure.update_layout(
            title=f"{selected['label']} · 교육용 시간축",
            xaxis_title="관측 시간",
            yaxis_title="정규화된 이상 신호",
            height=390,
            margin=dict(l=20, r=20, t=65, b=30),
            paper_bgcolor=chart_paper,
            plot_bgcolor=chart_plot,
            font=dict(family="Noto Sans KR, Arial", size=16, color=chart_text),
            xaxis=dict(gridcolor=chart_grid, zerolinecolor=chart_grid),
            yaxis=dict(gridcolor=chart_grid, zerolinecolor=chart_grid),
            showlegend=False,
        )
        st.plotly_chart(figure, use_container_width=True)
    with explanation_col:
        active = selected["steps"][current_step]
        st.subheader(f"현재 단계의 판독 기준")
        st.markdown(f"**관찰 대상**  \n{active['evidence']}")
        st.markdown(f"**해석 원칙**  \n{active['detail']}")
        st.warning("하나의 지표만으로 공격을 확정하지 않습니다. 정상 유지보수, 고밀도 환경, 드라이버 오류 같은 대안을 함께 검토합니다.")

    if advanced_learning_mode:
        advanced_focus = selected_advanced["stage_focus"][current_step]
        st.markdown(
            f"""
            <section class="advanced-panel">
              <h3>🧠 심화 탐지 판단</h3>
              <p>현재 단계의 신호를 프로토콜 조건과 대안 가설로 다시 검증합니다.</p>
              <ul><li>{escape(advanced_focus['protocol'])}</li><li>{escape(advanced_focus['analysis'])}</li></ul>
            </section>
            """,
            unsafe_allow_html=True,
        )

    st.info("향후 Telemetry Adapter가 연결되면 이 영역에 pcap 요약, WIDS 이벤트, AP 상태와 실습 엔진의 단계 이벤트가 같은 시간축으로 표시됩니다.", icon="🔌")


with tab_defense:
    st.markdown('<div class="section-heading"><div><h2>방어는 설정에서 검증까지</h2><p>권장 사항을 나열하는 데서 끝내지 않고 확인 방법까지 연결합니다.</p></div><span class="status-pill">방어 체크리스트</span></div>', unsafe_allow_html=True)
    defense_cards = []
    for defense in selected["defenses"]:
        defense_cards.append(
            f"""
            <article class="defense-card">
              <div class="defense-card__top"><span>🛡️</span><span class="defense-card__priority">{escape(defense['priority'])}</span></div>
              <h3>{escape(defense['title'])}</h3>
              <p>{escape(defense['description'])}</p>
              <p class="verify"><strong>검증:</strong> {escape(defense['verification'])}</p>
            </article>
            """
        )
    st.markdown(f"<div class='defense-grid'>{''.join(defense_cards)}</div>", unsafe_allow_html=True)

    if advanced_learning_mode:
        st.markdown(
            f"""
            <section class="advanced-panel">
              <h3>🧠 심화 방어 검증</h3>
              <p>{escape(selected_advanced['stage_focus'][current_step]['design'])}</p>
              <p>권장 설정의 적용 여부뿐 아니라 공격 전후 지표, 호환성 저하, 예외 경로와 원상 복구 조건까지 검증 범위에 포함합니다.</p>
            </section>
            """,
            unsafe_allow_html=True,
        )

    st.subheader("✅ 학습자 확인")
    checked = 0
    for index, defense in enumerate(selected["defenses"]):
        if st.checkbox(f"{defense['title']} — 적용 조건과 검증 방법을 설명할 수 있다", key=f"defense_{selected_key}_{index}"):
            checked += 1
    st.progress(checked / len(selected["defenses"]), text=f"방어 개념 {checked} / {len(selected['defenses'])}개 확인")


with tab_simulation:
    active_simulation_step = selected["steps"][current_step]
    defense_names = "".join(f"<li>{escape(item['title'])}</li>" for item in selected["defenses"][:3])
    simulation_card_modifier = " simulation-card--advanced" if advanced_learning_mode else ""
    advanced_simulation_item = (
        f"<li>심화 검증: {escape(selected_advanced['stage_focus'][current_step]['analysis'])}</li>"
        if advanced_learning_mode
        else ""
    )
    st.markdown(
        '<div class="section-heading"><div><h2>실제 시뮬레이션</h2><p>학습과 실행을 분리하고, 승인된 격리 실습망에서 공격·방어 결과를 비교하는 공간입니다.</p></div><span class="status-pill">실행 엔진 미연결</span></div>',
        unsafe_allow_html=True,
    )
    st.markdown(
        f"""
        <div class="simulation-grid">
          <article class="simulation-card{simulation_card_modifier}">
            <div class="simulation-card__top"><span class="simulation-card__icon">🧪</span><span class="simulation-card__status">ATTACK · 준비 중</span></div>
            <h3>{selected['icon']} {escape(selected['label'])} 공격 시뮬레이션</h3>
            <p>선택한 공격의 학습 단계를 격리 실습 엔진의 이벤트와 연결할 예정입니다.</p>
            <ul class="simulation-card__list">
              <li>선택 단계: {current_step + 1}단계 · {escape(active_simulation_step['title'])}</li>
              <li>관측 기준: {escape(active_simulation_step['evidence'])}</li>
              <li>출력 예정: 단계 상태 · 관측 증거 · 중지·실패 사유</li>
              {advanced_simulation_item}
            </ul>
          </article>
          <article class="simulation-card{simulation_card_modifier}">
            <div class="simulation-card__top"><span class="simulation-card__icon">🛡️</span><span class="simulation-card__status">DEFENSE · 준비 중</span></div>
            <h3>{escape(selected['label'])} 방어 시뮬레이션</h3>
            <p>공격 전후의 기준선을 비교하고 방어 적용 효과와 부작용을 검증할 예정입니다.</p>
            <ul class="simulation-card__list">{defense_names}</ul>
          </article>
        </div>
        """,
        unsafe_allow_html=True,
    )

    st.markdown(
        """
        <div class="section-heading"><div><h2>시뮬레이션 진행 구조</h2><p>실행 기능이 연결되더라도 아래 네 단계를 통과해야 시작할 수 있습니다.</p></div></div>
        <div class="simulation-phases">
          <article class="simulation-phase"><span class="simulation-phase__number">01</span><strong>승인·격리 확인</strong><p>소유권, 대상 allowlist, 격리망과 비상 중지를 확인합니다.</p></article>
          <article class="simulation-phase"><span class="simulation-phase__number">02</span><strong>공격 시나리오</strong><p>시간과 대상이 제한된 시나리오를 단계 이벤트로 실행합니다.</p></article>
          <article class="simulation-phase"><span class="simulation-phase__number">03</span><strong>방어 적용</strong><p>기준선을 보존한 뒤 탐지·차단·정책 변경을 적용합니다.</p></article>
          <article class="simulation-phase"><span class="simulation-phase__number">04</span><strong>비교·복구</strong><p>전후 증거를 비교하고 환경을 원상 복구한 뒤 결과를 평가합니다.</p></article>
        </div>
        """,
        unsafe_allow_html=True,
    )

    simulation_attack_col, simulation_defense_col = st.columns(2)
    with simulation_attack_col:
        st.button("🧪 공격 시뮬레이션 · 엔진 연결 예정", disabled=True, width="stretch")
    with simulation_defense_col:
        st.button("🛡️ 방어 시뮬레이션 · 엔진 연결 예정", disabled=True, width="stretch")
    st.info("현재 화면은 UI와 데이터 연결 지점만 제공하며 실제 무선 공격·방어 명령은 실행하지 않습니다.", icon="🔒")


st.divider()
with st.expander("📚 공식 학습 참고 자료"):
    source_items = "".join(
        f'<li><a href="{escape(url)}" target="_blank" rel="noreferrer">{escape(title)}</a></li>'
        for title, url in selected["sources"]
    )
    st.markdown(f"<ul class='source-list'>{source_items}</ul>", unsafe_allow_html=True)
    st.caption("기술 내용은 Airgeddon 공식 문서·소스와 Cisco 무선 보안 문서를 중심으로 정리했습니다. 실제 실습은 소유하거나 명시적으로 허가받은 네트워크에서만 수행해야 합니다.")
