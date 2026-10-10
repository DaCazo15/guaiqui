<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { useSupabaseClient, useSupabaseUser } from '#imports'

const supabase = useSupabaseClient()
const user = useSupabaseUser()

const isMfaEnabled = ref(false)
const factorId = ref<string | null>(null)
const qrCodeUrl = ref('')
const secretCode = ref('')
const verifyCode = ref('')
const isEnrolling = ref(false)
const isLoading = ref(true)
const errorMsg = ref('')
const successMsg = ref('')

const recoveryCodes = ref<string[]>([])
const showRecoveryModal = ref(false)

const checkMfaStatus = async () => {
  isLoading.value = true
  try {
    const { data, error } = await supabase.auth.mfa.listFactors()
    if (error) throw error

    const verified = data?.totp?.find(f => f.status === 'verified')
    if (verified) {
      isMfaEnabled.value = true
      factorId.value = verified.id
    } else {
      isMfaEnabled.value = false
      factorId.value = null
    }
  } catch (err: any) {
    console.warn('Error checking MFA status:', err)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  checkMfaStatus()
})

const startEnrollment = async () => {
  errorMsg.value = ''
  successMsg.value = ''
  try {
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      issuer: 'Guaiqueríes de Margarita',
      friendlyName: 'Fan Zone 2FA'
    })

    if (error) throw error

    factorId.value = data.id
    qrCodeUrl.value = data.totp.qr_code
    secretCode.value = data.totp.secret
    isEnrolling.value = true
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al iniciar la activación de 2FA.'
  }
}

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

const confirmEnrollment = async () => {
  if (!verifyCode.value || verifyCode.value.length !== 6 || !factorId.value) return

  errorMsg.value = ''
  try {
    const challenge = await supabase.auth.mfa.challenge({ factorId: factorId.value })
    if (challenge.error) throw challenge.error

    const verify = await supabase.auth.mfa.verify({
      factorId: factorId.value,
      challengeId: challenge.data.id,
      code: verifyCode.value
    })

    if (verify.error) throw verify.error

    // Generate and save 10 recovery codes
    const codes = generateRecoveryCodes()
    recoveryCodes.value = codes
    const hashes = await Promise.all(codes.map(c => hashString(c)))

    await supabase.rpc('save_mfa_recovery_code_hashes', { p_hashes: hashes })

    await supabase.rpc('create_security_notification', {
      p_user_id: user.value?.id,
      p_title: 'Seguridad de la Cuenta',
      p_body: 'Se ha activado la verificación en dos pasos (2FA) en tu cuenta de fanático.'
    })

    isMfaEnabled.value = true
    isEnrolling.value = false
    showRecoveryModal.value = true
    successMsg.value = '¡Verificación en dos pasos activada exitosamente!'
  } catch (err: any) {
    errorMsg.value = err.message || 'Código de verificación incorrecto.'
  }
}

