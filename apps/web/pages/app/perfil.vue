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
