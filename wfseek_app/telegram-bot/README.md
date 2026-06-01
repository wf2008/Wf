# Wfseek Telegram Bot — Vercel Deployment Guide

A serverless Telegram webhook that lets the admin generate Wfseek activation
codes stored directly in Firebase Realtime Database.

---

## Step 1 — Get your Bot Token

1. Open Telegram → search **@BotFather** → send `/newbot`
2. Follow the prompts (choose a name and username for your bot)
3. BotFather gives you a token like: `123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
4. **Copy it** — this is your `BOT_TOKEN`

---

## Step 2 — Get your Telegram Chat ID

1. Open Telegram → search **@userinfobot** → send `/start`
2. It replies with your numeric ID, e.g. `Id: 987654321`
3. **Copy that number** — this is your `ADMIN_CHAT_ID`

---

## Step 3 — Deploy to Vercel

### 3a. Push this folder to GitHub (already done ✅)

### 3b. Import project on Vercel

1. Go to [vercel.com](https://vercel.com) → **Add New Project**
2. Import the **wf2008/Wf** GitHub repo
3. Set **Root Directory** to `wfseek_app/telegram-bot`
4. Framework: **Other** (leave as-is)
5. Click **Deploy** (it will fail first — that's OK, env vars come next)

---

## Step 4 — Add Environment Variables on Vercel

Go to your Vercel project → **Settings** → **Environment Variables**
Add these **4 variables** exactly:

---

### Variable 1
| Field | Value |
|-------|-------|
| **Name** | `BOT_TOKEN` |
| **Value** | The token from @BotFather (e.g. `123456789:AAxxxxxxxx`) |

---

### Variable 2
| Field | Value |
|-------|-------|
| **Name** | `ADMIN_CHAT_ID` |
| **Value** | Your numeric Telegram ID from @userinfobot (e.g. `987654321`) |

---

### Variable 3
| Field | Value |
|-------|-------|
| **Name** | `FIREBASE_DATABASE_URL` |
| **Value** | `https://wfdmike-default-rtdb.firebaseio.com` |

*(already known — copy exactly as shown above)*

---

### Variable 4 — **Most important, easy to get wrong**
| Field | Value |
|-------|-------|
| **Name** | `FIREBASE_SERVICE_ACCOUNT_JSON` |
| **Value** | The **entire contents** of your `serviceAccountKey.json` file, pasted as **one single line** |

**How to minify the JSON to one line:**
1. Go to [jsonminify.com](https://jsonminify.com) (or any JSON minifier)
2. Paste the full contents of your `wfdmike-firebase-adminsdk-fbsvc-....json` file
3. Click Minify
4. Copy the result (it will be one very long line starting with `{"type":"service_account"...}`)
5. Paste that single line as the value for `FIREBASE_SERVICE_ACCOUNT_JSON` on Vercel

---

## Step 5 — Redeploy

After adding all 4 environment variables:
1. Vercel project → **Deployments** tab → click the three dots on the latest deployment → **Redeploy**
2. Wait for it to finish

---

## Step 6 — Register the Webhook

Once deployed, Vercel gives you a URL like `https://your-app.vercel.app`.

Run this once in your browser or terminal (replace the placeholders):

```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook?url=https://<your-app>.vercel.app/api/webhook
```

You should get: `{"ok":true,"result":true,"description":"Webhook was set"}`

---

## Usage

Open your bot in Telegram and send:

| Command | What it does |
|---------|-------------|
| `/start` | Shows welcome message |
| `/generate paid 30` | Creates a 30-day paid activation code (admin only) |
| `/generate paid 7` | Creates a 7-day paid activation code (admin only) |

The bot replies with the code, e.g. `WFSEEK-AB12-CD34`.
The code is instantly written to Firebase → `activation_codes/WFSEEK-AB12-CD34`.

Users enter this code in the Wfseek app → Activation screen to unlock Pro Plan.

---

## Firebase Rules required

Make sure your Firebase Realtime Database rules allow writing to `activation_codes`:

```json
{
  "rules": {
    "activation_codes": {
      "$code": {
        ".read": "auth != null",
        ".write": false
      }
    }
  }
}
```

The bot uses the service account (admin SDK) which bypasses these rules, so
it can always write codes. App users can only read codes, never write them.
