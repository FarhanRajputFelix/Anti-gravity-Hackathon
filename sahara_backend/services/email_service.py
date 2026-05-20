"""
SAHARA AI — Email Alert Service
Sends HTML crisis alert emails to departments and auto-replies to users.
Uses Gmail SMTP with App Password (no external libs needed).
"""

import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime
from typing import Optional

SAHARA_EMAIL    = os.getenv("SAHARA_EMAIL", "farhanmuhammadbashir@gmail.com")
SAHARA_PASSWORD = os.getenv("SAHARA_EMAIL_PASSWORD", "")   # Gmail App Password

# Department email routing (demo addresses — update for real)
DEPARTMENT_EMAILS = {
    "Police":     "farhanmuhammadbashir@gmail.com",
    "Health":     "farhanmuhammadbashir@gmail.com",
    "Transport":  "farhanmuhammadbashir@gmail.com",
    "Emergency":  "farhanmuhammadbashir@gmail.com",
    "Roads":      "farhanmuhammadbashir@gmail.com",
}

SEVERITY_COLORS = {
    "CRITICAL": "#DC2626",
    "HIGH":     "#EA580C",
    "MEDIUM":   "#D97706",
    "LOW":      "#16A34A",
}


def _smtp_connection():
    server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
    server.login(SAHARA_EMAIL, SAHARA_PASSWORD)
    return server


