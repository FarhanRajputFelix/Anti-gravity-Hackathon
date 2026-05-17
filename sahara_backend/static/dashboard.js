/* SAHARA AI Command Center — Dashboard Logic */

const API = window.location.origin;

const SCENARIOS = {
    islamabad: { text: "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain", source: "citizen_report", location_hint: "G-10, Islamabad" },
    karachi: { text: "Extreme heat in Clifton area, multiple heatstroke cases reported", source: "hospital_report", location_hint: "Clifton, Karachi" },
    lahore: { text: "Major accident on Motorway M-2, traffic blocked both sides", source: "traffic_alert", location_hint: "M-2 Motorway, Lahore" },
};

// ---- INIT ----
document.addEventListener("DOMContentLoaded", () => {
    loadPipeline();
    loadLogs();
});

// ---- PIPELINE VISUALIZATION ----
async function loadPipeline() {
    try {
        const res = await fetch(`${API}/api/workflow/template`);
        const data = await res.json();

        // Update Gemini status badge
        const badge = document.getElementById("geminiStatus");
        if (data.gemini_enabled) {
            badge.textContent = "GEMINI: ACTIVE";
            badge.className = "badge badge-gemini";
        } else {
            badge.textContent = "GEMINI: OFFLINE";
            badge.className = "badge badge-offline";
        }

        const container = document.getElementById("pipelineContainer");
        container.innerHTML = "";
        data.pipeline.forEach((step, i) => {
            if (i > 0) {
                const conn = document.createElement("div");
                conn.className = "pipe-connector";
                container.appendChild(conn);
            }
            const el = document.createElement("div");
            el.className = "pipe-step";
            el.id = `pipe-step-${step.step}`;
            el.innerHTML = `
                <div class="pipe-dot"></div>
                <div>
                    <div class="pipe-name">${step.agent}</div>
                    <div class="pipe-tools">${step.tools.join(" | ")}</div>
                </div>
            `;
            container.appendChild(el);
        });
    } catch (e) {
        console.error("Pipeline load failed:", e);
    }
}

// ---- LOAD SCENARIO ----
function loadScenario(key) {
    const s = SCENARIOS[key];
    if (s) {
        document.getElementById("crisisInput").value = s.text;
    }
}

// ---- RUN ANALYSIS ----
async function runAnalysis() {
    const text = document.getElementById("crisisInput").value.trim();
    if (!text) return;

    const btn = document.getElementById("analyzeBtn");
    btn.disabled = true;
    btn.textContent = "Analyzing...";

    // Reset pipeline visual
    document.querySelectorAll(".pipe-step").forEach(el => {
        el.classList.remove("active", "complete");
    });

    // Find matching scenario for location_hint
    let locationHint = null;
    for (const [_, s] of Object.entries(SCENARIOS)) {
        if (text.includes(s.text.substring(0, 10))) {
            locationHint = s.location_hint;
            break;
        }
    }

    try {
        // Animate pipeline steps
        const steps = document.querySelectorAll(".pipe-step");
        let stepIndex = 0;
        const animInterval = setInterval(() => {
            if (stepIndex < steps.length) {
                if (stepIndex > 0) steps[stepIndex - 1].classList.replace("active", "complete");
                steps[stepIndex].classList.add("active");
                stepIndex++;
            }
        }, 300);

        const res = await fetch(`${API}/api/analyze`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text, source: "web_dashboard", location_hint: locationHint }),
        });

        clearInterval(animInterval);
        steps.forEach(s => { s.classList.remove("active"); s.classList.add("complete"); });

        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const result = await res.json();

        showResult(result);
        showTraces(result.agent_traces || []);
        showWorkflow(result.orchestration_workflow || []);
        loadLogs();
    } catch (e) {
        alert("Analysis failed: " + e.message);
    } finally {
        btn.disabled = false;
        btn.textContent = "Analyze Signal";
    }
}

// ---- SHOW RESULT ----
function showResult(r) {
    document.getElementById("resultPanel").classList.remove("hidden");
    document.getElementById("resultTitle").textContent = `${r.crisis_type} in ${r.city}`;

    const sevBadge = document.getElementById("resultSeverity");
    sevBadge.textContent = r.severity;
    sevBadge.className = `badge badge-severity-${r.severity}`;

    document.getElementById("mConfidence").textContent = `${Math.round(r.confidence * 100)}%`;
    document.getElementById("mAgents").textContent = (r.agent_traces || []).length;
    document.getElementById("mActions").textContent = (r.action_plan || []).length;
    document.getElementById("mTime").textContent = r.total_execution_time_ms;
}

// ---- SHOW WORKFLOW ----
function showWorkflow(workflow) {
    const container = document.getElementById("workflowGraph");
    container.innerHTML = "";
    workflow.forEach(step => {
        const el = document.createElement("div");
        el.className = `wf-step fade-in ${step.gemini_used ? "gemini" : ""}`;
        el.innerHTML = `
            <span class="wf-agent">Step ${step.step}: ${step.agent_name}</span>
            ${step.gemini_used ? '<span class="wf-badge">GEMINI</span>' : ""}
            <span class="wf-tools">${(step.tool_calls || []).join(", ")}</span>
        `;
        container.appendChild(el);
    });
}

// ---- SHOW TRACES ----
function showTraces(traces) {
    const container = document.getElementById("traceContainer");
    container.innerHTML = "";
    traces.forEach(t => {
        const card = document.createElement("div");
        card.className = `trace-card fade-in ${t.gemini_enhanced ? "gemini-trace" : ""}`;
        const reasoning = (t.reasoning_steps || []).join("\n");
        card.innerHTML = `
            <div class="trace-agent">
                <span>[${t.agent_index}] ${t.agent_name} ${t.gemini_enhanced ? "&#x2728;" : ""}</span>
                <span class="trace-conf">${Math.round(t.confidence * 100)}%</span>
            </div>
            <div class="trace-reasoning">${escapeHtml(reasoning)}</div>
        `;
        container.appendChild(card);
    });
}

// ---- LOAD LOGS ----
async function loadLogs() {
    try {
        const res = await fetch(`${API}/api/logs`);
        const data = await res.json();
        const container = document.getElementById("logsContainer");
        container.innerHTML = "";

        if (!data.logs || data.logs.length === 0) {
            container.innerHTML = '<p class="muted">No analyses yet.</p>';
            return;
        }
        data.logs.slice(-10).reverse().forEach(log => {
            const el = document.createElement("div");
            el.className = "log-card fade-in";
            el.innerHTML = `
                <span class="log-type">${log.crisis_type || "?"}</span>
                <span class="log-city">${log.city || "?"}</span>
                <span class="badge badge-severity-${log.severity || "MEDIUM"}">${log.severity || "?"}</span>
            `;
            container.appendChild(el);
        });
    } catch (_) {}
}

// ---- UTILS ----
function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
}
