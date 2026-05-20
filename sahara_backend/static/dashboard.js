/* ═══════════════════════════════════════════════════════
   SAHARA AI — Command Center v2.0
   Real-time SSE pipeline streaming + multi-source input
   ═══════════════════════════════════════════════════════ */

const API = window.location.origin;
let crisisCount = 0;
let timerInterval = null;
let timerStart = 0;

// ─── AGENT PIPELINE DEFINITIONS ───────────────────────
const PIPELINE_DEFS = [
  { step: 1, name: "Signal Ingestion Agent",    purpose: "Parse multilingual signal → structured data", tools: ["language_detector","crisis_classifier","entity_extractor"] },
  { step: 2, name: "Verification Agent",         purpose: "Cross-check APIs → confidence score",         tools: ["mock_weather_api","mock_traffic_api","signal_correlation_engine"] },
  { step: 3, name: "Severity Analysis Agent",    purpose: "Estimate impact → severity level",            tools: ["population_impact_model","road_network_analyzer","impact_modeler"] },
  { step: 4, name: "Response Planning Agent",    purpose: "Generate prioritized action plan",            tools: ["resource_inventory_api","action_template_engine","dept_notification_api"] },
  { step: 5, name: "Execution Simulation Agent", purpose: "Simulate response + before/after state",      tools: ["system_state_snapshot","google_maps_rerouting_api","alert_broadcaster"] },
  { step: 6, name: "Fallback & Recovery Agent",  purpose: "Resilience audit + system health check",      tools: ["system_health_check","resilience_auditor","historical_baseline"] },
];

const SCENARIOS = {
  flood: {
    primary: "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain aur logon ke ghar doob rahe hain. Rescue ki zaroorat hai!",
    srcPrimary: "citizen_report",
    weather: "PMD issues flash flood warning for Rawalpindi/Islamabad — 87.3mm rainfall recorded in last 3 hours. Severe thunderstorm advisory active.",
    traffic: "NHA: Srinagar Highway at 87/100 congestion, 14 incidents reported, G-10 Markaz Road and Murree Road blocked.",
    location: "G-10, Islamabad",
  },
  heat: {
    primary: "Severe heatwave emergency in Karachi. Temperature 48°C. Multiple heat stroke cases near Saddar — hospitals overwhelmed.",
    srcPrimary: "weather_api",
    weather: "KMD extreme heat advisory: feels like 52°C with heat index. Red alert issued. 3 heat-related deaths reported.",
    traffic: "Karachi traffic: M.A. Jinnah Road 72/100 congestion, 8 incidents, hospitals seeing 3x normal intake.",
    location: "Saddar, Karachi",
  },
  accident: {
    primary: "Bada accident hua hai Shahrah-e-Quaid-e-Azam pe. Teen gaariyan takra gayi hain, road completely block hai. Ambulance chahiye!",
    srcPrimary: "social_media",
    weather: "Lahore weather: partly cloudy, 34°C — no weather emergency contributing to accident.",
    traffic: "NHA: Shahrah-e-Quaid-e-Azam completely blocked, 3-vehicle collision, traffic backed up 2km. Rescue 1122 en route.",
    location: "Shahrah-e-Quaid-e-Azam, Lahore",
  },
  fire: {
    primary: "Factory mein aag lag gayi hai, karkhanay ke andar workers phanse hain. Bohot bada dhuan aa raha hai. Fire Brigade ko call karo!",
    srcPrimary: "citizen_report",
    weather: "PMD: wind speed 45km/h from SW — fire risk HIGH, smoke spreading toward residential areas.",
    traffic: "Traffic blocked on Industrial Zone road, emergency vehicles queued. Area cordoned by police.",
    location: "SITE Industrial Area, Karachi",
  },
};

// ─── INIT ──────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  initPipeline();
  initTicker();
  loadLogs();
  checkGemini();
  loadLiveSignals();
  startFeedStream();
});

