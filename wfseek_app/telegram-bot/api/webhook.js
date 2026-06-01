const { Telegraf } = require('telegraf');
const admin = require('firebase-admin');

const ADMIN_CHAT_ID = parseInt(process.env.ADMIN_CHAT_ID || '0', 10);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
    ),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });
}

const bot = new Telegraf(process.env.BOT_TOKEN);

// ── Helpers ────────────────────────────────────────────────────────────────

function isAdmin(ctx) {
  return ctx.from.id === ADMIN_CHAT_ID;
}

function makeCode() {
  const seg = () => Math.random().toString(36).substring(2, 6).toUpperCase();
  return `WFSEEK-${seg()}-${seg()}`;
}

async function createCode(plan, days) {
  const code = makeCode();
  // days = 0 means never expires (family plan)
  const expires = days === 0 ? 0 : Date.now() + days * 86_400_000;
  await admin.database().ref(`activation_codes/${code}`).set({
    used: false,
    plan,
    expires,
  });
  return { code, expires };
}

function expiryLabel(expires) {
  if (expires === 0) return 'Never expires ♾️';
  const d = new Date(expires);
  return `Expires ${d.toDateString()}`;
}

// ── Commands ───────────────────────────────────────────────────────────────

bot.command('start', (ctx) =>
  ctx.reply(
    '👋 *Wfseek Admin Bot*\n\n' +
    'Generate activation codes for your customers:\n\n' +
    '📅 /weekly  — 7-day code\n' +
    '📆 /monthly — 30-day code\n' +
    '♾️  /family  — Never-expire code (family)\n\n' +
    '_Only the admin can run these commands._',
    { parse_mode: 'Markdown' },
  ),
);

bot.command('weekly', async (ctx) => {
  if (!isAdmin(ctx)) return ctx.reply('⛔ Unauthorized.');
  const { code, expires } = await createCode('weekly', 7);
  ctx.reply(
    `✅ *Weekly Code Generated*\n\n` +
    `\`${code}\`\n\n` +
    `📅 Plan: 7 days\n` +
    `🕐 ${expiryLabel(expires)}\n\n` +
    `Send this code to your customer. They enter it in the app → Activate Plan.`,
    { parse_mode: 'Markdown' },
  );
});

bot.command('monthly', async (ctx) => {
  if (!isAdmin(ctx)) return ctx.reply('⛔ Unauthorized.');
  const { code, expires } = await createCode('monthly', 30);
  ctx.reply(
    `✅ *Monthly Code Generated*\n\n` +
    `\`${code}\`\n\n` +
    `📆 Plan: 30 days\n` +
    `🕐 ${expiryLabel(expires)}\n\n` +
    `Send this code to your customer. They enter it in the app → Activate Plan.`,
    { parse_mode: 'Markdown' },
  );
});

bot.command('family', async (ctx) => {
  if (!isAdmin(ctx)) return ctx.reply('⛔ Unauthorized.');
  const { code, expires } = await createCode('family', 0);
  ctx.reply(
    `✅ *Family Code Generated*\n\n` +
    `\`${code}\`\n\n` +
    `♾️  Plan: Never expires\n` +
    `👨‍👩‍👧 For family members only.\n\n` +
    `Send this code to your family member. They enter it in the app → Activate Plan.`,
    { parse_mode: 'Markdown' },
  );
});

// Legacy: /generate <plan> <days> still works for custom durations
bot.command('generate', async (ctx) => {
  if (!isAdmin(ctx)) return ctx.reply('⛔ Unauthorized.');
  const parts = ctx.message.text.split(/\s+/);
  const plan = parts[1] || 'paid';
  const days = parseInt(parts[2] || '30', 10);
  if (!days || days <= 0) {
    return ctx.reply('Usage: /generate <plan> <days>\n\nOr use /weekly /monthly /family');
  }
  const { code, expires } = await createCode(plan, days);
  ctx.reply(
    `✅ *Code Generated*\n\n` +
    `\`${code}\`\n\n` +
    `📋 Plan: ${plan} (${days} days)\n` +
    `🕐 ${expiryLabel(expires)}`,
    { parse_mode: 'Markdown' },
  );
});

// ── Webhook handler ────────────────────────────────────────────────────────

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
