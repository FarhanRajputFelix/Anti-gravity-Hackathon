"""
SAHARA AI — Live Crisis Monitor Service
Runs as a background task. Every 90 seconds it:
  1. Fetches real news from Pakistani RSS feeds
  2. Fetches real weather from OpenWeatherMap
  3. Uses Gemini AI to classify crisis severity from real headlines
  4. Pushes detected crises into the signal queue
  5. Optionally auto-triggers the Antigravity pipeline
"""

import asyncio
import os
from datetime import datetime
from typing import List, Dict, Any, Optional
import json

# In-memory signal store — dashboard polls this
LIVE_SIGNAL_QUEUE: List[Dict[str, Any]] = []
MONITOR_STATUS = {
    "running":        False,
    "last_scan":      None,
    "scans_total":    0,
    "signals_found":  0,
    "auto_analyses":  0,
    "gemini_enabled": False,
}

MAX_QUEUE_SIZE   = 50
MONITOR_INTERVAL = 90   # seconds between scans
AUTO_THRESHOLD   = 0.75  # confidence above this → auto-trigger analysis

# Gemini client (shared with orchestrator)
_gemini_model = None


def _init_gemini():
    global _gemini_model
    if _gemini_model:
        return _gemini_model
    try:
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            import google.generativeai as genai
        key = os.getenv("GEMINI_API_KEY", "")
        if key and key != "your-gemini-api-key-here":
            genai.configure(api_key=key)
            _gemini_model = genai.GenerativeModel("gemini-2.0-flash")
            MONITOR_STATUS["gemini_enabled"] = True
    except Exception:
        pass
    return _gemini_model


async def _gemini_classify(signals: List[Dict]) -> List[Dict]:
    """
    Use Gemini to enrich and re-score raw signals.
    Returns the same list with added fields: gemini_summary, confidence, should_alert.
    """
    model = _init_gemini()
    if not model or not signals:
        # Rule-based fallback scoring
        for s in signals:
            s["gemini_summary"] = None
            s["confidence"] = 0.65
            s["should_alert"] = True
        return signals

    texts = "\n".join([f"{i+1}. [{s.get('crisis_type','?')}] {s['text'][:200]}" for i, s in enumerate(signals)])
    prompt = f"""You are SAHARA AI's Crisis Intelligence Monitor for Pakistan.
Analyze these {len(signals)} crisis signals just detected from Pakistani news and weather feeds.

SIGNALS:
{texts}

For each signal (1 to {len(signals)}), respond with a JSON array like:
[{{"index":1,"severity":"CRITICAL|HIGH|MEDIUM|LOW","confidence":0.0-1.0,"summary":"1-sentence summary in plain English","should_alert":true|false,"location":"city name"}}]

Rules:
- Confidence > 0.75 = credible crisis requiring immediate response
- should_alert = true if severity HIGH or CRITICAL and confidence > 0.6
- summary must be concise and factual
- Only return valid JSON array, nothing else."""

    try:
        resp = await model.generate_content_async(prompt)
        text = resp.text.strip()
        # Strip markdown code fences if present
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        classifications = json.loads(text.strip())
        for item in classifications:
            idx = item.get("index", 0) - 1
            if 0 <= idx < len(signals):
                signals[idx]["gemini_severity"]  = item.get("severity", "MEDIUM")
                signals[idx]["confidence"]        = float(item.get("confidence", 0.65))
                signals[idx]["gemini_summary"]    = item.get("summary", "")
                signals[idx]["should_alert"]      = item.get("should_alert", True)
                signals[idx]["gemini_location"]   = item.get("location", "")
    except Exception as e:
        for s in signals:
            s["gemini_summary"] = None
            s["confidence"]     = 0.65
            s["should_alert"]   = True
    return signals


async def run_scan() -> List[Dict]:
    """
    One complete monitoring scan: fetch news + weather → Gemini classify → return signals.
    """
    from services.news_service import get_all_live_signals

    MONITOR_STATUS["last_scan"] = datetime.utcnow().isoformat()
    MONITOR_STATUS["scans_total"] += 1

    # Fetch all live signals (news + weather)
    raw_signals = await get_all_live_signals(max_items=15)

    if not raw_signals:
        return []

    # Gemini classification (or rule-based fallback)
    enriched = await _gemini_classify(raw_signals)

    # Filter to only signals worth alerting on
    alerts = [s for s in enriched if s.get("should_alert", True)]

    # Add to queue (newest first, cap at MAX_QUEUE_SIZE)
    for sig in alerts:
        sig["queued_at"] = datetime.utcnow().isoformat()
        LIVE_SIGNAL_QUEUE.insert(0, sig)

    del LIVE_SIGNAL_QUEUE[MAX_QUEUE_SIZE:]
    MONITOR_STATUS["signals_found"] += len(alerts)
    return alerts


async def auto_analyze_top_signal(signal: Dict) -> Optional[Dict]:
    """
    Auto-run the Antigravity pipeline on the highest-confidence signal.
    Returns the analysis result or None.
    """
    from orchestrator import orchestrator
    from models import CrisisSignal

    try:
        text         = signal.get("gemini_summary") or signal.get("text", "")
        location     = signal.get("gemini_location") or signal.get("location_hint") or signal.get("city", "")
        source       = signal.get("source", "news_agency")
        crisis_signal = CrisisSignal(text=text, source=source, location_hint=location or None)
        result = await orchestrator.analyze(crisis_signal)
        MONITOR_STATUS["auto_analyses"] += 1
        return result.model_dump()
    except Exception:
        return None


async def monitor_loop():
    """
    Main background monitoring loop.
    Runs indefinitely, scans every MONITOR_INTERVAL seconds.
    """
    MONITOR_STATUS["running"] = True
    print(f"[MONITOR] Background crisis monitoring STARTED — scan interval {MONITOR_INTERVAL}s")
    _init_gemini()

    while True:
        try:
            alerts = await run_scan()
            if alerts:
                print(f"[MONITOR] Scan complete — {len(alerts)} crisis signal(s) detected")
                # Auto-analyze the top-confidence signal
                top = max(alerts, key=lambda x: x.get("confidence", 0))
                if top.get("confidence", 0) >= AUTO_THRESHOLD:
                    print(f"[MONITOR] Auto-analyzing: {top['text'][:80]}")
                    await auto_analyze_top_signal(top)
            else:
                print(f"[MONITOR] Scan complete — no crisis signals detected")
        except Exception as e:
            print(f"[MONITOR] Scan error: {e}")

        await asyncio.sleep(MONITOR_INTERVAL)


def get_live_signals(limit: int = 20) -> List[Dict]:
    """Return the most recent signals from the queue."""
    return LIVE_SIGNAL_QUEUE[:limit]


def get_monitor_status() -> Dict:
    return dict(MONITOR_STATUS)
