<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)

const handleLogin = async () => {
  if (!email.value || !password.value) {
    errorMessage.value = 'Por favor complete todos los campos.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  const result = await authStore.signIn(email.value, password.value)

  if (result.success) {
    router.push('/staff/cola')
  } else {
    errorMessage.value = result.message || 'Error al ingresar al portal de taquilla.'
  }

  isSubmitting.value = false
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 flex flex-col justify-center items-center px-4 py-12">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl space-y-6">
      <!-- Header / Logo -->
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center mb-1">
          <img src="/logo.png" alt="Guaiqueríes Taquilla Logo" class="w-16 h-16 object-contain" />
        </div>
        <h1 class="text-2xl font-bold text-white tracking-wide">Guaiqueríes Taquilla</h1>
        <p class="text-sm text-slate-400">Portal de Validación y Canjes para Personal</p>
      </div>

      <!-- Alert Error Message -->
      <div
        v-if="errorMessage || authStore.authError"
        class="p-4 bg-red-950/50 border border-red-800/80 rounded-xl text-red-200 text-sm flex items-start gap-3"
      >
        <i class="bi bi-exclamation-octagon-fill text-red-400 text-lg flex-shrink-0 mt-0.5"></i>
        <div>
          <span class="font-semibold block">Acceso denegado</span>
          <span class="text-red-300 text-xs">{{ errorMessage || authStore.authError }}</span>
        </div>
      </div>

      <!-- Login Form -->
      <form @submit.prevent="handleLogin" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
            Correo Electrónico
          </label>

          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500">
              <i class="bi bi-envelope"></i>
            </span>

            <input
              v-model="email"
              type="email"
              required
              placeholder="personal@guaiqueries.com"
              class="w-full pl-10 pr-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 text-sm transition-all"
            />
          </div>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
            Contraseña
          </label>

          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500">
              <i class="bi bi-key"></i>
            </span>

            <input
              v-model="password"
              type="password"
              required
              placeholder="••••••••"
              class="w-full pl-10 pr-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 text-sm transition-all"
            />
          </div>
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full py-3 px-4 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white font-semibold rounded-xl transition-all duration-150 flex items-center justify-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50 disabled:cursor-not-allowed mt-2"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin text-lg"></i>
          <i v-else class="bi bi-box-arrow-in-right text-lg"></i>
          <span>{{ isSubmitting ? 'Verificando acceso...' : 'Ingresar al Sistema' }}</span>
        </button>
      </form>

      <div class="pt-4 border-t border-slate-800/80 text-center">
        <p class="text-xs text-slate-500">
          ¿No tienes credenciales de taquilla? Contacta al administrador del sistema.
        </p>
      </div>
    </div>
  </div>
</template>
