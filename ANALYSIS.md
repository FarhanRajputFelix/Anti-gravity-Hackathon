# SAHARA AI - 24-Hour Implementation Analysis & Action Plan

**Current Time: 23:10 May 19, 2026**  
**Submission Deadline: 23:59 May 20, 2026**  
**Time Remaining: ~24 hours (accounting for sleep/meals/classes)**

---

## PART 1: CURRENT STATE ANALYSIS

### ✅ What Already Works
1. **Agent Pipeline Foundation** - Orchestrator correctly sequences 6 agents
2. **Crisis Context Propagation** - State correctly flows through agents
3. **Gemini Integration** - API key handling and async calls work
4. **Firebase Persistence** - Crisis storage implemented
5. **Agent Traces** - Detailed logging of each step

### ❌ Critical Gaps

#### Gap 1: No Input Validation / Gate Keeper
- **Problem**: Signal Ingestion Agent accepts ANYTHING (even "asasasass")
- **Current Code**: `detect_crisis_type()` defaults to `UNKNOWN` for gibberish - it doesn't reject
- **Result**: Nonsense text runs through ALL 6 agents, wasting compute and confusing output
- **Location**: `agents/signal_ingestion.py` lines 68-78
- **Impact**: HIGH - judges will immediately see "asasasass" → 6 agents running

#### Gap 2: No WhatsApp Integration
- **Problem**: Zero WhatsApp webhook implementation exists
- **Current**: App only accepts manual JSON posts via `/api/analyze`
- **Missing**: 
  - WhatsApp webhook router (`/webhook/whatsapp`)
  - WhatsApp message receiver
  - WhatsApp reply sender
  - Meta verification handshake
- **Location**: No routers/whatsapp.py exists
- **Impact**: CRITICAL - entire citizen input channel blocked

#### Gap 3: No Verification Gate
- **Problem**: Unverified crises still flow to Firebase and map
- **Current Code**: Orchestrator saves EVERY crisis, regardless of verification status
- **Location**: `orchestrator.py` lines 375-388 (always writes to Firebase)
- **Expected**: Only save if `verification.status == CONFIRMED`
- **Impact**: HIGH - invalid reports appear on the map

#### Gap 4: Over-Engineered for Deadline
- **Problem**: 6-agent pipeline requires all to complete successfully
- **Current**: Severity Analysis → Response Planning → Execution Simulation → Fallback (8 steps total)
- **ChatGPT's Recommendation**: Collapse to 4 agents
  - Agent 1: Parser (reject noise)
  - Agent 2: Multi-Signal Verification
  - Agent 3: Response Planning
  - Agent 4: Dispatcher (Firebase + WhatsApp)
- **Issue**: One agent failure blocks the rest; Execution Simulation adds no demo value
- **Impact**: MEDIUM - adds complexity, risk of timeouts

#### Gap 5: No Crisis Confidence Filtering Before DB Write
- **Problem**: Confidence scores calculated but ignored for persistence
- **Code**: Line 263-280 in verification.py calculates status → but orchestrator ignores it
- **Expected**: If `confidence < 0.65` → don't save
- **Impact**: HIGH - false positives persist in database

---

## PART 2: WHAT NEEDS TO BE BUILT (Priority Order)

### Phase 0: Deploy Backend (DO TODAY)
**Time: 2-3 hours**
- [ ] Push to Railway / Render / Google Cloud Run
- [ ] Get public HTTPS URL (e.g., `https://sahara-backend.railway.app`)
- [ ] Test `/health` endpoint responds
- **Why First**: WhatsApp webhook requires public URL; Meta won't accept localhost

### Phase 1: Input Gate + Noise Filter (DO FIRST)
**Time: 1.5 hours**
- Modify `agents/signal_ingestion.py`
  - Add Gemini confidence check: "Is this a real crisis report?"
  - If Gemini confidence < 0.6, return `{"status": "REJECTED", "reason": "Not a crisis"}`
  - Stop pipeline immediately
- Test with: "asasasass", "hello", "what's the weather", "G-10 mein pani"
- **Why**: Prevents garbage from running through entire pipeline

