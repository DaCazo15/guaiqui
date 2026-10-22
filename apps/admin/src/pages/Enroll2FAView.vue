<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const qrCodeUrl = ref('')
const secretCode = ref('')
const factorId = ref('')
const verifyCode = ref('')
const errorMsg = ref('')
const isSubmitting = ref(false)
const recoveryCodes = ref<string[]>([])
const showRecoveryModal = ref(false)

onMounted(async () => {
  try {
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      issuer: 'Guaiqueríes de Margarita',
      friendlyName: 'Staff 2FA'
    })

    if (error) throw error

    factorId.value = data.id
    qrCodeUrl.value = data.totp.qr_code
    secretCode.value = data.totp.secret
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al generar el código QR de 2FA.'
  }
})

const generateRecoveryCodes = (): string[] => {
  const codes: string[] = []
  for (let i = 0; i < 10; i++) {
    const rand = Math.random().toString(36).substring(2, 6).toUpperCase() + '-' + Math.random().toString(36).substring(2, 6).toUpperCase()
    codes.push(rand)
  }
  return codes
}

const hashString = async (text: string): Promise<string> => {
  const encoder = new TextEncoder()
  const data = encoder.encode(text.trim().toUpperCase())
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

const handleVerifyEnrollment = async () => {
  if (!verifyCode.value || verifyCode.value.length !== 6) {
    errorMsg.value = 'Ingresa un código válido de 6 dígitos.'
    return
  }

  isSubmitting.value = true
  errorMsg.value = ''

  try {
    const challenge = await supabase.auth.mfa.challenge({ factorId: factorId.value })
    if (challenge.error) throw challenge.error

    const verifyResp = await supabase.auth.mfa.verify({
      factorId: factorId.value,
      challengeId: challenge.data.id,
      code: verifyCode.value
    })

    if (verifyResp.error) throw verifyResp.error

    // Generate 10 recovery codes & save hashes
    const generatedCodes = generateRecoveryCodes()
    recoveryCodes.value = generatedCodes

    const hashes = await Promise.all(generatedCodes.map(c => hashString(c)))
    const { error: saveErr } = await supabase.rpc('save_mfa_recovery_code_hashes', { p_hashes: hashes })
    if (saveErr) console.warn('Could not save recovery code hashes:', saveErr)

    showRecoveryModal.value = true
  } catch (err: any) {
    errorMsg.value = err.message || 'Código de verificación incorrecto. Intenta de nuevo.'
  } finally {
    isSubmitting.value = false
  }
}

const finishEnrollment = () => {
  if (authStore.isAdmin) {
    router.replace({ name: 'admin-dashboard' })
  } else {
    router.replace({ name: 'staff-queue' })
  }
}

const copyCodes = () => {
  navigator.clipboard.writeText(recoveryCodes.value.join('\n'))
}

const downloadCodes = () => {
  const blob = new Blob([recoveryCodes.value.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'codigos-recuperacion-guaiqueries.txt'
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 flex flex-col justify-center items-center px-4 py-12 font-body">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl space-y-6">
      <div class="text-center space-y-2">
        <div class="w-14 h-14 bg-amber-950/60 border border-amber-700/60 text-amber-400 rounded-2xl flex items-center justify-center mx-auto shadow-inner">
          <i class="bi bi-shield-lock text-2xl"></i>
        </div>
        <h1 class="text-2xl font-bold text-white tracking-wide font-title">Verificación en Dos Pasos Obligatoria</h1>
        <p class="text-sm text-slate-400">
          Por seguridad del sistema, el personal y los administradores deben vincular una aplicación de autenticación (Google Authenticator, Authy, etc.).
        </p>
      </div>

      <div v-if="errorMsg" class="p-4 bg-red-950/50 border border-red-800/80 rounded-xl text-red-200 text-sm flex items-start gap-3">
        <i class="bi bi-exclamation-octagon-fill text-red-400 text-lg flex-shrink-0 mt-0.5"></i>
        <div>
          <span class="font-semibold block">Error de activación</span>
          <span class="text-red-300 text-xs">{{ errorMsg }}</span>
        </div>
      </div>

      <!-- QR Code Section -->
      <div class="flex flex-col items-center space-y-4">
        <div v-if="qrCodeUrl" class="p-3 border border-slate-700 rounded-2xl bg-white shadow-lg">
          <img :src="qrCodeUrl" alt="Código QR 2FA" class="w-48 h-48 rounded-lg" />
        </div>
        <div v-else class="w-48 h-48 bg-slate-950 border border-slate-800 animate-pulse rounded-2xl flex items-center justify-center">
          <span class="text-xs text-slate-500">Generando QR...</span>
        </div>

        <div class="text-center space-y-1.5 w-full">
          <p class="text-xs text-slate-400 font-medium">¿No puedes escanear el código QR?</p>
          <p class="text-xs font-mono bg-slate-950 px-3 py-2 rounded-xl border border-slate-800 text-emerald-400 break-all select-all shadow-inner">
            {{ secretCode || 'Cargando clave...' }}
          </p>
        </div>
      </div>

      <!-- Verification Code Form -->
      <form @submit.prevent="handleVerifyEnrollment" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2 text-center">
            Código de 6 dígitos
          </label>
          <input
            v-model="verifyCode"
            type="text"
            maxlength="6"
            placeholder="123456"
            class="w-full py-3.5 px-4 bg-slate-950 border border-slate-800 rounded-xl text-center text-3xl tracking-[0.3em] font-mono text-emerald-400 placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all shadow-inner"
            required
            autofocus
          />
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full py-3.5 px-4 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white font-semibold rounded-xl transition-all duration-150 flex items-center justify-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50 disabled:cursor-not-allowed text-sm mt-2"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin text-lg"></i>
          <i v-else class="bi bi-shield-check text-lg"></i>
          <span>{{ isSubmitting ? 'Verificando...' : 'Activar Verificación 2FA' }}</span>
        </button>
      </form>
    </div>

    <!-- Recovery Codes Modal -->
    <div v-if="showRecoveryModal" class="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div class="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
        <div class="flex items-center gap-3 text-emerald-400">
          <i class="bi bi-check-circle-fill text-3xl"></i>
          <div>
            <h3 class="text-lg font-bold text-white font-title">¡2FA Activado Exitosamente!</h3>
            <p class="text-xs text-slate-400">Guarda tus códigos de recuperación de un solo uso.</p>
          </div>
        </div>

        <div class="p-3 bg-amber-950/50 border border-amber-800/80 rounded-xl text-xs text-amber-200">
          <i class="bi bi-exclamation-triangle-fill mr-1 text-amber-400"></i>
          Estos códigos solo se muestran <strong>UNA SOLA VEZ</strong>. Te permitirán ingresar si pierdes tu dispositivo 2FA.
        </div>

        <div class="grid grid-cols-2 gap-2 bg-slate-950 p-4 rounded-xl font-mono text-sm border border-slate-800">
          <div v-for="code in recoveryCodes" :key="code" class="text-center py-1.5 bg-slate-900 rounded-lg border border-slate-800 text-emerald-400 font-bold">
            {{ code }}
          </div>
        </div>

        <div class="flex gap-2">
          <button @click="copyCodes" class="flex-1 py-2.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors">
            <i class="bi bi-clipboard"></i> Copiar
          </button>
          <button @click="downloadCodes" class="flex-1 py-2.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors">
            <i class="bi bi-download"></i> Descargar
          </button>
        </div>

        <button @click="finishEnrollment" class="w-full py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl text-sm transition-colors shadow-lg shadow-emerald-950/50">
          Entendido, ir al sistema
        </button>
      </div>
    </div>
  </div>
</template>
