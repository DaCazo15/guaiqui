<script setup lang="ts">
import { ref, computed } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'
import ProfileCoverHeader from '~/components/profile/ProfileCoverHeader.vue'
import ProfileFormFields from '~/components/profile/ProfileFormFields.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Mi Perfil — Guaiqueríes de Margarita',
  description: 'Gestiona tu perfil oficial de fanático de Guaiqueríes de Margarita, personaliza tu avatar y foto de portada.',
})

const authStore = useAuthStore()
const triviaStore = useTriviaStore()

const avatarUploading = ref(false)
const coverUploading = ref(false)
const localError = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const showBirthdayPrompt = ref(true)

const currentBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})

const streakDays = computed(() => {
  return triviaStore.homeSummary?.streak?.streak_days || 0
})

async function handleAvatarUpload(file: File) {
  avatarUploading.value = true
  localError.value = null
  successMessage.value = null
  try {
    await authStore.uploadAvatar(file)
    successMessage.value = '¡Foto de perfil actualizada con éxito!'
  } catch (err: any) {
    localError.value = err.message
  } finally {
    avatarUploading.value = false
  }
}

async function handleCoverUpload(file: File) {
  coverUploading.value = true
  localError.value = null
  successMessage.value = null
  try {
    await authStore.uploadCover(file)
    successMessage.value = '¡Foto de portada actualizada con éxito!'
  } catch (err: any) {
    localError.value = err.message
  } finally {
    coverUploading.value = false
  }
}

async function handleCoverUpdate(coverUrl: string) {
  localError.value = null
  successMessage.value = null
  try {
    await authStore.updateProfile({ cover_url: coverUrl } as any)
    successMessage.value = '¡Foto de portada actualizada!'
  } catch (err: any) {
    localError.value = err.message
  }
}

async function handleSaveProfile(updates: any) {
  localError.value = null
  successMessage.value = null
  try {
    await authStore.updateProfile(updates)
    successMessage.value = '¡Perfil actualizado con éxito!'
  } catch (err: any) {
    localError.value = err.message
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- 1. HEADER ESTILO FACEBOOK: FOTO DE PORTADA Y AVATAR SUPERPUESTO -->
    <ProfileCoverHeader
      :profile="authStore.profile"
      :balance="currentBalance"
      :streak-days="streakDays"
      :uploading-avatar="avatarUploading"
      :uploading-cover="coverUploading"
      @upload-avatar="handleAvatarUpload"
      @upload-cover="handleCoverUpload"
      @update-cover="handleCoverUpdate"
    />

    <!-- Mensajes Globales de Éxito o Error -->
    <div
      v-if="successMessage"
      class="p-3.5 bg-emerald-50 border border-emerald-300 rounded-guaiqui-xl text-emerald-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-600 text-base"></i>
        <span class="font-medium">{{ successMessage }}</span>
      </div>
      <button @click="successMessage = null" class="text-emerald-700 hover:text-emerald-900 text-xs p-1">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <div
      v-if="localError"
      class="p-3.5 bg-rose-50 border border-rose-300 rounded-guaiqui-xl text-rose-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-circle-fill text-rose-600 text-base"></i>
        <span class="font-medium">{{ localError }}</span>
      </div>
      <button @click="localError = null" class="text-rose-700 hover:text-rose-900 text-xs p-1">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- Aviso Discreto de Cumpleaños para saludo del equipo -->
    <div
      v-if="!authStore.profile?.birth_date && showBirthdayPrompt"
      class="p-4 bg-emerald-50 border border-emerald-200 rounded-guaiqui-xl flex items-center justify-between gap-4 shadow-guaiqui-sm text-guaiqui-text"
    >
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center shrink-0 font-bold text-xl">
          <i class="bi bi-gift-fill"></i>
        </div>
        <div>
          <p class="text-sm font-semibold text-guaiqui-text">Añade tu cumpleaños para recibir un saludo del equipo</p>
          <p class="text-xs text-guaiqui-text-muted">Los Guaiqueríes de Margarita te enviarán una felicitación especial el día de tu cumpleaños.</p>
        </div>
      </div>
      <button
        @click="showBirthdayPrompt = false"
        class="text-slate-400 hover:text-slate-600 p-1.5 rounded-lg hover:bg-emerald-100/50 transition-colors"
        title="Ignorar aviso"
        aria-label="Ignorar aviso de cumpleaños"
      >
        <i class="bi bi-x-lg text-sm"></i>
      </button>
    </div>

    <!-- 2. TARJETA PRINCIPAL DE DATOS Y PREFERENCIAS DEL FANÁTICO -->
    <BaseCard class="bg-white border-guaiqui-border p-5 sm:p-6 rounded-guaiqui-2xl space-y-6 shadow-guaiqui-sm">
      <!-- Encabezado de la Tarjeta con Enlace a la Plantilla Oficial -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 mb-2 border-b border-guaiqui-border">
        <div>
          <h2 class="font-display font-extrabold text-xl text-guaiqui-text uppercase tracking-wide">
            Información del Fanático
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Actualiza tus preferencias para personalizar tu experiencia en la plataforma.
          </p>
        </div>
      </div>

      <!-- Formulario de Campos de Perfil -->
      <ProfileFormFields
        :profile="authStore.profile"
        :loading="authStore.isLoading"
        :error="localError"
        :success="null"
        @save="handleSaveProfile"
      />
    </BaseCard>
  </div>
</template>
