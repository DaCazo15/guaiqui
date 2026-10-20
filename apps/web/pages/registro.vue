<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import RegisterStepAccount from '~/components/register/RegisterStepAccount.vue'
import RegisterStepProfile from '~/components/register/RegisterStepProfile.vue'
import RegisterStepPreferences from '~/components/register/RegisterStepPreferences.vue'

definePageMeta({
  middleware: ['guest'],
})

const authStore = useAuthStore()

const currentStep = ref<1 | 2 | 3>(1)

const formData = ref({
  email: '',
  password: '',
  consent: { terms: false, privacy: false, pearlsRules: false },
  displayName: '',
  municipality: '',
  birthDate: '',
  gender: '',
  favoritePlayerId: '',
  shirtSize: '',
  referralSource: '',
})

const localError = ref<string | null>(null)

async function handleStep1Submit(payload: {
  email: string
  pass: string
  consent: { terms: boolean; privacy: boolean; pearlsRules: boolean }
}) {
  formData.value.email = payload.email
  formData.value.password = payload.pass
  formData.value.consent = payload.consent
  currentStep.value = 2
}

async function handleStep2Submit(payload: { displayName: string; municipality: string }) {
  formData.value.displayName = payload.displayName
  formData.value.municipality = payload.municipality
  currentStep.value = 3
}

async function finishRegistration(optionalPreferences?: {
  birthDate?: string
  gender?: string
  favoritePlayerId?: string
  shirtSize?: string
  referralSource?: string
}) {
  if (optionalPreferences) {
    formData.value.birthDate = optionalPreferences.birthDate || ''
    formData.value.gender = optionalPreferences.gender || ''
    formData.value.favoritePlayerId = optionalPreferences.favoritePlayerId || ''
    formData.value.shirtSize = optionalPreferences.shirtSize || ''
    formData.value.referralSource = optionalPreferences.referralSource || ''
  }

  localError.value = null
  try {
    // Sign Up in Supabase Auth with full metadata
    await authStore.signUpWithEmail(
      formData.value.email,
      formData.value.password,
      formData.value.consent,
      {
        displayName: formData.value.displayName,
        municipality: formData.value.municipality,
        birthDate: formData.value.birthDate || null,
        gender: formData.value.gender || null,
        favoritePlayerId: formData.value.favoritePlayerId || null,
        shirtSize: formData.value.shirtSize || null,
        referralSource: formData.value.referralSource || null,
      }
    )

    navigateTo('/verificar-correo')
  } catch (err: any) {
    localError.value = err.message
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-guaiqui-surface text-guaiqui-text">
    <div class="w-full max-w-lg space-y-6">
      <!-- Header -->
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center mb-1">
          <img src="/logo.png" alt="Guaiqueríes Logo" class="w-14 h-14 object-contain" />
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Únete a la <span class="text-guaiqui-primary">Tribu</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Paso {{ currentStep }} de 3 — Registra tu cuenta y empieza a ganar perlitas.
        </p>

        <!-- Step Indicator -->
        <div class="flex items-center justify-center gap-2 pt-2">
          <div
            v-for="step in 3"
            :key="step"
            class="h-2 rounded-full transition-all duration-300"
            :class="[
              currentStep === step
                ? 'w-8 bg-guaiqui-primary'
                : currentStep > step
                ? 'w-4 bg-guaiqui-primary-dark'
                : 'w-4 bg-guaiqui-border',
            ]"
          />
        </div>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl">
        <RegisterStepAccount
          v-if="currentStep === 1"
          :initial-email="formData.email"
          :error="localError"
          @submit="handleStep1Submit"
        />

        <RegisterStepProfile
          v-else-if="currentStep === 2"
          :initial-display-name="formData.displayName"
          :initial-municipality="formData.municipality"
          :error="localError"
          @back="currentStep = 1"
          @submit="handleStep2Submit"
        />

        <RegisterStepPreferences
          v-else-if="currentStep === 3"
          :loading="authStore.isLoading"
          :error="localError"
          @back="currentStep = 2"
          @skip="finishRegistration()"
          @submit="finishRegistration"
        />
      </BaseCard>

      <div class="text-center text-sm text-guaiqui-text-muted">
        ¿Ya tienes cuenta?
        <NuxtLink to="/login" class="text-guaiqui-primary font-semibold hover:text-guaiqui-primary-dark underline ml-1">
          Inicia sesión aquí
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
