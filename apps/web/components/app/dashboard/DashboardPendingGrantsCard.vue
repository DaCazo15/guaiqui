<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseButton, PearlIcon } from '@guaiqui/ui'
import { usePendingGrants, type PendingGrantItem } from '~/composables/usePendingGrants'
import { useWallet } from '~/composables/useWallet'

const pendingGrants = usePendingGrants()
const wallet = useWallet()

const selectedTeamByGrant = ref<Record<string, string>>({})
const claimingId = ref<string | null>(null)
const feedbackMessage = ref<{ type: 'success' | 'error'; text: string } | null>(null)

const followedTeams = computed(() => {
  return wallet.summary.value.teams.filter((t) => t.is_following)
})

onMounted(async () => {
  await Promise.all([
    pendingGrants.fetchPendingGrants(),
    wallet.fetchSummary(),
  ])

  // Default selection for teams
  if (followedTeams.value.length > 0) {
    const firstTeamId = followedTeams.value[0].team_id
    pendingGrants.grants.value.forEach((g) => {
      if (!selectedTeamByGrant.value[g.id]) {
        selectedTeamByGrant.value[g.id] = firstTeamId
      }
    })
  }
})

const handleClaim = async (grant: PendingGrantItem) => {
  const teamId = selectedTeamByGrant.value[grant.id] || (followedTeams.value[0]?.team_id)
  if (!teamId) return

  claimingId.value = grant.id
  feedbackMessage.value = null

  const success = await pendingGrants.claimGrant(grant.id, teamId)
  if (success) {
    feedbackMessage.value = {
      type: 'success',
      text: `¡${grant.amount} perlitas asignadas correctamente a tu equipo!`,
    }
    // Update team balance and total balance reactively
    await wallet.refreshWallet()
    setTimeout(() => {
      if (feedbackMessage.value?.type === 'success') {
        feedbackMessage.value = null
      }
    }, 4000)
  } else {
    feedbackMessage.value = {
      type: 'error',
      text: pendingGrants.error.value || 'No se pudo asignar la concesión.',
    }
  }
  claimingId.value = null
}
</script>

