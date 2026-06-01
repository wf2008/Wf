const { Telegraf } = require('telegraf');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────
// Replace with the Telegram chat ID of the admin user that is
// allowed to generate activation codes.
const ADMIN_CHAT_ID = parseInt(process.env.ADMIN_CHAT_ID || '0', 10);
// ─────────────────────────────────────────────────────────────

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
    ),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });
}

const bot = new Telegraf(process.env.BOT_TOKEN);

bot.command('start', (ctx) =>
  ctx.reply(
    'Welcome to Wfseek bot. Use /generate <plan> <days> as admin to create activation codes.',
  ),
);

bot.command('generate', async (ctx) => {
  if (ctx.from.id !== ADMIN_CHAT_ID) {
    return ctx.reply('Unauthorized.');
  }
  const parts = ctx.message.text.split(/\s+/);
  const plan = parts[1] || 'paid';
  const days = parseInt(parts[2] || '30', 10);
  if (!days || days <= 0) {
    return ctx.reply('Usage: /generate <plan> <days>');
  }
  const code =
    'WFSEEK-' +
    Math.random().toString(36).substring(2, 6).toUpperCase() +
    '-' +
    Math.random().toString(36).substring(2, 6).toUpperCase();
  const expires = Date.now() + days * 86400000;
  await admin.database().ref(`activation_codes/${code}`).set({
    used: false,
    plan,
    expires,
  });
  ctx.reply(`Code generated: ${code} (${days} days, ${plan})`);
});

module.exports = async (req, res) => {
  try {
    if (req.method === 'POST') {
      await bot.handleUpdate(req.body);
    }
    res.status(200).send('ok');
  } catch (e) {
    res.status(500).send(String(e));
  }
};
