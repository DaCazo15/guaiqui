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
  <div class="min-h-screen flex items-center justify-center bg-gray-100 p-4">
    <div class="max-w-md w-full bg-white rounded-xl shadow-lg p-6 space-y-6">
      <div class="text-center space-y-2">
        <div class="w-12 h-12 bg-amber-100 text-amber-600 rounded-full flex items-center justify-center mx-auto">
          <i class="bi bi-shield-lock text-2xl"></i>
        </div>
        <h1 class="text-xl font-bold text-gray-900">Verificación en Dos Pasos Obligatoria</h1>
        <p class="text-sm text-gray-600">
          Por seguridad del sistema, el personal y los administradores deben vincular una aplicación de autenticación (Google Authenticator, Authy, etc.).
        </p>
      </div>

      <div v-if="errorMsg" class="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <span>{{ errorMsg }}</span>
      </div>

      <!-- QR Code Section -->
      <div class="flex flex-col items-center space-y-4">
        <div v-if="qrCodeUrl" class="p-3 border border-gray-200 rounded-lg bg-white shadow-inner">
          <img :src="qrCodeUrl" alt="Código QR 2FA" class="w-48 h-48" />
        </div>
        <div v-else class="w-48 h-48 bg-gray-100 animate-pulse rounded-lg flex items-center justify-center">
          <span class="text-xs text-gray-400">Generando QR...</span>
        </div>

        <div class="text-center space-y-1">
          <p class="text-xs text-gray-500 font-medium">¿No puedes escanear el código QR?</p>
          <p class="text-xs font-mono bg-gray-100 px-3 py-1 rounded border text-gray-800 break-all select-all">
            {{ secretCode || 'Cargando clave...' }}
          </p>
        </div>
      </div>

      <!-- Verification Code Form -->
      <form @submit.prevent="handleVerifyEnrollment" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Código de 6 dígitos</label>
          <input
            v-model="verifyCode"
            type="text"
            maxlength="6"
            placeholder="123456"
            class="w-full px-4 py-2 border rounded-lg text-center text-2xl tracking-widest font-mono focus:ring-2 focus:ring-green-500 focus:outline-none"
            required
          />
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg transition disabled:opacity-50 flex items-center justify-center gap-2"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin"></i>
          <span>{{ isSubmitting ? 'Verificando...' : 'Activar Verificación 2FA' }}</span>
        </button>
      </form>
    </div>

    <!-- Recovery Codes Modal -->
    <div v-if="showRecoveryModal" class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div class="bg-white rounded-xl max-w-lg w-full p-6 space-y-4">
        <div class="flex items-center gap-3 text-green-600">
          <i class="bi bi-check-circle-fill text-3xl"></i>
          <div>
            <h3 class="text-lg font-bold text-gray-900">¡2FA Activado Exitosamente!</h3>
            <p class="text-xs text-gray-500">Guarda tus códigos de recuperación de un solo uso.</p>
          </div>
        </div>

        <div class="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-800">
          <i class="bi bi-exclamation-circle-fill mr-1"></i>
          Estos códigos solo se muestran <strong>UNA SOLA VEZ</strong>. Te permitirán ingresar si pierdes tu dispositivo 2FA.
        </div>

        <div class="grid grid-cols-2 gap-2 bg-gray-50 p-4 rounded-lg font-mono text-sm border">
          <div v-for="code in recoveryCodes" :key="code" class="text-center py-1 bg-white rounded border text-gray-800">
            {{ code }}
          </div>
        </div>

        <div class="flex gap-2">
          <button @click="copyCodes" class="flex-1 py-2 border rounded-lg hover:bg-gray-50 text-sm font-medium flex items-center justify-center gap-1">
            <i class="bi bi-clipboard"></i> Copiar
          </button>
          <button @click="downloadCodes" class="flex-1 py-2 border rounded-lg hover:bg-gray-50 text-sm font-medium flex items-center justify-center gap-1">
            <i class="bi bi-download"></i> Descargar
          </button>
        </div>

        <button @click="finishEnrollment" class="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-2 rounded-lg text-sm">
          Entendido, ir al sistema
        </button>
      </div>
    </div>
  </div>
</template>
