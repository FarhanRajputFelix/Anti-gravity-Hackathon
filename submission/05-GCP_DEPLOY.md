# Deploy SAHARA AI to Google Cloud Run

**Why Cloud Run:** Free tier covers your entire hackathon (2M requests/month forever). Same project as your Firebase. Permanent HTTPS URL. Auto-scales to zero when idle (=$0 charge).

**Card required:** Yes, but Google won't charge you — your usage stays inside the always-free tier. Just don't click "Upgrade".

---

## Step 1 · Enable billing on the same Firebase project

1. Open: https://console.cloud.google.com/billing/linkedaccount?project=sahara-9c923
2. Click **Link a billing account** → **Create billing account** if you don't have one
3. Enter card → activates $300 free credit for 90 days
4. Once linked, you'll see "Billing is enabled" on the project page

> Important: This will **not** auto-charge you. Charging only starts after the $300 trial AND after you manually click "Upgrade my account". Until then you're on Free tier.

## Step 2 · Enable Cloud Run + Artifact Registry

1. Open: https://console.cloud.google.com/apis/library/run.googleapis.com?project=sahara-9c923 → click **Enable**
2. Open: https://console.cloud.google.com/apis/library/artifactregistry.googleapis.com?project=sahara-9c923 → click **Enable**
3. Open: https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com?project=sahara-9c923 → click **Enable**

## Step 3 · Install gcloud CLI on Windows (one-time, 2 min)

1. Download: https://cloud.google.com/sdk/docs/install#windows → run the installer
2. After install opens, sign in with `farhanmuhammadbashir@gmail.com`
3. When prompted for project, choose **sahara-9c923**

## Step 4 · Deploy with ONE command

Open PowerShell in the project folder:

```powershell
cd C:\Users\Laptronics.co\OneDrive\Desktop\Hack\sahara_backend

gcloud run deploy sahara-ai `
  --source . `
  --region asia-south1 `
  --platform managed `
  --allow-unauthenticated `
  --memory 1Gi `
  --cpu 1 `
  --timeout 300 `
  --min-instances 0 `
  --max-instances 3 `
  --port 8080
```

First deploy takes 4–6 minutes (it builds the Docker image in the cloud and rolls it out).
You'll get a URL like:
**`https://sahara-ai-XXXXXXXX-as.a.run.app`**

## Step 5 · Add environment variables (Secrets)

```powershell
gcloud run services update sahara-ai --region asia-south1 `
  --update-env-vars `
GEMINI_API_KEY=YOUR_GEMINI_KEY,`
WEATHERAPI_KEY=YOUR_WEATHERAPI_KEY,`
GEOAPIFY_API_KEY=YOUR_GEOAPIFY_KEY,`
TWILIO_ACCOUNT_SID=YOUR_TWILIO_SID,`
TWILIO_AUTH_TOKEN=YOUR_TWILIO_TOKEN,`
TWILIO_WHATSAPP_FROM=+14155238886,`
WHATSAPP_NUMBER=923250909907,`
FIREBASE_ENABLED=true,`
FIREBASE_DB_URL=https://sahara-9c923-default-rtdb.firebaseio.com
```

> For `FIREBASE_CREDENTIALS_JSON` (which has special chars), use **Secret Manager** instead — see Step 6.

## Step 6 · Mount Firebase service account via Secret Manager (more secure)

```powershell
# Create the secret from your downloaded JSON file
gcloud secrets create firebase-creds `
  --data-file="C:\path\to\your\NEW-firebase-adminsdk-XXXXX.json"

# Grant Cloud Run access to it
gcloud secrets add-iam-policy-binding firebase-creds `
  --member="serviceAccount:828203966346-compute@developer.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"

# Mount as env var inside Cloud Run
gcloud run services update sahara-ai --region asia-south1 `
  --update-secrets=FIREBASE_CREDENTIALS_JSON=firebase-creds:latest
```

## Step 7 · Verify deploy

Open these URLs (replace with your actual Run URL):

- `https://sahara-ai-XXXX.a.run.app/health` → `{"status":"healthy","firebase_connected":true,...}`
- `https://sahara-ai-XXXX.a.run.app/app/` → Flutter web app
- `https://sahara-ai-XXXX.a.run.app/api/live-crises` → seeded crises
- `https://sahara-ai-XXXX.a.run.app/docs` → API docs

## Step 8 · Wire production URL into the APK

1. GitHub repo settings → Secrets → new secret `SAHARA_API_BASE_URL` = your Cloud Run URL
2. Actions tab → **Build Android APK** → **Run workflow**
3. After 5 min, fresh APK on Releases pointing to your live Cloud Run backend

## Step 9 · Point Twilio webhook

In Twilio sandbox config:
- "When a message comes in": `https://sahara-ai-XXXX.a.run.app/api/whatsapp/incoming`
- Method: HTTP POST → Save

---

## Cost expectations

Your hackathon load:
- ~100 requests/day during demo = ~3,000 requests/month
- Free tier limit: **2,000,000 requests/month**
- Your usage: **0.15% of free tier**
- **Expected bill: $0.00**

Even if 1000 people use it for a month: still inside free tier.

---

## How to stay safe (never get charged)

1. After deploying, set a **budget alert**: https://console.cloud.google.com/billing/budgets → New budget → $1 threshold → email alert at $0.50
2. Don't click "Upgrade my account" — leaves you on trial mode
3. After 90 days, your $300 credit expires. By then you'll have already submitted the hackathon.

---

## Compared to other options

| Platform | Card? | Quality | Best for |
|---|---|---|---|
| **Cloud Run** ⭐ | Yes (no charge) | Production-grade | Final submission |
| Hugging Face Spaces | No | Good | Quick demo, no card |
| Render | Yes (charges) | Good | Avoid now |
| Koyeb | Yes (charges) | Good | Avoid now |

For a hackathon submission, **Cloud Run is the winner** — same project as Firebase, integrated auth, permanent URL, professional appearance. The card is the only minor friction.
