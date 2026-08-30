(function () {
  "use strict";

  const scenarios = window.WFSAT_SCENARIOS || [];
  if (!scenarios.length) {
    document.body.innerHTML = "<p style='padding:2rem;color:white'>시나리오 데이터를 불러오지 못했습니다.</p>";
    return;
  }

  const $ = (id) => document.getElementById(id);
  const elements = {
    scenarioList: $("scenarioList"),
    scenarioLayer: $("scenarioLayer"),
    scenarioEnglish: $("scenarioEnglish"),
    scenarioTitle: $("scenarioTitle"),
    scenarioSummary: $("scenarioSummary"),
    learningDuration: $("learningDuration"),
    learningObjectiveList: $("learningObjectiveList"),
    topStatus: $("topStatus"),
    topbarStatus: document.querySelector(".topbar-status"),
    resetButton: $("resetButton"),
    previousButton: $("previousButton"),
    nextButton: $("nextButton"),
    stepBarLabel: $("stepBarLabel"),
    stepBarFill: $("stepBarFill"),
    metricAps: $("metricAps"),
    metricApsDelta: $("metricApsDelta"),
    metricAlerts: $("metricAlerts"),
    metricAlertsDelta: $("metricAlertsDelta"),
    metricRate: $("metricRate"),
    metricRateDelta: $("metricRateDelta"),
    metricSensor: $("metricSensor"),
    metricSensorDelta: $("metricSensorDelta"),
    sensorIcon: $("sensorIcon"),
    phaseBadge: $("phaseBadge"),
    phaseNumber: $("phaseNumber"),
    phaseKicker: $("phaseKicker"),
    phaseTitle: $("phaseTitle"),
    phaseDescription: $("phaseDescription"),
    phaseFocus: $("phaseFocus"),
    plainExplanation: $("plainExplanation"),
    severityBadge: $("severityBadge"),
    evidenceList: $("evidenceList"),
    technicalExplanation: $("technicalExplanation"),
    packetFields: $("packetFields"),
    defenseName: $("defenseName"),
    defenseDescription: $("defenseDescription"),
    defenseBefore: $("defenseBefore"),
    defenseAfter: $("defenseAfter"),
    progressFill: $("progressFill"),
    phaseTimeline: $("phaseTimeline"),
    nodeLayer: $("nodeLayer"),
    linkLayer: $("linkLayer"),
    packetLayer: $("packetLayer"),
    networkStage: $("networkStage"),
    trafficChart: $("trafficChart"),
    chartSummary: $("chartSummary"),
    eventLog: $("eventLog"),
    identityList: $("identityList"),
    glossaryList: $("glossaryList"),
    signaturePanel: $("signaturePanel"),
    signatureBadge: $("signatureBadge"),
    signatureCaption: $("signatureCaption"),
    signatureBody: $("signatureBody"),
    signatureNote: $("signatureNote"),
    checkpointSection: $("checkpointSection"),
    checkpointBadge: $("checkpointBadge"),
    checkpointGate: $("checkpointGate"),
    checkpointForm: $("checkpointForm"),
    checkpointFieldset: $("checkpointFieldset"),
    checkpointQuestion: $("checkpointQuestion"),
    checkpointOptions: $("checkpointOptions"),
    checkpointSubmit: $("checkpointSubmit"),
    checkpointFeedback: $("checkpointFeedback"),
    checkpointFeedbackTitle: $("checkpointFeedbackTitle"),
    checkpointFeedbackText: $("checkpointFeedbackText"),
    reviewPhaseButton: $("reviewPhaseButton"),
    retryCheckpointButton: $("retryCheckpointButton"),
    toast: $("toast")
  };

  const severityLabels = {
    neutral: "관찰 중",
    low: "정보",
    medium: "주의",
    high: "위험",
    critical: "심각",
    resolved: "대응 완료"
  };

  const stateLabels = {
    normal: "정상",
    warning: "주의",
    danger: "공격",
    defense: "보호됨",
    idle: "대기",
    offline: "연결 끊김"
  };

  const connectionLabels = {
    associated: "연결됨",
    dropping: "끊기는 중",
    disconnected: "끊김",
    protected: "PMF 보호"
  };

  const verdictLabels = {
    trap: "같아서 위험",
    differ: "다름",
    downgrade: "보안 하향",
    "fake-stronger": "더 강함"
  };

  const verdictSymbols = {
    trap: "=",
    differ: "≠",
    downgrade: "↓",
    "fake-stronger": "↑"
  };

  const fakeStatusLabels = {
    rogue: "Rogue AP",
    attacking: "Deauth 전송",
    blocked: "차단됨"
  };

  const phaseTime = ["00:00", "00:06", "00:12", "00:18", "00:24"];
  const phaseFocusLabels = [
    "평소의 정상 통신 모습을 먼저 기억하세요.",
    "공격 전에 새로 등장하거나 달라진 신호를 찾아보세요.",
    "누가 누구에게 어떤 프레임을 보내는지 따라가 보세요.",
    "사용자와 네트워크에 생긴 실제 변화를 확인하세요.",
    "탐지 근거가 어떤 방어 방법으로 이어지는지 연결해 보세요."
  ];
  const historyKey = "wfsat-learning-history-v1";
  const state = {
    scenarioId: scenarios[0].id,
    phaseIndex: 0,
    speed: 1,
    playing: false,
    timer: null,
    toastTimer: null,
    resizeTimer: null,
    checkpointSelection: null,
    checkpointResult: null,
    checkpointAttempts: 0
  };

  function getScenario() {
    return scenarios.find((scenario) => scenario.id === state.scenarioId) || scenarios[0];
  }

  function getPhase() {
    return getScenario().phases[state.phaseIndex];
  }

  function safeHistoryRead() {
    try {
      const stored = JSON.parse(localStorage.getItem(historyKey) || "[]");
      return Array.isArray(stored) ? stored : [];
    } catch (error) {
      return [];
    }
  }

  function safeHistoryWrite(history) {
    try {
      localStorage.setItem(historyKey, JSON.stringify(history));
      return true;
    } catch (error) {
      return false;
    }
  }

  function getHistoryEntry(scenarioId) {
    return safeHistoryRead().find((entry) => entry && entry.scenarioId === scenarioId) || null;
  }

  function getLearningConfig(scenario) {
    const learning = scenario.learning || {};
    const objectives = Array.isArray(learning.objectives) && learning.objectives.length
      ? learning.objectives.slice(0, 3)
      : ["공격 흐름을 단계별로 이해하기", "탐지 근거와 방어 방법 연결하기"];
    return {
      estimatedMinutes: Number.isFinite(learning.estimatedMinutes) ? learning.estimatedMinutes : 4,
      objectives,
      checkpoint: learning.checkpoint || null
    };
  }

  function isCheckpointValid(checkpoint) {
    if (!checkpoint || typeof checkpoint.prompt !== "string" || !Array.isArray(checkpoint.options)) return false;
    if (checkpoint.options.length < 2 || typeof checkpoint.correctOptionId !== "string") return false;
    return checkpoint.options.every((option) => option && typeof option.id === "string" && typeof option.label === "string")
      && checkpoint.options.some((option) => option.id === checkpoint.correctOptionId);
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function renderScenarioNavigation() {
    const history = safeHistoryRead();
    elements.scenarioList.innerHTML = scenarios.map((scenario) => {
      const entry = history.find((item) => item && item.scenarioId === scenario.id);
      const progressClass = entry && entry.checkpointCorrect ? "checked" : entry && entry.checkpointAnswered ? "retry" : entry ? "complete" : "new";
      const progressLabel = entry && entry.checkpointCorrect ? "이해 확인 완료" : entry && entry.checkpointAnswered ? "문제 재도전" : entry ? "5단계 완료" : "학습 전";
      return `
      <button
        class="scenario-button"
        type="button"
        data-scenario="${escapeHtml(scenario.id)}"
        aria-current="${scenario.id === state.scenarioId ? "true" : "false"}"
        aria-label="${escapeHtml(scenario.title)} 시나리오 선택, ${progressLabel}"
      >
        <span class="scenario-icon" aria-hidden="true">${scenario.icon}</span>
        <span class="scenario-name">
          <strong>${escapeHtml(scenario.shortName)}</strong>
          <span>${escapeHtml(scenario.english)}</span>
          <small class="scenario-progress ${progressClass}">${progressLabel}</small>
        </span>
        <span class="scenario-arrow" aria-hidden="true">›</span>
      </button>
    `;
    }).join("");

    elements.scenarioList.querySelectorAll("[data-scenario]").forEach((button) => {
      button.addEventListener("click", () => selectScenario(button.dataset.scenario));
    });
  }

  function renderHero(scenario) {
    const learning = getLearningConfig(scenario);
    elements.scenarioLayer.textContent = scenario.layer;
    elements.scenarioEnglish.textContent = scenario.english;
    elements.scenarioTitle.textContent = scenario.title;
    elements.scenarioSummary.textContent = scenario.summary;
    elements.learningDuration.textContent = `약 ${learning.estimatedMinutes}분`;
    elements.learningObjectiveList.innerHTML = learning.objectives.map((objective) => `<li>${escapeHtml(objective)}</li>`).join("");
  }

  function renderMetrics(phase) {
    elements.metricAps.textContent = phase.aps;
    elements.metricApsDelta.textContent = phase.apsDelta;
    elements.metricAlerts.textContent = phase.alerts;
    elements.metricAlertsDelta.textContent = phase.alertsDelta;
    elements.metricRate.textContent = phase.rate.toLocaleString("ko-KR");
    elements.metricRateDelta.textContent = phase.rateDelta;
    elements.metricSensor.textContent = phase.sensor;
    elements.metricSensorDelta.textContent = phase.sensorDelta;
    elements.sensorIcon.textContent = phase.severity === "critical" ? "!" : phase.severity === "resolved" ? "✓" : "◉";
    elements.sensorIcon.className = `metric-icon ${phase.severity === "critical" ? "red" : phase.severity === "resolved" ? "green" : "green"}`;
  }

  function renderNarrative(scenario, phase) {
    elements.phaseBadge.textContent = `${state.phaseIndex + 1}단계 · ${phase.label}`;
    elements.phaseNumber.textContent = String(state.phaseIndex + 1).padStart(2, "0");
    elements.phaseKicker.textContent = phase.kicker;
    elements.phaseTitle.textContent = phase.title;
    elements.phaseDescription.textContent = phase.description;
    elements.phaseFocus.textContent = phaseFocusLabels[state.phaseIndex] || phaseFocusLabels[0];
    elements.plainExplanation.textContent = phase.plain;
    elements.severityBadge.textContent = severityLabels[phase.severity];
    elements.severityBadge.className = `severity-badge ${phase.severity}`;
    elements.technicalExplanation.textContent = scenario.technical;

    elements.evidenceList.innerHTML = phase.evidence.map((item, index) => `
      <li>
        <span class="evidence-number">${index + 1}</span>
        <span>${escapeHtml(item)}</span>
      </li>
    `).join("");

    elements.packetFields.innerHTML = Object.entries(phase.packetFields || {}).map(([key, value]) => `
      <dt>${escapeHtml(key)}</dt><dd>${escapeHtml(value)}</dd>
    `).join("");

    elements.defenseName.textContent = scenario.defense.name;
    elements.defenseDescription.textContent = scenario.defense.description;
    elements.defenseBefore.textContent = scenario.defense.before;
    elements.defenseAfter.textContent = scenario.defense.after;
  }

  function renderTimeline(scenario) {
    const progressPct = `${(state.phaseIndex / (scenario.phases.length - 1)) * 100}%`;
    elements.progressFill.style.width = progressPct;
    elements.stepBarFill.style.width = progressPct;
    elements.phaseTimeline.innerHTML = scenario.phases.map((phase, index) => {
      const statusClass = index === state.phaseIndex ? "active" : index < state.phaseIndex ? "complete" : "";
      return `
        <li>
          <button
            class="phase-button ${statusClass}"
            type="button"
            data-phase="${index}"
            aria-current="${index === state.phaseIndex ? "step" : "false"}"
          >
            <small>STEP ${String(index + 1).padStart(2, "0")}</small>
            <strong>${escapeHtml(phase.label)}</strong>
            <span>${escapeHtml(phase.title)}</span>
          </button>
        </li>
      `;
    }).join("");

    elements.phaseTimeline.querySelectorAll("[data-phase]").forEach((button) => {
      button.addEventListener("click", () => {
        stopPlayback();
        setPhase(Number(button.dataset.phase));
      });
    });
  }

  // 학습 화면의 토폴로지 무대(기본 컨텍스트). 실습 화면은 자체 무대를 넘겨 재사용한다.
  const LEARN_TOPO = {
    nodeLayer: elements.nodeLayer,
    linkLayer: elements.linkLayer,
    packetLayer: elements.packetLayer,
    networkStage: elements.networkStage,
    idPrefix: "topology-"
  };

  function renderTopology(scenario, phase, ctx = LEARN_TOPO) {
    // 무대 요소가 없는 화면(예: 토폴로지를 두지 않는 라이브 뷰)에서는 조용히 건너뛴다.
    if (!ctx || !ctx.nodeLayer) return;
    ctx.nodeLayer.innerHTML = scenario.nodes.map((node) => {
      const nodeState = phase.states[node.id] || "idle";
      return `
        <button
          type="button"
          id="${ctx.idPrefix}${escapeHtml(node.id)}"
          class="topology-node ${escapeHtml(node.role)}"
          data-status="${escapeHtml(nodeState)}"
          title="${escapeHtml(node.label)} · ${escapeHtml(node.detail)} · ${stateLabels[nodeState]}"
          aria-label="${escapeHtml(node.label)}, ${escapeHtml(node.detail)}, 현재 상태 ${stateLabels[nodeState]}"
        >
          <span class="node-status-label" aria-hidden="true"></span>
          <span class="node-icon" aria-hidden="true">${node.icon}</span>
          <span class="node-label">${escapeHtml(node.label)}</span>
          <span class="node-detail">${escapeHtml(node.detail)}</span>
        </button>
      `;
    }).join("");

    ctx.nodeLayer.querySelectorAll(".topology-node").forEach((node) => {
      node.addEventListener("click", () => showToast(node.getAttribute("aria-label")));
    });

    requestAnimationFrame(() => drawTopologyConnections(phase, ctx));
  }

  function getNodeCenter(nodeId, ctx = LEARN_TOPO) {
    const node = $(`${ctx.idPrefix}${nodeId}`);
    if (!node) return null;
    const stageRect = ctx.networkStage.getBoundingClientRect();
    const nodeRect = node.getBoundingClientRect();
    return {
      x: nodeRect.left - stageRect.left + nodeRect.width / 2,
      y: nodeRect.top - stageRect.top + nodeRect.height / 2
    };
  }

  function drawTopologyConnections(phase, ctx = LEARN_TOPO) {
    ctx.linkLayer.innerHTML = "";
    ctx.packetLayer.innerHTML = "";

    phase.links.forEach((connection) => {
      const start = getNodeCenter(connection.from, ctx);
      const end = getNodeCenter(connection.to, ctx);
      if (!start || !end) return;
      const deltaX = end.x - start.x;
      const deltaY = end.y - start.y;
      const distance = Math.hypot(deltaX, deltaY);
      const angle = Math.atan2(deltaY, deltaX) * 180 / Math.PI;

      const lineElement = document.createElement("div");
      lineElement.className = `topology-link ${connection.type}`;
      lineElement.style.left = `${start.x}px`;
      lineElement.style.top = `${start.y}px`;
      lineElement.style.width = `${distance}px`;
      lineElement.style.transform = `rotate(${angle}deg)`;
      ctx.linkLayer.appendChild(lineElement);

      const labelElement = document.createElement("span");
      labelElement.className = "link-label";
      labelElement.textContent = connection.label;
      labelElement.style.left = `${start.x + deltaX * 0.5}px`;
      labelElement.style.top = `${start.y + deltaY * 0.5}px`;
      ctx.linkLayer.appendChild(labelElement);
    });

    animatePacket(phase.packet, ctx);
  }

  function animatePacket(packetData, ctx = LEARN_TOPO) {
    if (!packetData) return;
    const start = getNodeCenter(packetData.from, ctx);
    const end = getNodeCenter(packetData.to, ctx);
    if (!start || !end) return;

    const token = document.createElement("span");
    token.className = `packet-token ${packetData.tone || "normal"}`;
    token.textContent = packetData.label;
    token.style.left = "0";
    token.style.top = "0";
    ctx.packetLayer.appendChild(token);

    const startTransform = `translate(${start.x - 11}px, ${start.y - 11}px)`;
    const endTransform = `translate(${end.x - 11}px, ${end.y - 11}px)`;
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (reduceMotion || typeof token.animate !== "function") {
      token.style.transform = endTransform;
      return;
    }

    token.animate(
      [
        { transform: startTransform, opacity: 0 },
        { transform: startTransform, opacity: 1, offset: 0.08 },
        { transform: endTransform, opacity: 1, offset: 0.86 },
        { transform: endTransform, opacity: 0 }
      ],
      {
        duration: 1800 / state.speed,
        iterations: state.playing ? Infinity : 2,
        easing: "ease-in-out"
      }
    );
  }

  function createTrafficSeries(scenario, phaseIndex) {
    const baseline = scenario.phases[0].rate;
    const current = scenario.phases[phaseIndex].rate;
    const count = 30;
    const pattern = [0, 0.08, -0.04, 0.12, -0.07, 0.05, -0.02];
    const baselineSeries = [];
    const observedSeries = [];

    for (let index = 0; index < count; index += 1) {
      const normalValue = Math.max(1, baseline * (1 + pattern[index % pattern.length]));
      baselineSeries.push(normalValue);

      if (phaseIndex < 2) {
        const multiplier = phaseIndex === 0 ? 1 : 1 + Math.max(0, index - 19) / 90;
        observedSeries.push(normalValue * multiplier);
      } else if (phaseIndex === 4) {
        const historicPeak = Math.max(...scenario.phases.slice(0, 4).map((phase) => phase.rate));
        if (index < 11) observedSeries.push(normalValue);
        else if (index < 20) observedSeries.push(normalValue + (historicPeak - normalValue) * ((index - 10) / 9));
        else observedSeries.push(current + (historicPeak - current) * ((29 - index) / 9));
      } else if (index < 11) {
        observedSeries.push(normalValue);
      } else {
        const progress = (index - 10) / 19;
        const shaped = Math.min(1, progress * (phaseIndex === 2 ? 1.35 : 1.8));
        const jitter = 1 + pattern[(index + 2) % pattern.length] * 1.8;
        observedSeries.push((normalValue + (current - normalValue) * shaped) * jitter);
      }
    }
    return { baselineSeries, observedSeries };
  }

  function drawTrafficChart(scenario, phase) {
    const canvas = elements.trafficChart;
    const context = canvas.getContext("2d");
    const rect = canvas.getBoundingClientRect();
    elements.chartSummary.textContent = `${scenario.title} ${phase.label}: 정상 기준선 ${scenario.phases[0].rate} 패킷/초, 현재 ${phase.rate} 패킷/초입니다.`;
    if (rect.width < 10) return;
    const width = Math.max(320, rect.width);
    const height = Math.max(190, rect.height);
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.floor(width * ratio);
    canvas.height = Math.floor(height * ratio);
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);

    const { baselineSeries, observedSeries } = createTrafficSeries(scenario, state.phaseIndex);
    const padding = { top: 17, right: 14, bottom: 25, left: 43 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;
    const maximum = Math.max(50, ...baselineSeries, ...observedSeries) * 1.15;

    context.font = "8px ui-monospace, SFMono-Regular, Menlo, monospace";
    context.textAlign = "right";
    context.textBaseline = "middle";
    for (let lineIndex = 0; lineIndex <= 4; lineIndex += 1) {
      const y = padding.top + chartHeight * lineIndex / 4;
      const value = Math.round(maximum * (1 - lineIndex / 4));
      context.beginPath();
      context.moveTo(padding.left, y);
      context.lineTo(width - padding.right, y);
      context.strokeStyle = "rgba(142, 183, 219, 0.09)";
      context.lineWidth = 1;
      context.stroke();
      context.fillStyle = "#6e879c";
      context.fillText(value.toLocaleString("ko-KR"), padding.left - 7, y);
    }

    function point(index, value, length) {
      return {
        x: padding.left + chartWidth * index / (length - 1),
        y: padding.top + chartHeight * (1 - value / maximum)
      };
    }

    function drawLine(series, color, lineWidth, dashed) {
      context.save();
      context.beginPath();
      series.forEach((value, index) => {
        const coordinate = point(index, value, series.length);
        if (index === 0) context.moveTo(coordinate.x, coordinate.y);
        else context.lineTo(coordinate.x, coordinate.y);
      });
      context.strokeStyle = color;
      context.lineWidth = lineWidth;
      context.lineJoin = "round";
      context.lineCap = "round";
      if (dashed) context.setLineDash([5, 5]);
      context.stroke();
      context.restore();
    }

    if (state.phaseIndex >= 2) {
      const gradient = context.createLinearGradient(0, padding.top, 0, height - padding.bottom);
      gradient.addColorStop(0, "rgba(255, 93, 115, 0.22)");
      gradient.addColorStop(1, "rgba(255, 93, 115, 0.005)");
      context.beginPath();
      observedSeries.forEach((value, index) => {
        const coordinate = point(index, value, observedSeries.length);
        if (index === 0) context.moveTo(coordinate.x, coordinate.y);
        else context.lineTo(coordinate.x, coordinate.y);
      });
      context.lineTo(width - padding.right, height - padding.bottom);
      context.lineTo(padding.left, height - padding.bottom);
      context.closePath();
      context.fillStyle = gradient;
      context.fill();
    }

    drawLine(baselineSeries, "rgba(145, 168, 188, 0.62)", 1.5, true);
    drawLine(observedSeries, state.phaseIndex === 4 ? "#3ed6a1" : state.phaseIndex >= 2 ? "#ff5d73" : "#34c8ff", 2.3, false);

    context.textAlign = "center";
    context.textBaseline = "top";
    context.fillStyle = "#6e879c";
    [0, 10, 20, 29].forEach((index) => {
      const coordinate = point(index, 0, observedSeries.length);
      context.fillText(`${index - 29}s`, coordinate.x, height - padding.bottom + 8);
    });

    const lastPoint = point(observedSeries.length - 1, observedSeries[observedSeries.length - 1], observedSeries.length);
    context.beginPath();
    context.arc(lastPoint.x, lastPoint.y, 3.5, 0, Math.PI * 2);
    context.fillStyle = state.phaseIndex === 4 ? "#3ed6a1" : state.phaseIndex >= 2 ? "#ff5d73" : "#34c8ff";
    context.fill();

  }

  function renderEventLog(scenario) {
    const visiblePhases = scenario.phases.slice(0, state.phaseIndex + 1).map((phase, index) => ({ ...phase, originalIndex: index })).reverse();
    elements.eventLog.innerHTML = visiblePhases.map((phase) => {
      const currentEvent = phase.event;
      return `
        <tr>
          <td>T+${phaseTime[phase.originalIndex]}</td>
          <td><span class="event-type ${escapeHtml(currentEvent.tone)}">${escapeHtml(currentEvent.type)}</span></td>
          <td>${escapeHtml(currentEvent.source)}</td>
          <td>${escapeHtml(currentEvent.detail)}</td>
          <td><span class="event-status ${escapeHtml(currentEvent.tone)}">${escapeHtml(currentEvent.status)}</span></td>
        </tr>
      `;
    }).join("");
  }

  function renderIdentityList(scenario, phase) {
    elements.identityList.innerHTML = scenario.nodes.map((node) => {
      const nodeState = phase.states[node.id] || "idle";
      return `
        <div class="identity-row">
          <span class="identity-icon" aria-hidden="true">${node.icon}</span>
          <div><strong>${escapeHtml(node.label)}</strong><span>${escapeHtml(node.role)}</span></div>
          <code>${escapeHtml(node.detail)}</code>
          <span class="identity-state ${escapeHtml(nodeState)}">${stateLabels[nodeState]}</span>
        </div>
      `;
    }).join("");
  }

  function renderGlossary(scenario) {
    elements.glossaryList.innerHTML = scenario.glossary.map((item) => `
      <article class="glossary-item">
        <strong>${escapeHtml(item.term)}</strong>
        <p>${escapeHtml(item.description)}</p>
      </article>
    `).join("");
  }

  function setSignatureBody(title, bodyHtml, summary) {
    elements.signatureBody.innerHTML = `<p class="signature-frame-title">${escapeHtml(title)}</p>${bodyHtml}`;
    elements.signatureBody.setAttribute("aria-label", summary);
  }

  function renderDeauthBurst(signature, data) {
    const level = Math.max(0, Math.min(Number(data.level) || 0, 4));
    const rejected = Boolean(data.pmf);
    const connection = connectionLabels[data.connection] ? data.connection : "associated";
    const connectionLabel = connectionLabels[connection];
    const framesLabel = data.framesLabel || "";
    const reasonChip = data.reason ? `<span class="burst-reason">Reason ${escapeHtml(data.reason)}</span>` : "";

    setSignatureBody(signature.title, `
      <div class="deauth-burst${rejected ? " rejected" : ""}">
        <div class="burst-row">
          <span class="burst-actor">공격자 ▶</span>
          <span class="burst-meter${rejected ? " burst-rejected" : ""}"><span class="burst-fill lv${level}"></span></span>
          <span class="burst-frames">${escapeHtml(framesLabel)}</span>
          ${reasonChip}
        </div>
        <div class="burst-row">
          <span class="burst-actor">클라이언트 연결</span>
          <span class="conn-lamp ${escapeHtml(connection)}"><i aria-hidden="true"></i>${escapeHtml(connectionLabel)}</span>
        </div>
      </div>
    `, rejected
      ? `위조 Deauth 프레임이 PMF에 의해 거부됨, 클라이언트 연결 ${connectionLabel}`
      : `위조 Deauth ${framesLabel}${data.reason ? `, Reason ${data.reason}` : ""}, 클라이언트 연결 ${connectionLabel}`);
  }

  function renderApCompare(signature, data) {
    const fields = Array.isArray(signature.fields) ? signature.fields : [];
    const fakePresent = Boolean(data.fakePresent);
    const fakeStatus = data.fakeStatus || "idle";

    function connectionBadge(side) {
      if (data.connectedTo === side) return '<span class="ap-connected-badge">연결됨</span>';
      if (side === "real" && !data.connectedTo) return '<span class="ap-connected-badge lost">연결 끊김</span>';
      return "";
    }

    const realFields = fields.map((field) => `
      <div class="ap-field">
        <span class="ap-field-label">${escapeHtml(field.label)}</span>
        <span class="ap-field-value">${escapeHtml(field.real)}</span>
      </div>
    `).join("");

    const fakeFields = fields.map((field) => `
      <div class="ap-field ${escapeHtml(field.verdict)}">
        <span class="ap-field-label">${escapeHtml(field.label)}</span>
        <span class="ap-field-value">${escapeHtml(field.fake)}</span>
        <span class="ap-field-flag">${escapeHtml(verdictLabels[field.verdict] || "")}</span>
      </div>
    `).join("");

    const relations = fields
      .map((field) => `<span>${fakePresent ? escapeHtml(verdictSymbols[field.verdict] || "·") : "·"}</span>`)
      .join("");

    const statusChip = fakePresent && fakeStatusLabels[fakeStatus]
      ? `<span class="ap-status-chip ${escapeHtml(fakeStatus)}">${escapeHtml(fakeStatusLabels[fakeStatus])}</span>`
      : "";

    setSignatureBody(signature.title, `
      <div class="ap-compare">
        <article class="ap-card real">
          <header class="ap-card-head"><strong>정상 AP</strong>${connectionBadge("real")}</header>
          ${realFields}
        </article>
        <div class="ap-rel"><span class="ap-rel-spacer"></span>${relations}</div>
        <article class="ap-card fake ${fakePresent ? escapeHtml(fakeStatus) : "absent"}">
          <header class="ap-card-head"><strong>가짜 AP</strong>${statusChip}${connectionBadge("fake")}</header>
          ${fakePresent ? fakeFields : '<div class="ap-placeholder">같은 이름의 다른 AP가 아직 없습니다</div>'}
        </article>
      </div>
    `, `${fakePresent
      ? fields.map((field) => `${field.label}은 정상 AP ${field.real}, 가짜 AP ${field.fake}`).join(", ")
      : "같은 이름을 쓰는 AP가 정상 AP 하나뿐"}. ${data.connectedTo === "fake"
      ? "현재 기기가 가짜 AP에 연결됨"
      : data.connectedTo === "real" ? "현재 기기가 정상 AP에 연결됨" : "현재 기기의 연결이 끊김"}`);
  }

  function renderSignature(scenario) {
    const signature = scenario.signature;
    const panel = elements.signaturePanel;
    const renderers = {
      "deauth-burst": renderDeauthBurst,
      "ap-compare": renderApCompare
    };
    const data = signature && Array.isArray(signature.phases) ? signature.phases[state.phaseIndex] : null;
    const renderer = signature ? renderers[signature.type] : null;

    if (!data || !renderer) {
      panel.hidden = true;
      return;
    }

    panel.hidden = false;
    elements.signatureBadge.textContent = `${state.phaseIndex + 1}단계`;
    elements.signatureCaption.textContent = signature.caption || "";
    elements.signatureNote.textContent = data.note || "";
    renderer(signature, data);
  }

  function renderCheckpoint(scenario) {
    const checkpoint = getLearningConfig(scenario).checkpoint;
    const unlocked = state.phaseIndex === scenario.phases.length - 1;
    const valid = isCheckpointValid(checkpoint);
    const historyEntry = getHistoryEntry(scenario.id);

    elements.checkpointGate.hidden = unlocked && valid;
    elements.checkpointForm.hidden = !unlocked || !valid || state.checkpointResult !== null;
    elements.checkpointFeedback.hidden = !unlocked || state.checkpointResult === null;

    if (!valid) {
      elements.checkpointBadge.textContent = "문제 준비 중";
      elements.checkpointBadge.className = "checkpoint-badge waiting";
      elements.checkpointGate.innerHTML = '<span aria-hidden="true">ℹ</span><div><strong>이 시나리오의 문제를 불러오지 못했습니다</strong><p>단계 학습은 계속 진행할 수 있습니다.</p></div>';
      return;
    }

    if (!unlocked) {
      elements.checkpointBadge.textContent = "5단계 후 열림";
      elements.checkpointBadge.className = "checkpoint-badge waiting";
      elements.checkpointGate.innerHTML = '<span aria-hidden="true">🔒</span><div><strong>아직 학습 중입니다</strong><p>공격 흐름을 5단계까지 확인하면 문제가 열립니다.</p></div>';
      return;
    }

    const previouslyCorrect = Boolean(historyEntry && historyEntry.checkpointCorrect);
    const needsRetry = Boolean(historyEntry && historyEntry.checkpointAnswered && !historyEntry.checkpointCorrect);
    elements.checkpointBadge.textContent = state.checkpointResult === true || previouslyCorrect
      ? "이해 확인 완료"
      : state.checkpointResult === false || needsRetry ? "재도전 가능" : "문제 풀기";
    elements.checkpointBadge.className = `checkpoint-badge ${state.checkpointResult === true || previouslyCorrect ? "complete" : state.checkpointResult === false || needsRetry ? "retry" : "ready"}`;
    elements.checkpointQuestion.textContent = checkpoint.prompt;
    elements.checkpointOptions.innerHTML = checkpoint.options.map((option) => `
      <label class="checkpoint-option">
        <input type="radio" name="checkpointAnswer" value="${escapeHtml(option.id)}" ${state.checkpointSelection === option.id ? "checked" : ""}>
        <span class="option-marker" aria-hidden="true">${escapeHtml(option.id.toUpperCase())}</span>
        <span>${escapeHtml(option.label)}</span>
      </label>
    `).join("");
    elements.checkpointSubmit.disabled = state.checkpointSelection === null;

    if (state.checkpointResult !== null) {
      const correct = state.checkpointResult;
      elements.checkpointFeedback.className = `checkpoint-feedback ${correct ? "correct" : "incorrect"}`;
      elements.checkpointFeedbackTitle.textContent = correct ? "정답입니다. 핵심을 잘 찾았어요." : "아직 괜찮습니다. 해설에서 근거를 다시 확인해 보세요.";
      elements.checkpointFeedbackText.textContent = checkpoint.explanation;
      elements.reviewPhaseButton.hidden = correct;
      elements.retryCheckpointButton.textContent = correct ? "한 번 더 풀기" : "다시 풀기";
    }
  }

  function saveCompletion(scenario) {
    const history = safeHistoryRead();
    const existingIndex = history.findIndex((entry) => entry && entry.scenarioId === scenario.id);
    const existing = existingIndex >= 0 ? history.splice(existingIndex, 1)[0] : null;
    const entry = {
      ...(existing || {}),
      scenarioId: scenario.id,
      title: scenario.title,
      icon: scenario.icon,
      timestamp: existing && existing.timestamp ? existing.timestamp : Date.now(),
      score: existing && existing.checkpointCorrect ? "이해 확인 완료" : existing && existing.checkpointAnswered ? "문제 재도전" : "5단계 완료"
    };
    safeHistoryWrite([entry, ...history].slice(0, 6));
  }

  function saveCheckpointResult(scenario, correct) {
    const history = safeHistoryRead();
    const existingIndex = history.findIndex((entry) => entry && entry.scenarioId === scenario.id);
    const existing = existingIndex >= 0 ? history.splice(existingIndex, 1)[0] : {};
    const checkpointCorrect = Boolean(existing.checkpointCorrect || correct);
    const entry = {
      ...existing,
      scenarioId: scenario.id,
      title: scenario.title,
      icon: scenario.icon,
      timestamp: Date.now(),
      score: checkpointCorrect ? "이해 확인 완료" : "문제 재도전",
      checkpointAnswered: true,
      checkpointCorrect,
      checkpointAttempts: Number(existing.checkpointAttempts || 0) + 1
    };
    safeHistoryWrite([entry, ...history].slice(0, 6));
  }

  // 단계 이동 버튼 상태와 상단바의 현재 단계 표시 갱신(재생/속도 버튼은 제거됨)
  function updatePlaybackUi() {
    const scenario = getScenario();
    elements.previousButton.disabled = state.phaseIndex === 0;
    elements.nextButton.disabled = state.phaseIndex === scenario.phases.length - 1;
    elements.stepBarLabel.textContent = `${state.phaseIndex + 1}단계 · ${scenario.phases[state.phaseIndex].label}`;
    elements.topbarStatus.classList.toggle("running", state.playing);
    if (state.phaseIndex === scenario.phases.length - 1) elements.topStatus.textContent = "학습 단계 완료";
    else elements.topStatus.textContent = `${state.phaseIndex + 1}단계 · ${scenario.phases[state.phaseIndex].label}`;
  }

  function render(options = {}) {
    const scenario = getScenario();
    const phase = getPhase();
    if (state.phaseIndex === scenario.phases.length - 1 && options.recordCompletion !== false) {
      saveCompletion(scenario);
    }
    renderScenarioNavigation();
    renderHero(scenario);
    renderMetrics(phase);
    renderNarrative(scenario, phase);
    renderTimeline(scenario);
    renderTopology(scenario, phase);
    renderSignature(scenario);
    drawTrafficChart(scenario, phase);
    renderEventLog(scenario);
    renderIdentityList(scenario, phase);
    renderGlossary(scenario);
    renderCheckpoint(scenario);
    updatePlaybackUi();
  }

  function setPhase(index, options = {}) {
    const scenario = getScenario();
    const previousIndex = state.phaseIndex;
    state.phaseIndex = Math.max(0, Math.min(index, scenario.phases.length - 1));
    render(options);
    if (state.phaseIndex === scenario.phases.length - 1 && previousIndex !== state.phaseIndex) {
      if (state.playing) stopPlayback(false);
      showToast(`${scenario.title}의 5단계를 완료했습니다. 이제 이해도를 확인해 보세요.`);
    }
  }

  function selectScenario(scenarioId) {
    if (!scenarios.some((scenario) => scenario.id === scenarioId)) return;
    stopPlayback(false);
    state.scenarioId = scenarioId;
    state.phaseIndex = 0;
    state.checkpointSelection = null;
    state.checkpointResult = null;
    state.checkpointAttempts = 0;
    render({ recordCompletion: false });
    showToast(`${getScenario().title} 시나리오를 불러왔습니다.`);
  }

  function stopPlayback(update = true) {
    clearInterval(state.timer);
    state.timer = null;
    state.playing = false;
    if (update) updatePlaybackUi();
  }

  function showToast(message) {
    clearTimeout(state.toastTimer);
    elements.toast.textContent = message;
    elements.toast.classList.add("visible");
    state.toastTimer = window.setTimeout(() => elements.toast.classList.remove("visible"), 2600);
  }

  elements.previousButton.addEventListener("click", () => {
    stopPlayback();
    setPhase(state.phaseIndex - 1, { recordCompletion: false });
  });
  elements.nextButton.addEventListener("click", () => {
    stopPlayback();
    setPhase(state.phaseIndex + 1);
  });
  elements.resetButton.addEventListener("click", () => {
    stopPlayback();
    setPhase(0, { recordCompletion: false });
    showToast("처음 단계로 되돌렸습니다.");
  });
  elements.checkpointOptions.addEventListener("change", (event) => {
    const input = event.target.closest('input[name="checkpointAnswer"]');
    if (!input) return;
    state.checkpointSelection = input.value;
    elements.checkpointSubmit.disabled = false;
  });

  elements.checkpointForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const scenario = getScenario();
    const checkpoint = getLearningConfig(scenario).checkpoint;
    if (state.phaseIndex !== scenario.phases.length - 1 || !isCheckpointValid(checkpoint) || state.checkpointSelection === null) return;
    state.checkpointAttempts += 1;
    state.checkpointResult = state.checkpointSelection === checkpoint.correctOptionId;
    saveCheckpointResult(scenario, state.checkpointResult);
    renderScenarioNavigation();
    renderCheckpoint(scenario);
    showToast(state.checkpointResult ? "정답입니다. 이해도 확인을 완료했습니다." : "해설을 확인한 뒤 다시 도전해 보세요.");
  });

  elements.retryCheckpointButton.addEventListener("click", () => {
    state.checkpointSelection = null;
    state.checkpointResult = null;
    renderCheckpoint(getScenario());
    const firstOption = elements.checkpointOptions.querySelector('input[name="checkpointAnswer"]');
    if (firstOption) firstOption.focus();
  });

  elements.reviewPhaseButton.addEventListener("click", () => {
    const scenario = getScenario();
    const checkpoint = getLearningConfig(scenario).checkpoint;
    const reviewIndex = isCheckpointValid(checkpoint) && Number.isInteger(checkpoint.reviewPhaseIndex) ? checkpoint.reviewPhaseIndex : 2;
    setPhase(reviewIndex, { recordCompletion: false });
    document.querySelector(".primary-grid").scrollIntoView({ behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" });
  });

  window.addEventListener("keydown", (event) => {
    const target = event.target;
    // 입력 필드(체크포인트 라디오·텍스트 등)에서는 방향키 기본 동작을 방해하지 않음.
    // 버튼·링크에 포커스가 있어도 방향키로 단계 이동이 되도록 허용한다.
    const typingField = target.closest && target.closest("input, select, textarea, [contenteditable='true']");
    if (typingField) return;
    if (event.key === "ArrowRight") {
      stopPlayback();
      setPhase(state.phaseIndex + 1);
    } else if (event.key === "ArrowLeft") {
      stopPlayback();
      setPhase(state.phaseIndex - 1, { recordCompletion: false });
    } else if (event.key.toLowerCase() === "r") {
      stopPlayback();
      setPhase(0, { recordCompletion: false });
    }
  });

  window.addEventListener("resize", () => {
    clearTimeout(state.resizeTimer);
    state.resizeTimer = window.setTimeout(() => {
      drawTopologyConnections(getPhase());
      drawTrafficChart(getScenario(), getPhase());
    }, 120);
  });

  render({ recordCompletion: false });

  /* =====================================================================
   * 실습(라이브) 모드 — bridge.py 의 /api/state 를 폴링해 실제 수집 데이터를 표시.
   * 학습 모드(시나리오 재생)와 완전히 분리되어 있으며, 데이터가 없어도
   * 오류 없이 "대기 상태" 로만 표시된다.
   * ===================================================================== */
  (function initLiveMode() {
    const LIVE_ENDPOINT = "/api/state";
    const POLL_MS = 3000;

    const live = {
      learnView: $("learnView"),
      liveView: $("liveView"),
      learnButton: $("modeLearnButton"),
      liveButton: $("modeLiveButton"),
      connBadge: $("liveConnBadge"),
      statusBadge: $("liveStatusBadge"),
      statusEmpty: $("liveStatusEmpty"),
      statusGrid: $("liveStatusGrid"),
      essid: $("liveEssid"),
      bssid: $("liveBssid"),
      channel: $("liveChannel"),
      iface: $("liveInterface"),
      dos: $("liveDos"),
      elapsed: $("liveElapsed"),
      clients: $("liveClients"),
      creds: $("liveCreds"),
      eventsEmpty: $("liveEventsEmpty"),
      eventList: $("liveEventList"),
      eventsCount: $("liveEventsCount"),
      detectEmpty: $("liveDetectEmpty"),
      detectWrap: $("liveDetectWrap"),
      detectBody: $("liveDetectBody"),
      detectMeta: $("liveDetectMeta"),
      updated: $("liveUpdated"),
      flowBadge: $("liveFlowBadge"),
      flowFocus: $("liveFlowFocus"),
      flowIndex: $("liveFlowIndex"),
      flowKicker: $("liveFlowKicker"),
      flowTitle: $("liveFlowTitle"),
      flowDesc: $("liveFlowDesc")
    };

    // 실습 토폴로지 무대(학습과 동일한 렌더 함수를 자체 무대로 재사용)
    const LIVE_TOPO = {
      nodeLayer: $("liveNodeLayer"),
      linkLayer: $("liveLinkLayer"),
      packetLayer: $("livePacketLayer"),
      networkStage: $("liveNetworkStage"),
      idPrefix: "livetopology-"
    };

    // 필수 요소가 없으면(구버전 HTML 등) 조용히 비활성화
    if (!live.liveView || !live.liveButton || !live.learnButton) return;

    let pollTimer = null;

    function escapeHtml(value) {
      return String(value == null ? "" : value)
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    }

    function formatElapsed(sec) {
      const n = Number(sec);
      if (!Number.isFinite(n) || n < 0) return "—";
      const m = Math.floor(n / 60);
      const s = n % 60;
      return m > 0 ? `${m}분 ${s}초` : `${s}초`;
    }

    const EVENT_META = {
      attack_start: { label: "공격 시작", tone: "warning" },
      client_connected: { label: "클라이언트 접속", tone: "warning" },
      credential_captured: { label: "자격증명 탈취", tone: "attack" },
      attack_stop: { label: "공격 종료", tone: "neutral" }
    };

    function eventDetail(ev) {
      const d = ev && ev.data ? ev.data : {};
      switch (ev && ev.type) {
        case "attack_start":
          return `대상 ${escapeHtml(d.essid || "?")} · CH ${escapeHtml(d.channel)} · ${escapeHtml(d.dos_method || "-")}`;
        case "client_connected":
          return `IP ${escapeHtml(d.ip || "?")} · MAC ${escapeHtml(d.mac || "?")}`;
        case "credential_captured":
          return `${escapeHtml(d.credential_type || "cred")}: ${escapeHtml(d.value || "")}`;
        case "attack_stop":
          return `경과 ${escapeHtml(d.elapsed_seconds)}s · 클라이언트 ${escapeHtml(d.connected_clients)} · 자격증명 ${escapeHtml(d.credentials_captured)}`;
        default:
          return "";
      }
    }

    const DETECT_TONE = { "정상": "normal", "의심": "warning", "공격중": "attack" };

    function setConn(stateName, text) {
      live.connBadge.dataset.state = stateName;
      live.connBadge.textContent = text;
    }

    function renderStatus(summary) {
      // summary 가 null(공격 전) 이면 대기 상태만 표시
      if (!summary) {
        live.statusEmpty.hidden = false;
        live.statusGrid.hidden = true;
        live.statusBadge.dataset.state = "idle";
        live.statusBadge.textContent = "대기 중";
        return;
      }
      live.statusEmpty.hidden = true;
      live.statusGrid.hidden = false;
      const running = summary.status === "running";
      live.statusBadge.dataset.state = running ? "running" : "stopped";
      live.statusBadge.textContent = running ? "공격 진행 중" : "종료됨";
      live.essid.textContent = summary.essid || "—";
      live.bssid.textContent = summary.bssid || "—";
      live.channel.textContent = (summary.channel != null && summary.channel !== "") ? summary.channel : "—";
      live.iface.textContent = summary.interface || "—";
      live.dos.textContent = summary.dos_method || "—";
      live.elapsed.textContent = formatElapsed(summary.elapsed_seconds);
      live.clients.textContent = summary.connected_clients != null ? summary.connected_clients : "0";
      live.creds.textContent = summary.credentials_captured != null ? summary.credentials_captured : "0";
    }

    function renderEvents(events) {
      const list = Array.isArray(events) ? events : [];
      live.eventsCount.textContent = `${list.length}건`;
      if (!list.length) {
        live.eventsEmpty.hidden = false;
        live.eventList.hidden = true;
        live.eventList.innerHTML = "";
        return;
      }
      live.eventsEmpty.hidden = true;
      live.eventList.hidden = false;
      // 최신이 위로 오도록 역순 표시
      live.eventList.innerHTML = list.slice().reverse().map((ev) => {
        const meta = EVENT_META[ev && ev.type] || { label: (ev && ev.type) || "event", tone: "neutral" };
        const ts = (ev && ev.timestamp ? String(ev.timestamp).replace("T", " ").replace("Z", "") : "");
        return `<li class="live-event tone-${meta.tone}">
          <span class="live-event-time">${escapeHtml(ts)}</span>
          <span class="live-event-type">${escapeHtml(meta.label)}</span>
          <span class="live-event-detail">${eventDetail(ev)}</span>
        </li>`;
      }).join("");
    }

    function renderDetections(detections) {
      const rows = detections && Array.isArray(detections.ap_table) ? detections.ap_table : [];
      const findings = detections && Array.isArray(detections.findings) ? detections.findings : [];
      if (!rows.length) {
        live.detectEmpty.hidden = false;
        live.detectWrap.hidden = true;
        live.detectBody.innerHTML = "";
        live.detectMeta.textContent = "—";
        return;
      }
      live.detectEmpty.hidden = true;
      live.detectWrap.hidden = false;
      live.detectMeta.textContent = `AP ${rows.length} · 탐지 ${findings.length}`;
      live.detectBody.innerHTML = rows.map((ap) => {
        const tone = DETECT_TONE[ap.status] || "normal";
        const sig = ap.signals || {};
        const flags = [
          sig.S1_zero_width ? "S1" : null,
          sig.S2_twin_bssid ? "S2" : null,
          sig.S3_downgrade ? "S3" : null
        ].filter(Boolean).join(" ") || "—";
        const score = (typeof ap.score === "number") ? ap.score.toFixed(2) : (ap.score || "—");
        return `<tr class="detect-tone-${tone}">
          <td><span class="detect-verdict detect-tone-${tone}">${escapeHtml(ap.status || "?")}</span></td>
          <td>${escapeHtml(ap.ssid || "&lt;hidden&gt;")}</td>
          <td class="mono">${escapeHtml(ap.bssid || "—")}</td>
          <td>${escapeHtml(ap.channel != null ? ap.channel : "—")}</td>
          <td>${escapeHtml(ap.enc || "—")}</td>
          <td>${escapeHtml(score)}</td>
          <td class="mono">${escapeHtml(flags)}</td>
        </tr>`;
      }).join("");
    }

    // 실제 상태로부터 토폴로지 장면을 구성한다.
    // 기본은 정상(클라이언트+진짜 AP)이며, Evil Twin 이 탐지되거나 공격이
    // 진행 중이면 학습 3단계처럼 공격자 노드와 공격 링크가 나타난다.
    function buildFlow(data) {
      const summary = data && data.summary ? data.summary : null;
      const detections = data && data.detections ? data.detections : { findings: [] };
      const events = Array.isArray(data && data.events) ? data.events : [];
      const findings = Array.isArray(detections.findings) ? detections.findings : [];

      const running = !!(summary && summary.status === "running");
      const hasFinding = findings.length > 0;
      const underAttack = hasFinding || running;
      const credsCaptured = (summary && Number(summary.credentials_captured) > 0)
        || events.some((e) => e && e.type === "credential_captured");

      const f0 = findings[0] || {};
      const essid = (summary && summary.essid) || f0.ssid || "대상 AP";
      const channel = (summary && summary.channel != null && summary.channel !== "")
        ? summary.channel : (f0.channel != null ? f0.channel : "?");
      const iface = (summary && summary.interface) || "wlan";
      const suspectBssid = f0.suspect_bssid || (summary && summary.bssid) || "위조 AP";
      const clientEvt = events.slice().reverse().find((e) => e && e.type === "client_connected");
      const clientMac = (clientEvt && clientEvt.data && clientEvt.data.mac) || "클라이언트";

      const client = { id: "client", role: "client", icon: "💻", label: "정상 클라이언트", detail: clientMac };
      const realAp = { id: "real-ap", role: "real-ap", icon: "📡", label: "진짜 AP", detail: `${essid} · CH ${channel}` };
      const attacker = { id: "attacker", role: "attacker", icon: "⚠️", label: "Evil Twin", detail: suspectBssid };
      const sensor = { id: "sensor", role: "sensor", icon: "🔎", label: "WFSAT 센서", detail: iface };

      if (!underAttack) {
        return {
          nodes: [client, realAp],
          phase: {
            states: { client: "normal", "real-ap": "normal" },
            links: [{ from: "real-ap", to: "client", type: "normal", label: "정상 연결" }],
            packet: { from: "real-ap", to: "client", label: "DATA", tone: "normal" }
          },
          badge: "정상 상태", index: "01", kicker: "NORMAL STATE",
          title: "정상 통신 중입니다",
          desc: "아직 Evil Twin 공격이 탐지되지 않았습니다. 공격이 시작되면 이 화면이 자동으로 바뀝니다.",
          focus: "정상 클라이언트와 진짜 AP만 통신하는 평상시 모습입니다."
        };
      }

      return {
        nodes: [client, realAp, attacker, sensor],
        phase: {
          states: {
            client: credsCaptured ? "offline" : "warning",
            "real-ap": "normal",
            attacker: "danger",
            sensor: "defense"
          },
          links: [
            { from: "real-ap", to: "client", type: "inactive", label: "연결 약화" },
            { from: "attacker", to: "client", type: "attack", label: credsCaptured ? "자격증명 탈취" : "위조 AP 유인" },
            { from: "sensor", to: "attacker", type: "warning", label: "공격 탐지" }
          ],
          packet: { from: "attacker", to: "client", label: credsCaptured ? "CRED" : "EVIL TWIN", tone: "attack" }
        },
        badge: credsCaptured ? "자격증명 탈취됨" : "공격 탐지됨",
        index: credsCaptured ? "04" : "03",
        kicker: "EVIL TWIN DETECTED",
        title: credsCaptured ? "가짜 AP가 자격증명을 가로챕니다" : "Evil Twin이 클라이언트를 유인합니다",
        desc: `진짜 AP(${essid})를 사칭한 위조 AP(${suspectBssid})가 탐지되었습니다. 클라이언트가 가짜 AP에 연결되면 트래픽이 공격자를 거쳐 흐릅니다.`,
        focus: credsCaptured
          ? "가짜 AP를 거친 트래픽에서 자격증명이 수집되고 있습니다."
          : "공격자가 진짜 AP인 척 클라이언트를 자기 쪽으로 끌어들이는 중입니다."
      };
    }

    let lastFlowPhase = null;

    function renderFlow(data) {
      const flow = buildFlow(data);
      // 라이브 뷰에는 flow 서술 블록이 없을 수 있으므로 요소가 있을 때만 채운다.
      if (live.flowBadge) live.flowBadge.textContent = flow.badge;
      if (live.flowFocus) live.flowFocus.textContent = flow.focus;
      if (live.flowIndex) live.flowIndex.textContent = flow.index;
      if (live.flowKicker) live.flowKicker.textContent = flow.kicker;
      if (live.flowTitle) live.flowTitle.textContent = flow.title;
      if (live.flowDesc) live.flowDesc.textContent = flow.desc;
      lastFlowPhase = flow.phase;
      renderTopology({ nodes: flow.nodes }, flow.phase, LIVE_TOPO);
    }

    let lastData = null;

    function renderLive(data) {
      lastData = data;
      renderFlow(data);
      renderStatus(data && data.summary ? data.summary : null);
      renderEvents(data ? data.events : []);
      renderDetections(data ? data.detections : null);
      live.updated.textContent = new Date().toLocaleTimeString();
    }

    function showLiveDisconnected(message) {
      setConn("error", message);
      // 연결이 끊겨도 마지막으로 그려진 값은 유지(화면이 비워지지 않도록)
    }

    async function pollLive() {
      // 1) 통신 단계: 여기서 실패해야만 "연결 실패" 로 표시한다.
      let data;
      try {
        const res = await fetch(LIVE_ENDPOINT, { cache: "no-store" });
        if (!res.ok) { showLiveDisconnected(`서버 응답 오류 (${res.status})`); return; }
        data = await res.json();
      } catch (err) {
        showLiveDisconnected("브리지 서버에 연결할 수 없습니다");
        return;
      }
      // 2) 렌더 단계: 연결은 성공했으므로 렌더 오류를 연결 실패로 표시하지 않는다.
      setConn("ok", "연결됨");
      try {
        renderLive(data);
      } catch (err) {
        console.error("renderLive 실패:", err);
      }
    }

    function startLivePolling() {
      stopLivePolling();
      setConn("connecting", "연결 확인 중…");
      pollLive();
      pollTimer = window.setInterval(pollLive, POLL_MS);
    }

    function stopLivePolling() {
      if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
    }

    function setMode(mode) {
      const liveOn = mode === "live";
      if (liveOn) stopPlayback(false); // 시나리오 자동재생이 돌고 있으면 멈춤
      live.learnView.hidden = liveOn;
      live.liveView.hidden = !liveOn;
      live.learnButton.classList.toggle("active", !liveOn);
      live.liveButton.classList.toggle("active", liveOn);
      live.learnButton.setAttribute("aria-pressed", String(!liveOn));
      live.liveButton.setAttribute("aria-pressed", String(liveOn));
      if (liveOn) startLivePolling();
      else stopLivePolling();
    }

    live.learnButton.addEventListener("click", () => setMode("learn"));
    live.liveButton.addEventListener("click", () => setMode("live"));

    // 탭이 백그라운드일 때는 폴링을 멈춰 불필요한 요청을 줄임
    document.addEventListener("visibilitychange", () => {
      if (live.liveView.hidden) return; // 실습 모드가 아닐 때는 무시
      if (document.hidden) stopLivePolling();
      else startLivePolling();
    });

    // 창 크기가 바뀌면 실습 토폴로지의 연결선을 다시 그린다
    let liveResizeTimer = null;
    window.addEventListener("resize", () => {
      if (live.liveView.hidden || !lastFlowPhase) return;
      clearTimeout(liveResizeTimer);
      liveResizeTimer = window.setTimeout(() => drawTopologyConnections(lastFlowPhase, LIVE_TOPO), 140);
    });
  })();
})();