// ─── LIVE SIGNAL FEED ─────────────────────────────────
const CRISIS_ICONS = {
  FLOODING: "🌊", HEATWAVE: "🌡", TRAFFIC_ACCIDENT: "🚗",
  INFRASTRUCTURE: "⚡", FIRE: "🔥", EARTHQUAKE: "🌍", default: "⚠"
};
const CRISIS_COLORS = {
  FLOODING: "var(--blue)", HEATWAVE: "var(--orange)", TRAFFIC_ACCIDENT: "var(--orange)",
  INFRASTRUCTURE: "var(--cyan)", FIRE: "var(--red)", EARTHQUAKE: "var(--red)", default: "var(--text-lo)"
};

let _tickerLiveItems = [];       // real signals loaded from API
let _feedStreamSource = null;    // SSE connection for real-time feed

async function loadLiveSignals() {
  try {
    const res = await fetch(`${API}/api/feed`);
    const data = await res.json();
    const signals = data.signals || [];
    if (!signals.length) return;

    _tickerLiveItems = signals.map(s => ({
      text: `${CRISIS_ICONS[s.crisis_type] || "⚠"} ${s.city || "Pakistan"} — ${(s.text || "").slice(0, 90)}`,
      color: CRISIS_COLORS[s.crisis_type] || CRISIS_COLORS.default,
      raw: s,
    }));

    // Refresh ticker with real data
    buildTicker(_tickerLiveItems);

    // Populate live feed panel if present
    renderFeedPanel(signals, data.source);
  } catch (_) {
    // Leave static ticker on failure
  }
}

function buildTicker(items) {
  const container = document.getElementById("tickerItems");
  if (!container || !items.length) return;
  const doubled = [...items, ...items];
  container.innerHTML = doubled.map(item =>
    `<span class="ticker-item"><span class="ticker-dot" style="background:${item.color}"></span>${escHtml(item.text)}</span>`
  ).join("");
}

function renderFeedPanel(signals, source) {
  const panel = document.getElementById("liveFeedPanel");
  if (!panel) return;
  panel.classList.remove("hidden");
  const sourceTag = source === "live" ? '<span class="gemini-tag">LIVE</span>' : '<span class="hbadge hbadge-offline">CACHED</span>';
  const list = document.getElementById("liveFeedList");
  if (!list) return;
  const topSignals = signals.slice(0, 10);
  list.innerHTML = topSignals.length ? topSignals.map((s, i) => `
    <div class="feed-item" data-signal-index="${i}">
      <div class="feed-icon">${CRISIS_ICONS[s.crisis_type] || "⚠"}</div>
      <div class="feed-body">
        <div class="feed-city">${escHtml(s.city || "Pakistan")}</div>
        <div class="feed-text">${escHtml((s.text || "").slice(0, 120))}</div>
        ${s.gemini_summary ? `<div class="feed-summary">✦ ${escHtml(s.gemini_summary)}</div>` : ""}
      </div>
      <div class="feed-meta">
        <span class="feed-type" style="color:${CRISIS_COLORS[s.crisis_type] || "var(--text-lo)"}">${s.crisis_type || "?"}</span>
        ${s.confidence ? `<span class="feed-conf">${(s.confidence * 100).toFixed(0)}%</span>` : ""}
      </div>
    </div>
  `).join("") : '<p class="muted-text">Waiting for signals…</p>';

  // Attach click handlers after render (avoids inline JS escaping issues)
  list.querySelectorAll(".feed-item[data-signal-index]").forEach(el => {
    const idx = parseInt(el.dataset.signalIndex);
    el.addEventListener("click", () => injectSignal(topSignals[idx].text));
  });
}

function injectSignal(text) {
  const el = document.getElementById("sigPrimary");
  if (el) el.value = text;
}

function startFeedStream() {
  if (_feedStreamSource) { _feedStreamSource.close(); }
  try {
    _feedStreamSource = new EventSource(`${API}/api/feed/stream`);
    _feedStreamSource.onmessage = (ev) => {
      try {
        const sig = JSON.parse(ev.data);
        if (sig.type === "heartbeat") return;
        // Prepend to live items and refresh ticker
        const item = {
          text: `${CRISIS_ICONS[sig.crisis_type] || "⚠"} ${sig.city || "Pakistan"} — ${(sig.text || "").slice(0, 90)}`,
          color: CRISIS_COLORS[sig.crisis_type] || CRISIS_COLORS.default,
          raw: sig,
        };
        _tickerLiveItems.unshift(item);
        if (_tickerLiveItems.length > 20) _tickerLiveItems.length = 20;
        buildTicker(_tickerLiveItems);
        // Update feed panel
        loadLiveSignals();
      } catch (_) {}
    };
    _feedStreamSource.onerror = () => {
      // Silently reconnect after 15s
      setTimeout(startFeedStream, 15000);
    };
  } catch (_) {}
}

