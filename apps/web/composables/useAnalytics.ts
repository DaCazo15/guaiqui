import { ref, computed } from 'vue'

export interface ConsentState {
  necessary: boolean
  analytics: boolean
  advertising: boolean
  decidedAt: string | null
}

const CONSENT_COOKIE_NAME = 'guaiqui_cookie_consent'

const FORBIDDEN_PII_KEYS = new Set([
  'email',
  'name',
  'display_name',
  'first_name',
  'last_name',
  'balance',
  'balance_cache',
  'pearls',
  'phone',
  'birth_date',
  'user_email',
  'password',
])

interface PostHogClient {
  init: (key: string, options: Record<string, unknown>) => void
  opt_out_capturing: () => void
  identify: (userId: string) => void
  capture: (event: string, properties?: Record<string, unknown>) => void
}

interface CustomWindow extends Window {
  dataLayer?: unknown[]
  gtag?: (...args: unknown[]) => void
  [key: `ga-disable-${string}`]: boolean | undefined
}

const consentState = ref<ConsentState>({
  necessary: true,
  analytics: false,
  advertising: false,
  decidedAt: null,
})

const isGA4Initialized = ref(false)
const isPostHogInitialized = ref(false)
let posthogInstance: PostHogClient | null = null

/**
 * Normalizes URL path to remove UUIDs, tokens, and PII before dispatching to analytics
 */
export function normalizePath(fullPath: string): string {
  if (!fullPath) return '/'
  const cleanPath = fullPath.split('?')[0] // Strip query parameters

  const segments = cleanPath.split('/').filter(Boolean)
  const normalizedSegments = segments.map((segment) => {
    // Check UUID pattern
    if (/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(segment)) {
      return ':id'
    }
    // Check numeric ID pattern
    if (/^\d+$/.test(segment)) {
      return ':id'
    }
    return segment
  })

  return '/' + normalizedSegments.join('/')
}

