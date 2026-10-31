<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseButton, PearlIcon, PearlAmount } from '@guaiqui/ui'
import { usePendingGrants, type PendingGrantItem } from '~/composables/usePendingGrants'
import { useWallet } from '~/composables/useWallet'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Perlitas Pendientes por Asignar — Fan Zone',
  description: 'Asigna tus perlitas ganadas por anuncios y referidos al equipo que sigues.',
})

const pendingGrants = usePendingGrants()
const wallet = useWallet()

const selectedTeamByGrant = ref<Record<string, string>>({})
const claimingId = ref<string | null>(null)
const feedbackMessage = ref<{ type: 'success' | 'error'; text: string } | null>(null)
const currentTab = ref<'all' | 'ads_block' | 'referral_signup'>('all')

const followedTeams = computed(() => {
  return wallet.summary.value.teams.filter((t) => t.is_following)
})

const filteredGrants = computed(() => {
  if (currentTab.value === 'all') return pendingGrants.grants.value
  return pendingGrants.grants.value.filter((g) => g.source === currentTab.value)
})

onMounted(async () => {
  await Promise.all([
    pendingGrants.fetchPendingGrants(),
    wallet.fetchSummary(),
  ])

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
      text: `¡${grant.amount} perlitas asignadas exitosamente a tu equipo!`,
    }
    await wallet.refreshWallet()
    setTimeout(() => {
      if (feedbackMessage.value?.type === 'success') {
        feedbackMessage.value = null
      }
    }, 4500)
  } else {
    feedbackMessage.value = {
      type: 'error',
      text: pendingGrants.error.value || 'Error al asignar las perlitas.',
    }
  }
  claimingId.value = null
}
</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Perlitas <span class="text-guaiqui-primary">por Asignar</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted mt-1">
          Asigna tus perlitas ganadas en dinámicas globales al equipo activo de tu preferencia.
        </p>
      </div>

      <!-- Action buttons -->
      <div class="flex items-center gap-2">
        <NuxtLink to="/app/billetera">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-wallet2 mr-1.5 text-guaiqui-primary"></i>
            Mi Billetera
          </BaseButton>
        </NuxtLink>
        <NuxtLink to="/app/referidos">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-people mr-1.5 text-guaiqui-primary"></i>
            Referidos
          </BaseButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Summary Stats Banner -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
      <BaseCard class="p-4 bg-gradient-to-br from-amber-50 to-white border border-amber-200 rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-3">
        <div class="w-11 h-11 rounded-xl bg-amber-500/10 text-amber-600 border border-amber-500/20 flex items-center justify-center text-xl shrink-0">
          <i class="bi bi-hourglass-split"></i>
        </div>
        <div>
          <span class="text-[11px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">Total Pendiente</span>
          <div class="flex items-baseline gap-1 mt-0.5">
            <PearlAmount :amount="pendingGrants.totalPendingPearls.value" size="lg" animated />
          </div>
        </div>
      </BaseCard>

      <BaseCard class="p-4 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-3">
        <div class="w-11 h-11 rounded-xl bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 flex items-center justify-center text-xl shrink-0">
          <i class="bi bi-play-btn-fill"></i>
        </div>
        <div>
          <span class="text-[11px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">Por Anuncios</span>
          <span class="font-display font-black text-xl text-guaiqui-text block">
            {{ pendingGrants.grants.value.filter(g => g.source === 'ads_block').length }} bloques
          </span>
        </div>
      </BaseCard>

      <BaseCard class="p-4 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-3">
        <div class="w-11 h-11 rounded-xl bg-blue-500/10 text-blue-600 border border-blue-500/20 flex items-center justify-center text-xl shrink-0">
          <i class="bi bi-people-fill"></i>
        </div>
        <div>
          <span class="text-[11px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">Por Referidos</span>
          <span class="font-display font-black text-xl text-guaiqui-text block">
            {{ pendingGrants.grants.value.filter(g => g.source === 'referral_signup').length }} concesiones
          </span>
        </div>
      </BaseCard>
    </div>

    <!-- Feedback Message -->
    <div
      v-if="feedbackMessage"
      class="p-3.5 rounded-guaiqui-lg text-xs font-semibold flex items-center gap-2 shadow-guaiqui-xs"
      :class="feedbackMessage.type === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-red-50 text-red-800 border border-red-200'"
    >
      <i :class="feedbackMessage.type === 'success' ? 'bi bi-check-circle-fill text-emerald-600 text-sm' : 'bi bi-exclamation-triangle-fill text-red-600 text-sm'"></i>
      <span>{{ feedbackMessage.text }}</span>
    </div>

    <!-- Warning if user follows NO active teams -->
    <div
      v-if="followedTeams.length === 0"
      class="p-4 bg-amber-50 border border-amber-200 rounded-guaiqui-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-guaiqui-xs"
    >
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center text-lg shrink-0">
          <i class="bi bi-exclamation-circle-fill"></i>
        </div>
        <div>
          <h2 class="text-sm font-bold text-amber-900">Aún no sigues a ningún equipo activo</h2>
          <p class="text-xs text-amber-800/80">Para asignar tus perlitas debes seguir al menos a un equipo de la liga.</p>
        </div>
      </div>
      <NuxtLink to="/app/equipos" class="shrink-0 w-full sm:w-auto">
        <BaseButton variant="primary" size="sm" class="w-full text-xs">
          <i class="bi bi-search mr-1.5"></i>
          Buscar Equipos
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Grants Main Card -->
    <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm">
      <!-- Tabs filter -->
      <div class="flex items-center justify-between border-b border-guaiqui-border/60 pb-3 mb-4">
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="px-3 py-1.5 rounded-guaiqui-md text-xs font-bold transition-colors cursor-pointer"
            :class="currentTab === 'all' ? 'bg-guaiqui-primary text-white' : 'text-guaiqui-text-muted hover:bg-slate-100'"
            @click="currentTab = 'all'"
          >
            Todas ({{ pendingGrants.grants.value.length }})
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-guaiqui-md text-xs font-bold transition-colors cursor-pointer"
            :class="currentTab === 'ads_block' ? 'bg-guaiqui-primary text-white' : 'text-guaiqui-text-muted hover:bg-slate-100'"
            @click="currentTab = 'ads_block'"
          >
            Anuncios
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-guaiqui-md text-xs font-bold transition-colors cursor-pointer"
            :class="currentTab === 'referral_signup' ? 'bg-guaiqui-primary text-white' : 'text-guaiqui-text-muted hover:bg-slate-100'"
            @click="currentTab = 'referral_signup'"
          >
            Referidos
          </button>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-if="filteredGrants.length === 0"
        class="py-12 text-center space-y-3"
      >
        <div class="w-12 h-12 rounded-full bg-slate-50 text-slate-400 mx-auto flex items-center justify-center text-xl border border-slate-200">
          <i class="bi bi-inbox"></i>
        </div>
        <div>
          <p class="text-sm font-bold text-guaiqui-text">No hay concesiones pendientes en esta sección</p>
          <p class="text-xs text-guaiqui-text-muted mt-0.5">Mira videos de patrocinadores o invita a tus amigos para acumular más perlitas.</p>
        </div>
      </div>

      <!-- Grants items -->
      <div v-else class="space-y-3">
        <div
          v-for="grant in filteredGrants"
          :key="grant.id"
          class="p-4 border border-guaiqui-border/80 rounded-guaiqui-lg hover:border-guaiqui-primary/40 transition-colors bg-slate-50/50 flex flex-col md:flex-row md:items-center justify-between gap-4"
        >
          <div class="flex items-start gap-3.5">
            <div
              class="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0"
              :class="grant.source === 'ads_block' ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-100 text-blue-700'"
            >
              <i :class="grant.source === 'ads_block' ? 'bi bi-play-btn-fill' : 'bi bi-people-fill'"></i>
            </div>
            <div>
              <div class="flex items-center gap-2 flex-wrap">
                <span class="text-sm font-bold text-guaiqui-text">
                  {{ grant.source === 'ads_block' ? 'Bloque de 10 Anuncios Vistos' : 'Bono por Amigo Registrado' }}
                </span>
                <span class="inline-flex items-center gap-1 font-display font-black text-xs text-guaiqui-primary bg-guaiqui-primary-soft px-2.5 py-0.5 rounded-full">
                  <PearlIcon size="xs" />
                  +{{ grant.amount }} perlitas
                </span>
              </div>

              <div class="flex items-center gap-3 text-xs mt-1 text-guaiqui-text-muted">
                <span>
                  Obtenido el {{ new Date(grant.created_at).toLocaleDateString('es-VE') }}
                </span>
                <span>•</span>
                <span v-if="grant.expires_at === null" class="inline-flex items-center gap-1 text-emerald-700 font-semibold">
                  <i class="bi bi-shield-check"></i>
                  Nunca vence
                </span>
                <span
                  v-else
                  class="inline-flex items-center gap-1 font-medium"
                  :class="(grant.days_remaining ?? 99) <= 7 ? 'text-amber-600 font-bold' : ''"
                >
                  <i class="bi bi-clock-history"></i>
                  Vence en {{ grant.days_remaining }} días
                </span>
              </div>
            </div>
          </div>

          <!-- Controls -->
          <div v-if="followedTeams.length > 0" class="flex items-center gap-2 shrink-0 w-full md:w-auto">
            <select
              v-model="selectedTeamByGrant[grant.id]"
              class="flex-1 md:flex-initial text-xs py-2 px-3 rounded-guaiqui-md border border-guaiqui-border bg-white text-guaiqui-text focus:outline-none focus:ring-1 focus:ring-guaiqui-primary font-medium"
              :disabled="claimingId === grant.id"
            >
              <option
                v-for="team in followedTeams"
                :key="team.team_id"
                :value="team.team_id"
              >
                {{ team.team_name }}
              </option>
            </select>

            <button
              type="button"
              class="px-4 py-2 rounded-guaiqui-md bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-xs uppercase tracking-wider transition-colors disabled:opacity-50 cursor-pointer shrink-0 shadow-guaiqui-xs flex items-center gap-1.5"
              :disabled="claimingId === grant.id || !selectedTeamByGrant[grant.id]"
              @click="handleClaim(grant)"
            >
              <i v-if="claimingId === grant.id" class="bi bi-arrow-repeat animate-spin"></i>
              <span v-else>Asignar Puntos</span>
            </button>
          </div>
        </div>
      </div>
    </BaseCard>

    <!-- Informational Card: Rules -->
    <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs space-y-3">
      <h2 class="text-sm font-bold text-guaiqui-text flex items-center gap-2">
        <i class="bi bi-info-circle-fill text-guaiqui-primary"></i>
        <span>¿Cómo funcionan las perlitas pendientes?</span>
      </h2>
      <ul class="text-xs text-guaiqui-text-muted space-y-1.5 list-disc pl-5">
        <li>Las perlitas ganadas en dinámicas de plataforma (como anuncios o referidos) se almacenan de forma neutral sin pertenecer a ningún equipo.</li>
        <li>Tú decides a cuál de tus equipos seguidos asignarlas en cualquier momento.</li>
        <li>Las perlitas por anuncios nunca caducan; las perlitas por registro de un referido tienen un plazo de 90 días para ser asignadas.</li>
        <li>Al asignarlas, se genera una transacción inmutable en el libro contable de la billetera del equipo seleccionado.</li>
      </ul>
    </BaseCard>
  </div>
</template>
