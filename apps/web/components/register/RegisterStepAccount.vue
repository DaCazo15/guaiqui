<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton, BaseCheckbox } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const props = defineProps<{
  initialEmail?: string
  loading?: boolean
  error?: string | null
}>()

const emit = defineEmits<{
  (e: 'submit', payload: {
    email: string
    pass: string
    consent: { terms: boolean; privacy: boolean; pearlsRules: boolean }
  }): void
}>()

const authStore = useAuthStore()

const email = ref(props.initialEmail || '')
const password = ref('')
const confirmPassword = ref('')
const terms = ref(false)
const privacy = ref(false)
const pearlsRules = ref(false)

const localError = ref<string | null>(null)
const isCheckingEmail = ref(false)

async function checkAvailability(): Promise<boolean> {
  const cleanEmail = email.value.trim().toLowerCase()
  if (!cleanEmail || !cleanEmail.includes('@') || !cleanEmail.includes('.')) {
    return false
  }

  isCheckingEmail.value = true
  try {
    const exists = await authStore.checkEmailExists(cleanEmail)
    if (exists) {
      localError.value = 'Este correo electrónico ya está en uso. Por favor inicia sesión o utiliza otro correo.'
      return false
    }
    return true
  } finally {
    isCheckingEmail.value = false
  }
}

async function onEmailBlur() {
  if (localError.value && localError.value.includes('correo')) {
    localError.value = null
  }
  const cleanEmail = email.value.trim().toLowerCase()
  if (cleanEmail && cleanEmail.includes('@') && cleanEmail.includes('.')) {
    await checkAvailability()
  }
}

async function handleSubmit() {
  localError.value = null

  if (!email.value || !email.value.includes('@')) {
    localError.value = 'Ingresa un correo electrónico válido.'
    return
  }

  if (!password.value || password.value.length < 8) {
    localError.value = 'La contraseña debe tener al menos 8 caracteres.'
    return
  }

  if (password.value !== confirmPassword.value) {
    localError.value = 'Las contraseñas no coinciden.'
    return
  }

  if (!terms.value || !privacy.value || !pearlsRules.value) {
    localError.value = 'Debes aceptar los Términos, Políticas de Privacidad y Reglas de Perlitas.'
    return
  }

  // Strictly block proceeding if email is not available
  const isAvailable = await checkAvailability()
  if (!isAvailable) {
    return
  }

  emit('submit', {
    email: email.value.trim().toLowerCase(),
    pass: password.value,
    consent: {
      terms: terms.value,
      privacy: privacy.value,
      pearlsRules: pearlsRules.value,
    },
  })
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="space-y-4">
    <div v-if="localError || error" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ localError || error }}</span>
    </div>

    <BaseInput
      v-model="email"
      label="Correo electrónico *"
      type="email"
      placeholder="tu@email.com"
      required
      @blur="onEmailBlur"
    />

    <BaseInput
      v-model="password"
      label="Contraseña *"
      type="password"
      placeholder="Mínimo 8 caracteres"
      required
    />

    <BaseInput
      v-model="confirmPassword"
      label="Confirmar contraseña *"
      type="password"
      placeholder="Repite tu contraseña"
      required
    />

    <div class="space-y-3 pt-2 text-sm text-guaiqui-text-muted">
      <BaseCheckbox v-model="terms">
        Acepto los
        <NuxtLink to="/politicas/terminos" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
          Términos y Condiciones
        </NuxtLink>
        *
      </BaseCheckbox>

      <BaseCheckbox v-model="privacy">
        Acepto las
        <NuxtLink to="/politicas/privacidad" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
          Políticas de Privacidad
        </NuxtLink>
        *
      </BaseCheckbox>

      <BaseCheckbox v-model="pearlsRules">
        Acepto las
        <NuxtLink to="/politicas/perlitas" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
          Reglas del Programa de Perlitas
        </NuxtLink>
        *
      </BaseCheckbox>
    </div>

    <AuthTurnstileWrapper />

    <BaseButton type="submit" variant="primary" block :loading="loading || isCheckingEmail">
      <span v-if="isCheckingEmail">Verificando correo...</span>
      <span v-else>Continuar a Datos de Perfil</span>
      <i v-if="!isCheckingEmail" class="bi bi-arrow-right ml-1.5"></i>
    </BaseButton>
  </form>
</template>
