/**
 * CI Script: verify-no-prod-secrets.mjs
 * Prevents accidental injection of production Supabase URLs or secrets in non-production builds.
 */

const currentEnv = process.env.VERCEL_ENV || process.env.NODE_ENV || 'development';
const prodSupabaseUrl = process.env.PROD_SUPABASE_URL_PATTERN || 'https://prod-guaiqui.supabase.co';

console.log(`[CI Verify] Environment: ${currentEnv}`);

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

  console.log('✅ Validation passed: No production secrets detected in non-production environment.');
} else {
  console.log('ℹ️ Running in production environment, verification skipped.');
}
