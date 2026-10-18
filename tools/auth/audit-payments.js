// Read-only payment release audit. Prints configuration flags, never credentials,
// secret payloads, customer records, or purchase receipts. Uses the CLI login.
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');

async function main() {
  const root = path.resolve(__dirname, '../..');
  const cliRoot = process.env.FIREBASE_TOOLS_ROOT ||
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools');
  const auth = require(path.join(cliRoot, 'lib', 'auth.js'));
  const account = auth.getProjectDefaultAccount(root);
  if (!account) throw new Error('Firebase CLI login required.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase',
  ]);
  const source = fs.readFileSync(path.join(root, 'lib/firebase_options.dart'), 'utf8');
  const project = source.match(/projectId: '([^']+)'/)[1];
  async function get(url) {
    try {
      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${token.access_token}` },
        signal: AbortSignal.timeout(15000),
        redirect: 'error',
      });
      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        const reasons = (body.error?.details || []).map(detail => detail.reason)
          .filter(reason => typeof reason === 'string' && /^[A-Z_]+$/.test(reason));
        return { httpStatus: response.status, reasons };
      }
      return { httpStatus: response.status, data: await response.json() };
    } catch (_) {
      return { status: 'unverified: request failed' };
    }
  }
  async function secretStatus(name) {
    // Listing version metadata does not access any secret value.
    const result = await get(`https://secretmanager.googleapis.com/v1/projects/${project}/secrets/${name}/versions?pageSize=100`);
    if (!result.data) return { name, ...result };
    return {
      name,
      hasEnabledVersion: (result.data.versions || []).some(v => v.state === 'ENABLED'),
      complete: !result.data.nextPageToken,
    };
  }
  async function rulesStatus() {
    const release = await get(`https://firebaserules.googleapis.com/v1/projects/${project}/releases/cloud.firestore`);
    if (!release.data) return release;
    const rulesetName = release.data.rulesetName;
    if (typeof rulesetName !== 'string' || !rulesetName.startsWith(`projects/${project}/rulesets/`)) {
      return { status: 'unverified: unexpected ruleset reference' };
    }
    const ruleset = await get(`https://firebaserules.googleapis.com/v1/${rulesetName}`);
    if (!ruleset.data) return ruleset;
    const files = ruleset.data.source?.files || [];
    const deployed = files.find(file => file.name === 'firestore.rules') ||
      (files.length === 1 ? files[0] : null);
    if (typeof deployed?.content !== 'string') return { status: 'unverified: source unavailable' };
    const normalize = value => value.replace(/\r\n/g, '\n').trim();
    const local = normalize(fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8'));
    const live = normalize(deployed.content);
    if (process.argv.includes('--save')) {
      const output = path.join(root, '.dart_tool', 'payment-audit');
      fs.mkdirSync(output, { recursive: true });
      fs.writeFileSync(path.join(output, 'deployed-firestore.rules'), deployed.content);
    }
    const hash = value => crypto.createHash('sha256').update(value).digest('hex');
    return {
      matchesCheckout: local === live,
      deployedSha256: hash(live),
      checkoutSha256: hash(local),
      deployedHasPrivatePurchaseSnapshotCheck: live.includes('function hasVerifiedCoursePurchase('),
      updatedAt: release.data.updateTime,
    };
  }
  const [apiKey, webhookKey, rules] = await Promise.all([
    secretStatus('REVENUECAT_SECRET_API_KEY'),
    secretStatus('REVENUECAT_WEBHOOK_SECRET'),
    rulesStatus(),
  ]);
  const report = JSON.stringify({ checkedAt: new Date().toISOString(), project,
    secrets: [apiKey, webhookKey], rules }, null, 2);
  if (process.argv.includes('--save')) {
    const output = path.join(root, '.dart_tool', 'payment-audit');
    fs.mkdirSync(output, { recursive: true });
    fs.writeFileSync(path.join(output, 'configuration.json'), report + '\n');
  }
  console.log(report);
}

main().catch(() => {
  console.error('Payment configuration audit failed. Check Firebase CLI login and access. No credentials were printed.');
  process.exitCode = 1;
});
