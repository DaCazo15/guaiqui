import { defineNuxtPlugin, useRouter } from '#imports'
import { inject } from '@vercel/analytics'
import { injectSpeedInsights } from '@vercel/speed-insights'
import { useAnalytics } from '~/composables/useAnalytics'

export default defineNuxtPlugin((nuxtApp) => {
  const analytics = useAnalytics()
  const router = useRouter()

  // Initialize Vercel Analytics & Speed Insights
  try {
    inject()
    injectSpeedInsights()
  } catch (_e) {}

  // Initialize consent on app mount
  analytics.initConsent()

  // Track SPA route changes with normalized paths
  router.afterEach((to) => {
    analytics.trackPageView(to.fullPath)
  })

  // Register v-track Directive for click tracking without text/input capturing
  nuxtApp.vueApp.directive('track', {
    mounted(el, binding) {
      const { section, element_id, destination } = binding.value || {}
      el.addEventListener('click', () => {
        analytics.trackEvent('ui_click', {
          section: section || 'general',
          element_id: element_id || el.id || 'unnamed_element',
          destination: destination || (el.getAttribute('href') || ''),
        })
      })
    },
  })
})
