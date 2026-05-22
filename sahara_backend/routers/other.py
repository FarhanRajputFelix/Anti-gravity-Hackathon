"""SAHARA AI — /api/logs, /api/simulate, /api/crisis/{id}, /api/feed, /api/monitor routers"""
import asyncio
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from models import SimulateRequest
from orchestrator import orchestrator

router = APIRouter()


@router.get("/logs")
async def get_logs():
    """Return the last 20 agent trace logs."""
    return {"logs": orchestrator.get_logs(), "count": len(orchestrator.get_logs())}


@router.get("/crisis/{crisis_id}")
async def get_crisis(crisis_id: str):
    """Return stored crisis details by ID."""
    result = orchestrator.get_crisis(crisis_id)
    if not result:
        raise HTTPException(status_code=404, detail=f"Crisis {crisis_id} not found.")
    return result


@router.post("/simulate")
async def run_simulation(req: SimulateRequest):
    """Re-run execution simulation for an existing crisis."""
    existing = orchestrator.get_crisis(req.crisis_id)
    if not existing:
        raise HTTPException(status_code=404, detail=f"Crisis {req.crisis_id} not found.")
    return {
        "crisis_id": req.crisis_id,
        "simulation": existing.get("simulation"),
        "status": "simulation_retrieved",
    }


@router.get("/feed")
async def get_signal_feed():
    """
    Real-time signal feed — returns live signals from Pakistani news + weather.
    Falls back to mock signals if no live data is available yet.
    """
    from services.monitor_service import get_live_signals

    live = get_live_signals(limit=20)

    if live:
        return {"signals": live, "count": len(live), "source": "live"}

    # Fallback: mock data until first scan completes
    from mock_data import RECENT_SIGNAL_FEED
    return {"signals": RECENT_SIGNAL_FEED, "count": len(RECENT_SIGNAL_FEED), "source": "mock_fallback"}


@router.get("/feed/stream")
async def stream_signal_feed():
    """
    SSE stream — pushes new signals to connected clients as they're detected.
    Connect once; receive events whenever the monitor finds new signals.
    """
    from services.monitor_service import get_live_signals, MONITOR_STATUS

    async def generate():
        last_count = 0
        while True:
            signals = get_live_signals(limit=20)
            if len(signals) > last_count:
                new_signals = signals[:len(signals) - last_count]
                for sig in new_signals:
                    yield f"data: {json.dumps(sig, default=str)}\n\n"
                last_count = len(signals)
            else:
                # Heartbeat to keep connection alive
                yield f"data: {json.dumps({'type':'heartbeat','timestamp':__import__('datetime').datetime.utcnow().isoformat()})}\n\n"
            await asyncio.sleep(5)

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/monitor/status")
async def monitor_status():
    """Return live monitoring service status."""
    from services.monitor_service import get_monitor_status
    return get_monitor_status()


@router.post("/monitor/scan")
async def trigger_scan():
    """
    Manually trigger one monitoring scan right now.
    Returns signals detected in this scan.
    """
    from services.monitor_service import run_scan
    signals = await run_scan()
    return {
        "signals_detected": len(signals),
        "signals": signals,
        "message": f"Scan complete — {len(signals)} crisis signal(s) found from live news + weather feeds."
    }


@router.get("/weather/{city}")
async def get_live_weather(city: str):
    """Return real-time weather for a Pakistani city from WeatherAPI.com."""
    from services.weather_service import get_real_weather
    data = await get_real_weather(city.lower())
    return data