export function useAnalytics() {
  const getGA4MeasurementId = (): string => {
    if (typeof window === 'undefined') return ''
    try {
      const config = useRuntimeConfig()
      if (config?.public?.gaMeasurementId) {
        return config.public.gaMeasurementId
      }
    } catch (_e) {}

    return (
      (import.meta.env.VITE_GA_MEASUREMENT_ID as string) ||
      (import.meta.env.NUXT_PUBLIC_GA_MEASUREMENT_ID as string) ||
      'G-P6EY10HB0B'
    )
  }

  const initConsent = () => {
    if (typeof window === 'undefined') return

    // Initialize GA4 with Google Consent Mode v2 default (denied) so Google Tag is detected
    initGA4()

    try {
      const stored = localStorage.getItem(CONSENT_COOKIE_NAME)
      if (stored) {
        const parsed = JSON.parse(stored)
        consentState.value = {
          necessary: true,
          analytics: !!parsed.analytics,
          advertising: parsed.advertising !== undefined ? !!parsed.advertising : !!parsed.analytics,
          decidedAt: parsed.decidedAt || null,
        }
      }
    } catch (_e) {
      // Default fallback
    }

    if (consentState.value.analytics && consentState.value.decidedAt) {
      updateGA4Consent()
      initPostHog()
    }
  }

  const setConsent = (analytics: boolean, advertising: boolean = analytics) => {
    consentState.value = {
      necessary: true,
      analytics,
      advertising,
      decidedAt: new Date().toISOString(),
    }

    if (typeof window !== 'undefined') {
      localStorage.setItem(CONSENT_COOKIE_NAME, JSON.stringify(consentState.value))
    }

    updateGA4Consent()

    if (analytics) {
      initPostHog()
    } else {
      revokeAnalytics()
    }
  }

  const initAdapters = () => {
    initGA4()
    updateGA4Consent()
    if (consentState.value.analytics) {
      initPostHog()
    }
  }

  const revokeAnalytics = () => {
    if (typeof window === 'undefined') return

    // 1. PostHog opt out
    if (posthogInstance) {
      try {
        posthogInstance.opt_out_capturing()
      } catch (_e) {}
    }

    // 2. GA4 disable flag & Consent update
    const gaId = getGA4MeasurementId()
    if (gaId) {
      ;(window as unknown as CustomWindow)[`ga-disable-${gaId}`] = true
    }
    updateGA4Consent()

    // 3. Delete all _ga cookies
    try {
      document.cookie.split(';').forEach((c) => {
        const eqPos = c.indexOf('=')
        const name = eqPos > -1 ? c.substring(0, eqPos).trim() : c.trim()
        if (name.startsWith('_ga')) {
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${window.location.hostname};`
        }
      })
    } catch (_e) {}
  }

  const updateGA4Consent = () => {
    const win = window as unknown as CustomWindow
    if (typeof window === 'undefined' || !win.gtag) return
    const gaId = getGA4MeasurementId()
    if (!gaId) return

    if (consentState.value.analytics) {
      win[`ga-disable-${gaId}`] = false
      win.gtag('consent', 'update', {
        analytics_storage: 'granted',
        ad_storage: consentState.value.advertising ? 'granted' : 'denied',
        ad_user_data: consentState.value.advertising ? 'granted' : 'denied',
        ad_personalization: consentState.value.advertising ? 'granted' : 'denied',
      })
    } else {
      win[`ga-disable-${gaId}`] = true
      win.gtag('consent', 'update', {
        analytics_storage: 'denied',
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
      })
    }
  }

  const initGA4 = () => {
    if (typeof window === 'undefined' || isGA4Initialized.value) return

    const gaId = getGA4MeasurementId()
    if (!gaId) return

    const win = window as unknown as CustomWindow
    if (!document.getElementById('ga4-script')) {
      // 1. Initialize dataLayer & Consent Mode v2 default (denied) BEFORE loading script
      win.dataLayer = win.dataLayer || []
      function gtag(...args: unknown[]) {
        win.dataLayer?.push(args)
      }
      win.gtag = gtag

      gtag('consent', 'default', {
        ad_storage: 'denied',
        analytics_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        wait_for_update: 500,
      })

      // 2. Load gtag script tag
      const script = document.createElement('script')
      script.id = 'ga4-script'
      script.async = true
      script.src = `https://www.googletagmanager.com/gtag/js?id=${gaId}`
      document.head.appendChild(script)

      gtag('js', new Date())
      gtag('config', gaId, {
        allow_google_signals: false,
        allow_ad_personalization_signals: false,
        send_page_view: false,
      })
    }

    isGA4Initialized.value = true
  }

  const initPostHog = async () => {
    if (typeof window === 'undefined' || isPostHogInitialized.value) return
    if (!consentState.value.analytics) return

    const apiKey = (import.meta.env.VITE_POSTHOG_KEY as string) || (import.meta.env.NUXT_PUBLIC_POSTHOG_KEY as string) || ''
    const apiHost = (import.meta.env.VITE_POSTHOG_HOST as string) || (import.meta.env.NUXT_PUBLIC_POSTHOG_HOST as string) || '/ingest'

    if (!apiKey) return

    try {
      const posthogModule = await import('posthog-js')
      const posthog = (posthogModule.default || posthogModule) as unknown as PostHogClient

      posthog.init(apiKey, {
        api_host: apiHost,
        ui_host: 'https://us.posthog.com',
        autocapture: false,
        disable_session_recording: true,
        respect_dnt: true,
        capture_pageview: false,
        persistence: 'localStorage',
      })

      posthogInstance = posthog
      isPostHogInitialized.value = true
    } catch (err) {
      console.warn('PostHog initialization warning:', err)
    }
  }

  const identifyUser = (userId: string) => {
    if (!consentState.value.analytics) return
    if (!userId || typeof userId !== 'string') return

    // Identify in GA4
    const gaId = getGA4MeasurementId()
    const win = window as unknown as CustomWindow
    if (isGA4Initialized.value && win.gtag && gaId) {
      win.gtag('config', gaId, { user_id: userId })
    }

    // Identify in PostHog
    if (posthogInstance) {
      try {
        posthogInstance.identify(userId)
      } catch (_e) {}
    }
  }

  const sanitizeProperties = (props?: Record<string, unknown>): Record<string, unknown> => {
    if (!props) return {}
    const cleanProps: Record<string, unknown> = {}

    let count = 0
    for (const [key, value] of Object.entries(props)) {
      if (count >= 25) break // Max 25 params per event
      if (!FORBIDDEN_PII_KEYS.has(key.toLowerCase())) {
        let val = value
        if (typeof val === 'string' && val.length > 100) {
          val = val.substring(0, 100) // Max 100 chars per param value
        }
        cleanProps[key] = val
        count++
      }
    }
    return cleanProps
  }

  const trackPageView = (path: string) => {
    if (!consentState.value.analytics) return null
    const normalized = normalizePath(path)

    const gaId = getGA4MeasurementId()
    const win = window as unknown as CustomWindow
    if (isGA4Initialized.value && win.gtag && gaId) {
      win.gtag('event', 'page_view', { page_path: normalized })
    }

    if (posthogInstance) {
      try {
        posthogInstance.capture('$pageview', { $current_url: normalized })
      } catch (_e) {}
    }

    return normalized
  }

  const trackEvent = (eventName: string, properties?: Record<string, unknown>) => {
    if (!consentState.value.analytics) return null

    // Ensure event name max 40 chars
    const cleanEventName = eventName.substring(0, 40)
    const cleanProps = sanitizeProperties(properties)

    // Dispatch to GA4
    const win = window as unknown as CustomWindow
    if (isGA4Initialized.value && win.gtag) {
      try {
        win.gtag('event', cleanEventName, cleanProps)
      } catch (_e) {}
    }

    // Dispatch to PostHog
    if (posthogInstance) {
      try {
        posthogInstance.capture(cleanEventName, cleanProps)
      } catch (_e) {}
    }

    return { eventName: cleanEventName, properties: cleanProps }
  }

  const isConsentPending = computed(() => consentState.value.decidedAt === null)
  const hasAnalyticsConsent = computed(() => consentState.value.analytics)
  const hasAdvertisingConsent = computed(() => consentState.value.advertising)

  return {
    consentState,
    isConsentPending,
    hasAnalyticsConsent,
    hasAdvertisingConsent,
    initConsent,
    setConsent,
    identifyUser,
    trackPageView,
    trackEvent,
    sanitizeProperties,
    normalizePath,
  }
}
