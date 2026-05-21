# Deploy SAHARA AI Backend to Hugging Face Spaces (no card needed)

Hugging Face Spaces = free 16GB RAM container with a public HTTPS URL. No credit card.

## Step 1 · Create a Space

1. Go to https://huggingface.co/spaces and sign up (GitHub login works)
2. Click **Create new Space**
3. Fill in:
   - **Owner:** your username
   - **Space name:** `sahara-ai`
   - **License:** MIT
   - **Space SDK:** **Docker**
   - **Hardware:** CPU basic (free)
   - **Visibility:** Public
4. Click **Create Space**

You now have a Space URL like: **`https://huggingface.co/spaces/<your-username>/sahara-ai`**
The live API will be at: **`https://<your-username>-sahara-ai.hf.space`**

## Step 2 · Upload the backend code

Two options:

### Option A — Push via Git (recommended)
```bash
cd "C:\Users\Laptronics.co\OneDrive\Desktop\Hack\sahara_backend"
git init
git remote add hf https://huggingface.co/spaces/<your-username>/sahara-ai
# HF will prompt for username + access token (create at https://huggingface.co/settings/tokens)
# Rename our HF Dockerfile so HF picks it up
cp Dockerfile.hf Dockerfile
git add .
git commit -m "Initial backend deploy"
git push hf main
```

### Option B — Upload via web UI
1. On your Space page, click **Files → Add file → Upload files**
2. Upload **every file** from `sahara_backend/` (drag & drop the whole folder)
3. **Rename** `Dockerfile.hf` to `Dockerfile` (HF auto-detects Dockerfile)

## Step 3 · Add environment variables (Secrets)

1. On your Space page, click **Settings** (tab) → scroll to **Variables and secrets**
2. Click **New secret** and add each of these one by one (mark all as "Secret"):

| Secret Name | Value |
|---|---|
| `GEMINI_API_KEY` | your Gemini key |
| `WEATHERAPI_KEY` | your WeatherAPI key |
| `GEOAPIFY_API_KEY` | your Geoapify key |
| `TWILIO_ACCOUNT_SID` | your Twilio SID |
| `TWILIO_AUTH_TOKEN` | your Twilio token |
| `TWILIO_WHATSAPP_FROM` | `+14155238886` |
| `WHATSAPP_NUMBER` | `923250909907` |
| `FIREBASE_ENABLED` | `true` |
| `FIREBASE_DB_URL` | from Firebase Realtime DB page |
| `FIREBASE_CREDENTIALS_JSON` | the **NEW** service account JSON, entire content as one string |

3. Click **Restart Space** at the top — the rebuild takes 3-5 minutes (watch the **Logs** tab)

## Step 4 · Verify

Open these URLs (replace `<user>` with your HF username):

- `https://<user>-sahara-ai.hf.space/health` → `{"status":"healthy","firebase_connected":true,...}`
- `https://<user>-sahara-ai.hf.space/app/` → the Flutter web app
- `https://<user>-sahara-ai.hf.space/api/live-crises` → auto-seeded crises

## Step 5 · Update GitHub secret for APK build

1. https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/settings/secrets/actions
2. Create/update secret `SAHARA_API_BASE_URL` → value = your HF URL (e.g. `https://<user>-sahara-ai.hf.space`)
3. Go to https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/actions/workflows/build-apk.yml → **Run workflow**
4. After 5 min, fresh APK on https://github.com/FarhanRajputFelix/Anti-gravity-Hackathon/releases/latest pointing to your live HF backend

## Step 6 · Twilio webhook

In Twilio sandbox config, set "When a message comes in" to:
`https://<user>-sahara-ai.hf.space/api/whatsapp/incoming`

---

## Notes

- HF free tier doesn't sleep as aggressively as Render
- 16GB RAM is plenty for this workload
- Logs are live-viewable in the Space's **Logs** tab — easy debugging
- If the build fails, the Logs tab tells you exactly why
