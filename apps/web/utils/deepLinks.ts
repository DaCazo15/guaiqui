export interface ParsedDeepLink {
  isAuthCallback: boolean
  accessToken?: string
  refreshToken?: string
  authCode?: string
  path: string
}

/**
 * Parsea una URL de deep link entrante (guaiqui:// o https://guaiqueries.com)
 * extrayendo la ruta interna de navegación o los tokens de autenticación OAuth.
 */
export function parseDeepLinkUrl(url: string): ParsedDeepLink {
  if (!url) {
    return { isAuthCallback: false, path: '/' }
  }

  // 1. Caso Auth Callback (guaiqui://auth-callback#access_token=... o guaiqui://auth-callback?code=...)
  if (url.includes('auth-callback') || url.includes('/confirm')) {
    // Parcheo de fragment hash (#access_token=...)
    let accessToken: string | undefined
    let refreshToken: string | undefined
    let authCode: string | undefined

    if (url.includes('#')) {
      const hashParams = new URLSearchParams(url.split('#')[1])
      accessToken = hashParams.get('access_token') || undefined
      refreshToken = hashParams.get('refresh_token') || undefined
    }

    if (url.includes('?')) {
      const queryParams = new URLSearchParams(url.split('?')[1].split('#')[0])
      authCode = queryParams.get('code') || undefined
      if (!accessToken) accessToken = queryParams.get('access_token') || undefined
      if (!refreshToken) refreshToken = queryParams.get('refresh_token') || undefined
    }

    return {
      isAuthCallback: true,
      accessToken,
      refreshToken,
      authCode,
      path: '/app'
    }
  }

  // 2. Esquema personalizado guaiqui://
  if (url.startsWith('guaiqui://')) {
    const rawPath = url.replace('guaiqui://', '')
    const cleanPath = rawPath.startsWith('/') ? rawPath : `/${rawPath}`
    return {
      isAuthCallback: false,
      path: cleanPath
    }
  }

  // 3. URLs HTTP/HTTPS Universales (ej. https://guaiqueries.com/e/marinos o /registro?ref=XYZ)
  try {
    const parsed = new URL(url)
    const fullPath = parsed.pathname + parsed.search + parsed.hash
    return {
      isAuthCallback: false,
      path: fullPath || '/'
    }
  } catch {
    // Si no es una URL parseable completa, asegurar que empiece por /
    const fallbackPath = url.startsWith('/') ? url : `/${url}`
    return {
      isAuthCallback: false,
      path: fallbackPath
    }
  }
}
