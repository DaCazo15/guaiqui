<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'
import { useSocialProfile } from '~/composables/useSocialProfile'
import ProfileCoverHeader from '~/components/profile/ProfileCoverHeader.vue'
import ProfileFormFields from '~/components/profile/ProfileFormFields.vue'
import ProfileStatsGrid from '~/components/profile/ProfileStatsGrid.vue'
import ProfileUsersListModal from '~/components/profile/ProfileUsersListModal.vue'
import ProfileFollowRequestsCard from '~/components/profile/ProfileFollowRequestsCard.vue'
import ProfileBlockedUsersCard from '~/components/profile/ProfileBlockedUsersCard.vue'
import ProfileFollowedTeamsCard from '~/components/profile/ProfileFollowedTeamsCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Mi Perfil — Guaiqueríes de Margarita',
  description: 'Gestiona tu perfil oficial de fanático, seguidores, solicitudes y deporte favorito.',
})

const authStore = useAuthStore()
const triviaStore = useTriviaStore()
const socialProfile = useSocialProfile()

const avatarUploading = ref(false)
const coverUploading = ref(false)
const localError = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const showBirthdayPrompt = ref(true)

// Modales de lista de usuarios (seguidores / seguidos)
const isUsersModalOpen = ref(false)
const usersModalTitle = ref('Seguidores')
const activeModalUsers = computed(() => {
  return usersModalTitle.value === 'Seguidores'
    ? socialProfile.followersList.value
    : socialProfile.followingList.value
})

const currentBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})

const streakDays = computed(() => {
  return triviaStore.homeSummary?.streak?.streak_days || 0
})

const loadProfileData = async () => {
  if (authStore.profile?.id) {
    await Promise.all([
      socialProfile.fetchPublicProfile(authStore.profile.id),
      socialProfile.fetchFollowRequests(),
      socialProfile.fetchBlockedUsers(),
    ])
  }
}

onMounted(() => {
  loadProfileData()
})

watch(
  () => authStore.profile?.id,
  (newId) => {
    if (newId) {
      loadProfileData()
    }
  }
)

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
    if (authStore.profile?.id) {
      await socialProfile.fetchPublicProfile(authStore.profile.id)
    }
  } catch (err: any) {
    localError.value = err.message
  }
}

async function handleOpenFollowers() {
  if (!authStore.profile?.id) return
  usersModalTitle.value = 'Seguidores'
  isUsersModalOpen.value = true
  await socialProfile.fetchFollowers(authStore.profile.id)
}

async function handleOpenFollowing() {
  if (!authStore.profile?.id) return
  usersModalTitle.value = 'Seguidos'
  isUsersModalOpen.value = true
  await socialProfile.fetchFollowing(authStore.profile.id)
}

async function handleRespondRequest(payload: { followerId: string; accept: boolean }) {
  const ok = await socialProfile.respondRequest(payload.followerId, payload.accept)
  if (ok && authStore.profile?.id) {
    await socialProfile.fetchPublicProfile(authStore.profile.id)
  }
}

async function handleUnblockUser(userId: string) {
  await socialProfile.unblock(userId)
}
</script>

<template>
  <div class="space-y-6">
    <!-- 1. Header con Foto de Portada y Avatar -->
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
      v-if="successMessage || socialProfile.successMessage.value"
      class="p-3.5 bg-emerald-50 border border-emerald-300 rounded-guaiqui-xl text-emerald-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-600 text-base"></i>
        <span class="font-medium">{{ successMessage || socialProfile.successMessage.value }}</span>
      </div>
      <button
        @click="successMessage = null; socialProfile.clearMessages()"
        class="text-emerald-700 hover:text-emerald-900 text-xs p-1"
      >
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <div
      v-if="localError || socialProfile.error.value"
      class="p-3.5 bg-rose-50 border border-rose-300 rounded-guaiqui-xl text-rose-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-circle-fill text-rose-600 text-base"></i>
        <span class="font-medium">{{ localError || socialProfile.error.value }}</span>
      </div>
      <button
        @click="localError = null; socialProfile.clearMessages()"
        class="text-rose-700 hover:text-rose-900 text-xs p-1"
      >
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- 2. Grid de Estadísticas Reales (Ranking, Canjes, Último Premio, Seguidores, Seguidos) -->
    <ProfileStatsGrid
      :followers-count="socialProfile.currentProfile.value?.followers_count || 0"
      :following-count="socialProfile.currentProfile.value?.following_count || 0"
      :ranking="socialProfile.currentProfile.value?.ranking"
      :redemptions-count="socialProfile.currentProfile.value?.redemptions_count"
      :last-reward="socialProfile.currentProfile.value?.last_reward"
      :total-pearls="socialProfile.currentProfile.value?.total_pearls"
      @open-followers="handleOpenFollowers"
      @open-following="handleOpenFollowing"
    />

    <!-- Aviso Discreto de Cumpleaños -->
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

    <!-- 3. Solicitudes de Seguimiento Recibidas -->
    <ProfileFollowRequestsCard
      :requests="socialProfile.followRequests.value"
      :loading="socialProfile.loadingRequests.value"
      :action-loading="socialProfile.actionLoading.value"
      @respond="handleRespondRequest"
    />

    <!-- 4. Equipos que Sigue el Fanático -->
    <ProfileFollowedTeamsCard
      :teams="socialProfile.currentProfile.value?.followed_teams || []"
    />

    <!-- 5. Tarjeta Principal de Información y Preferencias (Deporte Favorito Editable) -->
    <BaseCard class="bg-white border-guaiqui-border p-5 sm:p-6 rounded-guaiqui-2xl space-y-6 shadow-guaiqui-sm">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 mb-2 border-b border-guaiqui-border">
        <div>
          <h2 class="font-display font-extrabold text-xl text-guaiqui-text uppercase tracking-wide">
            Información del Fanático
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Personaliza tus datos y tu deporte favorito.
          </p>
        </div>
      </div>

      <ProfileFormFields
        :profile="authStore.profile"
        :loading="authStore.isLoading"
        :error="localError"
        :success="null"
        @save="handleSaveProfile"
      />
    </BaseCard>

    <!-- 6. Lista de Usuarios Bloqueados -->
    <ProfileBlockedUsersCard
      :blocked-users="socialProfile.blockedUsers.value"
      :loading="socialProfile.loadingBlocked.value"
      :action-loading="socialProfile.actionLoading.value"
      @unblock="handleUnblockUser"
    />

    <!-- Modal Reutilizable de Seguidores / Seguidos -->
    <ProfileUsersListModal
      :is-open="isUsersModalOpen"
      :title="usersModalTitle"
      :users="activeModalUsers"
      :loading="socialProfile.loadingList.value"
      @close="isUsersModalOpen = false"
    />
  </div>
</template>
