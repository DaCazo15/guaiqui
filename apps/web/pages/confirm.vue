<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, navigateTo } from '#imports'
import { useSupabaseClient } from '#imports'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const supabase = useSupabaseClient()
const authStore = useAuthStore()

const status = ref<'verifying' | 'error' | 'success'>('verifying')

onMounted(async () => {
  // 1. Verificar si la URL trae parámetros de error en query o hash fragment
  let errorParam = (route.query.error || route.query.error_description) as string | undefined
  let errorCode = route.query.error_code as string | undefined

  if (!errorParam && typeof window !== 'undefined' && window.location.hash) {
    const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''))
    errorParam = hashParams.get('error_description') || hashParams.get('error') || undefined
    errorCode = hashParams.get('error_code') || undefined
  }

  if (errorParam || errorCode) {
    status.value = 'error'
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
    return
  }

  // 2. Si regresamos con código PKCE (?code=...), intentar intercambiar por sesión
  const code = route.query.code
  if (code && typeof code === 'string') {
    try {
      await supabase.auth.exchangeCodeForSession(code)
    } catch {
      // Si el plugin de @nuxtjs/supabase ya consumió el código en paralelo, continuamos
    }
  }

  // 3. Obtener usuario de la sesión activa
  let activeUser = (await supabase.auth.getUser()).data?.user
  if (!activeUser) {
    const { data: sessionData } = await supabase.auth.getSession()
    activeUser = sessionData.session?.user || null
  }

  if (activeUser) {
    await authStore.fetchProfile(activeUser)

    if (authStore.isAuthenticated) {
      status.value = 'success'
      if (!authStore.isEmailVerified) {
        navigateTo('/verificar-correo')
      } else if (authStore.needsConsent) {
        navigateTo('/aceptar-terminos')
      } else {
        navigateTo('/app')
      }
      return
    }
  }

  // 4. Si tras verificar no hay usuario ni sesión activa:
  if (!code) {
    navigateTo('/login')
  } else {
    status.value = 'error'
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
  }
})

async function handleGoToLogin() {
  try {
    await authStore.logout()
  } catch {
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
    if (typeof window !== 'undefined') {
      window.location.href = '/login'
    } else {
      await navigateTo('/login')
    }
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-guaiqui-surface text-guaiqui-text px-4 py-12">
    <!-- Estado: Verificando -->
    <div v-if="status === 'verifying'" class="text-center space-y-4 max-w-sm">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary text-3xl shadow-guaiqui-sm">
        <i class="bi bi-arrow-repeat animate-spin"></i>
      </div>
      <h2 class="text-xl font-display font-bold uppercase tracking-wider text-guaiqui-text">Verificando enlace</h2>
      <p class="text-guaiqui-text-muted text-sm font-medium">Validando tu acceso con la plataforma...</p>
    </div>

    <!-- Estado: Error / Inicio no válido -->
    <div v-else-if="status === 'error'" class="w-full max-w-md bg-white border border-guaiqui-border rounded-2xl p-6 sm:p-8 shadow-guaiqui-md space-y-6 text-center">
      <!-- Logo -->
      <div class="inline-flex items-center justify-center">
        <img src="/logo.png" alt="Guaiqueríes Logo" class="w-16 h-16 object-contain" />
      </div>

      <!-- Título y Subtítulo -->
      <div class="space-y-2">
        <h2 class="text-2xl font-display font-bold uppercase tracking-wider text-guaiqui-text">
          Inicio no válido
        </h2>
        <p class="text-guaiqui-text-muted text-sm leading-relaxed">
          Por favor comunícate con soporte técnico
        </p>
      </div>

      <!-- Botón de redirección -->
      <div class="pt-2">
        <button
          type="button"
          class="w-full py-2.5 px-4 rounded-lg bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-sm tracking-wide transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-guaiqui-sm"
          @click="handleGoToLogin"
        >
          <i class="bi bi-box-arrow-in-right"></i>
          <span>Ir a Iniciar Sesión</span>
        </button>
      </div>
    </div>
  </div>
</template>
