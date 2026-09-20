// Read-only Firebase Auth configuration audit. Uses the Firebase CLI's existing
// login; prints only provider availability and configuration-presence flags.
// No tokens, client secrets, private keys, or user records are printed.
const path = require('node:path');
const fs = require('node:fs');

async function main() {
  const cliRoot = process.env.FIREBASE_TOOLS_ROOT ||
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools');
  const auth = require(path.join(cliRoot, 'lib', 'auth.js'));
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account) throw new Error('No Firebase CLI login is available. Run firebase login first.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase',
  ]);
  const source = fs.readFileSync(path.join(__dirname, '../../lib/firebase_options.dart'), 'utf8');
  const project = source.match(/projectId: '([^']+)'/)[1];
  const get = async (suffix) => {
    const response = await fetch(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/${suffix}`, {
      headers: {Authorization: `Bearer ${token.access_token}`},
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`Auth configuration read failed: HTTP ${response.status}`);
    return response.json();
  };
  const [config, providers] = await Promise.all([get('config'), get('defaultSupportedIdpConfigs')]);
  console.log(JSON.stringify({
    project,
    authorizedDomains: config.authorizedDomains || [],
    anonymousEnabled: config.signIn?.anonymous?.enabled === true,
    emailEnabled: config.signIn?.email?.enabled === true,
    providers: (providers.defaultSupportedIdpConfigs || []).map(p => ({
      id: p.name.split('/').pop(),
      enabled: p.enabled === true,
      hasClientId: !!p.clientId,
      hasClientSecret: !!p.clientSecret,
    })),
  }, null, 2));
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
