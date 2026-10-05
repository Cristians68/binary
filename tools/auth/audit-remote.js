// Read-only Firebase release configuration audit. Uses the Firebase CLI's existing
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
  const readStatus = async (url, summarize) => {
    try {
      const response = await fetch(url, {
        headers: {Authorization: `Bearer ${token.access_token}`},
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) return {status: `unverified: HTTP ${response.status}`};
      return summarize(await response.json());
    } catch (_) {
      return {status: 'unverified: request failed'};
    }
  };
  const [iosApps, billing, functions] = await Promise.all([
    readStatus(`https://firebase.googleapis.com/v1beta1/projects/${project}/iosApps`,
      data => ({apps: (data.apps || []).map(app => ({appId: app.appId, bundleId: app.bundleId}))})),
    readStatus(`https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`,
      data => ({enabled: data.billingEnabled === true})),
    readStatus(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/-/functions?pageSize=1000`,
      data => ({
        functions: (data.functions || []).map(fn => ({name: fn.name.split('/').pop(), state: fn.state})),
        complete: !data.nextPageToken && !(data.unreachable || []).length,
      })),
  ]);
  console.log(JSON.stringify({
    project,
    authorizedDomains: config.authorizedDomains || [],
    anonymousEnabled: config.signIn?.anonymous?.enabled === true,
    emailEnabled: config.signIn?.email?.enabled === true,
    iosApps,
    billing,
    functions,
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