def _build_alert_html(result: dict, department: Optional[str] = None) -> str:
    crisis_id  = result.get("crisis_id", "N/A")
    crisis_type = result.get("crisis_type", "UNKNOWN").replace("_", " ")
    location   = result.get("location", "Unknown")
    city       = result.get("city", "Unknown")
    severity   = result.get("severity", "UNKNOWN")
    confidence = result.get("confidence", 0)
    verif      = result.get("verification_status", "UNVERIFIED")
    actions    = result.get("action_plan", [])
    sim        = result.get("simulation") or {}
    ts         = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    sev_color = SEVERITY_COLORS.get(severity, "#6B7280")
    dept_section = f"<p><strong>Department:</strong> {department}</p>" if department else ""

    action_rows = ""
    for a in actions[:8]:
        dept_name = a.get("department", "")
        action    = a.get("action", "")
        priority  = a.get("priority", "")
        ticket    = a.get("ticket_id", "")
        eta       = a.get("eta_minutes", "")
        action_rows += f"""
        <tr>
          <td style="padding:8px;border-bottom:1px solid #e5e7eb;">{dept_name}</td>
          <td style="padding:8px;border-bottom:1px solid #e5e7eb;">{action}</td>
          <td style="padding:8px;border-bottom:1px solid #e5e7eb;color:{sev_color};font-weight:bold;">{priority}</td>
          <td style="padding:8px;border-bottom:1px solid #e5e7eb;">{ticket}</td>
          <td style="padding:8px;border-bottom:1px solid #e5e7eb;">{eta} min</td>
        </tr>"""

    alerts_sent    = sim.get("alerts_sent", 0)
    pop_helped     = sim.get("population_helped", 0)
    congestion_b   = sim.get("congestion_level_before", "N/A")
    congestion_a   = sim.get("congestion_level_after", "N/A")
    units_deployed = sim.get("units_deployed", 0)

    return f"""<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;margin:0;padding:20px;">
  <div style="max-width:700px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);">

    <!-- Header -->
    <div style="background:#0f172a;padding:24px 32px;display:flex;align-items:center;">
      <div>
        <h1 style="color:#fff;margin:0;font-size:22px;letter-spacing:1px;">🛡️ SAHARA AI — CRISIS ALERT</h1>
        <p style="color:#94a3b8;margin:4px 0 0;font-size:13px;">Pakistan's Agentic Urban Crisis Response System</p>
      </div>
    </div>

    <!-- Severity Banner -->
    <div style="background:{sev_color};padding:14px 32px;">
      <span style="color:#fff;font-size:18px;font-weight:bold;letter-spacing:2px;">
        ⚠️ SEVERITY: {severity}
      </span>
      <span style="color:rgba(255,255,255,0.85);float:right;font-size:13px;margin-top:3px;">{ts}</span>
    </div>

    <!-- Crisis Details -->
    <div style="padding:28px 32px 0;">
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:6px 0;color:#6b7280;width:160px;">Crisis ID</td>
          <td style="padding:6px 0;font-weight:bold;font-family:monospace;">{crisis_id}</td>
        </tr>
        <tr>
          <td style="padding:6px 0;color:#6b7280;">Crisis Type</td>
          <td style="padding:6px 0;font-weight:bold;">{crisis_type}</td>
        </tr>
        <tr>
          <td style="padding:6px 0;color:#6b7280;">Location</td>
          <td style="padding:6px 0;">{location}, {city}</td>
        </tr>
        <tr>
          <td style="padding:6px 0;color:#6b7280;">Confidence</td>
          <td style="padding:6px 0;">{confidence:.0%} — {verif}</td>
        </tr>
        {dept_section}
      </table>
    </div>

    <!-- Simulation Summary -->
    <div style="margin:24px 32px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:16px;">
      <h3 style="margin:0 0 12px;color:#0f172a;font-size:15px;">📊 Response Simulation</h3>
      <div style="display:flex;gap:24px;flex-wrap:wrap;">
        <div style="text-align:center;min-width:90px;">
          <div style="font-size:24px;font-weight:bold;color:{sev_color};">{alerts_sent:,}</div>
          <div style="font-size:12px;color:#6b7280;">Alerts Sent</div>
        </div>
        <div style="text-align:center;min-width:90px;">
          <div style="font-size:24px;font-weight:bold;color:#2563eb;">{pop_helped:,}</div>
          <div style="font-size:12px;color:#6b7280;">People Helped</div>
        </div>
        <div style="text-align:center;min-width:90px;">
          <div style="font-size:24px;font-weight:bold;color:#7c3aed;">{units_deployed}</div>
          <div style="font-size:12px;color:#6b7280;">Units Deployed</div>
        </div>
        <div style="text-align:center;min-width:90px;">
          <div style="font-size:14px;font-weight:bold;color:#0f172a;">{congestion_b} → {congestion_a}</div>
          <div style="font-size:12px;color:#6b7280;">Congestion</div>
        </div>
      </div>
    </div>

    <!-- Action Plan -->
    <div style="padding:0 32px 28px;">
      <h3 style="margin:0 0 12px;color:#0f172a;font-size:15px;">📋 Action Plan ({len(actions)} Actions)</h3>
      <table style="width:100%;border-collapse:collapse;font-size:13px;">
        <thead>
          <tr style="background:#f1f5f9;">
            <th style="padding:10px 8px;text-align:left;color:#475569;">Department</th>
            <th style="padding:10px 8px;text-align:left;color:#475569;">Action</th>
            <th style="padding:10px 8px;text-align:left;color:#475569;">Priority</th>
            <th style="padding:10px 8px;text-align:left;color:#475569;">Ticket</th>
            <th style="padding:10px 8px;text-align:left;color:#475569;">ETA</th>
          </tr>
        </thead>
        <tbody>{action_rows}</tbody>
      </table>
    </div>

    <!-- Footer -->
    <div style="background:#f1f5f9;padding:16px 32px;text-align:center;">
      <p style="margin:0;font-size:12px;color:#94a3b8;">
        This alert was generated automatically by <strong>SAHARA AI v2.0</strong> using Google Antigravity multi-agent orchestration.<br>
        6 AI agents processed this crisis signal in real time. Do not reply to this email.
      </p>
    </div>

  </div>
</body>
</html>"""


def send_department_alerts(result: dict):
    """Send crisis alert emails to all relevant departments."""
    if not SAHARA_PASSWORD:
        print("[EMAIL] No SAHARA_EMAIL_PASSWORD set — skipping department emails")
        return

    actions = result.get("action_plan", [])
    departments_involved = list({a.get("department") for a in actions if a.get("department")})
    if not departments_involved:
        departments_involved = list(DEPARTMENT_EMAILS.keys())

    crisis_type = result.get("crisis_type", "CRISIS").replace("_", " ")
    city        = result.get("city", "Unknown")
    severity    = result.get("severity", "UNKNOWN")
    crisis_id   = result.get("crisis_id", "N/A")
    subject     = f"[SAHARA AI] ⚠️ {severity} ALERT — {crisis_type} in {city} | {crisis_id}"

    try:
        server = _smtp_connection()
        for dept in departments_involved:
            to_email = DEPARTMENT_EMAILS.get(dept, SAHARA_EMAIL)
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"]    = f"SAHARA AI <{SAHARA_EMAIL}>"
            msg["To"]      = to_email
            html = _build_alert_html(result, department=dept)
            msg.attach(MIMEText(html, "html"))
            server.sendmail(SAHARA_EMAIL, to_email, msg.as_string())
            print(f"[EMAIL] Alert sent to {dept} <{to_email}>")
        server.quit()
    except Exception as e:
        print(f"[EMAIL] Failed to send department alerts: {e}")


