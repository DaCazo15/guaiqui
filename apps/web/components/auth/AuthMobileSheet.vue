<script setup lang="ts">
import { ref } from 'vue'

const props = withDefaults(
  defineProps<{
    loading?: boolean
    errorMessage?: string | null
    initialMode?: 'login' | 'register'
  }>(),
  {
    loading: false,
    errorMessage: null,
    initialMode: 'login'
  }
)

const emit = defineEmits<{
  (e: 'login', payload: { email: string; pass: string }): void
  (e: 'register', payload: { email: string; pass: string }): void
  (e: 'googleAuth'): void
}>()

const activeTab = ref<'login' | 'register'>(props.initialMode)

// Login form
const loginEmail = ref('')
const loginPassword = ref('')

// Register form
const regEmail = ref('')
const regPassword = ref('')
const regConfirmPassword = ref('')
const regTerms = ref(true)

const localValidation = ref<string | null>(null)

function handleLoginSubmit() {
  localValidation.value = null
  if (!loginEmail.value.trim() || !loginPassword.value) {
    localValidation.value = 'Ingresa tu correo y contraseña para continuar.'
    return
  }
  emit('login', {
    email: loginEmail.value.trim(),
    pass: loginPassword.value
  })
}

function handleRegisterSubmit() {
  localValidation.value = null
  if (!regEmail.value.trim() || !regEmail.value.includes('@')) {
    localValidation.value = 'Ingresa un correo electrónico válido.'
    return
  }
  if (!regPassword.value || regPassword.value.length < 8) {
    localValidation.value = 'La contraseña debe tener al menos 8 caracteres.'
    return
  }
  if (regPassword.value !== regConfirmPassword.value) {
    localValidation.value = 'Las contraseñas no coinciden.'
    return
  }
  if (!regTerms.value) {
    localValidation.value = 'Debes aceptar los Términos y Políticas para unirte.'
    return
  }

  emit('register', {
    email: regEmail.value.trim(),
    pass: regPassword.value
  })
}
</script>