// ─── INIT PIPELINE STEPS ──────────────────────────────
function initPipeline() {
  const container = document.getElementById("pipelineSteps");
  container.innerHTML = "";
  PIPELINE_DEFS.forEach(def => {
    const el = document.createElement("div");
    el.className = "pipe-step pending";
    el.id = `step-${def.step}`;
    el.innerHTML = `
      <div class="pipe-index">${def.step}</div>
      <div class="pipe-body">
        <div class="pipe-name">${def.name}</div>
        <div class="pipe-purpose">${def.purpose}</div>
        <div class="pipe-tools">
          ${def.tools.map(t => `<span class="tool-chip">${t}</span>`).join("")}
        </div>
        <div class="pipe-details" id="details-${def.step}">
          <div class="pipe-confidence-row">
            <span style="font-size:10px;color:var(--text-lo)">Confidence:</span>
            <div class="conf-bar-track"><div class="conf-bar-fill" id="conf-${def.step}" style="width:0;background:var(--blue)"></div></div>
            <span class="conf-val" id="confval-${def.step}">–</span>
          </div>
          <div class="pipe-decision" id="decision-${def.step}"></div>
          <div class="pipe-reasoning" id="reasoning-${def.step}"></div>
          <div class="pipe-handoff" id="handoff-${def.step}" style="display:none"></div>
        </div>
      </div>
      <span class="pipe-status status-pending" id="status-${def.step}">PENDING</span>
    `;
    el.addEventListener("click", () => el.classList.toggle("expanded"));
    container.appendChild(el);
  });
}

// ─── LIVE TICKER ──────────────────────────────────────
// Static fallback items — replaced by real signals once /api/feed loads
const TICKER_ITEMS_STATIC = [
  { text: "⚠ SAHARA AI monitoring active — fetching live Pakistani news…", color: "var(--blue)" },
  { text: "📡 Connecting to Dawn, Geo TV, ARY, Express Tribune RSS feeds", color: "var(--cyan)" },
  { text: "🌡 OpenWeatherMap weather alerts scanning 7 cities", color: "var(--orange)" },
  { text: "✦ Gemini AI crisis classification engine online", color: "var(--green)" },
];

function initTicker() {
  // Start with static until live data arrives
  buildTicker(TICKER_ITEMS_STATIC);
}

// ─── CHECK GEMINI + ADK ────────────────────────────────
async function checkGemini() {
  try {
    const res = await fetch(`${API}/api/workflow/template`);
    const data = await res.json();
    const badge = document.getElementById("geminiStatus");
    if (data.gemini_enabled) {
      badge.textContent = "⬡ GEMINI: ACTIVE";
      badge.classList.add("hbadge-gemini");
    } else {
      badge.textContent = "⬡ GEMINI: RULE-BASED";
      badge.classList.add("hbadge-offline");
    }
  } catch (_) {}

  // Check Google ADK status
  try {
    const adkRes = await fetch(`${API}/api/adk/status`);
    const adkData = await adkRes.json();
    const adkBadge = document.getElementById("adkStatus");
    if (adkData.adk_ready && adkData.gemini_api_configured) {
      adkBadge.textContent = "▲ ADK: LIVE";
      adkBadge.classList.add("hbadge-adk");
    } else if (adkData.adk_ready) {
      adkBadge.textContent = "▲ ADK: READY";
      adkBadge.classList.add("hbadge-gemini");
    } else {
      adkBadge.textContent = "▲ ADK: OFFLINE";
      adkBadge.classList.add("hbadge-offline");
    }
  } catch (_) {
    const adkBadge = document.getElementById("adkStatus");
    if (adkBadge) { adkBadge.textContent = "▲ ADK: OFFLINE"; adkBadge.classList.add("hbadge-offline"); }
  }
}

