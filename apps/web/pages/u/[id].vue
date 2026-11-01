<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { BaseCard, BaseButton, BaseModal } from '@guaiqui/ui'
import { useSocialProfile } from '~/composables/useSocialProfile'
import { useAuthStore } from '~/stores/auth'
import ProfileFollowedTeamsCard from '~/components/profile/ProfileFollowedTeamsCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const authStore = useAuthStore()
const socialProfile = useSocialProfile()

const userId = computed(() => route.params.id as string)
const profile = computed(() => socialProfile.currentProfile.value)
const isBlockModalOpen = ref(false)

useSeoMeta({
  title: computed(() => profile.value ? `${profile.value.display_name} — Perfil de Fanático` : 'Perfil de Fanático'),
  description: 'Consulta el perfil público del fanático en la plataforma oficial de Guaiqueríes de Margarita.',
})

onMounted(async () => {
  if (userId.value) {
    await socialProfile.fetchPublicProfile(userId.value)
  }
})

async function handleFollowAction() {
  if (!profile.value) return
  if (profile.value.relation_status === 'none') {
    await socialProfile.sendFollow(profile.value.id)
  } else if (profile.value.relation_status === 'pending') {
    await socialProfile.cancelFollow(profile.value.id)
  } else if (profile.value.relation_status === 'accepted') {
    await socialProfile.unfollow(profile.value.id)
  }
}

async function handleRespond(accept: boolean) {
  if (!profile.value) return
  await socialProfile.respondRequest(profile.value.id, accept)
  await socialProfile.fetchPublicProfile(profile.value.id)
}

async function handleConfirmBlock() {
  if (!profile.value) return
  const ok = await socialProfile.block(profile.value.id)
  isBlockModalOpen.value = false
  if (ok) {
    // Navigate back to community search
    navigateTo('/app/usuarios')
  }
}
</script>

