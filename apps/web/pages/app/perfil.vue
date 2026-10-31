<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'
import { useFanProfile } from '~/composables/useFanProfile'
import ProfileCoverHeader from '~/components/profile/ProfileCoverHeader.vue'
import ProfileFanLevelCard from '~/components/profile/ProfileFanLevelCard.vue'
import ProfileBadgesGrid from '~/components/profile/ProfileBadgesGrid.vue'
import ProfileTeamsLoyalty from '~/components/profile/ProfileTeamsLoyalty.vue'
import ProfileFormFields from '~/components/profile/ProfileFormFields.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Mi Perfil — Fan Zone Oficial',
  description: 'Gestiona tu perfil de fanático, insignias oficiales, nivel de lealtad y equipos seguidos.',
})

const authStore = useAuthStore()
const triviaStore = useTriviaStore()
const fanProfile = useFanProfile()

const avatarUploading = ref(false)
const coverUploading = ref(false)
const localError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const currentBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})

const streakDays = computed(() => {
  return triviaStore.homeSummary?.streak?.streak_days || fanProfile.stats.value.streak_days || 0
})

onMounted(async () => {
  await fanProfile.fetchProfileEnriched()
})

async function handleAvatarUpload(file: File) {
  avatarUploading.value = true
  localError.value = null
  successMessage.value = null
  try {
    await authStore.uploadAvatar(file)
    await fanProfile.fetchProfileEnriched()
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
    await fanProfile.fetchProfileEnriched()
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
    await fanProfile.fetchProfileEnriched()
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
    await fanProfile.fetchProfileEnriched()
    successMessage.value = '¡Perfil actualizado con éxito!'
  } catch (err: any) {
    localError.value = err.message
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- 1. Header con foto de portada y avatar superpuesto -->
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

    <!-- Mensajes de Estado -->
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

    <!-- 2. Nivel de Fanático y Progreso de Lealtad (XP) -->
    <ProfileFanLevelCard
      :level="fanProfile.level.value"
      :stats="fanProfile.stats.value"
    />

    <!-- 3. Insignias y Logros Reales del Fanático -->
    <ProfileBadgesGrid
      :badges="fanProfile.badges.value"
      :unlocked-count="fanProfile.unlockedBadgesCount.value"
    />

    <!-- 4. Equipos que Sigue y Saldo por Club -->
    <ProfileTeamsLoyalty
      :teams="fanProfile.teamsFollowed.value"
    />

    <!-- 5. Formulario de Datos y Preferencias -->
    <BaseCard class="bg-white border border-guaiqui-border p-5 sm:p-6 rounded-guaiqui-2xl space-y-4 shadow-guaiqui-sm">
      <div class="pb-3 border-b border-guaiqui-border">
        <h2 class="font-display font-extrabold text-xl text-guaiqui-text uppercase tracking-wide">
          Información del Fanático
        </h2>
        <p class="text-xs text-guaiqui-text-muted">
          Actualiza tus datos y preferencias para personalizar tu experiencia.
        </p>
      </div>

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