// ─── LOAD SCENARIO ────────────────────────────────────
function loadScenario(key) {
  const s = SCENARIOS[key];
  if (!s) return;
  document.getElementById("sigPrimary").value  = s.primary;
  document.getElementById("srcPrimary").value  = s.srcPrimary;
  document.getElementById("sigWeather").value  = s.weather;
  document.getElementById("sigTraffic").value  = s.traffic;
  document.getElementById("locationHint").value = s.location;
}

// ─── RUN ANALYSIS (SSE streaming) ─────────────────────
async function runAnalysis() {
  const text     = document.getElementById("sigPrimary").value.trim();
  const source   = document.getElementById("srcPrimary").value;
  const location = document.getElementById("locationHint").value.trim();
  if (!text) { alert("Enter a crisis signal first."); return; }

  prepareUI();

  const params = new URLSearchParams({ text, source });
  if (location) params.append("location_hint", location);
  const url = `${API}/api/analyze/stream?${params.toString()}`;

  const evtSource = new EventSource(url);

  evtSource.onmessage = (ev) => {
    try {
      const event = JSON.parse(ev.data);
      handleSSEEvent(event);
      if (event.type === "complete" || event.type === "error") {
        evtSource.close();
        finalizeUI();
      }
    } catch (e) {
      console.error("SSE parse error:", e);
    }
  };

  evtSource.onerror = () => {
    evtSource.close();
    finalizeUI();
    showError("SSE connection lost — falling back to standard analysis.");
    runAnalysisFallback(text, source, location);
  };
}

// Fallback: plain POST if SSE fails
async function runAnalysisFallback(text, source, location) {
  try {
    const res = await fetch(`${API}/api/analyze`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, source, location_hint: location || null }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const result = await res.json();
    simulatePipelineAnimation(result);
    renderResult(result);
  } catch (e) {
    showError("Analysis failed: " + e.message);
  } finally {
    finalizeUI();
  }
}

