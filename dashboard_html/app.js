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
    topStatus: $("topStatus"),
    topbarStatus: document.querySelector(".topbar-status"),
    resetButton: $("resetButton"),
    previousButton: $("previousButton"),
    playButton: $("playButton"),
    playIcon: $("playIcon"),
    playLabel: $("playLabel"),
    nextButton: $("nextButton"),
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
    plainExplanation: $("plainExplanation"),
    severityBadge: $("severityBadge"),
    evidenceList: $("evidenceList"),
    technicalExplanation: $("technicalExplanation"),
    packetFields: $("packetFields"),
    defenseName: $("defenseName"),
    defenseDescription: $("defenseDescription"),
    defenseBefore: $("defenseBefore"),
    defenseAfter: $("defenseAfter"),
    progressText: $("progressText"),
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
    historyList: $("historyList"),
    clearHistoryButton: $("clearHistoryButton"),
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

  const phaseTime = ["00:00", "00:06", "00:12", "00:18", "00:24"];
  const historyKey = "wfsat-learning-history-v1";
  const state = {
    scenarioId: scenarios[0].id,
    phaseIndex: 0,
    speed: 1,
    playing: false,
    timer: null,
    toastTimer: null,
    resizeTimer: null
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

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function renderScenarioNavigation() {
    elements.scenarioList.innerHTML = scenarios.map((scenario) => `
      <button
        class="scenario-button"
        type="button"
        data-scenario="${escapeHtml(scenario.id)}"
        aria-current="${scenario.id === state.scenarioId ? "true" : "false"}"
        aria-label="${escapeHtml(scenario.title)} 시나리오 선택"
      >
        <span class="scenario-icon" aria-hidden="true">${scenario.icon}</span>
        <span class="scenario-name">
          <strong>${escapeHtml(scenario.shortName)}</strong>
          <span>${escapeHtml(scenario.english)}</span>
        </span>
        <span class="scenario-arrow" aria-hidden="true">›</span>
      </button>
    `).join("");

    elements.scenarioList.querySelectorAll("[data-scenario]").forEach((button) => {
      button.addEventListener("click", () => selectScenario(button.dataset.scenario));
    });
  }

  function renderHero(scenario) {
    elements.scenarioLayer.textContent = scenario.layer;
    elements.scenarioEnglish.textContent = scenario.english;
    elements.scenarioTitle.textContent = scenario.title;
    elements.scenarioSummary.textContent = scenario.summary;
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
    elements.progressText.textContent = `${state.phaseIndex + 1} / ${scenario.phases.length}`;
    elements.progressFill.style.width = `${(state.phaseIndex / (scenario.phases.length - 1)) * 100}%`;
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

  function renderTopology(scenario, phase) {
    elements.nodeLayer.innerHTML = scenario.nodes.map((node) => {
      const nodeState = phase.states[node.id] || "idle";
      return `
        <button
          type="button"
          id="topology-${escapeHtml(node.id)}"
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

    elements.nodeLayer.querySelectorAll(".topology-node").forEach((node) => {
      node.addEventListener("click", () => showToast(node.getAttribute("aria-label")));
    });

    requestAnimationFrame(() => drawTopologyConnections(phase));
  }

  function getNodeCenter(nodeId) {
    const node = $(`topology-${nodeId}`);
    if (!node) return null;
    const stageRect = elements.networkStage.getBoundingClientRect();
    const nodeRect = node.getBoundingClientRect();
    return {
      x: nodeRect.left - stageRect.left + nodeRect.width / 2,
      y: nodeRect.top - stageRect.top + nodeRect.height / 2
    };
  }

  function drawTopologyConnections(phase) {
    elements.linkLayer.innerHTML = "";
    elements.packetLayer.innerHTML = "";

    phase.links.forEach((connection) => {
      const start = getNodeCenter(connection.from);
      const end = getNodeCenter(connection.to);
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
      elements.linkLayer.appendChild(lineElement);

      const labelElement = document.createElement("span");
      labelElement.className = "link-label";
      labelElement.textContent = connection.label;
      labelElement.style.left = `${start.x + deltaX * 0.5}px`;
      labelElement.style.top = `${start.y + deltaY * 0.5}px`;
      elements.linkLayer.appendChild(labelElement);
    });

    animatePacket(phase.packet);
  }

  function animatePacket(packetData) {
    if (!packetData) return;
    const start = getNodeCenter(packetData.from);
    const end = getNodeCenter(packetData.to);
    if (!start || !end) return;

    const token = document.createElement("span");
    token.className = `packet-token ${packetData.tone || "normal"}`;
    token.textContent = packetData.label;
    token.style.left = "0";
    token.style.top = "0";
    elements.packetLayer.appendChild(token);

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

    elements.chartSummary.textContent = `${scenario.title} ${phase.label}: 정상 기준선 ${scenario.phases[0].rate} 패킷/초, 현재 ${phase.rate} 패킷/초입니다.`;
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

  function saveCompletion(scenario) {
    const history = safeHistoryRead();
    const latest = history[0];
    if (latest && latest.scenarioId === scenario.id && Date.now() - latest.timestamp < 5000) return;
    const entry = {
      scenarioId: scenario.id,
      title: scenario.title,
      icon: scenario.icon,
      timestamp: Date.now(),
      score: "5단계 완료"
    };
    safeHistoryWrite([entry, ...history].slice(0, 6));
    renderHistory();
  }

  function renderHistory() {
    const history = safeHistoryRead();
    if (!history.length) {
      elements.historyList.innerHTML = '<div class="empty-history">아직 완료한 시나리오가 없습니다. 공격 흐름을 5단계까지 재생해 보세요.</div>';
      return;
    }

    elements.historyList.innerHTML = history.slice(0, 6).map((entry) => {
      const date = new Date(entry.timestamp);
      const dateLabel = Number.isNaN(date.getTime()) ? "최근" : new Intl.DateTimeFormat("ko-KR", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }).format(date);
      return `
        <article class="history-card">
          <span aria-hidden="true">${entry.icon || "✓"}</span>
          <div><strong>${escapeHtml(entry.title)}</strong><small>${escapeHtml(dateLabel)}</small></div>
          <span class="history-score">${escapeHtml(entry.score || "완료")}</span>
        </article>
      `;
    }).join("");
  }

  function updatePlaybackUi() {
    const scenario = getScenario();
    elements.playButton.setAttribute("aria-pressed", String(state.playing));
    elements.playIcon.textContent = state.playing ? "Ⅱ" : "▶";
    elements.playLabel.textContent = state.playing ? "일시정지" : state.phaseIndex === scenario.phases.length - 1 ? "처음부터 다시 보기" : "시뮬레이션 시작";
    elements.previousButton.disabled = state.phaseIndex === 0;
    elements.nextButton.disabled = state.phaseIndex === scenario.phases.length - 1;
    elements.topbarStatus.classList.toggle("running", state.playing);
    if (state.playing) elements.topStatus.textContent = "시뮬레이션 재생 중";
    else if (state.phaseIndex === scenario.phases.length - 1) elements.topStatus.textContent = "학습 단계 완료";
    else elements.topStatus.textContent = `${state.phaseIndex + 1}단계 · ${scenario.phases[state.phaseIndex].label}`;
  }

  function render(options = {}) {
    const scenario = getScenario();
    const phase = getPhase();
    renderScenarioNavigation();
    renderHero(scenario);
    renderMetrics(phase);
    renderNarrative(scenario, phase);
    renderTimeline(scenario);
    renderTopology(scenario, phase);
    drawTrafficChart(scenario, phase);
    renderEventLog(scenario);
    renderIdentityList(scenario, phase);
    renderGlossary(scenario);
    renderHistory();
    updatePlaybackUi();

    if (state.phaseIndex === scenario.phases.length - 1 && options.recordCompletion !== false) {
      saveCompletion(scenario);
    }
  }

  function setPhase(index, options = {}) {
    const scenario = getScenario();
    state.phaseIndex = Math.max(0, Math.min(index, scenario.phases.length - 1));
    render(options);
    if (state.phaseIndex === scenario.phases.length - 1 && state.playing) {
      stopPlayback(false);
      showToast(`${scenario.title}의 5단계 학습을 완료했습니다.`);
    }
  }

  function selectScenario(scenarioId) {
    if (!scenarios.some((scenario) => scenario.id === scenarioId)) return;
    stopPlayback(false);
    state.scenarioId = scenarioId;
    state.phaseIndex = 0;
    render({ recordCompletion: false });
    showToast(`${getScenario().title} 시나리오를 불러왔습니다.`);
  }

  function startPlayback() {
    const scenario = getScenario();
    if (state.phaseIndex === scenario.phases.length - 1) state.phaseIndex = 0;
    clearInterval(state.timer);
    state.playing = true;
    updatePlaybackUi();
    render({ recordCompletion: false });
    state.timer = window.setInterval(() => {
      if (state.phaseIndex >= getScenario().phases.length - 1) {
        stopPlayback();
        return;
      }
      setPhase(state.phaseIndex + 1);
    }, 2500 / state.speed);
  }

  function stopPlayback(update = true) {
    clearInterval(state.timer);
    state.timer = null;
    state.playing = false;
    if (update) updatePlaybackUi();
  }

  function togglePlayback() {
    if (state.playing) stopPlayback();
    else startPlayback();
  }

  function updateSpeed(speed) {
    state.speed = speed;
    document.querySelectorAll("[data-speed]").forEach((button) => {
      const active = Number(button.dataset.speed) === speed;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    if (state.playing) startPlayback();
    else drawTopologyConnections(getPhase());
  }

  function showToast(message) {
    clearTimeout(state.toastTimer);
    elements.toast.textContent = message;
    elements.toast.classList.add("visible");
    state.toastTimer = window.setTimeout(() => elements.toast.classList.remove("visible"), 2600);
  }

  elements.playButton.addEventListener("click", togglePlayback);
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
    showToast("시뮬레이션을 처음 단계로 되돌렸습니다.");
  });
  document.querySelectorAll("[data-speed]").forEach((button) => {
    button.addEventListener("click", () => updateSpeed(Number(button.dataset.speed)));
  });
  elements.clearHistoryButton.addEventListener("click", () => {
    safeHistoryWrite([]);
    renderHistory();
    showToast("이 브라우저의 학습 기록을 초기화했습니다.");
  });

  window.addEventListener("keydown", (event) => {
    const target = event.target;
    const interactive = target.closest("button, input, select, textarea, summary, a");
    if (interactive) return;
    if (event.code === "Space") {
      event.preventDefault();
      togglePlayback();
    } else if (event.key === "ArrowRight") {
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
})();