### Phase 2: WhatsApp Webhook (DO SECOND)
**Time: 2-3 hours**
- Create `routers/whatsapp.py` with:
  - `GET /webhook/whatsapp` - Meta verification handshake
  - `POST /webhook/whatsapp` - Receive incoming messages
  - Extract sender, text, image URL from Meta payload
  - Call orchestrator.analyze() with the text
  - **On Response**: Send WhatsApp reply to citizen
- Update `main.py` to register the route
- **Environment Variables** (add to `.env`):
  - `WHATSAPP_PHONE_NUMBER_ID`
  - `WHATSAPP_ACCESS_TOKEN`
  - `WHATSAPP_VERIFY_TOKEN`
- **Why**: Enables citizen input channel judges expect to see

### Phase 3: Verification Gate (DO THIRD)
**Time: 30 minutes**
- Modify `orchestrator.py` lines 375-388
  - Add check: `if context.verification.status != VerificationStatus.CONFIRMED: return (without saving)`
  - OR: Add confidence check: `if context.verification.confidence_score < 0.65: return`
- Only write to Firebase if verified
- **Why**: Prevents false positives from appearing on live map

### Phase 4: Simplify Agent Pipeline (DO FOURTH - OPTIONAL IF TIME)
**Time: 1-2 hours**
- Collapse 6 agents → 4 agents (per ChatGPT recommendation):
  1. **Parser Agent**: Input validation + structuring (Gemini)
  2. **Verification Agent**: Weather + Maps + Confidence (keep mostly as-is)
  3. **Response Planning Agent**: Generate response (collapse Severity + Response into one)
  4. **Dispatcher**: Firebase write + WhatsApp reply
- Remove: Execution Simulation, fallback as separate agent
- **Why**: Fewer failure points; faster execution; less code to debug
- **Risk**: If this breaks other agents mid-way, revert to current 6-agent

### Phase 5: Demo-Critical Features
**Time: 1-2 hours (after everything above)**
- [ ] Flutter map shows crisis pins in real-time from Firebase
- [ ] WhatsApp test: Send message via Meta test number → map updates
- [ ] Agent traces visible in web dashboard `/dashboard`
- [ ] Rejection messages: "asasasass" → WhatsApp reply "Not a valid crisis report"

---

## PART 3: IMPLEMENTATION CHECKLIST (Do In This Order)

### HOURS 1-3 (Today, before sleep)
```
[ ] Deploy backend to Railway/Render
[ ] Get public URL
[ ] Test /health endpoint
[ ] Update .env with WHATSAPP_* variables (keep as placeholder for now)
```

### HOURS 4-5 (After classes, Day 2 early morning)
```
[ ] Create routers/whatsapp.py
    - GET /webhook/whatsapp (Meta verification)
    - POST /webhook/whatsapp (receive message)
    - Send reply back to citizen
[ ] Register route in main.py
[ ] Test locally with curl (POST /webhook/whatsapp with mock payload)
```

### HOURS 6-7
```
[ ] Modify agents/signal_ingestion.py
    - Add Gemini validation: "Is this a real crisis?"
    - Return REJECTED if confidence < 0.6
    - Stop pipeline on rejection
[ ] Test with test strings: "asasasass", "hello", "G-10 mein pani"
```

### HOURS 8-9
```
[ ] Modify orchestrator.py
    - Add verification gate: only save if status == CONFIRMED OR confidence >= 0.65
    - Return early if not verified (send citizen WhatsApp: "Could not verify")
[ ] Test: Send unverified crisis → should NOT appear in /api/logs or map
```

### HOURS 10-11
```
[ ] Set up Meta Business Account (if not done)
[ ] Create WhatsApp Business app
[ ] Get WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_ACCESS_TOKEN
[ ] Register webhook in Meta dashboard
[ ] Test with Meta test number
```

### HOURS 12-13
```
[ ] Confirm Flutter app:
    - Reads Firebase in real-time
    - Shows crisis pins on map
    - Displays verification status
[ ] Test: Send WhatsApp message → Firebase updates → Flutter shows pin
```

### HOURS 14-15
```
[ ] Polish UI:
    - Rejection messages clear to user
    - Agent traces readable
    - Map responsive
[ ] Test full flow: WhatsApp → Agents → Firebase → Flutter
```

