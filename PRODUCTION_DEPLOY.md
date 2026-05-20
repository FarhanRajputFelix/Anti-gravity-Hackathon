# SAHARA AI — Production Deployment

This guide takes you from code → public backend → persistent database → APK pointing to production. **~15 minutes total.**

---

## Step 1 · Firebase Realtime Database

You said you already signed up. Now:

1. Go to https://console.firebase.google.com
2. Click **Add project** → name it `sahara-ai` → continue
3. In the left sidebar: **Build → Realtime Database**
4. Click **Create Database** → choose **Singapore** location → start in **Test mode**
5. Copy your database URL (top of the page) — looks like `https://sahara-ai-default-rtdb.firebaseio.com` → save it as `FIREBASE_DB_URL`

### Get the service account JSON
1. Click the ⚙️ next to "Project Overview" → **Project settings**
2. Tab: **Service accounts**
3. Click **Generate new private key** → confirm → downloads a JSON file
4. Open the JSON in any editor, **copy the entire content** as one string — save it as `FIREBASE_CREDENTIALS_JSON`

---

## Step 2 · Render.com deploy

You said you already signed up. Now:

1. Go to https://dashboard.render.com
2. Click **New + → Blueprint**
3. Connect your GitHub → select `Anti-gravity-Hackathon` repo → click **Apply**
4. Render reads `render.yaml` and creates the `sahara-ai` service automatically
5. You'll be prompted for the secret env-vars (marked `sync: false` in the yaml). Paste these values:

| Variable | Value (from your local .env) |
|---|---|
| `GEMINI_API_KEY` | your Gemini key |
| `WEATHERAPI_KEY` | your WeatherAPI key |
| `GEOAPIFY_API_KEY` | your Geoapify key |
| `TWILIO_ACCOUNT_SID` | your Twilio SID |
| `TWILIO_AUTH_TOKEN` | your Twilio token |
| `WHATSAPP_NUMBER` | `923250909907` |
| `FIREBASE_DB_URL` | from Step 1 |
| `FIREBASE_CREDENTIALS_JSON` | the full service account JSON as one string |

6. Click **Apply** → first deploy takes ~3 minutes
7. When done, you get a URL like **`https://sahara-ai.onrender.com`**

### Verify it works
- Open `https://sahara-ai.onrender.com/health` — should show `{"status":"healthy","firebase_connected":true,...}`
- Open `https://sahara-ai.onrender.com/app/` — the Flutter web app
- Open `https://sahara-ai.onrender.com/api/live-crises` — auto-seeded crises

---

## Step 3 · Tell GitHub the production URL (so APK builds use it)

1. Go to https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/settings/secrets/actions
2. Click **New repository secret**
3. Name: `SAHARA_API_BASE_URL`
4. Value: `https://sahara-ai.onrender.com` (whatever Render gave you)
5. Click **Add secret**

Next time GitHub Actions builds the APK, it will hard-code that URL into the app.

---

## Step 4 · Rebuild the APK against production

Either:
- **Push any commit to main** → Actions auto-rebuilds the APK with the production URL
- **OR** go to https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/actions/workflows/build-apk.yml → click **Run workflow**

When complete (~5 min), the new APK appears on Releases:
**https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/releases**

Download `app-release.apk` to any Android device — it talks directly to your Render backend.

---

## Step 5 · Point Twilio webhook to production

1. https://console.twilio.com → **Messaging → Try it out → Send a WhatsApp message → Sandbox settings**
2. Field "When a message comes in": `https://sahara-ai.onrender.com/api/whatsapp/incoming`
3. Method: `HTTP POST` → **Save**

Done. No more tunnel resets — Twilio talks directly to Render forever.

---

## What you'll be submitting

| Asset | URL |
|---|---|
| **Live backend** | `https://sahara-ai.onrender.com` |
| **Live web app** | `https://sahara-ai.onrender.com/app/` |
| **API docs** | `https://sahara-ai.onrender.com/docs` |
| **Source code** | https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon |
| **APK download** | https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/releases/latest |
| **WhatsApp helpline** | Send to `+1 415 523 8886` (Twilio sandbox) after joining with `join <code>` |
| **Data persistence** | Firebase Realtime DB — survives backend restarts |

---

## Troubleshooting

**Render service shows "deploy failed"** → click the deploy log; usually a missing env-var. Fix it under **Environment** → **Manual Deploy → Deploy latest commit**.

**Render service "spun down" (10 sec delay first request)** → free tier behavior. Just hit `/healthz` once to wake it. For demo, send 1 request right before showing.

**APK says "connection error"** → the secret `SAHARA_API_BASE_URL` wasn't set BEFORE the APK was built. Set it (Step 3), then rerun the workflow (Step 4).

**Firebase write fails** → check `https://sahara-ai.onrender.com/health` — if `firebase_connected: false`, the JSON env-var is malformed. Re-paste it on a single line.
