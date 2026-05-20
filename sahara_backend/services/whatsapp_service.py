"""
SAHARA AI — WhatsApp Alert Service
Uses Twilio WhatsApp Sandbox (free trial, no business approval needed).

SETUP (5 minutes):
  1. Sign up at https://www.twilio.com/try-twilio (free, no credit card for sandbox)
  2. Go to Messaging > Try it out > Send a WhatsApp message
  3. Note your sandbox number (usually +1 415 523 8886) and join code (e.g. "join silver-fox")
  4. From the target phone (03250909907), send the join code to the sandbox number on WhatsApp
  5. Copy Account SID and Auth Token from twilio.com/console
  6. Add to .env:
       TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
       TWILIO_AUTH_TOKEN=your_auth_token
       TWILIO_WHATSAPP_FROM=+14155238886
       WHATSAPP_NUMBER=923250909907
"""

import os
import urllib.request
import urllib.parse
import base64
import json
from datetime import datetime

WHATSAPP_NUMBER      = os.getenv("WHATSAPP_NUMBER", "923250909907")
TWILIO_ACCOUNT_SID   = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN    = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_WHATSAPP_FROM = os.getenv("TWILIO_WHATSAPP_FROM", "+14155238886")

SEVERITY_EMOJI = {
    "CRITICAL": "🔴",
    "HIGH":     "🟠",
    "MEDIUM":   "🟡",
    "LOW":      "🟢",
}


def _build_whatsapp_message(result: dict) -> str:
    crisis_id   = result.get("crisis_id", "N/A")
    crisis_type = result.get("crisis_type", "UNKNOWN").replace("_", " ")
    location    = result.get("location", "Unknown")
    city        = result.get("city", "Unknown")
    severity    = result.get("severity", "UNKNOWN")
    confidence  = result.get("confidence", 0)
    actions     = result.get("action_plan", [])
    sim         = result.get("simulation") or {}
    emoji       = SEVERITY_EMOJI.get(severity, "⚠️")
    ts          = datetime.utcnow().strftime("%H:%M UTC")

    top_actions = ""
    for i, a in enumerate(actions[:3], 1):
        top_actions += f"\n  {i}. [{a.get('department')}] {a.get('action')} (ETA: {a.get('eta_minutes')}min)"

    alerts_sent = sim.get("alerts_sent", 0)
    pop_helped  = sim.get("population_helped", 0)

    return (
        f"{'='*30}\n"
        f"🛡️ *SAHARA AI — CRISIS ALERT*\n"
        f"{'='*30}\n"
        f"{emoji} *Severity:* {severity}\n"
        f"📍 *Location:* {location}, {city}\n"
        f"🚨 *Crisis:* {crisis_type}\n"
        f"🔬 *Confidence:* {confidence:.0%}\n"
        f"🆔 *ID:* {crisis_id}\n"
        f"🕐 *Time:* {ts}\n\n"
        f"*Actions Dispatched:*{top_actions}\n\n"
        f"📊 {alerts_sent:,} alerts sent | {pop_helped:,} people assisted\n\n"
        f"📞 1122 (Rescue) | 115 (Edhi) | 1339 (NDMA)\n"
        f"{'='*30}\n"
        f"_SAHARA AI v2.0 — Antigravity Pipeline_"
    )


def send_whatsapp_alert(result: dict, to_number: str = None) -> bool:
    """Send WhatsApp crisis alert via Twilio sandbox."""
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN:
        print("[WHATSAPP] Twilio not configured — see services/whatsapp_service.py for setup")
        return False

    number  = to_number or WHATSAPP_NUMBER
    # Ensure international format with + prefix
    if not number.startswith("+"):
        number = f"+{number}"

    message = _build_whatsapp_message(result)

    try:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
        data = urllib.parse.urlencode({
            "From": f"whatsapp:{TWILIO_WHATSAPP_FROM}",
            "To":   f"whatsapp:{number}",
            "Body": message,
        }).encode()

        credentials = base64.b64encode(f"{TWILIO_ACCOUNT_SID}:{TWILIO_AUTH_TOKEN}".encode()).decode()
        req = urllib.request.Request(url, data=data, headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type":  "application/x-www-form-urlencoded",
        })

        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read().decode())
            sid  = body.get("sid", "")
            status = body.get("status", "")
            print(f"[WHATSAPP] Alert sent to {number} — SID: {sid}, Status: {status}")
            return True

    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"[WHATSAPP] Twilio error {e.code}: {err[:200]}")
        return False
    except Exception as e:
        print(f"[WHATSAPP] Send failed: {e}")
        return False


def send_whatsapp_user_confirmation(to_number: str, crisis_id: str, severity: str, city: str) -> bool:
    """Send short confirmation to a user who reported a crisis."""
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN:
        return False

    if not to_number.startswith("+"):
        to_number = f"+{to_number}"

    emoji = SEVERITY_EMOJI.get(severity, "⚠️")
    message = (
        f"🛡️ *SAHARA AI — Report Received*\n\n"
        f"Your crisis report has been processed.\n\n"
        f"{emoji} Severity: *{severity}*\n"
        f"📍 Location: *{city}*\n"
        f"🆔 Crisis ID: *{crisis_id}*\n\n"
        f"Emergency services have been notified.\n"
        f"📞 Call 1122 (Rescue) or 115 (Edhi) for immediate help."
    )

    try:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
        data = urllib.parse.urlencode({
            "From": f"whatsapp:{TWILIO_WHATSAPP_FROM}",
            "To":   f"whatsapp:{to_number}",
            "Body": message,
        }).encode()
        credentials = base64.b64encode(f"{TWILIO_ACCOUNT_SID}:{TWILIO_AUTH_TOKEN}".encode()).decode()
        req = urllib.request.Request(url, data=data, headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type":  "application/x-www-form-urlencoded",
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 201
    except Exception as e:
        print(f"[WHATSAPP] User confirmation failed: {e}")
        return False