### HOURS 16-20
```
[ ] Documentation + README
[ ] Prepare demo script
[ ] Backup original code (git branch)
[ ] Final testing
```

### HOURS 21-24
```
[ ] Sleep + classes
[ ] Final submission
[ ] Demo prep (have phone ready for WhatsApp test)
```

---

## PART 4: EXACT CODE CHANGES NEEDED

### Change 1: agents/signal_ingestion.py - Add Gate Keeper Logic

**Before** (current line 111-208):
```python
def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    signal = context.signals[0] if context.signals else None
    # ... detects crisis type, always returns something
    # Returns context with entities populated
```

**After** (add at the beginning of run()):
```python
async def _validate_crisis_with_gemini(text: str) -> dict:
    """Use Gemini to validate if text describes a real crisis."""
    import google.generativeai as genai
    from dotenv import load_dotenv
    import os
    
    load_dotenv()
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        return {"valid": True, "confidence": 0.5}  # Fallback: assume valid
    
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-flash-latest")
        prompt = f"""You are a crisis report validator. Determine if this text describes a REAL crisis or emergency.

Text: "{text}"

Is this a genuine crisis/emergency report? Answer with JSON:
{{"valid": true/false, "confidence": 0.0-1.0, "reason": "brief explanation"}}

REAL crises: floods, fires, accidents, heatwaves, medical emergencies, infrastructure failure, crime, infrastructure damage
FAKE/INVALID: gibberish, greetings, jokes, random characters, off-topic questions, "hello", "test", "asasasass"

Be strict. Require clear evidence of a crisis."""

        response = model.generate_content(prompt)
        import json
        result = json.loads(response.text)
        return result
    except Exception as e:
        print(f"[GATE KEEPER] Gemini validation failed: {e}")
        return {"valid": True, "confidence": 0.5}

def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    signal = context.signals[0] if context.signals else None
    
    if not signal:
        context.system_status = "ERROR_NO_SIGNAL"
        return context
    
    text = signal.text
    
    # ──── NEW: GATE KEEPER VALIDATION ────
    validation = await _validate_crisis_with_gemini(text)
    if validation["confidence"] < 0.60:
        context.system_status = "REJECTED_INVALID_INPUT"
        # Return early - don't process further
        trace = AgentTrace(
            agent_name="Signal Ingestion Agent (Gate Keeper)",
            agent_index=1,
            timestamp=datetime.utcnow().isoformat(),
            input={"signal": text},
            observations=[f"Input validation: {validation['reason']}"],
            reasoning_steps=["Gate keeper rejected input. Not a valid crisis report."],
            tool_calls=[],
            decision="REJECTED - Input is not a crisis report",
            confidence=validation["confidence"],
            output={"status": "REJECTED", "reason": validation["reason"]},
            execution_time_ms=int((time.time() - start) * 1000),
            fallback_triggered=False,
        )
        context.agent_traces.append(trace)
        return context  # Stop here
    # ──── END: GATE KEEPER ────
    
    # Rest of existing code...
```

### Change 2: orchestrator.py - Add Verification Gate

**Before** (lines 375-388):
```python
# Store in memory + log + Firebase
result_payload = result.model_dump()
log_payload = {...}
CRISIS_STORE[context.crisis_id] = result_payload
LOG_STORE.append(log_payload)
firebase.save_crisis(context.crisis_id, result_payload)  # Always saves
firebase.save_log(log_payload)
return result
```

**After**:
```python
# ──── NEW: VERIFICATION GATE ────
if context.verification and context.verification.status == VerificationStatus.CONFIRMED:
    verified = True
elif context.verification and context.verification.confidence_score >= 0.65:
    verified = True
else:
    verified = False

if verified:
    # Store in memory + log + Firebase
    result_payload = result.model_dump()
    log_payload = {...}
    CRISIS_STORE[context.crisis_id] = result_payload
    LOG_STORE.append(log_payload)
    firebase.save_crisis(context.crisis_id, result_payload)
    firebase.save_log(log_payload)
else:
    # Log rejection but don't persist
    print(f"[ANTIGRAVITY] Crisis {context.crisis_id} REJECTED - confidence {context.verification.confidence_score if context.verification else 0:.0%} below threshold. Not saved to database.")
    log_payload = {
        "crisis_id": context.crisis_id,
        "status": "REJECTED",
        "timestamp": context.created_at,
        "confidence": context.verification.confidence_score if context.verification else 0,
        "reason": "Failed verification gate"
    }
    LOG_STORE.append(log_payload)

return result
```

