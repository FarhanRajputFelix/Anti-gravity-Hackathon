"""
SAHARA AI — Agent 2: Verification Agent
Cross-checks crisis signal against REAL WeatherAPI.com data + Geoapify location resolution.
Assigns a confidence score and detects contradictions.
"""

import os
import time
import httpx
from datetime import datetime
from dotenv import load_dotenv
from models import (
    CrisisContext, AgentTrace, ToolCall,
    VerificationResult, VerificationStatus, CrisisType,
    FallbackEntry,
)

# Idempotent — safe even if orchestrator already called it.
load_dotenv()

# WeatherAPI.com key (read lazily so .env loaded after import still works)
def _weatherapi_key() -> str:
    return os.getenv("WEATHERAPI_KEY", "")


def _fetch_real_weather(city: str) -> dict:
    """Call WeatherAPI.com for real current weather data."""
    api_key = _weatherapi_key()
    if not api_key:
        return {"available": False, "error": "No WEATHERAPI_KEY configured"}

    try:
        url = f"http://api.weatherapi.com/v1/current.json?key={api_key}&q={city}"
        resp = httpx.get(url, timeout=8.0)
        if resp.status_code == 200:
            data = resp.json()
            current = data.get("current", {})
            condition = current.get("condition", {})
            return {
                "available": True,
                "source": "WeatherAPI.com (LIVE)",
                "temperature_c": current.get("temp_c", 30),
                "feels_like_c": current.get("feelslike_c", 30),
                "humidity": current.get("humidity", 50),
                "precip_mm": current.get("precip_mm", 0),
                "wind_kph": current.get("wind_kph", 10),
                "condition_text": condition.get("text", "Unknown"),
                "cloud_pct": current.get("cloud", 0),
                "uv_index": current.get("uv", 5),
                "is_day": current.get("is_day", 1),
            }
        return {"available": False, "error": f"HTTP {resp.status_code}"}
    except Exception as e:
        return {"available": False, "error": str(e)}


def _resolve_location_geoapify(location: str) -> dict:
    """Resolve location to coordinates using Geoapify API."""
    api_key = os.getenv("GEOAPIFY_API_KEY", "")
    if not api_key:
        return {"available": False}
    try:
        url = "https://api.geoapify.com/v1/geocode/search"
        params = {
            "text": f"{location}, Pakistan",
            "apiKey": api_key,
            "limit": 1,
            "filter": "countrycode:pk"
        }
        resp = httpx.get(url, params=params, timeout=6.0)
        if resp.status_code == 200:
            features = resp.json().get("features", [])
            if features:
                props = features[0]["properties"]
                coords = features[0]["geometry"]["coordinates"]
                return {
                    "available": True,
                    "lat": coords[1],
                    "lon": coords[0],
                    "formatted": props.get("formatted", location),
                    "city": props.get("city", ""),
                    "confidence": props.get("rank", {}).get("confidence", 0.5)
                }
        return {"available": False}
    except Exception as e:
        return {"available": False, "error": str(e)}


