# SAHARA AI — Production Deployment (no credit card needed)

Total time: ~15 minutes.

---

## Step 1 · Firebase Service Account

You have a Firebase project (sahara-9c923). Now get the **backend** credentials:

1. Open: https://console.firebase.google.com/project/sahara-9c923/settings/serviceaccounts/adminsdk
2. Click **Generate new private key** → **Generate key** → downloads `sahara-9c923-firebase-adminsdk-XXXXX.json`
3. **Enable Realtime Database** (different from Firestore, which is what we want):
   - Sidebar → **Build → Realtime Database** → **Create Database** → **Singapore** → **Test mode**
   - Copy the URL at the top (something like `https://sahara-9c923-default-rtdb.firebaseio.com`) — save this as **`FIREBASE_DB_URL`**

> The `google-services.json` you already have is for the Android client app (gets embedded in the APK). The service account JSON is the *backend* identity — totally different file.

---

## Step 2 · Koyeb deployment (no credit card)

1. Sign up at https://app.koyeb.com — use GitHub login, **no card needed**
2. Click **Create App** → **GitHub** → connect → select `Anti-gravity-Hackathon`
3. Configure:
   - **Branch:** `main`
   - **Builder:** `Buildpack`
   - **Work directory:** `sahara_backend`
   - **Build command:** `pip install -r requirements.txt`
   - **Run command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Port:** `8000` (HTTP)
   - **Health check path:** `/healthz`
   - **Region:** Frankfurt
   - **Instance type:** `Free`

4. Click **Environment variables** → paste these (replace placeholders with your real values from `.env`):

| Variable | Value |
|---|---|
| `GEMINI_API_KEY` | your Gemini key |
| `WEATHERAPI_KEY` | your WeatherAPI key |
| `GEOAPIFY_API_KEY` | your Geoapify key |
| `TWILIO_ACCOUNT_SID` | your Twilio SID |
| `TWILIO_AUTH_TOKEN` | your Twilio token |
| `TWILIO_WHATSAPP_FROM` | `+14155238886` |
| `WHATSAPP_NUMBER` | `923250909907` |
| `FIREBASE_ENABLED` | `true` |
| `FIREBASE_DB_URL` | from Step 1 |
| `FIREBASE_CREDENTIALS_JSON` | the entire service-account JSON, on one line (or use Koyeb's multi-line input) |

5. Click **Deploy** → first build takes 4–6 min → you get a URL like **`https://sahara-ai-<random>.koyeb.app`**

### Verify it works
- `https://sahara-ai-<random>.koyeb.app/health` → returns `{"status":"healthy","firebase_connected":true,...}`
- `https://sahara-ai-<random>.koyeb.app/app/` → the Flutter web app
- `https://sahara-ai-<random>.koyeb.app/api/live-crises` → auto-seeded crises

---

## Step 3 · Tell GitHub the production URL

1. Go to https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/settings/secrets/actions
2. Click **New repository secret**
3. Name: `SAHARA_API_BASE_URL`
4. Value: your Koyeb URL (e.g. `https://sahara-ai-<random>.koyeb.app`)
5. **Add secret**

---

## Step 4 · Rebuild APK against production

Either:
- Push any commit → APK auto-rebuilds
- OR go to https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/actions/workflows/build-apk.yml → **Run workflow**

After ~5 min the new APK appears on:
**https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/releases/latest**

This APK talks directly to your Koyeb backend. Works on any Android phone.

---

## Step 5 · Point Twilio to production

1. https://console.twilio.com → **Messaging → Try it out → Send a WhatsApp message → Sandbox settings**
2. Field "When a message comes in": `https://sahara-ai-<random>.koyeb.app/api/whatsapp/incoming`
3. Method: `HTTP POST` → **Save**

---

## Submission summary

| Asset | URL |
|---|---|
| Live web app | `https://sahara-ai-<random>.koyeb.app/app/` |
| API docs | `https://sahara-ai-<random>.koyeb.app/docs` |
| APK download | https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/releases/latest |
| Source | https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon |
| WhatsApp helpline | `+1 415 523 8886` (Twilio sandbox) |
| Persistent DB | Firebase Realtime DB |

---

## Free-tier alternatives if Koyeb gives trouble

| Platform | Card? | Notes |
|---|---|---|
| **Koyeb** ⭐ | No | Recommended. 1 free service. |
| Hugging Face Spaces | No | FastAPI fully supported, 16GB RAM. Slower regions. |
| Render | Yes | Was best, now requires card |
| Railway | No (initially) | $5 free credit then needs card |
| Fly.io | Yes | More technical, Docker-based |
| Vercel | No | Serverless — needs FastAPI adapter (`mangum`) |

---

## Troubleshooting

- **Koyeb build fails on `firebase-admin`** → make sure Python version is 3.11+ in Koyeb settings.
- **`firebase_connected: false`** → JSON env var is malformed. Try Koyeb's multi-line var input, or escape newlines as `\n`.
- **APK shows "connection error"** → `SAHARA_API_BASE_URL` secret wasn't set before the APK was built. Set it (Step 3), then re-run workflow (Step 4).
- **Cold start delay** → free tier sleeps after ~30 min idle; first request takes ~10s. Hit `/healthz` once before demoing.