const disableMfa = async () => {
  if (!factorId.value) return
  if (!confirm('¿Estás seguro de desactivar la verificación en dos pasos? Tu cuenta tendrá menor seguridad.')) return

  errorMsg.value = ''
  successMsg.value = ''

  try {
    const { error } = await supabase.auth.mfa.unenroll({ factorId: factorId.value })
    if (error) throw error

    await supabase.rpc('create_security_notification', {
      p_user_id: user.value?.id,
      p_title: 'Seguridad de la Cuenta',
      p_body: 'Se ha desactivado la verificación en dos pasos (2FA) en tu cuenta.'
    })

    isMfaEnabled.value = false
    factorId.value = null
    successMsg.value = 'Verificación en dos pasos desactivada.'
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al desactivar 2FA.'
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
  a.download = 'codigos-recuperacion-fan.txt'
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-base font-semibold text-guaiqui-text">Verificación en Dos Pasos (2FA)</h3>
        <p class="text-xs text-guaiqui-text-muted">
          Añade una capa extra de seguridad para proteger tus perlitas, canjes y datos personales.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <span v-if="isMfaEnabled" class="px-2.5 py-1 text-xs font-semibold bg-green-100 text-green-700 rounded-full flex items-center gap-1">
          <i class="bi bi-shield-check"></i> Activado
        </span>
        <span v-else class="px-2.5 py-1 text-xs font-semibold bg-gray-100 text-gray-600 rounded-full flex items-center gap-1">
          <i class="bi bi-shield-x"></i> Desactivado
        </span>
      </div>
    </div>

    <div v-if="errorMsg" class="p-3 bg-red-50 border border-red-200 rounded-lg text-xs text-red-700 flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill"></i>
      <span>{{ errorMsg }}</span>
    </div>

    <div v-if="successMsg" class="p-3 bg-green-50 border border-green-200 rounded-lg text-xs text-green-700 flex items-center gap-2">
      <i class="bi bi-check-circle-fill"></i>
      <span>{{ successMsg }}</span>
    </div>

    <!-- Actions -->
    <div v-if="!isMfaEnabled && !isEnrolling" class="pt-2">
      <BaseButton variant="outline" size="sm" @click="startEnrollment">
        <i class="bi bi-shield-plus mr-1.5"></i> Activación Opcional de 2FA
      </BaseButton>
    </div>

    <div v-else-if="isMfaEnabled" class="pt-2">
      <BaseButton variant="danger" size="sm" @click="disableMfa">
        <i class="bi bi-shield-minus mr-1.5"></i> Desactivar 2FA
      </BaseButton>
    </div>

    <!-- Enrollment Steps -->
    <div v-if="isEnrolling" class="p-4 bg-gray-50 border rounded-lg space-y-4 text-xs">
      <p class="font-medium text-gray-800">1. Escanea este código QR con tu aplicación de autenticación (Google Authenticator, Authy, etc.):</p>
      <div class="flex flex-col items-center gap-2">
        <img v-if="qrCodeUrl" :src="qrCodeUrl" alt="Código QR 2FA" class="w-40 h-40 border rounded bg-white p-2" />
        <p class="font-mono bg-white px-2 py-1 border rounded text-gray-700 select-all">{{ secretCode }}</p>
      </div>

      <p class="font-medium text-gray-800">2. Ingresa el código de 6 dígitos que aparece en tu aplicación:</p>
      <div class="flex gap-2">
        <input
          v-model="verifyCode"
          type="text"
          maxlength="6"
          placeholder="123456"
          class="px-3 py-1.5 border rounded text-center text-lg tracking-widest font-mono w-40"
        />
        <BaseButton size="sm" @click="confirmEnrollment">Verificar y Confirmar</BaseButton>
        <BaseButton variant="outline" size="sm" @click="isEnrolling = false">Cancelar</BaseButton>
      </div>
    </div>

    <!-- Recovery Codes Modal -->
    <div v-if="showRecoveryModal" class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div class="bg-white rounded-xl max-w-md w-full p-6 space-y-4">
        <div class="flex items-center gap-2 text-green-600">
          <i class="bi bi-shield-lock-fill text-2xl"></i>
          <h4 class="font-bold text-gray-900">Códigos de Recuperación 2FA</h4>
        </div>
        <p class="text-xs text-gray-600">
          Guarda estos 10 códigos en un lugar seguro. Cada uno funciona 1 sola vez si pierdes tu dispositivo.
        </p>

        <div class="grid grid-cols-2 gap-2 bg-gray-50 p-3 rounded font-mono text-xs border">
          <div v-for="c in recoveryCodes" :key="c" class="text-center py-1 bg-white border rounded">
            {{ c }}
          </div>
        </div>

        <div class="flex gap-2 text-xs">
          <button @click="copyCodes" class="flex-1 py-1.5 border rounded hover:bg-gray-50 font-medium">
            <i class="bi bi-clipboard mr-1"></i> Copiar
          </button>
          <button @click="downloadCodes" class="flex-1 py-1.5 border rounded hover:bg-gray-50 font-medium">
            <i class="bi bi-download mr-1"></i> Descargar
          </button>
        </div>

        <BaseButton class="w-full" size="sm" @click="showRecoveryModal = false">Entendido</BaseButton>
      </div>
    </div>
  </div>
</template>