@router.get("/live-crises")
async def get_live_crises():
    """
    Return all processed crises with full context: location, severity,
    nearest hospitals, emergency routes — for the Flutter map and dashboard.
    """
    from orchestrator import CRISIS_STORE
    from services.geoapify_service import CITY_COORDS

    crises = []
    for crisis_id, payload in CRISIS_STORE.items():
        city = payload.get("city", "").lower()
        coords = CITY_COORDS.get(city, (33.6938, 73.0652))
        geo_ctx = payload.get("geoapify_context", {})
        hospitals = geo_ctx.get("nearest_hospitals", [])
        routes    = geo_ctx.get("emergency_routes", [])

        shelters = geo_ctx.get("nearest_shelters", [])
        police   = geo_ctx.get("nearest_police", [])
        fire     = geo_ctx.get("nearest_fire_stations", [])
        crisis_loc = geo_ctx.get("crisis_location", {})

        crises.append({
            "crisis_id":     crisis_id,
            "crisis_type":   payload.get("crisis_type", "UNKNOWN"),
            "location":      payload.get("location", "Unknown"),
            "city":          payload.get("city", "Unknown"),
            "severity":      payload.get("severity", "UNKNOWN"),
            "confidence":    payload.get("confidence", 0),
            "verification":  payload.get("verification_status", "UNVERIFIED"),
            "timestamp":     payload.get("created_at", ""),
            "lat":           crisis_loc.get("lat", coords[0]),
            "lon":           crisis_loc.get("lon", coords[1]),
            "hospitals":     hospitals[:5],
            "shelters":      shelters[:5],
            "police":        police[:3],
            "fire_stations": fire[:3],
            "routes":        routes[:3],
            "action_count":  len(payload.get("action_plan", [])),
            "simulation":    payload.get("simulation"),
        })

    # Sort newest first (by crisis_id which contains UUID ordering)
    crises.sort(key=lambda c: c["crisis_id"], reverse=True)

    return {
        "crises":   crises[:50],
        "count":    len(crises),
        "source":   "live",
    }


@router.get("/hospitals/{city}")
async def get_hospitals(city: str, lat: float = None, lon: float = None):
    """Find nearest hospitals/emergency services for a city."""
    from services.geoapify_service import find_nearest_hospitals
    hospitals = await find_nearest_hospitals(city.lower(), lat, lon, limit=5)
    return {"hospitals": hospitals, "city": city, "count": len(hospitals)}


@router.get("/route")
async def get_emergency_route(flat: float, flon: float, tlat: float, tlon: float, mode: str = "drive"):
    """Calculate emergency route between two coordinates."""
    from services.geoapify_service import get_route
    route = await get_route(flat, flon, tlat, tlon, mode)
    return route


@router.get("/tiles/{z}/{x}/{y}.png")
async def map_tile_proxy(z: int, x: int, y: int):
    """
    Proxy map tiles through the backend. Used by:
      - HF Spaces web app (bypasses CSP)
      - Native Android APK (no direct CartoDB access on locked-down phones)
    """
    import httpx
    from fastapi.responses import Response
    url = f"https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
    try:
        async with httpx.AsyncClient(timeout=6.0) as client:
            resp = await client.get(url)
        return Response(
            content=resp.content,
            media_type="image/png",
            headers={
                "Cache-Control":                  "public, max-age=86400, immutable",
                "Access-Control-Allow-Origin":    "*",
                "Cross-Origin-Resource-Policy":   "cross-origin",
            },
        )
    except Exception:
        return Response(status_code=502)


@router.get("/earthquakes")
async def get_live_earthquakes(min_mag: float = 3.0):
    """Real-time earthquake feed from USGS (public, no key)."""
    from services.earthquake_service import get_recent_earthquakes
    eqs = await get_recent_earthquakes(min_magnitude=min_mag, limit=15)
    return {"earthquakes": eqs, "count": len(eqs), "source": "usgs_realtime"}


@router.post("/analyze-signal")
async def analyze_existing_signal(payload: dict):
    """One-click: take a live news signal and run it through the 6-agent pipeline."""
    from orchestrator import orchestrator
    from models import CrisisSignal
    text   = payload.get("text", "")
    source = payload.get("source", "news_agency")
    hint   = payload.get("location_hint")
    if not text:
        return {"error": "text required"}
    signal = CrisisSignal(text=text, source=source, location_hint=hint)
    result = await orchestrator.analyze(signal)
    return result.model_dump()
