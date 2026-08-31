// `npm run lint` in this directory has never worked: package.json declares
// `eslint .` and ships eslint 8 + eslint-config-google, but no config file was
// ever committed, so every run exited with "ESLint couldn't find a
// configuration file". A lint script that always fails is one nobody reads.
//
// This uses eslint:recommended rather than eslint-config-google on purpose.
// The Google style guide would flag hundreds of formatting differences in
// existing, working code, which buries the findings that matter — undefined
// variables, unreachable code, unused bindings, forgotten awaits.
module.exports = {
  root: true,
  env: {
    node: true,
    es2022: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'script', // Cloud Functions are CommonJS.
  },
  extends: ['eslint:recommended'],
  rules: {
    // Server-side logs are how these functions are debugged in production;
    // firebase functions:log is the only window into them.
    'no-console': 'off',
    // Catch the mistake that actually bites in async handlers.
    'require-atomic-updates': 'error',
    'no-unused-vars': ['error', {argsIgnorePattern: '^_'}],
  },
  ignorePatterns: ['node_modules/**'],
};
