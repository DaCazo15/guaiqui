import fs from 'fs';
import path from 'path';

const migrationsDir = './supabase/migrations';
const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();

const tables = new Map();
const allPoliciesCreated = [];
const allPoliciesDropped = [];

files.forEach(file => {
  const content = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

  // Track ENABLE ROW LEVEL SECURITY
  const rlsRegex = /ALTER\s+TABLE\s+(?:ONLY\s+)?(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY/gi;
  let match;
  while ((match = rlsRegex.exec(content)) !== null) {
    const schema = match[1] || 'public';
    const tableName = `${schema}.${match[2]}`.replace('public.', '');
    if (!tables.has(tableName)) {
      tables.set(tableName, { schema, rlsEnabled: true, policies: new Map(), enabledIn: file });
    } else {
      tables.get(tableName).rlsEnabled = true;
    }
  }

  // Track DROP POLICY
  const dropPolicyRegex = /DROP\s+POLICY\s+(?:IF\s+EXISTS\s+)?(?:["']([^"']+)["']|([a-zA-Z0-9_]+))\s+ON\s+(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)/gi;
  while ((match = dropPolicyRegex.exec(content)) !== null) {
    const policyName = match[1] || match[2];
    const schema = match[3] || 'public';
    const tableName = `${schema}.${match[4]}`.replace('public.', '');
    allPoliciesDropped.push({ file, policyName, tableName });
    if (tables.has(tableName)) {
      const table = tables.get(tableName);
      if (table.policies.has(policyName)) {
        table.policies.get(policyName).droppedIn.push(file);
        table.policies.get(policyName).active = false;
      }
    }
  }

  // Track CREATE POLICY
  const createPolicyRegex = /CREATE\s+POLICY\s+(?:["']([^"']+)["']|([a-zA-Z0-9_]+))\s+ON\s+(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)([\s\S]*?)(?=;|\n\s*\n\s*(?:CREATE|ALTER|DROP|BEGIN|COMMIT|--\s*---+)|$)/gi;
  while ((match = createPolicyRegex.exec(content)) !== null) {
    const policyName = match[1] || match[2];
    const schema = match[3] || 'public';
    const tableName = `${schema}.${match[4]}`.replace('public.', '');
    const body = match[5].trim();

    const forMatch = body.match(/FOR\s+(ALL|SELECT|INSERT|UPDATE|DELETE)/i);
    const command = forMatch ? forMatch[1].toUpperCase() : 'ALL';

    const toMatch = body.match(/TO\s+([a-zA-Z0-9_,\s]+?)(?=\s+USING|\s+WITH\s+CHECK|$)/i);
    const roles = toMatch ? toMatch[1].trim() : 'public';

    const usingMatch = body.match(/USING\s*\(([\s\S]*?)\)(?=\s+WITH\s+CHECK|$)/i);
    const usingExpr = usingMatch ? usingMatch[1].trim() : null;

    const checkMatch = body.match(/WITH\s+CHECK\s*\(([\s\S]*?)\)$/i);
    const checkExpr = checkMatch ? checkMatch[1].trim() : null;

    if (!tables.has(tableName)) {
      tables.set(tableName, { schema, rlsEnabled: false, policies: new Map(), enabledIn: null });
    }
    const table = tables.get(tableName);
    table.policies.set(policyName, {
      file,
      policyName,
      command,
      roles,
      using: usingExpr,
      withCheck: checkExpr,
      active: true,
      droppedIn: []
    });
    allPoliciesCreated.push({ file, policyName, tableName, command, roles });
  }
});

console.log('=== AUDITORIA DE RLS DEL PROYECTO ===');
console.log(`Total tablas detectadas: ${tables.size}`);
console.log(`Total políticas creadas en migraciones: ${allPoliciesCreated.length}`);
console.log(`Total políticas eliminadas en migraciones: ${allPoliciesDropped.length}\n`);

for (const [tableName, info] of tables.entries()) {
  const activePolicies = Array.from(info.policies.values()).filter(p => p.active);
  console.log(`Tabla: ${tableName} (RLS: ${info.rlsEnabled ? 'HABILITADO' : 'DESHABILITADO'}) - Políticas activas: ${activePolicies.length}`);
  activePolicies.forEach(p => {
    console.log(`  ✓ "${p.policyName}" [${p.command}] para [${p.roles}] (en ${p.file})`);
  });
}
