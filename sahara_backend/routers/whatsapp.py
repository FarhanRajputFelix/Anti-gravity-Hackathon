"""
SAHARA AI — Inbound WhatsApp Webhook
Receives text AND image messages from users via Twilio, runs the 6-agent pipeline,
pushes result to the dashboard, alerts departments, and replies to the user.

Twilio calls POST /api/whatsapp/incoming every time someone messages
the SAHARA sandbox number (+14155238886 sandbox).
"""

import os
import asyncio
import base64
from datetime import datetime
from fastapi import APIRouter, Form, BackgroundTasks
from fastapi.responses import PlainTextResponse

router = APIRouter()

# In-memory log of all inbound WhatsApp reports (shown on dashboard)
WHATSAPP_REPORTS: list = []


def _twiml_reply(message: str) -> PlainTextResponse:
    """Return a TwiML XML response that sends a WhatsApp reply back to the user."""
    safe = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{safe}</Message>
</Response>"""
    return PlainTextResponse(content=xml, media_type="application/xml")


async def _analyze_image_with_gemini(image_url: str, media_type: str, user_text: str) -> str:
    """Download image from Twilio and analyze with Gemini Vision. Returns description."""
    try:
        import httpx
        import google.generativeai as genai

        api_key = os.getenv("GEMINI_API_KEY", "")
        if not api_key:
            return user_text or "Crisis reported via image"

        # Download the image using Twilio credentials (Twilio MediaUrls need auth)
        sid   = os.getenv("TWILIO_ACCOUNT_SID", "")
        token = os.getenv("TWILIO_AUTH_TOKEN", "")
        creds = base64.b64encode(f"{sid}:{token}".encode()).decode()

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(image_url, headers={"Authorization": f"Basic {creds}"})
            resp.raise_for_status()
            image_bytes = resp.content

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")

        prompt = (
            "You are an emergency crisis detection AI for Pakistan. "
            "Analyze this image and describe what crisis you see: flooding, fire, accident, heatwave, structural damage, etc. "
            "Extract: (1) crisis type, (2) location/area if visible, (3) severity. "
            "Reply in 2-3 sentences. If no crisis is visible, say 'No visible emergency detected.'"
        )

        if user_text:
            prompt += f"\nThe sender also wrote: '{user_text}'"

        import google.generativeai.types as types
        img_part = {"mime_type": media_type or "image/jpeg", "data": image_bytes}
        response = model.generate_content([prompt, img_part])
        description = response.text.strip() if response and response.text else ""

        if description and "no visible emergency" not in description.lower():
            combined = f"[IMAGE ANALYSIS] {description}"
            if user_text:
                combined += f" | User message: {user_text}"
            return combined

    except Exception as e:
        print(f"[WHATSAPP IMAGE] Gemini Vision failed: {e}")

    return user_text or "Crisis reported via image — details unclear from visual"


async def _send_twilio_reply(to_number: str, message: str):
    """Send a WhatsApp reply to a number via Twilio REST API."""
    import urllib.request, urllib.parse
    sid   = os.getenv("TWILIO_ACCOUNT_SID", "")
    token = os.getenv("TWILIO_AUTH_TOKEN", "")
    from_ = os.getenv("TWILIO_WHATSAPP_FROM", "+14155238886")

    if not sid or not token:
        return

    url  = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
    data = urllib.parse.urlencode({
        "From": f"whatsapp:{from_}",
        "To":   to_number if to_number.startswith("whatsapp:") else f"whatsapp:{to_number}",
        "Body": message,
    }).encode()
    creds = base64.b64encode(f"{sid}:{token}".encode()).decode()
    req = urllib.request.Request(url, data=data, headers={
        "Authorization": f"Basic {creds}",
        "Content-Type":  "application/x-www-form-urlencoded",
    })
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            print(f"[WHATSAPP] Reply sent to {to_number}")
    except Exception as e:
        print(f"[WHATSAPP] Reply failed to {to_number}: {e}")


async def _process_and_notify(sender: str, body: str, image_url: str = "", media_type: str = ""):
    """Run the full pipeline and fire all notifications. Called in background."""
    from orchestrator import orchestrator
    from models import CrisisSignal
    from services.email_service import send_department_alerts
    from services.whatsapp_service import send_whatsapp_alert

    # If image was sent, analyze it first with Gemini Vision
    signal_text = body
    has_image = bool(image_url)
    if has_image:
        print(f"[WHATSAPP HELPLINE] Processing image from {sender}: {image_url[:80]}")
        signal_text = await _analyze_image_with_gemini(image_url, media_type, body)
        print(f"[WHATSAPP HELPLINE] Image analysis result: {signal_text[:120]}")
    else:
        print(f"[WHATSAPP HELPLINE] Processing text from {sender}: {body[:80]}")

    signal = CrisisSignal(
        text=signal_text,
        source="whatsapp_image" if has_image else "whatsapp_helpline",
        location_hint=None,
    )

    try:
        result = await orchestrator.analyze(signal)
        result_dict = result.model_dump()

        crisis_id   = result_dict.get("crisis_id", "N/A")
        severity    = result_dict.get("severity", "UNKNOWN")
        city        = result_dict.get("city", "Unknown")
        crisis_type = result_dict.get("crisis_type", "UNKNOWN").replace("_", " ")
        confidence  = result_dict.get("confidence", 0)
        actions     = result_dict.get("action_plan", [])

        # Nearest hospitals from geoapify (if available in result)
        geo_ctx     = result_dict.get("geoapify_context", {})
        hospitals   = geo_ctx.get("nearest_hospitals", [])
        hospital_info = ""
        if hospitals:
            h = hospitals[0]
            hospital_info = f"\n\n🏥 *Nearest Hospital:* {h.get('name', '')}\n📍 {h.get('address', '')} ({h.get('distance_km', '?')} km)"

        # Log to in-memory store (dashboard polls this)
        WHATSAPP_REPORTS.insert(0, {
            "from":        sender,
            "body":        body[:300],
            "has_image":   has_image,
            "image_analysis": signal_text[:200] if has_image else None,
            "crisis_id":   crisis_id,
            "severity":    severity,
            "city":        city,
            "crisis_type": crisis_type,
            "confidence":  confidence,
            "actions":     len(actions),
            "hospitals":   hospitals[:3],
            "timestamp":   datetime.utcnow().isoformat(),
            "result":      result_dict,
        })
        del WHATSAPP_REPORTS[50:]  # keep last 50

        print(f"[WHATSAPP HELPLINE] Pipeline done: {crisis_id} | {severity} | {city}")

        # Department email alerts (non-blocking)
        loop = asyncio.get_event_loop()
        loop.run_in_executor(None, send_department_alerts, result_dict)

        # WhatsApp alert to control room 03250909907
        loop.run_in_executor(None, send_whatsapp_alert, result_dict)

        # Reply to sender with full confirmation
        severity_emoji = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢"}.get(severity, "⚠️")
        top_actions = "\n".join([
            f"  • [{a.get('department')}] {a.get('action')} (ETA: {a.get('eta_minutes')}min)"
            for a in actions[:3]
        ])
        image_note = "\n📸 *Image analyzed by Gemini Vision AI*\n" if has_image else ""
        reply = (
            f"🛡️ *SAHARA AI — Report Processed*\n"
            f"{image_note}\n"
            f"{severity_emoji} *{severity}* — {crisis_type}\n"
            f"📍 *Location:* {city}\n"
            f"🆔 *Crisis ID:* {crisis_id}\n"
            f"🔬 *Confidence:* {confidence:.0%}\n\n"
            f"*Emergency Response Dispatched:*\n{top_actions}"
            f"{hospital_info}\n\n"
            f"📞 1122 (Rescue) | 115 (Edhi) | 1339 (NDMA)"
        )

        await _send_twilio_reply(sender, reply)

    except Exception as e:
        print(f"[WHATSAPP HELPLINE] Pipeline error: {e}")
        await _send_twilio_reply(
            sender,
            "⚠️ *SAHARA AI* — Your report was received but we encountered an error processing it.\n\n📞 Call *1122* (Rescue) for immediate help."
        )


@router.post("/whatsapp/incoming")
async def whatsapp_incoming(
    background_tasks: BackgroundTasks,
    From: str = Form(...),
    Body: str = Form(""),
    To: str = Form(""),
    ProfileName: str = Form(""),
    NumMedia: str = Form("0"),
    MediaUrl0: str = Form(""),
    MediaContentType0: str = Form(""),
):
    """
    Twilio webhook — store the raw incoming WhatsApp message immediately
    so it appears on the admin dashboard. The admin then triggers analysis
    manually by clicking "Analyze with Agents" → /api/whatsapp/analyze/{id}.
    """
    sender    = From
    text      = Body.strip()
    name      = ProfileName or "User"
    has_media = int(NumMedia or 0) > 0

    if not text and not has_media:
        return _twiml_reply("🛡️ *SAHARA AI* — Please describe the crisis or send an image.\n\n📞 Emergency? Call *1122*")

    # Generate a unique ID for this incoming message
    msg_id = f"WA-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{sender[-4:]}"

    # Store as PENDING — admin will approve analysis
    WHATSAPP_REPORTS.insert(0, {
        "id":             msg_id,
        "from":           sender,
        "name":           name,
        "body":           text or "(image only)",
        "has_image":      has_media,
        "image_url":      MediaUrl0,
        "image_type":     MediaContentType0,
        "crisis_id":      None,         # set after admin triggers analysis
        "severity":       "PENDING",    # PENDING until admin approves
        "city":           "—",
        "crisis_type":    "AWAITING_ANALYSIS",
        "confidence":     0,
        "actions":        0,
        "hospitals":      [],
        "timestamp":      datetime.utcnow().isoformat(),
        "analyzed":       False,
        "result":         None,
    })
    del WHATSAPP_REPORTS[50:]

    print(f"[WHATSAPP HELPLINE] Stored pending message {msg_id} from {sender} ({name})")

    # Acknowledge to user — they'll get full reply after admin runs analysis
    ack = (
        f"🛡️ *SAHARA AI* received your report, {name}.\n\n"
        f"✅ Report logged (ID: {msg_id})\n"
        f"⏳ Admin will analyze and dispatch response.\n\n"
        f"📞 Emergency? Call *1122* (Rescue) immediately."
    )
    return _twiml_reply(ack)


@router.post("/whatsapp/analyze/{msg_id}")
async def admin_trigger_analysis(msg_id: str):
    """
    Admin clicks 'Analyze with Agents' on the dashboard → runs full 6-agent
    pipeline on a pending WhatsApp message, then updates the report in place
    and sends the result back to the original sender.
    """
    report = next((r for r in WHATSAPP_REPORTS if r.get("id") == msg_id), None)
    if not report:
        return {"error": "report not found", "id": msg_id}
    if report.get("analyzed"):
        return {"status": "already_analyzed", "report": report}

    # Run pipeline (sync from dashboard click)
    await _process_and_notify(
        report["from"],
        report["body"],
        report.get("image_url", ""),
        report.get("image_type", ""),
    )

    # _process_and_notify inserts a NEW row — merge: copy fresh result back into original row, drop the duplicate
    if WHATSAPP_REPORTS and WHATSAPP_REPORTS[0].get("id") != msg_id:
        fresh = WHATSAPP_REPORTS.pop(0)   # the new analyzed row
        report["analyzed"]    = True
        report["crisis_id"]   = fresh.get("crisis_id")
        report["severity"]    = fresh.get("severity")
        report["city"]        = fresh.get("city")
        report["crisis_type"] = fresh.get("crisis_type")
        report["confidence"]  = fresh.get("confidence")
        report["actions"]     = fresh.get("actions")
        report["hospitals"]   = fresh.get("hospitals", [])
        report["result"]      = fresh.get("result")
    return {"status": "analyzed", "report": report}


@router.get("/whatsapp/reports")
async def get_whatsapp_reports():
    """Return all inbound WhatsApp crisis reports (for dashboard)."""
    return {
        "reports": WHATSAPP_REPORTS,
        "count":   len(WHATSAPP_REPORTS),
    }


@router.get("/whatsapp/reports/latest")
async def get_latest_report():
    """Return the most recent inbound WhatsApp report."""
    return {"report": WHATSAPP_REPORTS[0] if WHATSAPP_REPORTS else None}
