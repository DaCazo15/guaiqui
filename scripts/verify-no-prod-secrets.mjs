/**
 * CI Script: verify-no-prod-secrets.mjs
 * 1. Prevents accidental injection of production Supabase URLs or secrets in non-production builds.
 * 2. Scans codebase to ensure test tokens ('test-valid-pass') or Cloudflare dummy secrets
 *    do not leak into client-side apps, packages, or production edge functions outside test/local files.
 */

import fs from 'fs';
import path from 'path';

const currentEnv = process.env.VERCEL_ENV || process.env.NODE_ENV || 'development';
const prodSupabaseUrl = process.env.PROD_SUPABASE_URL_PATTERN || 'https://prod-guaiqui.supabase.co';

console.log(`[CI Verify] Environment: ${currentEnv}`);

// 1. Environment URL validation
if (currentEnv !== 'production') {
  const checkVars = [
    process.env.SUPABASE_URL,
    process.env.VITE_SUPABASE_URL,
    process.env.NUXT_PUBLIC_SUPABASE_URL,
  ];

  for (const val of checkVars) {
    if (val && val.includes(prodSupabaseUrl)) {
      console.error(`❌ CRITICAL SECURITY ERROR: Production Supabase URL detected in non-production environment (${currentEnv})!`);
      process.exit(1);
    }
  }
}

// 2. Scan source files for forbidden test secrets and bypass tokens outside test/local files
console.log('[CI Verify] Scanning codebase for forbidden test tokens and testing secrets...');

const FORBIDDEN_PATTERNS = [
  { name: 'mock token "test-valid-pass"', regex: /test-valid-pass/ },
  { name: 'Cloudflare Turnstile test secret key', regex: /1x0000000000000000000000000000000AA/ },
  { name: 'hardcoded production IP salt pattern', regex: /_guaiqui_ip_salt_prod/ },
];

const SCAN_DIRS = ['apps', 'packages', 'supabase/functions'];
const IGNORED_PATHS = [
  'node_modules',
  '.nuxt',
  '.output',
  'dist',
  'coverage',
  '__tests__',
  '.test.',
  '.spec.',
  // verify-captcha is the authorized server function implementing the isLocal environment check
  'supabase/functions/verify-captcha/index.ts',
  'supabase/tests',
];

let violationsFound = false;

function scanDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) return;
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);
    const normalized = fullPath.replace(/\\/g, '/');

    if (IGNORED_PATHS.some((ignored) => normalized.includes(ignored))) {
      continue;
    }

    if (entry.isDirectory()) {
      scanDirectory(fullPath);
    } else if (entry.isFile() && /\.(ts|js|mjs|vue|json)$/.test(entry.name)) {
      const content = fs.readFileSync(fullPath, 'utf8');
      for (const pattern of FORBIDDEN_PATTERNS) {
        if (pattern.regex.test(content)) {
          console.error(`❌ SECURITY VIOLATION: Forbidden ${pattern.name} found in production source file: ${normalized}`);
          violationsFound = true;
        }
      }
    }
  }
}

for (const dir of SCAN_DIRS) {
  scanDirectory(dir);
}

// 3. Scan .env.example files to prevent leaking production secrets or non-empty IP_SALT
const ENV_EXAMPLE_FILES = ['.env.example', 'supabase/.env.example'];
for (const relFile of ENV_EXAMPLE_FILES) {
  const fullPath = path.resolve(relFile);
  if (fs.existsSync(fullPath)) {
    const content = fs.readFileSync(fullPath, 'utf8');
    for (const pattern of FORBIDDEN_PATTERNS) {
      if (pattern.regex.test(content)) {
        console.error(`❌ SECURITY VIOLATION: Forbidden ${pattern.name} found in example env file: ${relFile}`);
        violationsFound = true;
      }
    }
    const ipSaltMatch = content.match(/^IP_SALT=(.+)$/m);
    if (ipSaltMatch && ipSaltMatch[1].trim().length > 0) {
      console.error(`❌ SECURITY VIOLATION: Non-empty IP_SALT found in ${relFile}. Secret salts must be empty in example files.`);
      violationsFound = true;
    }
  }
}

if (violationsFound) {
  console.error('❌ Build failed: Remove forbidden test bypass tokens/secrets before merging.');
  process.exit(1);
}

console.log('✅ Validation passed: No test tokens or test secrets detected in production codebase.');

