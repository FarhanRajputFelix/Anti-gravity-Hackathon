"""
SAHARA AI -- FastAPI Backend Entry Point v2.0
Pakistan's First Agentic Urban Crisis Response Operating System
Powered by Google Antigravity Orchestration + Gemini AI
"""

import asyncio
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from routers.analyze import router as analyze_router
from routers.other import router as other_router
from routers.workflow import router as workflow_router
from routers.whatsapp import router as whatsapp_router


async def _rehydrate_from_firebase():
    """On boot, pull existing crises + WhatsApp reports from Firebase into memory."""
    try:
        from firebase_client import firebase
        from orchestrator import CRISIS_STORE
        from routers.whatsapp import WHATSAPP_REPORTS

        if not firebase.is_connected:
            return

        stored = firebase.get_all_crises() or {}
        for cid, c in stored.items():
            if cid and isinstance(c, dict):
                CRISIS_STORE[cid] = c
        if stored:
            print(f"[SAHARA] Rehydrated {len(stored)} crises from Firebase")

        wa = firebase.get_whatsapp_reports(limit=50) or []
        for r in wa:
            if isinstance(r, dict):
                WHATSAPP_REPORTS.append(r)
        if wa:
            print(f"[SAHARA] Rehydrated {len(wa)} WhatsApp reports from Firebase")
    except Exception as e:
        print(f"[SAHARA] Firebase rehydrate failed: {e}")


async def _startup_seed():
    """Run an immediate first scan AND seed 4 demo crises so the map is never empty."""
    await asyncio.sleep(2)

    # First, try to rehydrate from Firebase
    await _rehydrate_from_firebase()

    try:
        from services.monitor_service import run_scan
        await run_scan()
        print("[SAHARA] First news/weather scan complete.")
    except Exception as e:
        print(f"[SAHARA] First scan failed: {e}")

    # Auto-seed realistic crises across major cities so dashboard/map are populated
    try:
        from orchestrator import orchestrator, CRISIS_STORE
        from models import CrisisSignal
        if len(CRISIS_STORE) > 0:
            print(f"[SAHARA] Skipping auto-seed — {len(CRISIS_STORE)} crises already in store")
            return
        seed_signals = [
            ("Severe flooding in G-10 Islamabad, water 4 feet deep in streets, people stranded on rooftops", "citizen_report"),
            ("Heatwave emergency in Karachi Saddar area, temperature 49°C, dozens of heat stroke cases, hospitals overwhelmed", "weather_api"),
            ("Major fire at Anarkali bazaar Lahore, multiple shops burning, smoke spreading across Mall Road", "social_media"),
            ("Earthquake felt in Quetta Satellite Town, buildings cracked, magnitude 5.2, people running out", "news_agency"),
        ]
        for text, source in seed_signals:
            try:
                signal = CrisisSignal(text=text, source=source, location_hint=None)
                await orchestrator.analyze(signal)
            except Exception as inner:
                print(f"[SAHARA] Seed failed for '{text[:40]}': {inner}")
        print(f"[SAHARA] Auto-seed complete — {len(CRISIS_STORE)} crises ready")

        # Also seed WhatsApp helpline reports so the dashboard panel never looks empty
        try:
            from routers.whatsapp import WHATSAPP_REPORTS
            if not WHATSAPP_REPORTS:
                demo_wa = [
                    ("+923001234567", "Citizen reporting flooding in G-10 Islamabad", "FLOODING", "islamabad", "CRITICAL", 0.95),
                    ("+923211234567", "Heat stroke patients arriving at Civil Hospital Karachi", "HEATWAVE", "karachi", "CRITICAL", 0.92),
                    ("+923351234567", "Smoke and fire visible at Anarkali bazaar Lahore", "FIRE", "lahore", "HIGH", 0.81),
                ]
                from datetime import datetime
                for sender, body, ctype, city, sev, conf in demo_wa:
                    WHATSAPP_REPORTS.append({
                        "from":        f"whatsapp:{sender}",
                        "body":        body,
                        "has_image":   False,
                        "crisis_id":   f"CRS-WA{sender[-4:]}",
                        "severity":    sev,
                        "city":        city,
                        "crisis_type": ctype,
                        "confidence":  conf,
                        "actions":     4,
                        "hospitals":   [],
                        "timestamp":   datetime.utcnow().isoformat(),
                        "result":      {},
                    })
                print(f"[SAHARA] Seeded {len(WHATSAPP_REPORTS)} WhatsApp demo reports")
        except Exception as wa_err:
            print(f"[SAHARA] WhatsApp seed failed: {wa_err}")
    except Exception as e:
        print(f"[SAHARA] Auto-seed error: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background services + immediate seed on startup."""
    from services.monitor_service import monitor_loop
    from services.email_helpline import helpline_loop
    monitor_task  = asyncio.create_task(monitor_loop())
    helpline_task = asyncio.create_task(helpline_loop())
    seed_task     = asyncio.create_task(_startup_seed())
    print("[SAHARA] Background crisis monitor started.")
    print("[SAHARA] Email helpline started.")
    print("[SAHARA] Auto-seed scheduled.")
    yield
    for task in [monitor_task, helpline_task, seed_task]:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    print("[SAHARA] Background services stopped.")


app = FastAPI(
    title="SAHARA AI -- Crisis Intelligence Backend",
    description="Multi-agent crisis response system for Pakistani cities. Powered by Google Antigravity + Gemini AI.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# -- CORS -- Allow Flutter mobile app + web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -- Register routers
app.include_router(analyze_router, prefix="/api", tags=["Analysis"])
app.include_router(other_router, prefix="/api", tags=["Crisis & Logs"])
app.include_router(workflow_router, prefix="/api", tags=["Orchestration Workflow"])
app.include_router(whatsapp_router, prefix="/api", tags=["WhatsApp Helpline"])

# -- Serve web dashboard as static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir, html=True), name="static")


# -- Serve the Flutter web app at /app/ so everything is on a single port.
# Try bundled web_app first (HF/prod), fall back to relative dev path (local).
flutter_dir = os.path.join(os.path.dirname(__file__), "web_app")
if not os.path.isdir(flutter_dir):
    flutter_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "sahara_app", "build", "web"))
