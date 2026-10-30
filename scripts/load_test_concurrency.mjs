/**
 * Script de Pruebas de Carga Concurrente (100 llamadas simultáneas) — Fase 12
 * Mide tiempo de respuesta, throughput y tasas de éxito/bloqueo ante alta concurrencia.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

async function runLoadTest() {
  console.log('🚀 Iniciando Prueba de Carga Concurrente (100 peticiones en paralelo)...');
  const startTime = Date.now();

  const requests = Array.from({ length: 100 }, () => {
    return fetch(`${SUPABASE_URL}/rest/v1/rpc/health_check`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      }
    }).then(async (res) => {
      const data = await res.json();
      return { status: res.status, ok: res.ok, data };
    }).catch(err => ({ status: 500, ok: false, error: err.message }));
  });

  const results = await Promise.all(requests);
  const totalTime = Date.now() - startTime;

  const successful = results.filter(r => r.ok).length;
  const failed = results.filter(r => !r.ok).length;
  const avgTime = (totalTime / 100).toFixed(2);

  console.log(`\n📊 RESULTADOS DE LA PRUEBA DE CARGA:`);
  console.log(`- Peticiones Totales: 100`);
  console.log(`- Éxitos (200 OK): ${successful}`);
  console.log(`- Fallos: ${failed}`);
  console.log(`- Tiempo Total: ${totalTime} ms`);
  console.log(`- Tiempo Promedio / Petición: ${avgTime} ms`);
  console.log(`- Throughput Aprox: ${(100 / (totalTime / 1000)).toFixed(2)} req/sec`);
}

runLoadTest().catch(console.error);
