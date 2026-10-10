<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import ProfileAvatarUploader from '~/components/profile/ProfileAvatarUploader.vue'
import ProfileFormFields from '~/components/profile/ProfileFormFields.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const authStore = useAuthStore()
const avatarUploading = ref(false)
const localError = ref<string | null>(null)
const showBirthdayPrompt = ref(true)

async function handleAvatarUpload(file: File) {
  avatarUploading.value = true
  localError.value = null
  try {
    await authStore.uploadAvatar(file)
  } catch (err: any) {
    localError.value = err.message
  } finally {
    avatarUploading.value = false
  }
}

async function handleSaveProfile(updates: any) {
  localError.value = null
  try {
    await authStore.updateProfile(updates)
  } catch (err: any) {
    localError.value = err.message
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header with Roster Link Button -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Mi <span class="text-guaiqui-primary">Perfil</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Gestiona tus datos de fanático y personaliza tu avatar.
        </p>
      </div>

      <NuxtLink to="/app/plantilla">
        <BaseButton variant="outline" size="sm" class="flex items-center gap-2">
          <i class="bi bi-people-fill text-guaiqui-primary"></i>
          <span>Ver Plantilla de Jugadores</span>
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Discrete ignorable Birthday Prompt Card if birth_date is not loaded -->
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

    <!-- Main Card -->
    <BaseCard class="bg-white border-guaiqui-border p-6 rounded-guaiqui-xl space-y-8 shadow-guaiqui-sm">
      <!-- Avatar Section -->
      <ProfileAvatarUploader
        :avatar-url="authStore.profile?.avatar_url"
        :display-name="authStore.profile?.display_name"
        :uploading="avatarUploading"
        @upload="handleAvatarUpload"
      />

      <div class="border-t border-guaiqui-border pt-6">
        <ProfileFormFields
          :profile="authStore.profile"
          :loading="authStore.isLoading"
          :error="localError"
          @save="handleSaveProfile"
        />
      </div>
    </BaseCard>
  </div>
</template>