def send_user_reply(to_email: str, user_text: str, result: dict):
    """Reply to a user who submitted a crisis report via email."""
    if not SAHARA_PASSWORD:
        print("[EMAIL] No SAHARA_EMAIL_PASSWORD set — skipping user reply")
        return

    crisis_id   = result.get("crisis_id", "N/A")
    severity    = result.get("severity", "UNKNOWN")
    crisis_type = result.get("crisis_type", "UNKNOWN").replace("_", " ")
    city        = result.get("city", "Unknown")
    confidence  = result.get("confidence", 0)
    actions     = result.get("action_plan", [])
    sev_color   = SEVERITY_COLORS.get(severity, "#6B7280")

    action_list = "".join([
        f"<li><strong>{a.get('department')}</strong>: {a.get('action')} (ETA: {a.get('eta_minutes')} min, Ticket: {a.get('ticket_id')})</li>"
        for a in actions[:5]
    ])

    html = f"""<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;padding:20px;">
  <div style="max-width:600px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);">
    <div style="background:#0f172a;padding:20px 28px;">
      <h1 style="color:#fff;margin:0;font-size:20px;">🛡️ SAHARA AI — Report Received</h1>
      <p style="color:#94a3b8;margin:4px 0 0;font-size:12px;">Pakistan's Crisis Intelligence System</p>
    </div>
    <div style="background:{sev_color};padding:12px 28px;">
      <span style="color:#fff;font-weight:bold;font-size:16px;">⚠️ {severity} — {crisis_type} detected in {city}</span>
    </div>
    <div style="padding:24px 28px;">
      <p>Thank you for your report. SAHARA AI has processed it through our 6-agent AI pipeline.</p>

      <table style="width:100%;background:#f8fafc;border-radius:8px;padding:16px;border-collapse:collapse;">
        <tr><td style="color:#6b7280;padding:4px 8px;">Crisis ID</td><td style="font-family:monospace;font-weight:bold;">{crisis_id}</td></tr>
        <tr><td style="color:#6b7280;padding:4px 8px;">Crisis Type</td><td>{crisis_type}</td></tr>
        <tr><td style="color:#6b7280;padding:4px 8px;">Location</td><td>{city}</td></tr>
        <tr><td style="color:#6b7280;padding:4px 8px;">Severity</td><td style="color:{sev_color};font-weight:bold;">{severity}</td></tr>
        <tr><td style="color:#6b7280;padding:4px 8px;">Confidence</td><td>{confidence:.0%}</td></tr>
      </table>

      <h3 style="margin:20px 0 8px;font-size:15px;">🚨 Emergency Response Actions Dispatched:</h3>
      <ul style="padding-left:20px;line-height:2;">{action_list}</ul>

      <p style="margin-top:20px;color:#6b7280;font-size:13px;">
        Your report: <em>"{user_text[:200]}..."</em><br><br>
        Emergency services have been notified. Please call <strong>1122</strong> (Rescue), <strong>115</strong> (Edhi), or <strong>1339</strong> (NDMA) for immediate assistance.
      </p>
    </div>
    <div style="background:#f1f5f9;padding:14px 28px;text-align:center;">
      <p style="margin:0;font-size:11px;color:#94a3b8;">SAHARA AI v2.0 — Powered by Google Antigravity + Gemini AI</p>
    </div>
  </div>
</body>
</html>"""

    try:
        server = _smtp_connection()
        msg = MIMEMultipart("alternative")
        msg["Subject"] = f"[SAHARA AI] Your crisis report has been processed — {crisis_id}"
        msg["From"]    = f"SAHARA AI <{SAHARA_EMAIL}>"
        msg["To"]      = to_email
        msg.attach(MIMEText(html, "html"))
        server.sendmail(SAHARA_EMAIL, to_email, msg.as_string())
        server.quit()
        print(f"[EMAIL] User reply sent to {to_email}")
    except Exception as e:
        print(f"[EMAIL] Failed to send user reply: {e}")
