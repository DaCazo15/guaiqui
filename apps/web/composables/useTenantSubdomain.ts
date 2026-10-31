import { ref, computed } from 'vue'

const RESERVED_SUBDOMAINS = new Set([
  'www',
  'api',
  'admin',
  'app',
  'staff',
  'staging',
  'mail',
  'cdn',
  'static',
  'test',
  'preview'
])

/**
 * Extrae el subdominio de un hostname dado.
 * Ejemplos:
 * - 'guaiqueries.guaiqui.com' -> 'guaiqueries'
 * - 'guaiqueries.localhost' -> 'guaiqueries'
 * - 'guaiqueries.localhost:3000' -> 'guaiqueries'
 * - 'guaiqui.com' -> null
 * - 'www.guaiqui.com' -> null
 * - 'localhost:3000' -> null
 */
export function extractSubdomain(hostnameWithPort: string): string | null {
  if (!hostnameWithPort) return null

  // Limpiar puerto si viene incluido
  const hostname = hostnameWithPort.split(':')[0].toLowerCase().trim()

  // Ignorar IPs (IPv4)
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(hostname)) {
    return null
  }

  const parts = hostname.split('.')

  // Caso especial para localhost: e.g. 'guaiqueries.localhost'
  if (parts.length >= 2 && parts[parts.length - 1] === 'localhost') {
    const candidate = parts[0]
    return RESERVED_SUBDOMAINS.has(candidate) ? null : candidate
  }

  // Dominios estándar: e.g. 'guaiqueries.guaiqui.com' o 'guaiqueries.guaiqui.com.ve'
  // Si tiene al menos 3 partes (sub.domain.tld) o 4 partes (sub.domain.co.ve)
  if (parts.length >= 3) {
    const candidate = parts[0]
    if (!RESERVED_SUBDOMAINS.has(candidate)) {
      return candidate
    }
  }

  return null
}

export function useTenantSubdomain() {
  const currentSubdomain = ref<string | null>(null)

  let host = ''
  if (import.meta.server) {
    const reqUrl = useRequestURL()
    host = reqUrl.host || reqUrl.hostname
  } else if (typeof window !== 'undefined') {
    host = window.location.host || window.location.hostname
  }

  currentSubdomain.value = extractSubdomain(host)

  const isSubdomain = computed(() => !!currentSubdomain.value)

  return {
    subdomain: currentSubdomain,
    isSubdomain,
    extractSubdomain
  }
}