<template>
  <div class="space-y-6 max-w-4xl mx-auto">
    <!-- Estado de Carga -->
    <div v-if="socialProfile.loadingProfile.value" class="py-16 text-center text-guaiqui-text-muted">
      <div class="w-9 h-9 border-3 border-guaiqui-primary border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
      <p class="text-sm font-medium">Cargando perfil del fanático...</p>
    </div>

    <!-- Error o Bloqueo Mutuo -->
    <div v-else-if="!profile" class="py-16 text-center">
      <div class="w-16 h-16 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center text-3xl mx-auto mb-3">
        <i class="bi bi-person-x-fill"></i>
      </div>
      <h2 class="font-display font-extrabold text-xl text-guaiqui-text mb-1 uppercase">Usuario no encontrado</h2>
      <p class="text-xs text-guaiqui-text-muted mb-4 max-w-sm mx-auto">
        El perfil que buscas no existe, se encuentra inactivo o la privacidad de la cuenta impide su visualización.
      </p>
      <NuxtLink to="/app/usuarios">
        <BaseButton variant="primary" size="sm">
          <i class="bi bi-search mr-1.5"></i>
          Buscar otros fanáticos
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Perfil del Usuario -->
    <div v-else class="space-y-6">
      <!-- 1. Encabezado de Portada y Avatar -->
      <div class="relative bg-white rounded-guaiqui-2xl border border-guaiqui-border overflow-hidden shadow-guaiqui-sm">
        <!-- Foto de Portada -->
        <div class="h-40 sm:h-52 w-full bg-gradient-to-r from-emerald-800 to-teal-700 relative">
          <img
            v-if="profile.cover_url"
            :src="profile.cover_url"
            alt="Foto de portada"
            class="w-full h-full object-cover"
          />
        </div>

        <!-- Contenedor del Avatar y Botones de Acción -->
        <div class="px-5 pb-5 pt-3 sm:px-6">
          <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 -mt-16 sm:-mt-20 mb-4">
            <!-- Avatar -->
            <div class="relative">
              <img
                v-if="profile.avatar_url"
                :src="profile.avatar_url"
                :alt="profile.display_name"
                class="w-24 h-24 sm:w-28 sm:h-28 rounded-full object-cover border-4 border-white shadow-md bg-white"
              />
              <div
                v-else
                class="w-24 h-24 sm:w-28 sm:h-28 rounded-full border-4 border-white shadow-md bg-emerald-600 text-white flex items-center justify-center font-display font-extrabold text-3xl uppercase"
              >
                {{ profile.display_name.charAt(0) }}
              </div>
            </div>

            <!-- Botones de Acción de Seguimiento y Bloqueo -->
            <div class="flex flex-wrap items-center gap-2">
              <!-- Si es uno mismo -->
              <NuxtLink v-if="profile.relation_status === 'self'" to="/app/perfil">
                <BaseButton variant="primary" size="sm">
                  <i class="bi bi-pencil-fill mr-1.5"></i>
                  Editar Mi Perfil
                </BaseButton>
              </NuxtLink>

              <!-- Si hay solicitud entrante -->
              <template v-else-if="profile.relation_status === 'incoming_pending'">
                <BaseButton
                  variant="primary"
                  size="sm"
                  :loading="socialProfile.actionLoading.value"
                  @click="handleRespond(true)"
                >
                  <i class="bi bi-check-lg mr-1.5"></i>
                  Aceptar Solicitud
                </BaseButton>
                <BaseButton
                  variant="outline"
                  size="sm"
                  :disabled="socialProfile.actionLoading.value"
                  @click="handleRespond(false)"
                >
                  <i class="bi bi-x-lg mr-1.5"></i>
                  Rechazar
                </BaseButton>
              </template>

              <!-- Estados estándar (none / pending / accepted) -->
              <template v-else>
                <BaseButton
                  :variant="profile.relation_status === 'accepted' ? 'outline' : 'primary'"
                  size="sm"
                  :loading="socialProfile.actionLoading.value"
                  @click="handleFollowAction"
                >
                  <span v-if="profile.relation_status === 'none'">
                    <i class="bi bi-person-plus-fill mr-1.5"></i>
                    Solicitar Seguir
                  </span>
                  <span v-else-if="profile.relation_status === 'pending'" class="text-amber-700">
                    <i class="bi bi-hourglass-split mr-1.5"></i>
                    Solicitud Pendiente (Cancelar)
                  </span>
                  <span v-else-if="profile.relation_status === 'accepted'">
                    <i class="bi bi-check2 mr-1.5 text-emerald-600"></i>
                    Siguiendo (Dejar de seguir)
                  </span>
                </BaseButton>
              </template>

              <!-- Botón Bloquear (solo para otros usuarios) -->
              <button
                v-if="profile.relation_status !== 'self'"
                type="button"
                @click="isBlockModalOpen = true"
                class="text-xs text-slate-400 hover:text-rose-600 p-2 rounded-lg hover:bg-slate-50 transition-colors"
                title="Bloquear a este usuario"
              >
                <i class="bi bi-slash-circle"></i>
              </button>
            </div>
          </div>

          <!-- Información Principal del Usuario -->
          <div class="space-y-1">
            <h1 class="font-display font-black text-2xl text-guaiqui-text tracking-wide">
              {{ profile.display_name }}
            </h1>
            <p v-if="profile.favorite_sport" class="text-xs text-guaiqui-text-muted flex items-center gap-1.5">
              <i class="bi bi-dribbble text-guaiqui-primary"></i>
              <span>Deporte favorito: <strong class="text-guaiqui-text">{{ profile.favorite_sport }}</strong></span>
            </p>
          </div>

          <!-- Métricas Sociales Públicas (Seguidores y Seguidos) -->
          <div class="flex items-center gap-6 pt-4 mt-4 border-t border-guaiqui-border/60 text-sm">
            <div>
              <strong class="font-display font-extrabold text-guaiqui-text text-base">
                {{ profile.followers_count }}
              </strong>
              <span class="text-xs text-guaiqui-text-muted ml-1">seguidores</span>
            </div>
            <div>
              <strong class="font-display font-extrabold text-guaiqui-text text-base">
                {{ profile.following_count }}
              </strong>
              <span class="text-xs text-guaiqui-text-muted ml-1">seguidos</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 2. Equipos que Sigue (Siempre visible de forma pública) -->
      <ProfileFollowedTeamsCard :teams="profile.followed_teams" />

      <!-- 3. Contenido Completo (Solo para seguidores aceptados o el propio usuario) -->
      <div v-if="profile.is_full_profile" class="space-y-6">
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
          <!-- Ranking -->
          <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs">
            <span class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider block mb-1">Ranking</span>
            <div class="font-display font-black text-2xl text-guaiqui-text">
              {{ profile.ranking ? `#${profile.ranking.rank}` : '—' }}
            </div>
            <span class="text-[11px] text-guaiqui-text-muted">
              {{ profile.ranking ? `${profile.ranking.points} pts acumulados` : 'Sin puntuación' }}
            </span>
          </BaseCard>

          <!-- Perlitas Totales -->
          <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs">
            <span class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider block mb-1">Perlitas</span>
            <div class="font-display font-black text-2xl text-emerald-600">
              {{ profile.total_pearls || 0 }}
            </div>
            <span class="text-[11px] text-guaiqui-text-muted">Saldo global calculado</span>
          </BaseCard>

          <!-- Canjes Realizados -->
          <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs">
            <span class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider block mb-1">Canjes</span>
            <div class="font-display font-black text-2xl text-guaiqui-text">
              {{ profile.redemptions_count || 0 }}
            </div>
            <span class="text-[11px] text-guaiqui-text-muted">Premios entregados</span>
          </BaseCard>

          <!-- Último Premio -->
          <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs">
            <span class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider block mb-1">Último Premio</span>
            <div class="font-display font-bold text-sm text-guaiqui-text line-clamp-1">
              {{ profile.last_reward?.product_name || 'Ninguno aún' }}
            </div>
            <span class="text-[11px] text-guaiqui-text-muted">
              {{ profile.last_reward?.redeemed_at ? new Date(profile.last_reward.redeemed_at).toLocaleDateString('es-VE') : 'Sin canjes' }}
            </span>
          </BaseCard>
        </div>
      </div>

      <!-- 4. Cuenta Privada (Para quienes no siguen a la cuenta) -->
      <BaseCard v-else class="bg-white border-guaiqui-border p-8 rounded-guaiqui-2xl text-center shadow-guaiqui-sm">
        <div class="w-14 h-14 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-2xl mx-auto mb-3">
          <i class="bi bi-lock-fill"></i>
        </div>
        <h3 class="font-display font-black text-lg text-guaiqui-text uppercase tracking-wide mb-1">
          Esta Cuenta es Privada
        </h3>
        <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto mb-4">
          Envía una solicitud de seguimiento a {{ profile.display_name }} para poder ver sus estadísticas de ranking, canjes y saldo de perlitas.
        </p>
        <BaseButton
          v-if="profile.relation_status === 'none'"
          variant="primary"
          size="sm"
          :loading="socialProfile.actionLoading.value"
          @click="handleFollowAction"
        >
          <i class="bi bi-person-plus-fill mr-1.5"></i>
          Enviar Solicitud
        </BaseButton>
      </BaseCard>
    </div>

    <!-- Modal de Confirmación de Bloqueo -->
    <BaseModal
      :is-open="isBlockModalOpen"
      title="¿Bloquear a este usuario?"
      @close="isBlockModalOpen = false"
    >
      <div class="space-y-4">
        <p class="text-sm text-guaiqui-text">
          Al bloquear a <strong>{{ profile?.display_name }}</strong>, se eliminarán las relaciones de seguimiento mutuas y no podrán encontrarse en búsquedas ni interactuar en la plataforma.
        </p>
        <div class="flex items-center justify-end gap-2 pt-2">
          <BaseButton variant="outline" size="sm" @click="isBlockModalOpen = false">
            Cancelar
          </BaseButton>
          <BaseButton variant="danger" size="sm" :loading="socialProfile.actionLoading.value" @click="handleConfirmBlock">
            <i class="bi bi-slash-circle mr-1"></i>
            Sí, Bloquear
          </BaseButton>
        </div>
      </div>
    </BaseModal>
  </div>
</template>
