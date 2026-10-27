/**
 * CI Script: ci-audit.mjs
 * Runs 'pnpm audit --prod --json' and fails the build if any high or critical
 * vulnerabilities are found, unless they are explicitly allowlisted in ALLOWED_EXCEPTIONS
 * with a documented justification.
 */

import { execSync } from 'child_process';

const ALLOWED_EXCEPTIONS = {
  'GHSA-4r6h-8v6p-xvw6': {
    package: 'xlsx',
    severity: 'high',
    reason: 'Sin parche publicado en registro público npm (SheetJS migró su distribución privada). Usado exclusivamente en apps/admin bajo autenticación estricta de administrador.',
  },
  'GHSA-5pgg-2g8v-p4x9': {
    package: 'xlsx',
    severity: 'high',
    reason: 'Sin parche publicado en registro público npm (SheetJS migró su distribución privada). Usado exclusivamente en apps/admin bajo autenticación estricta de administrador.',
  },
};

console.log('[CI Audit] Ejecutando pnpm audit --prod...');

let auditOutput = '';
try {
  auditOutput = execSync('pnpm audit --prod --json', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
} catch (err) {
  // pnpm audit exits with code 1 if any vulnerability is found
  auditOutput = err.stdout || '';
}

if (!auditOutput.trim()) {
  console.log('✅ No se detectó salida de auditoría o no hay dependencias de producción.');
  process.exit(0);
}

let report;
try {
  report = JSON.parse(auditOutput);
} catch (e) {
  console.error('❌ Error al parsear reporte JSON de pnpm audit:', e.message);
  console.error(auditOutput);
  process.exit(1);
}

const advisories = report.advisories || {};
const blockingVulnerabilities = [];
const exceptedVulnerabilities = [];

for (const [id, adv] of Object.entries(advisories)) {
  const severity = (adv.severity || '').toLowerCase();
  const ghsaId = adv.github_advisory_id;

  if (severity === 'high' || severity === 'critical') {
    if (ghsaId && ALLOWED_EXCEPTIONS[ghsaId]) {
      exceptedVulnerabilities.push({
        id,
        ghsaId,
        title: adv.title,
        module: adv.module_name,
        severity,
        reason: ALLOWED_EXCEPTIONS[ghsaId].reason,
      });
    } else {
      blockingVulnerabilities.push({
        id,
        ghsaId,
        title: adv.title,
        module: adv.module_name,
        severity,
        url: adv.url,
      });
    }
  }
}

if (exceptedVulnerabilities.length > 0) {
  console.log(`⚠️ Excepciones documentadas de auditoría permitidas (${exceptedVulnerabilities.length}):`);
  for (const item of exceptedVulnerabilities) {
    console.log(`  - [${item.severity.toUpperCase()}] ${item.module} (${item.ghsaId}): ${item.title}`);
    console.log(`    Motivo documentado: ${item.reason}`);
  }
}

if (blockingVulnerabilities.length > 0) {
  console.error(`\n❌ ERROR DE SEGURIDAD CI: Se encontraron ${blockingVulnerabilities.length} vulnerabilidad(es) HIGH o CRITICAL no autorizadas:`);
  for (const item of blockingVulnerabilities) {
    console.error(`  - [${item.severity.toUpperCase()}] ${item.module} (${item.ghsaId || item.id}): ${item.title}`);
    console.error(`    Más info: ${item.url || 'N/A'}`);
  }
  console.error('\nPor favor actualice o sobreescriba las dependencias vulnerables antes de continuar.');
  process.exit(1);
}

console.log('\n✅ Auditoría de producción superada: 0 vulnerabilidades bloqueantes encontradas.');
process.exit(0);
