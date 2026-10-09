import { useAuthStore } from '~/stores/auth'

export default defineNuxtRouteMiddleware(async () => {
  const authStore = useAuthStore()

  if (authStore.isAuthenticated && !authStore.profile) {
    await authStore.fetchProfile()
  }

  if (authStore.isAuthenticated && authStore.isEmailVerified && !authStore.needsConsent) {
    return navigateTo('/app')
  }
})