<template>
  <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm">
    <!-- Header -->
    <div class="flex items-center justify-between gap-3 mb-4 border-b border-guaiqui-border/60 pb-3">
      <div class="flex items-center gap-2.5">
        <div class="w-9 h-9 rounded-xl bg-amber-500/10 text-amber-600 border border-amber-500/20 flex items-center justify-center text-lg shrink-0">
          <i class="bi bi-hourglass-split"></i>
        </div>
        <div>
          <h2 class="font-display font-black text-base text-guaiqui-text uppercase tracking-wider leading-tight">
            Perlitas por Asignar
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Ganadas en anuncios y referidos pendientes de equipo
          </p>
        </div>
      </div>

      <div
        v-if="pendingGrants.totalPendingPearls.value > 0"
        class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-bold text-xs"
      >
        <PearlIcon size="xs" animated />
        <span>{{ pendingGrants.totalPendingPearls.value }} pendientes</span>
      </div>
    </div>

    <!-- Feedback Banner -->
    <div
      v-if="feedbackMessage"
      class="mb-4 p-3 rounded-guaiqui-md text-xs font-semibold flex items-center gap-2"
      :class="feedbackMessage.type === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-red-50 text-red-800 border border-red-200'"
    >
      <i :class="feedbackMessage.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
      <span>{{ feedbackMessage.text }}</span>
    </div>

    <!-- Empty State: No pending grants -->
    <div
      v-if="pendingGrants.grants.value.length === 0"
      class="py-6 text-center space-y-3"
    >
      <div class="w-12 h-12 rounded-full bg-slate-50 text-slate-400 mx-auto flex items-center justify-center text-xl border border-slate-200">
        <i class="bi bi-check2-all"></i>
      </div>
      <div>
        <p class="text-sm font-bold text-guaiqui-text">Todas tus perlitas están asignadas</p>
        <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto mt-0.5">
          Gana nuevas perlitas por asignar viendo bloques de videos o invitando a tus amigos a registrarse.
        </p>
      </div>
      <div class="flex items-center justify-center gap-2 pt-1">
        <NuxtLink to="/app/anuncios">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-play-btn mr-1.5 text-guaiqui-primary"></i>
            Ver Videos
          </BaseButton>
        </NuxtLink>
        <NuxtLink to="/app/referidos">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-people mr-1.5 text-guaiqui-primary"></i>
            Invitar Amigos
          </BaseButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Active Grants List -->
    <div v-else class="space-y-3">
      <!-- Warning if user follows NO active teams -->
      <div
        v-if="followedTeams.length === 0"
        class="p-3 bg-amber-50 border border-amber-200 rounded-guaiqui-lg flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3"
      >
        <div class="flex items-center gap-2 text-xs text-amber-900 font-medium">
          <i class="bi bi-exclamation-circle-fill text-amber-600 text-base shrink-0"></i>
          <span>No sigues a ningún equipo. Debes seguir al menos a uno para asignarle tus perlitas.</span>
        </div>
        <NuxtLink to="/app/equipos" class="shrink-0 w-full sm:w-auto">
          <BaseButton variant="primary" size="sm" class="w-full text-xs">
            <i class="bi bi-search mr-1.5"></i>
            Buscar Equipos
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Grant Cards -->
      <div
        v-for="grant in pendingGrants.grants.value"
        :key="grant.id"
        class="p-3.5 border border-guaiqui-border/80 rounded-guaiqui-lg hover:border-guaiqui-primary/40 transition-colors flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-50/50"
      >
        <!-- Info: Source, Amount, Expiry -->
        <div class="flex items-start gap-3">
          <div
            class="w-9 h-9 rounded-lg flex items-center justify-center text-lg shrink-0 mt-0.5"
            :class="grant.source === 'ads_block' ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-100 text-blue-700'"
          >
            <i :class="grant.source === 'ads_block' ? 'bi bi-play-btn-fill' : 'bi bi-people-fill'"></i>
          </div>
          <div>
            <div class="flex items-center gap-2">
              <span class="text-sm font-bold text-guaiqui-text">
                {{ grant.source === 'ads_block' ? 'Bloque de Anuncios' : 'Amigo Registrado' }}
              </span>
              <span class="inline-flex items-center gap-1 font-display font-black text-xs text-guaiqui-primary bg-guaiqui-primary-soft px-2 py-0.5 rounded-full">
                <PearlIcon size="xs" />
                +{{ grant.amount }} pts
              </span>
            </div>

            <!-- Expiration tag -->
            <p class="text-xs mt-0.5">
              <span v-if="grant.expires_at === null" class="text-guaiqui-text-muted inline-flex items-center gap-1">
                <i class="bi bi-infinity"></i>
                Sin vencimiento
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 font-medium"
                :class="(grant.days_remaining ?? 99) <= 7 ? 'text-amber-600 font-bold' : 'text-guaiqui-text-muted'"
              >
                <i class="bi bi-clock-history"></i>
                Vence en {{ grant.days_remaining }} días
                <span v-if="(grant.days_remaining ?? 99) <= 7" class="text-[10px] bg-amber-100 text-amber-800 px-1.5 py-0.2 rounded font-bold uppercase">
                  Pronto
                </span>
              </span>
            </p>
          </div>
        </div>

        <!-- Controls: Team selector & Claim button -->
        <div v-if="followedTeams.length > 0" class="flex items-center gap-2 shrink-0 w-full sm:w-auto">
          <select
            v-model="selectedTeamByGrant[grant.id]"
            class="flex-1 sm:flex-initial text-xs py-1.5 px-2.5 rounded-guaiqui-md border border-guaiqui-border bg-white text-guaiqui-text focus:outline-none focus:ring-1 focus:ring-guaiqui-primary"
            :disabled="claimingId === grant.id"
          >
            <option
              v-for="team in followedTeams"
              :key="team.team_id"
              :value="team.team_id"
            >
              {{ team.team_short_name || team.team_name }}
            </option>
          </select>

          <button
            type="button"
            class="px-3.5 py-1.5 rounded-guaiqui-md bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-xs uppercase tracking-wider transition-colors disabled:opacity-50 cursor-pointer shrink-0 shadow-guaiqui-xs flex items-center gap-1"
            :disabled="claimingId === grant.id || !selectedTeamByGrant[grant.id]"
            @click="handleClaim(grant)"
          >
            <i v-if="claimingId === grant.id" class="bi bi-arrow-repeat animate-spin"></i>
            <span v-else>Asignar</span>
          </button>
        </div>
      </div>

      <!-- Footer link to dedicated screen -->
      <div class="pt-2 text-right">
        <NuxtLink
          to="/app/perlitas-pendientes"
          class="text-xs font-bold text-guaiqui-primary hover:underline inline-flex items-center gap-1"
        >
          <span>Gestionar todas mis perlitas pendientes</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>
      </div>
    </div>
  </BaseCard>
</template>