### Change 3: Create routers/whatsapp.py

```python
"""SAHARA AI — WhatsApp Cloud API Integration
Receives citizen crisis reports via WhatsApp, processes through agents, replies.
"""

import os
import hashlib
import hmac
import json
import httpx
from fastapi import APIRouter, Request, HTTPException
from dotenv import load_dotenv
from models import CrisisSignal
from orchestrator import orchestrator

load_dotenv()

router = APIRouter()

# WhatsApp configuration
WHATSAPP_PHONE_NUMBER_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
WHATSAPP_ACCESS_TOKEN = os.getenv("WHATSAPP_ACCESS_TOKEN", "")
WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "sahara_verify_2026")


def _send_whatsapp_message(phone_number: str, message: str) -> bool:
    """Send a reply message back to the citizen via WhatsApp API."""
    if not WHATSAPP_ACCESS_TOKEN or not WHATSAPP_PHONE_NUMBER_ID:
        print(f"[WHATSAPP] Skipping reply (no credentials). Would send to {phone_number}: {message}")
        return False
    
    try:
        url = f"https://graph.instagram.com/v18.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"
        headers = {
            "Authorization": f"Bearer {WHATSAPP_ACCESS_TOKEN}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": phone_number,
            "type": "text",
            "text": {"body": message},
        }
        response = httpx.post(url, json=payload, headers=headers, timeout=10)
        return response.status_code == 200
    except Exception as e:
        print(f"[WHATSAPP] Failed to send reply to {phone_number}: {e}")
        return False


@router.get("/webhook/whatsapp")
async def verify_webhook(request: Request):
    """Meta's verification handshake for webhook setup."""
    hub_mode = request.query_params.get("hub.mode")
    hub_token = request.query_params.get("hub.verify_token")
    hub_challenge = request.query_params.get("hub.challenge")
    
    if hub_mode == "subscribe" and hub_token == WHATSAPP_VERIFY_TOKEN:
        return {"hub.challenge": hub_challenge}
    
    raise HTTPException(status_code=403, detail="Invalid verification token")


@router.post("/webhook/whatsapp")
async def receive_whatsapp_message(request: Request):
    """Receive incoming WhatsApp messages from citizens."""
    payload = await request.json()
    
    # Meta sends webhook notifications in a specific format
    entry = payload.get("entry", [{}])[0]
    changes = entry.get("changes", [{}])[0]
    value = changes.get("value", {})
    messages = value.get("messages", [])
    
    if not messages:
        # Not a message (e.g., status update)
        return {"status": "ok"}
    
    msg = messages[0]
    sender = msg.get("from")  # Phone number
    text = ""
    image_url = None
    
    # Extract message content (text or image)
    if "text" in msg:
        text = msg["text"].get("body", "")
    elif "image" in msg:
        # Image with optional caption
        image_data = msg["image"]
        image_url = image_data.get("link")
        text = f"[Image received] {image_url}"  # For now, pass URL as text
    else:
        text = "[Unsupported message type]"
    
    if not text or not sender:
        return {"status": "ignored"}
    
    print(f"[WHATSAPP] Received from {sender}: {text[:80]}")
    
    # Pass to crisis analysis pipeline
    signal = CrisisSignal(
        text=text,
        source="whatsapp_citizen_report",
        location_hint=None,  # Agent will extract this
    )
    
    try:
        result = await orchestrator.analyze(signal)
        
        # Prepare reply based on verification status
        if result.verification_status == "CONFIRMED":
            reply = f"✅ Crisis reported: {result.crisis_type} in {result.city}. Response teams notified. Incident ID: {result.crisis_id}"
        elif result.verification_status == "UNCERTAIN":
            reply = f"⚠️ Report received but verification pending. Incident ID: {result.crisis_id}. Please confirm."
        else:
            reply = f"❌ Could not verify this as a crisis. If you have an emergency, please call 1122."
        
        # Send reply to citizen
        _send_whatsapp_message(sender, reply)
        
        return {
            "status": "processed",
            "crisis_id": result.crisis_id,
            "verification": result.verification_status,
            "reply_sent": True,
        }
    
    except Exception as e:
        print(f"[WHATSAPP] Error processing message: {e}")
        _send_whatsapp_message(sender, "❌ System error. Please try again.")
        return {"status": "error", "detail": str(e)}
```