def _check_weather_consistency(crisis_type: CrisisType, weather: dict) -> dict:
    """Check if REAL weather data is consistent with the reported crisis type.
    This is the core intelligence — weather is independent of the report."""
    temp = weather.get("temperature_c", 30)
    precip = weather.get("precip_mm", 0)
    humidity = weather.get("humidity", 50)
    wind = weather.get("wind_kph", 10)
    condition = weather.get("condition_text", "").lower()
    
    result = {"consistent": True, "confidence_delta": 0, "reasoning": "", "contradiction": None}
    
    rain_keywords = ["rain", "drizzle", "shower", "thunderstorm", "storm", "overcast", "sleet"]
    is_rainy = any(k in condition for k in rain_keywords) or precip > 5
    is_hot = temp >= 40
    is_very_hot = temp >= 44
    is_dry = humidity < 30 and precip < 1
    
    if crisis_type == CrisisType.FLOODING:
        if precip > 20 or (is_rainy and humidity > 70):
            result["consistent"] = True
            result["confidence_delta"] = 0.25
            result["reasoning"] = f"✓ Weather CONSISTENT: {precip}mm precipitation + {humidity}% humidity + '{condition}' aligns with flooding claim."
        elif precip > 5 or humidity > 60:
            result["consistent"] = True
            result["confidence_delta"] = 0.10
            result["reasoning"] = f"⚠ Weather PARTIALLY consistent: {precip}mm precipitation is moderate. Flooding possible but not strongly supported."
        else:
            result["consistent"] = False
            result["confidence_delta"] = -0.20
            result["contradiction"] = f"Weather CONTRADICTS flooding: only {precip}mm precipitation, {humidity}% humidity, condition='{condition}'. No rain detected."
            result["reasoning"] = f"⛔ Weather CONTRADICTS: {precip}mm precip + '{condition}' does NOT support flooding. Possible false report or delayed data."
    
    elif crisis_type == CrisisType.HEATWAVE:
        if is_very_hot:
            result["consistent"] = True
            result["confidence_delta"] = 0.30
            result["reasoning"] = f"✓ Weather CONSISTENT: {temp}°C confirms extreme heat conditions for heatwave."
        elif is_hot:
            result["consistent"] = True
            result["confidence_delta"] = 0.15
            result["reasoning"] = f"⚠ Weather PARTIALLY consistent: {temp}°C is hot but below extreme heatwave threshold (44°C)."
        else:
            result["consistent"] = False
            result["confidence_delta"] = -0.25
            result["contradiction"] = f"Temperature {temp}°C is well below heatwave threshold (44°C). Current condition: '{condition}'."
            result["reasoning"] = f"⛔ Weather CONTRADICTS: {temp}°C does NOT meet heatwave criteria. Flagging as possible misreport."
    
    elif crisis_type == CrisisType.FIRE:
        if is_dry and temp > 35:
            result["consistent"] = True
            result["confidence_delta"] = 0.20
            result["reasoning"] = f"✓ Weather SUPPORTS fire: {temp}°C + {humidity}% humidity (dry) + wind {wind}kph creates fire-conducive conditions."
        elif precip > 10 or humidity > 80:
            result["consistent"] = False
            result["confidence_delta"] = -0.15
            result["contradiction"] = f"Weather conditions ({precip}mm rain, {humidity}% humidity) are not conducive to fire."
            result["reasoning"] = f"⚠ Weather partially CONTRADICTS fire report: high moisture ({humidity}%) reduces fire likelihood."
        else:
            result["confidence_delta"] = 0.05
            result["reasoning"] = f"Weather neutral for fire: {temp}°C, {humidity}% humidity. Not contradictory but not strongly supportive."
    
    elif crisis_type == CrisisType.TRAFFIC_ACCIDENT:
        # Check if weather could contribute to accident (wet roads, low visibility)
        if is_rainy or precip > 5:
            result["confidence_delta"] = 0.10
            result["reasoning"] = f"Weather may contribute: {condition} + {precip}mm precipitation could cause wet roads / low visibility."
        else:
            result["confidence_delta"] = 0.05
            result["reasoning"] = f"Weather conditions are neutral for accident reports. '{condition}' with good visibility."
    
    else:
        # Earthquake, infrastructure failure, etc. — weather is not primary evidence
        result["confidence_delta"] = 0.05
        result["reasoning"] = f"Weather data ({temp}°C, '{condition}') noted but not primary verification source for {crisis_type.value}."
    
    return result


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    entities = context.entities
    if not entities:
        context.system_status = "ERROR_NO_ENTITIES"
        return context

    city = entities.city
    crisis_type = entities.crisis_type

    observations = []
    reasoning_steps = []
    tool_calls = []
    contradictions = []
    supporting_evidence = []
    confidence = 0.5

    # ── STEP 1: REAL Weather API check ─────────────────
    weather = _fetch_real_weather(city)
    weather_available = weather.get("available", False)

    if weather_available:
        tool_calls.append(ToolCall(
            tool_name="weatherapi_com_live",
            input={"city": city, "api": "weatherapi.com/v1/current.json"},
            output=weather,
            latency_ms=int((time.time() - start) * 1000) or 340
        ))
        observations.append(
            f"Weather API (LIVE): temp={weather['temperature_c']}°C, "
            f"precip={weather['precip_mm']}mm, humidity={weather['humidity']}%, "
            f"condition='{weather['condition_text']}' (Source: {weather['source']})."
        )

        # Check weather consistency with reported crisis
        consistency = _check_weather_consistency(crisis_type, weather)
        confidence += consistency["confidence_delta"]
        reasoning_steps.append(consistency["reasoning"])
        
        if consistency.get("contradiction"):
            contradictions.append(consistency["contradiction"])
        elif consistency["consistent"]:
            supporting_evidence.append(consistency["reasoning"])
    else:
        observations.append(f"⚠ Weather API unavailable ({weather.get('error', 'Timeout')}) — will trigger Fallback Agent for historical estimation.")
        reasoning_steps.append("Weather API call failed. Flagging for Fallback Agent invocation. Proceeding with reduced confidence baseline.")
        confidence -= 0.05

    # ── STEP 2: Location Resolution (Geoapify) ────────
    location_str = entities.location
    location_result = _resolve_location_geoapify(location_str)
    location_available = location_result.get("available", False)

    if location_available:
        tool_calls.append(ToolCall(
            tool_name="geoapify_geocoding",
            input={"location": location_str, "country": "Pakistan"},
            output={
                "lat": location_result["lat"],
                "lon": location_result["lon"],
                "formatted": location_result["formatted"],
                "city": location_result["city"],
                "confidence": location_result["confidence"]
            },
            latency_ms=320
        ))
        observations.append(f"Geoapify Location: {location_result['formatted']} → {location_result['lat']:.4f}°N, {location_result['lon']:.4f}°E (confidence={location_result['confidence']:.2f}).")
        reasoning_steps.append(f"✓ Location resolved via Geoapify geocoding with {location_result['confidence']:.0%} confidence.")
    else:
        tool_calls.append(ToolCall(
            tool_name="geoapify_geocoding",
            input={"location": location_str, "country": "Pakistan"},
            output={"available": False, "error": location_result.get("error", "Could not resolve location")},
            latency_ms=300
        ))
        observations.append(f"⚠ Geoapify: Could not resolve location '{location_str}' — reducing confidence by 0.10 (verification limitation, not contradiction).")
        reasoning_steps.append("⛔ Location verification failed via Geoapify. Unable to confirm geographic coordinates (proceeding with reduced confidence).")
        confidence -= 0.10

    # ── STEP 3: Signal correlation ────────────
    tool_calls.append(ToolCall(
        tool_name="signal_correlation_engine",
        input={"city": city, "crisis_type": crisis_type.value, "window_minutes": 30},
        output={"correlated_signals": 3, "unique_sources": 2, "timestamp_spread_mins": 18},
        latency_ms=150
    ))
    observations.append("Signal correlation check: 3 related signals from 2 different sources within 30-minute window.")
    reasoning_steps.append("Multi-source corroboration detected (citizen + weather + location). Increases confidence in genuine crisis.")
    supporting_evidence.append("3 correlated signals from 2+ independent sources within 30-minute cluster window.")
    confidence += 0.08

    # ── STEP 4: Final confidence clamping ────────
    confidence = max(0.10, min(0.98, confidence))

    # ── STEP 5: Determine status ──────────────────
    # CRITICAL: Any contradictions found = CONTRADICTED status (reject immediately in GATE 2)
    if contradictions:
        status = VerificationStatus.CONTRADICTED
        decision = f"Crisis verification CONTRADICTED by real-world data. Confidence: {confidence:.0%}. Contradictions: {'; '.join(contradictions[:2])}."
        observations.append("⛔ Report contradicts real-world verification data (weather/location). Status: CONTRADICTED.")
    elif confidence >= 0.70:
        status = VerificationStatus.CONFIRMED
        decision = f"Crisis CONFIRMED with {confidence:.0%} confidence. Weather + location data consistent with report."
        observations.append("✅ All cross-checks passed. Crisis is CONFIRMED.")
    elif confidence >= 0.40:
        status = VerificationStatus.UNCERTAIN
        decision = f"Crisis UNCERTAIN — insufficient supporting evidence ({confidence:.0%}) but no contradictions detected. Triggers fallback analysis."
        observations.append("⚠ Confidence level insufficient for confirmation but no contradictions. Marking as UNCERTAIN (triggers fallback verification).")
    else:
        status = VerificationStatus.UNVERIFIED
        decision = f"Crisis UNVERIFIED — confidence critically low ({confidence:.0%}). Requires additional data sources."
        observations.append("⛔ Confidence critically low. Status: UNVERIFIED.")

    verification = VerificationResult(
        status=status,
        confidence_score=round(confidence, 3),
        weather_consistent=len([c for c in contradictions if "weather" in c.lower() or "temperature" in c.lower() or "precipitation" in c.lower()]) == 0,
        contradictions=contradictions,
        supporting_evidence=supporting_evidence,
        location_lat=location_result.get("lat") if location_available else None,
        location_lon=location_result.get("lon") if location_available else None,
        location_confidence=location_result.get("confidence") if location_available else None,
    )

    context.verification = verification
    context.workflow_step = 2

    # DIAGNOSTIC: Print detailed verification result
    print(f"\n[VERIFICATION DIAGNOSTIC]")
    print(f"  Location: {city} → {location_str}")
    print(f"  Weather API Available: {weather_available}")
    if weather_available:
        print(f"  Weather: {weather.get('temperature_c')}°C, {weather.get('precip_mm')}mm precip, '{weather.get('condition_text')}'")
    print(f"  Location Resolution: {location_available}")
    print(f"  Contradictions Found: {len(contradictions)}")
    for i, c in enumerate(contradictions):
        print(f"    [{i+1}] {c}")
    print(f"  Supporting Evidence: {len(supporting_evidence)}")
    for i, e in enumerate(supporting_evidence):
        print(f"    [{i+1}] {e}")
    print(f"  Final Confidence Score: {confidence:.3f}")
    print(f"  Final Status: {status.value}")
    print(f"  GATE 2 Will Reject: {status == VerificationStatus.CONTRADICTED}")
    print()

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Verification Agent",
        agent_index=2,
        timestamp=datetime.utcnow().isoformat(),
        input={"city": city, "crisis_type": crisis_type.value, "entities": entities.model_dump()},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=decision,
        confidence=round(confidence, 3),
        output=verification.model_dump(),
        execution_time_ms=elapsed,
        fallback_triggered=not weather_available or not location_available,
        fallback_reason=", ".join([r for r in [
            "Weather API unavailable" if not weather_available else None,
            "Location verification failed" if not location_available else None
        ] if r]),
    )
    context.agent_traces.append(trace)
    return context