// ─── MULTI-SOURCE ANALYSIS ────────────────────────────
async function runMultiSource() {
  const primary = document.getElementById("sigPrimary").value.trim();
  const weather = document.getElementById("sigWeather").value.trim();
  const traffic = document.getElementById("sigTraffic").value.trim();
  const location = document.getElementById("locationHint").value.trim();
  if (!primary) { alert("Enter at least the primary signal."); return; }

  prepareUI();
  document.getElementById("analyzeBtnText").innerHTML = '<span class="spinner"></span>Multi-Source…';

  const signals = [{ text: primary, source: document.getElementById("srcPrimary").value, location_hint: location || null }];
  if (weather) signals.push({ text: weather, source: "weather_api", location_hint: location || null });
  if (traffic) signals.push({ text: traffic, source: "traffic_api", location_hint: location || null });

  try {
    const res = await fetch(`${API}/api/analyze/multi`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(signals),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const result = await res.json();
    simulatePipelineAnimation(result);
    renderResult(result);
    loadLogs();
  } catch (e) {
    showError("Multi-source analysis failed: " + e.message);
  } finally {
    finalizeUI();
  }
}

// ─── UI STATE ─────────────────────────────────────────
function prepareUI() {
  const btn = document.getElementById("analyzeBtn");
  btn.disabled = true;
  btn.classList.add("running");
  document.getElementById("analyzeBtnText").innerHTML = '<span class="spinner"></span>Analyzing…';

  initPipeline();
  document.getElementById("pipelineCrisisId").textContent = "Processing...";
  document.getElementById("workflowGraph").innerHTML = "";

  // Reset results
  document.getElementById("crisisCard").classList.add("hidden");
  document.getElementById("beforeAfterPanel").classList.add("hidden");
  document.getElementById("actionPlanPanel").classList.add("hidden");
  document.getElementById("execLogsPanel").classList.add("hidden");
  document.getElementById("ticketsPanel").classList.add("hidden");

  // Start timer
  timerStart = Date.now();
  clearInterval(timerInterval);
  timerInterval = setInterval(() => {
    document.getElementById("pipelineTimer").textContent = (Date.now() - timerStart) + "ms";
  }, 50);
}

function finalizeUI() {
  const btn = document.getElementById("analyzeBtn");
  btn.disabled = false;
  btn.classList.remove("running");
  document.getElementById("analyzeBtnText").textContent = "⚡ Analyze Signal";
  clearInterval(timerInterval);
  loadLogs();
}

// ─── SSE EVENT HANDLER ────────────────────────────────
function handleSSEEvent(event) {
  switch (event.type) {
    case "started":
      document.getElementById("pipelineCrisisId").textContent = event.crisis_id || "–";
      if (event.gemini_enabled) {
        const badge = document.getElementById("geminiStatus");
        badge.textContent = "⬡ GEMINI: ACTIVE";
        badge.className = "hbadge hbadge-gemini";
      }
      break;

    case "agent_start":
      setStepRunning(event.step);
      break;

    case "agent_complete":
      setStepComplete(event);
      break;

    case "fallback_triggered":
      // Mark step 3 as fallback
      setStepFallback(3);
      break;

    case "complete":
      renderResult(event.result);
      break;

    case "error":
      showError("Pipeline error: " + (event.message || "Unknown"));
      break;
  }
}

// Map orchestrator step numbers (1-7) to UI step numbers (1-6)
// Orchestrator: 1=Ingestion,2=Verify,3=Fallback(conditional),4=Severity,5=Plan,6=Sim,7=FinalAudit
// UI:           1=Ingestion,2=Verify,3=Severity,4=Plan,5=Sim,6=FinalAudit
const STEP_MAP = { 1: 1, 2: 2, 3: 6, 4: 3, 5: 4, 6: 5, 7: 6 };

// ─── PIPELINE STEP STATE ──────────────────────────────
function setStepRunning(rawStep) {
  const step = STEP_MAP[rawStep] || rawStep;
  const el = document.getElementById(`step-${step}`);
  if (!el) return;
  el.className = "pipe-step running";
  el.querySelector(`#status-${step}`).className = "pipe-status status-running";
  el.querySelector(`#status-${step}`).textContent = "RUNNING";
}

function setStepComplete(event) {
  const rawStep = event.step || guessStepFromName(event.agent_name);
  const step = STEP_MAP[rawStep] || rawStep;
  const el = document.getElementById(`step-${step}`);
  if (!el) return;

  const isFallback = event.fallback_triggered;
  el.className = `pipe-step ${isFallback ? "fallback" : "complete"}`;
  const statusEl = el.querySelector(`[id^="status-"]`);
  if (statusEl) { statusEl.className = `pipe-status ${isFallback ? "status-fallback" : "status-complete"}`; statusEl.textContent = isFallback ? "FALLBACK" : "COMPLETE"; }

  // Confidence bar
  const conf = (event.confidence || 0) * 100;
  const confColor = conf >= 75 ? "var(--green)" : conf >= 50 ? "var(--orange)" : "var(--red)";
  const barEl = el.querySelector(".conf-bar-fill");
  const valEl = el.querySelector(".conf-val");
  if (barEl) { barEl.style.width = conf + "%"; barEl.style.background = confColor; }
  if (valEl) valEl.textContent = conf.toFixed(0) + "%";

  // Decision
  const decEl = el.querySelector(".pipe-decision");
  if (decEl && event.decision) decEl.textContent = event.decision;

  // Gemini tag
  if (event.gemini_enhanced) {
    const nameEl = el.querySelector(".pipe-name");
    if (nameEl && !nameEl.querySelector(".gemini-tag")) {
      nameEl.insertAdjacentHTML("beforeend", ' <span class="gemini-tag">✦ GEMINI</span>');
    }
  }

  // Reasoning steps (top 3)
  const reasonEl = el.querySelector(".pipe-reasoning");
  if (reasonEl && event.reasoning_steps && event.reasoning_steps.length) {
    const rSteps = event.reasoning_steps.slice(0, 3);
    reasonEl.innerHTML = rSteps.map(s =>
      `<div class="reasoning-item"><span class="reasoning-dot"></span><span>${escHtml(s)}</span></div>`
    ).join("");
  }

  // Handoff message
  if (event.handoff) {
    const hEl = el.querySelector(".pipe-handoff");
    if (hEl) { hEl.style.display = "block"; hEl.textContent = "→ " + event.handoff; }
  }

  // Show details by default for completed steps
  el.querySelector(".pipe-details").style.display = "flex";
}

function setStepFallback(rawStep) {
  const step = STEP_MAP[rawStep] || rawStep;
  const el = document.getElementById(`step-${step}`);
  if (!el) return;
  el.className = "pipe-step fallback";
  const statusEl = el.querySelector(`#status-${step}`);
  if (statusEl) { statusEl.className = "pipe-status status-fallback"; statusEl.textContent = "FALLBACK"; }
}

function guessStepFromName(name) {
  if (!name) return 1;
  const n = name.toLowerCase();
  if (n.includes("ingestion"))  return 1;
  if (n.includes("verification")) return 2;
  if (n.includes("severity"))   return 3;
  if (n.includes("planning"))   return 4;
  if (n.includes("simulation")) return 5;
  if (n.includes("fallback"))   return 6;
  return 1;
}

// ─── SIMULATE PIPELINE (for fallback non-SSE) ─────────
function simulatePipelineAnimation(result) {
  const traces = result.agent_traces || [];
  traces.forEach((trace, i) => {
    setTimeout(() => {
      setStepRunning(i + 1);
      setTimeout(() => setStepComplete({
        step: i + 1,
        agent_name: trace.agent_name,
        confidence: trace.confidence,
        decision: trace.decision,
        reasoning_steps: trace.reasoning_steps,
        tool_calls: (trace.tool_calls || []).map(t => t.tool_name || t),
        fallback_triggered: trace.fallback_triggered,
        gemini_enhanced: trace.gemini_enhanced,
        handoff: "",
      }), 300);
    }, i * 400);
  });
}

// ─── RENDER FULL RESULT ───────────────────────────────
function renderResult(r) {
  if (!r) return;

  // Crisis card
  const ccEl = document.getElementById("crisisCard");
  ccEl.classList.remove("hidden");
  document.getElementById("ccType").textContent     = r.crisis_type || "–";
  document.getElementById("ccLocation").textContent = `${r.location} · ${r.city}`;
  document.getElementById("ccSeverity").textContent = r.severity || "–";
  document.getElementById("ccSeverity").className   = `sev-badge sev-${r.severity}`;
  document.getElementById("ccVerification").textContent = r.verification_status || "–";
  document.getElementById("ccVerification").className   = `ver-badge ver-${r.verification_status}`;
  document.getElementById("mConf").textContent    = Math.round((r.confidence || 0) * 100) + "%";
  document.getElementById("mAgents").textContent  = (r.agent_traces || []).length;
  document.getElementById("mActions").textContent = (r.action_plan || []).length;
  document.getElementById("mTime").textContent    = r.total_execution_time_ms || 0;

  // Before/After simulation
  const sim = r.simulation;
  if (sim) {
    const baEl = document.getElementById("beforeAfterPanel");
    baEl.classList.remove("hidden");
    document.getElementById("baCongBefore").textContent = sim.congestion_level_before + "/100";
    document.getElementById("baCongAfter").textContent  = sim.congestion_level_after + "/100";
    document.getElementById("baUnits").textContent  = sim.emergency_units_dispatched || 0;
    document.getElementById("baAlerts").textContent = (sim.alerts_sent || 0).toLocaleString();
    document.getElementById("baHelped").textContent = (sim.population_helped || 0).toLocaleString();
    document.getElementById("baResponse").textContent = sim.response_time_minutes || "–";

    const reduction = sim.congestion_level_before - sim.congestion_level_after;
    const pct = ((reduction / sim.congestion_level_before) * 100).toFixed(0);
    document.getElementById("baImprovement").textContent = `↓ ${reduction} pts (${pct}% congestion reduction)`;

    setTimeout(() => {
      document.getElementById("barBefore").style.width = sim.congestion_level_before + "%";
      document.getElementById("barAfter").style.width  = sim.congestion_level_after + "%";
      document.getElementById("barBeforeVal").textContent = sim.congestion_level_before;
      document.getElementById("barAfterVal").textContent  = sim.congestion_level_after;
    }, 200);

    // Execution logs
    if (sim.execution_logs && sim.execution_logs.length) {
      const logsEl = document.getElementById("execLogsPanel");
      logsEl.classList.remove("hidden");
      const listEl = document.getElementById("execLogList");
      listEl.innerHTML = "";
      sim.execution_logs.forEach((line, i) => {
        setTimeout(() => {
          const div = document.createElement("div");
          div.className = "log-line " + (line.includes("✅") ? "success" : line.includes("📊") ? "metric" : "info");
          div.textContent = line;
          listEl.appendChild(div);
          listEl.scrollTop = listEl.scrollHeight;
        }, i * 120);
      });
    }

    // Emergency tickets
    if (sim.emergency_tickets && sim.emergency_tickets.length) {
      const tEl = document.getElementById("ticketsPanel");
      tEl.classList.remove("hidden");
      document.getElementById("ticketList").innerHTML = sim.emergency_tickets.map(t => {
        const cls = t.startsWith("DISP") ? "disp" : t.startsWith("RTE") ? "rte" : t.startsWith("MED") ? "med" : "alt";
        return `<span class="ticket-chip ${cls}">${t}</span>`;
      }).join("");
    }
  }

  // Action plan
  if (r.action_plan && r.action_plan.length) {
    const apEl = document.getElementById("actionPlanPanel");
    apEl.classList.remove("hidden");
    document.getElementById("actionList").innerHTML = r.action_plan.map(a => `
      <div class="action-item">
        <div class="action-p">P${a.priority}</div>
        <div class="action-body">
          <div class="action-dept">${escHtml(a.responsible_department)}</div>
          <div class="action-desc">${escHtml(a.description)}</div>
          <div class="action-impact">▸ ${escHtml(a.expected_impact)}</div>
        </div>
        <span class="action-status status-${a.status}">${a.status}</span>
      </div>
    `).join("");
  }

  // Workflow graph
  if (r.orchestration_workflow && r.orchestration_workflow.length) {
    const wg = document.getElementById("workflowGraph");
    wg.innerHTML = "";
    r.orchestration_workflow.forEach((step, i) => {
      setTimeout(() => {
        const el = document.createElement("div");
        el.className = `wf-step ${step.gemini_used ? "gemini" : ""}`;
        el.innerHTML = `
          <span class="wf-agent">Step ${step.step}: ${step.agent_name}</span>
          ${step.gemini_used ? '<span class="wf-badge">✦ GEMINI</span>' : ""}
          <span class="wf-tools">${(step.tool_calls || []).join(", ")}</span>
        `;
        wg.appendChild(el);
      }, i * 80);
    });
  }

  // Update header count
  crisisCount++;
  document.getElementById("crisisCount").textContent = crisisCount + " CRISES";
}

// ─── LOAD LOGS ────────────────────────────────────────
async function loadLogs() {
  try {
    const res = await fetch(`${API}/api/logs`);
    const data = await res.json();
    const container = document.getElementById("logsContainer");
    const logs = (data.logs || []).slice(-8).reverse();
    if (!logs.length) { container.innerHTML = '<p class="muted-text">No analyses yet.</p>'; return; }

    container.innerHTML = logs.map(log => `
      <div class="log-item">
        <span class="log-type">${log.crisis_type || "?"}</span>
        <span class="log-city">${log.city || "?"}</span>
        <span class="sev-badge badge-sev sev-${log.severity || "MEDIUM"}">${log.severity || "?"}</span>
        ${log.gemini_enhanced ? '<span class="gemini-tag">✦ G</span>' : ""}
      </div>
    `).join("");
  } catch (_) {}
}

// ─── UTILS ────────────────────────────────────────────
function showError(msg) {
  const container = document.getElementById("pipelineSteps");
  const errEl = document.createElement("div");
  errEl.style.cssText = "padding:.75rem;border:1px solid var(--red);border-radius:8px;color:var(--red);font-size:12px;background:var(--red-dim);";
  errEl.textContent = "⚠ " + msg;
  container.prepend(errEl);
}

function escHtml(str) {
  const d = document.createElement("div");
  d.textContent = str || "";
  return d.innerHTML;
}
