import { useAuthStore } from '~/stores/auth'

export default defineNuxtRouteMiddleware(async (to) => {
  const authStore = useAuthStore()

  // Ensure profile and session are loaded
  if (!authStore.profile) {
    await authStore.fetchProfile()
  }

  if (!authStore.isAuthenticated) {
    return navigateTo(`/login?redirect=${encodeURIComponent(to.fullPath)}`)
  }

  if (!authStore.isEmailVerified) {
    return navigateTo('/verificar-correo')
  }

  if (authStore.needsConsent && to.path !== '/aceptar-terminos') {
    return navigateTo('/aceptar-terminos')
  }
})