if os.path.isdir(flutter_dir):
    app.mount("/app", StaticFiles(directory=flutter_dir, html=True), name="flutter_app")
    print(f"[SAHARA] Flutter web app mounted at /app  from  {flutter_dir}")
else:
    print(f"[SAHARA] No Flutter web build found — /app/ disabled")


@app.get("/dashboard", include_in_schema=False)
async def dashboard_redirect():
    """Redirect /dashboard to the web command center."""
    return RedirectResponse(url="/static/index.html")


@app.get("/", tags=["Health"])
async def root():
    return {
        "system": "SAHARA AI",
        "tagline": "Pakistan's First Agentic Urban Crisis Response Operating System",
        "version": "2.0.0",
        "orchestrator": "Google Antigravity v2.0 + Gemini AI",
        "agents": [
            "Signal Ingestion Agent",
            "Verification Agent",
            "Severity Analysis Agent",
            "Response Planning Agent",
            "Execution Simulation Agent",
            "Fallback & Recovery Agent",
        ],
        "status": "ONLINE",
        "dashboard": "/dashboard",
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health():
    from firebase_client import firebase
    from orchestrator import CRISIS_STORE
    return {
        "status":            "healthy",
        "service":           "SAHARA AI Backend v2.0",
        "firebase_connected": firebase.is_connected,
        "crises_in_memory":  len(CRISIS_STORE),
        "version":           "2.1.0",
    }


@app.get("/healthz", include_in_schema=False)
async def healthz():
    """Lightweight ping for Render/uptime monitors."""
    return {"ok": True}
