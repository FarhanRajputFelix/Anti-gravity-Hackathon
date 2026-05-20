# SAHARA AI — Free Deployment Guide

## Recommended: Render.com (100% free, no credit card)

**Why Render:**
- 100% free tier (750 hours/month — enough for one always-on service)
- No credit card required
- Auto-deploys from GitHub on every push
- HTTPS + custom subdomain `https://sahara-ai.onrender.com`
- Persistent public URL for Twilio webhook (no more tunnel needed!)
- Supports Python, environment variables, background tasks
- Only downside: spins down after 15 min inactivity (10s cold start on first request)

### Deploy in 5 minutes

**1. Push backend to GitHub**
```bash
cd sahara_backend
git init
git add .
git commit -m "Initial backend"
gh repo create sahara-backend --public --source=. --push
```

**2. Sign up at https://render.com (use GitHub account)**

**3. Click "New +" → "Web Service" → connect your `sahara-backend` repo**

**4. Configure:**
- **Name:** `sahara-ai`
- **Region:** Singapore (closest to Pakistan)
- **Branch:** `main`
- **Runtime:** `Python 3`
- **Build Command:** `pip install -r requirements.txt`
- **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Plan:** `Free`

**5. Add Environment Variables** (paste from your local `.env`):
```
GEMINI_API_KEY=<your-gemini-key>
WEATHERAPI_KEY=<your-weatherapi-key>
GEOAPIFY_API_KEY=<your-geoapify-key>
TWILIO_ACCOUNT_SID=<your-twilio-sid>
TWILIO_AUTH_TOKEN=<your-twilio-token>
TWILIO_WHATSAPP_FROM=+14155238886
WHATSAPP_NUMBER=<destination-whatsapp-number>
```
> **Important:** never commit real API keys to git — paste them directly into Render's environment variable UI.

**6. Click "Create Web Service"** — first build takes ~3 min. Done.

**7. Update Twilio webhook** to point to your new URL:
   `https://sahara-ai.onrender.com/api/whatsapp/incoming`

**8. Update Flutter app** to use the new backend:
```bash
flutter build apk --release --dart-define=SAHARA_API_BASE_URL=https://sahara-ai.onrender.com
```

---

## Alternative Free Platforms

| Platform | Free Tier | Credit Card? | Notes |
|---|---|---|---|
| **Render** ⭐ | 750h/month | No | Best for FastAPI, easy setup |
| **Railway** | $5 credit | No (initially) | Faster, no cold start, but credit expires |
| **Koyeb** | 1 web service | No | Similar to Render |
| **Fly.io** | 3 small VMs | Yes | More technical, Docker-based |
| **PythonAnywhere** | 1 web app | No | Simpler but limited Python features |
| **Vercel** | Unlimited | No | Serverless, requires FastAPI adapter |

For a hackathon demo, **Render.com is the easiest and most reliable.**
