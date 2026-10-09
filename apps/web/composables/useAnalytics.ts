import { ref, computed } from 'vue'

export interface ConsentState {
  necessary: boolean
  analytics: boolean
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

const consentState = ref<ConsentState>({
  necessary: true,
  analytics: false,
  decidedAt: null,
})

const isPostHogInitialized = ref(false)
let posthogInstance: any = null

export function useAnalytics() {
  const initConsent = () => {
    if (typeof window === 'undefined') return

    try {
      const stored = localStorage.getItem(CONSENT_COOKIE_NAME)
      if (stored) {
        const parsed = JSON.parse(stored)
        consentState.value = {
          necessary: true,
          analytics: !!parsed.analytics,
          decidedAt: parsed.decidedAt || null,
        }
      }
    } catch (_e) {
      // Fallback default
    }

    if (consentState.value.analytics && consentState.value.decidedAt) {
      initPostHog()
    }
  }

  const setConsent = (analytics: boolean) => {
    consentState.value = {
      necessary: true,
      analytics,
      decidedAt: new Date().toISOString(),
    }

    if (typeof window !== 'undefined') {
      localStorage.setItem(CONSENT_COOKIE_NAME, JSON.stringify(consentState.value))
    }

    if (analytics) {
      initPostHog()
    } else if (posthogInstance) {
      try {
        posthogInstance.opt_out_capturing()
      } catch (_e) {}
    }
  }

  const initPostHog = async () => {
    if (typeof window === 'undefined' || isPostHogInitialized.value) return
    if (!consentState.value.analytics) return

    const apiKey = (import.meta.env.VITE_POSTHOG_KEY as string) || (import.meta.env.NUXT_PUBLIC_POSTHOG_KEY as string) || ''
    const apiHost = (import.meta.env.VITE_POSTHOG_HOST as string) || (import.meta.env.NUXT_PUBLIC_POSTHOG_HOST as string) || '/ingest'

    if (!apiKey) return

    try {
      const posthogModule = await import('posthog-js')
      const posthog = posthogModule.default || posthogModule

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
    if (!consentState.value.analytics || !posthogInstance) return
    if (!userId || typeof userId !== 'string') return
    // Strict requirement: Identify ONLY with internal UUID string, never pass traits object containing PII
    try {
      posthogInstance.identify(userId)
    } catch (_e) {}
  }

  const sanitizeProperties = (props?: Record<string, any>): Record<string, any> => {
    if (!props) return {}
    const cleanProps: Record<string, any> = {}

    for (const [key, value] of Object.entries(props)) {
      if (!FORBIDDEN_PII_KEYS.has(key.toLowerCase())) {
        cleanProps[key] = value
      }
    }
    return cleanProps
  }

  const trackEvent = (eventName: string, properties?: Record<string, any>) => {
    if (!consentState.value.analytics) return null

    const cleanProps = sanitizeProperties(properties)

    if (posthogInstance) {
      try {
        posthogInstance.capture(eventName, cleanProps)
      } catch (_e) {}
    }

    return { eventName, properties: cleanProps }
  }

  const isConsentPending = computed(() => consentState.value.decidedAt === null)
  const hasAnalyticsConsent = computed(() => consentState.value.analytics)

  return {
    consentState,
    isConsentPending,
    hasAnalyticsConsent,
    initConsent,
    setConsent,
    identifyUser,
    trackEvent,
    sanitizeProperties,
  }
}
