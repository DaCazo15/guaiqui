<script setup lang="ts">
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import type { TeamSummary } from '~/composables/useCurrentTeam'

const props = defineProps<{
  team: TeamSummary
  targetSection: 'trivias' | 'tienda' | 'hub'
}>()

const emit = defineEmits<{
  (e: 'select', slug: string): void
}>()

const isInactive = props.team.status === 'inactive'

const handleClick = () => {
  if (isInactive) return
  emit('select', props.team.slug)
}
</script>

<template>
  <button
    type="button"
    :disabled="isInactive"
    @click="handleClick"
    class="w-full text-left p-3.5 rounded-2xl border transition-all duration-200 flex items-center justify-between gap-3 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400"
    :class="[
      isInactive
        ? 'bg-slate-900/40 border-slate-800/80 opacity-60 cursor-not-allowed'
        : 'bg-slate-900/80 hover:bg-slate-800/90 border-slate-700/60 hover:border-emerald-500/50 hover:shadow-lg hover:shadow-emerald-950/30 cursor-pointer active:scale-[0.99]'
    ]"
  >
    <div class="flex items-center gap-3 min-w-0">
      <!-- Team Logo / Fallback -->
      <div class="w-12 h-12 rounded-xl bg-slate-950 border border-slate-700/60 p-1.5 flex items-center justify-center shrink-0 shadow-inner">
        <img
          v-if="team.logo_url"
          :src="team.logo_url"
          :alt="team.name"
          class="w-full h-full object-contain"
        />
        <i v-else class="bi bi-shield-fill text-xl text-emerald-400"></i>
      </div>

      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <h4 class="text-sm font-bold text-white truncate group-hover:text-emerald-300 transition-colors">
            {{ team.name }}
          </h4>
          <span
            v-if="isInactive"
            class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-rose-950/60 border border-rose-800/50 text-rose-300"
          >
            Inactivo
          </span>
        </div>
        <p class="text-xs text-slate-400 truncate">
          {{ team.short_name || 'Equipo de la liga' }}
        </p>
      </div>
    </div>

    <!-- Balance badge & action icon -->
    <div class="flex items-center gap-2.5 shrink-0">
      <div class="flex items-center gap-1.5 text-xs font-black text-amber-950 bg-amber-300 border border-amber-400 px-2.5 py-1 rounded-full shadow-xs">
        <PearlIcon size="xs" animated />
        <span>{{ formatPerlitas(team.balance || 0) }}</span>
      </div>

      <i
        class="bi text-base transition-transform group-hover:translate-x-0.5"
        :class="isInactive ? 'bi-lock-fill text-slate-500' : 'bi-chevron-right text-emerald-400'"
      ></i>
    </div>
  </button>
</template>
