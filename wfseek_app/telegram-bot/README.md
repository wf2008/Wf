# Wfseek Telegram bot

A tiny Vercel serverless function that exposes a Telegram webhook so the admin
can generate Wfseek activation codes.

## Setup

1. Create a bot with [@BotFather](https://t.me/botfather) and copy the token.
2. Generate a Firebase service-account JSON for your project.
3. Configure environment variables on Vercel:

   - `BOT_TOKEN` – Telegram bot token
   - `ADMIN_CHAT_ID` – your Telegram numeric ID (only this user can run /generate)
   - `FIREBASE_DATABASE_URL` – your RTDB URL
   - `FIREBASE_SERVICE_ACCOUNT_JSON` – the entire service account JSON as a string

4. Deploy:

   ```bash
   vercel --prod
   ```

5. Register the webhook:

   ```bash
   curl "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=https://<your-app>.vercel.app/api/webhook"
   ```

## Commands

- `/start` – Greeting.
- `/generate <plan> <days>` – Admin only. Creates an activation code and writes
  it to `activation_codes/<code>` in Firebase RTDB.