### Change 4: main.py - Register WhatsApp Router

**Before** (line 12-14):
```python
from routers.analyze import router as analyze_router
from routers.other import router as other_router
from routers.workflow import router as workflow_router
```

**After**:
```python
from routers.analyze import router as analyze_router
from routers.other import router as other_router
from routers.workflow import router as workflow_router
from routers.whatsapp import router as whatsapp_router
```

And register it (after line 35):
```python
app.include_router(whatsapp_router, prefix="/api", tags=["WhatsApp Citizen Reports"])
```

### Change 5: .env.example - Add WhatsApp Variables

**Add these lines**:
```env
# Meta WhatsApp Cloud API — for citizen crisis reports
# Get these from: developers.facebook.com > Your App > WhatsApp > Configuration
WHATSAPP_PHONE_NUMBER_ID=your_phone_number_id_here
WHATSAPP_ACCESS_TOKEN=your_access_token_here
WHATSAPP_VERIFY_TOKEN=sahara_verify_2026
```

---

## PART 5: WHAT TO TELL CLAUDE CODE

Once you've read this plan, give Claude Code this prompt:

```
I need WhatsApp integration + input validation for SAHARA AI before 11:59 PM May 20.
Submission is 24 hours away. Here's exactly what to implement:

1. Create routers/whatsapp.py with:
   - GET /webhook/whatsapp for Meta verification handshake
   - POST /webhook/whatsapp to receive citizen messages
   - Extract sender phone, message text, image URL from Meta payload
   - Call orchestrator.analyze() with the text
   - Send WhatsApp reply using Meta API
   
2. Modify agents/signal_ingestion.py:
   - Add Gemini validation at the start: "Is this a real crisis?"
   - If confidence < 0.6, return {"status": "REJECTED"} and STOP pipeline
   - Test with: "asasasass" (should be rejected), "G-10 mein pani" (should pass)
   
3. Modify orchestrator.py:
   - Add verification gate before saving to Firebase
   - Only save if verification.status == "CONFIRMED" OR confidence >= 0.65
   - Unverified crises should NOT be written to database
   
4. Register whatsapp router in main.py at path /api/webhook/whatsapp

5. Add WHATSAPP_* variables to .env.example

Environment variables you'll need:
- GEMINI_API_KEY (should already be set)
- WHATSAPP_PHONE_NUMBER_ID (from Meta)
- WHATSAPP_ACCESS_TOKEN (from Meta)
- WHATSAPP_VERIFY_TOKEN=sahara_verify_2026

The goal: Demo judges can send a WhatsApp message → app processes it through agents → 
only verified crises save to Firebase → Flutter map updates → judges see live crisis pin.
Test with "asasasass" first to confirm it gets rejected.
```

---

## SUMMARY

| What | Status | Impact | Timeline |
|------|--------|--------|----------|
| Deploy Backend | Not Done | CRITICAL | Hours 1-3 |
| WhatsApp Router | Not Done | CRITICAL | Hours 4-5 |
| Input Gate Keeper | Not Done | CRITICAL | Hours 6-7 |
| Verification Gate | Not Done | HIGH | Hours 8-9 |
| Simplify Agents | Optional | MEDIUM | Hours 10-11 (if time) |
| Final Testing | Not Done | CRITICAL | Hours 12-15 |

**You are NOT behind. You have everything needed. Focus on the three gates in order:**
1. Reject gibberish (Gate Keeper)
2. Verify crises (Verification Gate)
3. Accept WhatsApp input (WhatsApp Router)

Everything else already works.
