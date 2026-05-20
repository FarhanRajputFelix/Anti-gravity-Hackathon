"""
SAHARA AI — Email Helpline Monitor
Polls farhanmuhammadbashir@gmail.com via IMAP for incoming crisis reports.
Every 60 seconds:
  1. Checks for new unread emails
  2. Extracts sender + body text
  3. Runs full 6-agent Antigravity pipeline
  4. Sends department alert emails
  5. Sends WhatsApp alert
  6. Replies to sender with full results
"""

import imaplib
import email
import asyncio
import os
from email.header import decode_header
from datetime import datetime

SAHARA_EMAIL    = os.getenv("SAHARA_EMAIL", "farhanmuhammadbashir@gmail.com")
SAHARA_PASSWORD = os.getenv("SAHARA_EMAIL_PASSWORD", "")
HELPLINE_INTERVAL = 60   # seconds


def _decode_str(value):
    if not value:
        return ""
    decoded, enc = decode_header(value)[0]
    if isinstance(decoded, bytes):
        return decoded.decode(enc or "utf-8", errors="replace")
    return decoded


def _extract_body(msg) -> str:
    """Extract plain-text body from email message."""
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            cd = str(part.get("Content-Disposition", ""))
            if ct == "text/plain" and "attachment" not in cd:
                charset = part.get_content_charset() or "utf-8"
                body = part.get_payload(decode=True).decode(charset, errors="replace")
                break
    else:
        charset = msg.get_content_charset() or "utf-8"
        body = msg.get_payload(decode=True).decode(charset, errors="replace")
    return body.strip()


def _fetch_new_emails():
    """Connect to Gmail via IMAP and return list of (uid, from, subject, body) for unseen emails."""
    if not SAHARA_PASSWORD:
        return []

    results = []
    try:
        mail = imaplib.IMAP4_SSL("imap.gmail.com")
        mail.login(SAHARA_EMAIL, SAHARA_PASSWORD)
        mail.select("inbox")

        _, uids = mail.search(None, "UNSEEN")
        uid_list = uids[0].split()
        if not uid_list:
            mail.logout()
            return []

        for uid in uid_list[-10:]:   # process at most 10 new emails per scan
            _, data = mail.fetch(uid, "(RFC822)")
            raw = data[0][1]
            msg = email.message_from_bytes(raw)

            sender  = _decode_str(msg.get("From", ""))
            subject = _decode_str(msg.get("Subject", ""))
            body    = _extract_body(msg)

            # Skip emails from SAHARA itself (our own alerts/replies)
            if SAHARA_EMAIL in sender:
                continue

            # Extract the sender's email address
            from_addr = sender
            if "<" in sender and ">" in sender:
                from_addr = sender.split("<")[1].rstrip(">").strip()

            results.append({
                "uid":      uid.decode(),
                "from":     from_addr,
                "subject":  subject,
                "body":     body,
                "raw_text": f"{subject}. {body}"[:1000],
            })

        mail.logout()
    except Exception as e:
        print(f"[HELPLINE] IMAP error: {e}")

    return results


async def process_email_report(email_data: dict):
    """Run the full pipeline on a user email report and send back alerts."""
    from orchestrator import orchestrator
    from models import CrisisSignal
    from services.email_service import send_department_alerts, send_user_reply
    from services.whatsapp_service import send_whatsapp_alert

    raw_text  = email_data["raw_text"]
    from_addr = email_data["from"]
    subject   = email_data["subject"]

    print(f"[HELPLINE] New email from {from_addr}: {subject[:60]}")

    # Run 6-agent pipeline
    signal = CrisisSignal(
        text=raw_text,
        source="email_helpline",
        location_hint=None,
    )
    try:
        result = await orchestrator.analyze(signal)
        result_dict = result.model_dump()
        crisis_id = result_dict.get("crisis_id", "N/A")
        severity  = result_dict.get("severity", "UNKNOWN")
        city      = result_dict.get("city", "Unknown")

        print(f"[HELPLINE] Pipeline complete: {crisis_id} | {severity} | {city}")

        # Fire all notifications concurrently
        loop = asyncio.get_event_loop()

        # Email department alerts
        loop.run_in_executor(None, send_department_alerts, result_dict)

        # Reply to user
        loop.run_in_executor(None, send_user_reply, from_addr, email_data["body"], result_dict)

        # WhatsApp alert to control room
        loop.run_in_executor(None, send_whatsapp_alert, result_dict, None, "Control Room")

        print(f"[HELPLINE] All notifications dispatched for {crisis_id}")

    except Exception as e:
        print(f"[HELPLINE] Pipeline error for email from {from_addr}: {e}")


async def helpline_loop():
    """
    Background loop: polls inbox every HELPLINE_INTERVAL seconds.
    Skips silently if credentials are missing or invalid.
    """
    if not SAHARA_PASSWORD:
        print("[HELPLINE] No SAHARA_EMAIL_PASSWORD set — email helpline inactive (demo mode)")
        return

    # Verify credentials work before starting the loop
    try:
        import imaplib as _imap
        test = _imap.IMAP4_SSL("imap.gmail.com")
        test.login(SAHARA_EMAIL, SAHARA_PASSWORD)
        test.logout()
    except Exception as e:
        print(f"[HELPLINE] Credential check failed ({e}) — email helpline inactive")
        return

    print(f"[HELPLINE] Email helpline STARTED — polling {SAHARA_EMAIL} every {HELPLINE_INTERVAL}s")

    while True:
        try:
            new_emails = _fetch_new_emails()
            if new_emails:
                print(f"[HELPLINE] {len(new_emails)} new report(s) received")
                for em in new_emails:
                    await process_email_report(em)
            else:
                print(f"[HELPLINE] Inbox scan complete — no new reports")
        except Exception as e:
            print(f"[HELPLINE] Loop error: {e}")

        await asyncio.sleep(HELPLINE_INTERVAL)
