<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton, BaseCheckbox } from '@guaiqui/ui'

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

const email = ref(props.initialEmail || '')
const password = ref('')
const confirmPassword = ref('')
const terms = ref(false)
const privacy = ref(false)
const pearlsRules = ref(false)

const localError = ref<string | null>(null)

function handleSubmit() {
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

  emit('submit', {
    email: email.value,
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

    <BaseButton type="submit" variant="primary" block :loading="loading">
      Continuar a Datos de Perfil
      <i class="bi bi-arrow-right ml-1.5"></i>
    </BaseButton>
  </form>
</template>
