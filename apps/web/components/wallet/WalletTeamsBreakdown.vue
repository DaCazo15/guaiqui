<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseBadge, BaseButton } from '@guaiqui/ui'
import { formatPerlitas } from '@guaiqui/shared'
import type { WalletSummaryTeam } from '~/composables/useWallet'

const props = defineProps<{
  teams: WalletSummaryTeam[]
  selectedTeamId?: string | null
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'select-team', teamId: string | null): void
}>()

const logoErrors = ref<Record<string, boolean>>({})

const onLogoError = (teamId: string) => {
  logoErrors.value[teamId] = true
}

const toggleTeamFilter = (teamId: string) => {
  if (props.selectedTeamId === teamId) {
    emit('select-team', null)
  } else {
    emit('select-team', teamId)
  }
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <div>
        <h2 class="font-display text-lg md:text-xl font-bold text-guaiqui-text uppercase tracking-wider">
          Perlitas por <span class="text-guaiqui-primary">Equipo</span>
        </h2>
        <p class="text-xs text-guaiqui-text-muted">
          Cada club maneja su propia moneda de fidelización. Canjea tus perlitas en la tienda del equipo correspondiente.
        </p>
      </div>
      <NuxtLink to="/app/equipos">
        <BaseButton variant="outline" size="sm" class="text-xs font-semibold">
          <i class="bi bi-compass mr-1.5 text-guaiqui-primary"></i>
          <span>Explorar Equipos</span>
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Empty State: Fan follows 0 teams and has 0 balances -->
    <div
      v-if="teams.length === 0"
      class="bg-white border border-guaiqui-border rounded-guaiqui-xl p-8 text-center shadow-guaiqui-xs"
    >
      <div class="w-16 h-16 mx-auto mb-3 rounded-full bg-slate-50 border border-slate-200 flex items-center justify-center text-slate-400">
        <i class="bi bi-wallet-fill text-3xl"></i>
      </div>
      <h3 class="font-display font-bold text-base text-guaiqui-text uppercase tracking-wider">
        Aún no tienes perlitas ni sigues a ningún equipo
      </h3>
      <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto mt-1 mb-5">
        Para comenzar a acumular perlitas en trivias y canjear premios oficiales, sigue a tus equipos favoritos.
      </p>
      <NuxtLink to="/app/equipos">
        <BaseButton variant="primary" size="md">
          <i class="bi bi-shield-plus mr-1.5"></i>
          <span>Descubrir Equipos</span>
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Grid of Team Wallets -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <BaseCard
        v-for="team in teams"
        :key="team.team_id"
        class="p-4 bg-white border rounded-guaiqui-xl shadow-guaiqui-xs transition-all relative overflow-hidden flex flex-col justify-between"
        :class="selectedTeamId === team.team_id ? 'border-guaiqui-primary ring-2 ring-guaiqui-primary/20 bg-emerald-50/20' : 'border-guaiqui-border hover:shadow-guaiqui-sm'"
      >
        <!-- Top color accent -->
        <div
          class="absolute top-0 left-0 right-0 h-1"
          :style="{ backgroundColor: team.team_primary_color || '#005a36' }"
        ></div>

        <div class="space-y-3 pt-1">
          <!-- Team Header -->
          <div class="flex items-start justify-between gap-2.5">
            <div class="flex items-center gap-2.5 min-w-0">
              <!-- Team Logo used as Currency Emblem -->
              <div class="w-11 h-11 rounded-xl bg-slate-50 border border-slate-200 p-1.5 flex items-center justify-center shrink-0 shadow-xs overflow-hidden">
                <img
                  v-if="team.team_logo_url && !logoErrors[team.team_id]"
                  :src="team.team_logo_url"
                  :alt="team.team_name"
                  class="w-full h-full object-contain"
                  @error="onLogoError(team.team_id)"
                />
                <i v-else class="bi bi-shield-shaded text-guaiqui-primary text-xl"></i>
              </div>

              <div class="min-w-0">
                <h4 class="font-display font-bold text-sm text-guaiqui-text truncate leading-tight">
                  {{ team.team_name }}
                </h4>
                <span class="text-[10px] text-guaiqui-text-muted block truncate">
                  {{ team.team_slug }}
                </span>
              </div>
            </div>

            <!-- Follow Status Badge -->
            <BaseBadge
              :variant="team.is_following ? 'success' : 'soft'"
              size="sm"
              class="shrink-0 text-[9px] uppercase tracking-wider"
            >
              {{ team.is_following ? 'Siguiendo' : 'No seguido' }}
            </BaseBadge>
          </div>

          <!-- Balance Info -->
          <div class="bg-slate-50 rounded-guaiqui-lg p-2.5 border border-slate-100 flex items-baseline justify-between">
            <span class="text-[11px] font-semibold text-guaiqui-text-muted">
              Saldo Disponible:
            </span>
            <div class="flex items-center gap-1.5">
              <span class="font-display font-black text-lg text-guaiqui-primary leading-none">
                {{ formatPerlitas(team.balance) }}
              </span>
              <span class="text-[10px] font-bold text-guaiqui-primary/80 uppercase tracking-widest">
                PERLITAS
              </span>
            </div>
          </div>

          <!-- Held balance warning if > 0 -->
          <div
            v-if="team.held_balance > 0"
            class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200/60 rounded-guaiqui-md px-2 py-1 flex items-center gap-1.5"
          >
            <i class="bi bi-hourglass-split shrink-0"></i>
            <span>{{ formatPerlitas(team.held_balance) }} retenidas en revisión</span>
          </div>
        </div>

        <!-- Card Footer Actions -->
        <div class="mt-4 pt-2.5 border-t border-slate-100 flex items-center justify-between gap-2">
          <button
            type="button"
            class="text-xs font-semibold transition-colors inline-flex items-center gap-1 cursor-pointer"
            :class="selectedTeamId === team.team_id ? 'text-guaiqui-primary underline font-bold' : 'text-guaiqui-text-muted hover:text-guaiqui-text'"
            @click="toggleTeamFilter(team.team_id)"
          >
            <i class="bi" :class="selectedTeamId === team.team_id ? 'bi-funnel-fill text-guaiqui-primary' : 'bi-funnel'"></i>
            <span>{{ selectedTeamId === team.team_id ? 'Mostrando este equipo' : 'Ver movimientos' }}</span>
          </button>

          <NuxtLink to="/app/tienda" class="shrink-0">
            <button
              type="button"
              class="px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider rounded-guaiqui-md bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white transition-colors cursor-pointer shadow-guaiqui-xs flex items-center gap-1"
            >
              <i class="bi bi-bag-heart-fill text-xs"></i>
              <span>Canjear</span>
            </button>
          </NuxtLink>
        </div>
      </BaseCard>
    </div>
  </div>
</template>