<template>
  <div class="relative z-10 w-full bg-gradient-to-b from-[#0e743a] via-[#09542a] to-[#043319] rounded-t-[36px] sm:rounded-t-[44px] border-t-2 border-emerald-400/40 shadow-[0_-20px_50px_rgba(0,0,0,0.7)] px-5 pt-8 pb-10 sm:px-8 sm:pt-10 sm:pb-12 md:px-10 md:pt-11 md:pb-12 text-white">
    <!-- Toggle buttons (Pill style matching the mockup) -->
    <div class="space-y-3 mb-6">
      <div class="grid grid-cols-2 gap-2 sm:gap-3 p-1.5 rounded-full bg-slate-950/40 border border-emerald-500/30 backdrop-blur-md">
        <button
          type="button"
          @click="activeTab = 'login'; localValidation = null"
          :class="[
            'py-2.5 sm:py-3 px-4 sm:px-6 rounded-full text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-300 flex items-center justify-center gap-1.5 sm:gap-2',
            activeTab === 'login'
              ? 'bg-white text-slate-950 shadow-lg shadow-black/30 scale-[1.02]'
              : 'text-emerald-100 hover:text-white hover:bg-white/10'
          ]"
        >
          <i class="bi bi-box-arrow-in-right"></i>
          <span>Iniciar Sesión</span>
        </button>

        <button
          type="button"
          @click="activeTab = 'register'; localValidation = null"
          :class="[
            'py-2.5 sm:py-3 px-4 sm:px-6 rounded-full text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-300 flex items-center justify-center gap-1.5 sm:gap-2',
            activeTab === 'register'
              ? 'bg-white text-slate-950 shadow-lg shadow-black/30 scale-[1.02]'
              : 'text-emerald-100 hover:text-white hover:bg-white/10'
          ]"
        >
          <i class="bi bi-person-plus-fill"></i>
          <span>Registrarte</span>
        </button>
      </div>
    </div>

    <!-- Feedback alerts -->
    <div
      v-if="localValidation || errorMessage"
      class="mb-4 p-3 rounded-2xl bg-red-950/80 border border-red-500/50 text-red-200 text-xs flex items-center gap-2 shadow-md animate-shake"
    >
      <i class="bi bi-exclamation-triangle-fill text-red-400 shrink-0"></i>
      <span class="flex-1">{{ localValidation || errorMessage }}</span>
    </div>

    <!-- Mode: Iniciar Sesión Form -->
    <form v-if="activeTab === 'login'" @submit.prevent="handleLoginSubmit" class="space-y-3.5">
      <div>
        <label class="block text-[11px] font-bold uppercase tracking-wider text-emerald-200 mb-1">
          Correo Electrónico
        </label>
        <div class="relative">
          <i class="bi bi-envelope-fill absolute left-3.5 top-1/2 -translate-y-1/2 text-emerald-400/80 text-sm"></i>
          <input
            v-model="loginEmail"
            type="email"
            autocomplete="email"
            placeholder="fanatico@ejemplo.com"
            required
            class="w-full pl-10 pr-4 py-3 rounded-2xl bg-slate-950/50 border border-emerald-500/40 text-white placeholder-emerald-200/40 text-xs sm:text-sm focus:outline-none focus:border-white focus:ring-2 focus:ring-white/20 transition-all shadow-inner"
          />
        </div>
      </div>

      <div>
        <div class="flex items-center justify-between mb-1">
          <label class="text-[11px] font-bold uppercase tracking-wider text-emerald-200">
            Contraseña
          </label>
          <NuxtLink
            to="/recuperar"
            class="text-[11px] text-emerald-300 hover:text-white underline font-semibold transition-colors"
          >
            ¿La olvidaste?
          </NuxtLink>
        </div>
        <div class="relative">
          <i class="bi bi-lock-fill absolute left-3.5 top-1/2 -translate-y-1/2 text-emerald-400/80 text-sm"></i>
          <input
            v-model="loginPassword"
            type="password"
            autocomplete="current-password"
            placeholder="••••••••"
            required
            class="w-full pl-10 pr-4 py-3 rounded-2xl bg-slate-950/50 border border-emerald-500/40 text-white placeholder-emerald-200/40 text-xs sm:text-sm focus:outline-none focus:border-white focus:ring-2 focus:ring-white/20 transition-all shadow-inner"
          />
        </div>
      </div>

      <button
        type="submit"
        :disabled="loading"
        class="w-full mt-2 py-3.5 sm:py-4 px-6 rounded-full bg-white hover:bg-slate-100 active:scale-[0.99] text-slate-950 font-bold uppercase text-xs sm:text-sm tracking-wider shadow-lg shadow-black/25 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
      >
        <i v-if="loading" class="bi bi-arrow-repeat animate-spin text-base"></i>
        <i v-else class="bi bi-box-arrow-in-right text-emerald-700"></i>
        <span>{{ loading ? 'Entrando a la Tribu...' : 'Iniciar Sesión' }}</span>
      </button>
    </form>

    <!-- Mode: Registrarte Form -->
    <form v-else @submit.prevent="handleRegisterSubmit" class="space-y-3.5">
      <div>
        <label class="block text-[11px] font-bold uppercase tracking-wider text-emerald-200 mb-1">
          Tu Correo Electrónico
        </label>
        <div class="relative">
          <i class="bi bi-envelope-fill absolute left-3.5 top-1/2 -translate-y-1/2 text-emerald-400/80 text-sm"></i>
          <input
            v-model="regEmail"
            type="email"
            autocomplete="email"
            placeholder="fanatico@ejemplo.com"
            required
            class="w-full pl-10 pr-4 py-3 rounded-2xl bg-slate-950/50 border border-emerald-500/40 text-white placeholder-emerald-200/40 text-xs sm:text-sm focus:outline-none focus:border-white focus:ring-2 focus:ring-white/20 transition-all shadow-inner"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-emerald-200 mb-1">
            Contraseña
          </label>
          <div class="relative">
            <i class="bi bi-lock-fill absolute left-3.5 top-1/2 -translate-y-1/2 text-emerald-400/80 text-sm"></i>
            <input
              v-model="regPassword"
              type="password"
              autocomplete="new-password"
              placeholder="Mín. 8 caracteres"
              required
              class="w-full pl-10 pr-4 py-3 rounded-2xl bg-slate-950/50 border border-emerald-500/40 text-white placeholder-emerald-200/40 text-xs sm:text-sm focus:outline-none focus:border-white focus:ring-2 focus:ring-white/20 transition-all shadow-inner"
            />
          </div>
        </div>

        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-emerald-200 mb-1">
            Confirmar
          </label>
          <div class="relative">
            <i class="bi bi-check2-circle absolute left-3.5 top-1/2 -translate-y-1/2 text-emerald-400/80 text-sm"></i>
            <input
              v-model="regConfirmPassword"
              type="password"
              autocomplete="new-password"
              placeholder="Repite la clave"
              required
              class="w-full pl-10 pr-4 py-3 rounded-2xl bg-slate-950/50 border border-emerald-500/40 text-white placeholder-emerald-200/40 text-xs sm:text-sm focus:outline-none focus:border-white focus:ring-2 focus:ring-white/20 transition-all shadow-inner"
            />
          </div>
        </div>
      </div>

      <div class="flex items-start gap-2 pt-1 text-[11px] text-emerald-100">
        <input
          v-model="regTerms"
          id="terms_consent"
          type="checkbox"
          required
          class="mt-0.5 rounded border-emerald-500/50 bg-slate-950 text-emerald-600 focus:ring-emerald-400"
        />
        <label for="terms_consent" class="cursor-pointer">
          Acepto los
          <NuxtLink to="/politicas/terminos" target="_blank" class="text-white underline font-bold">Términos</NuxtLink>,
          <NuxtLink to="/politicas/privacidad" target="_blank" class="text-white underline font-bold">Privacidad</NuxtLink> y
          <NuxtLink to="/politicas/perlitas" target="_blank" class="text-white underline font-bold">Reglas de Perlitas</NuxtLink>.
        </label>
      </div>

      <button
        type="submit"
        :disabled="loading"
        class="w-full mt-2 py-3.5 sm:py-4 px-6 rounded-full bg-white hover:bg-slate-100 active:scale-[0.99] text-slate-950 font-bold uppercase text-xs sm:text-sm tracking-wider shadow-lg shadow-black/25 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
      >
        <i v-if="loading" class="bi bi-arrow-repeat animate-spin text-base"></i>
        <i v-else class="bi bi-award-fill text-amber-500"></i>
        <span>{{ loading ? 'Creando cuenta...' : 'Crear Mi Cuenta Gratis' }}</span>
      </button>
    </form>

    <!-- Divider: OR (Exact match to the mockup) -->
    <div class="relative my-6 flex items-center justify-center">
      <div class="w-full border-t border-emerald-400/30"></div>
      <span class="absolute bg-[#09542a] px-4 text-[11px] font-bold uppercase tracking-widest text-emerald-200/90 rounded-full border border-emerald-400/20">
        O
      </span>
    </div>

    <!-- Google Login / Register Button (Pill outline with Google SVG logo) -->
    <button
      type="button"
      @click="emit('googleAuth')"
      :disabled="loading"
      class="w-full py-3.5 sm:py-4 px-6 rounded-full border-2 border-white/80 hover:border-white bg-slate-950/30 hover:bg-slate-950/50 text-white font-bold text-xs sm:text-sm tracking-wide transition-all duration-200 flex items-center justify-center gap-3 cursor-pointer shadow-md hover:shadow-lg active:scale-[0.99] disabled:opacity-50"
    >
      <!-- Official Google 4-color SVG logo -->
      <svg class="w-5 h-5 shrink-0" viewBox="0 0 24 24">
        <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
        <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
      </svg>
      <span>{{ activeTab === 'login' ? 'Continuar con Google' : 'Registrarte con Google' }}</span>
    </button>
  </div>
</template>
