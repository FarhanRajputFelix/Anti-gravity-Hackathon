# SAHARA AI - Antigravity Development Plan & Walkthrough

## Vision
Build Pakistan's first Agentic Urban Crisis Response system that ingests
multi-source signals (citizen reports, news RSS, weather, earthquakes,
WhatsApp), runs a 6-agent Antigravity-orchestrated pipeline, and dispatches
verified responses with hospital + shelter routing.

## 6-Agent Pipeline (Antigravity Orchestrator)

1. **Signal Ingestion Agent**
   - Multilingual (English, Urdu, Roman Urdu) text classification
   - 35+ Pakistani city detection (Sindh, KP, Balochistan, AJK, GB, Punjab)
   - Gemini AI fallback for obscure cities
   - Early-rejection gate: if no crisis type AND no city -> halt pipeline

2. **Verification Agent**
   - Cross-checks claim against WeatherAPI.com (live), traffic API, signal correlation
   - Computes confidence 0.10-0.98
   - UNKNOWN crises can never reach AUTHENTIC
   - Returns CONFIRMED / UNCERTAIN / CONTRADICTED / UNVERIFIED

3. **Severity Analysis Agent**
   - Population impact estimation, infrastructure risk modelling
   - LOW / MEDIUM / HIGH / CRITICAL classification

4. **Response Planning Agent**
   - Template-driven action plan: rescue, alerts, medical, traffic, evacuation
   - Department dispatch: PDMA, Rescue 1122, Edhi, NDMA

5. **Execution Simulation Agent**
   - Before/after congestion modelling
   - Population helped estimation, alerts broadcast count

6. **Fallback & Recovery Agent**
   - System health audit, fallback strategies if APIs fail
   - Historical baseline injection

## Real Data Sources Integrated
- Gemini 1.5 Flash / 2.0 Flash (LLM reasoning, vision for image inputs)
- WeatherAPI.com (live weather)
- Geoapify Places API (hospitals, shelters, police stations, fire stations)
- Geoapify Routing API (emergency routes)
- USGS Earthquake API (real-time, Pakistan region)
- Pakistani RSS news (Dawn, Geo, ARY, Tribune, The News) - polled every 90s
- Twilio WhatsApp Sandbox (helpline number +14155238886)
- Firebase Realtime Database (persistence)

## Deployment
- Backend: Hugging Face Spaces (Docker SDK, no credit card)
- APK: GitHub Actions auto-build pipeline, published to Releases
- Web App: served from same backend at /app/
- WhatsApp webhook: Twilio sandbox -> /api/whatsapp/incoming

## Key Innovations
1. Early-rejection at Agent 1 saves compute on junk input
2. Admin-approval flow for WhatsApp - human in the loop before dispatch
3. Multi-source signal correlation prevents false escalation
4. Cinematic Flutter map: world -> Pakistan -> exact crisis city zoom
5. Multi-color emergency routes appear only AFTER agents verify AUTHENTIC
