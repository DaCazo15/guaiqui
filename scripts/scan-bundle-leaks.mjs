import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const rootDir = path.resolve(__dirname, '..')

const targetDirectories = [
  path.join(rootDir, 'apps/web/.output/public'),
  path.join(rootDir, 'apps/admin/dist'),
  path.join(rootDir, 'dist'),
  path.join(rootDir, '.output/public'),
]

// Forbidden leak patterns in client bundles
const leakRules = [
  {
    name: 'Supabase Service Role Claims in JWT',
    regex: /["'\\]*role["'\\]*\s*:\s*["'\\]*service_role["'\\]*/g,
  },
  {
    name: 'Resend API Key Leak',
    regex: /re_[A-Za-z0-9_-]{20,}/g,
  },
  {
    name: 'Turnstile Secret Key Leak',
    regex: /1x0000000000000000000000000000000AA/g,
  },
]


let foundLeaks = 0
let scannedFilesCount = 0

function scanDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) {
    return
  }

  const entries = fs.readdirSync(dirPath, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name)

    if (entry.isDirectory()) {
      scanDirectory(fullPath)
    } else if (entry.isFile() && (entry.name.endsWith('.js') || entry.name.endsWith('.html') || entry.name.endsWith('.json'))) {
      scannedFilesCount++
      const content = fs.readFileSync(fullPath, 'utf8')

      for (const rule of leakRules) {
        const matches = content.match(rule.regex)
        if (matches && matches.length > 0) {
          console.error(`\x1b[31m[ERROR ALERTA DE SEGURIDAD]\x1b[0m Fuga detectada: "${rule.name}" en el archivo: ${fullPath}`)
          foundLeaks += matches.length
        }
      }
    }
  }
}

console.log('🔒 Iniciando escaneo de seguridad en bundles compilados del cliente...')

for (const dir of targetDirectories) {
  scanDirectory(dir)
}

console.log(`ℹ️ Archivos escaneados: ${scannedFilesCount}`)

if (foundLeaks > 0) {
  console.error(`\x1b[31m❌ PRUEBA DE SEGURIDAD FALLIDA: Se encontraron ${foundLeaks} fugas de secretos privados en los artefactos del cliente.\x1b[0m`)
  process.exit(1)
} else {
  console.log('\x1b[32m✅ ESCANEO EXITOSO: No se detectaron secretos ni llaves privadas en los bundles del cliente.\x1b[0m')
  process.exit(0)
}
