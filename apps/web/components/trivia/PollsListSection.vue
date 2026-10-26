<script setup lang="ts">
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveTriviaPoll } from '@guaiqui/shared'

const props = defineProps<{
  polls: ActiveTriviaPoll[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'selectPoll', poll: ActiveTriviaPoll): void
}>()

const getPollCardBadge = (poll: ActiveTriviaPoll) => {
  if (poll.is_resolved) {
    if (poll.user_vote?.is_winner) {
      return { label: `¡Acertaste! +${poll.user_vote.pearls_awarded}`, class: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40', icon: 'bi-trophy-fill text-amber-400' }
    }
    if (poll.user_vote && !poll.user_vote.is_winner) {
      return { label: 'No acertaste', class: 'bg-slate-800 text-slate-400 border-slate-700', icon: 'bi-x-circle' }
    }
    return { label: 'Finalizada', class: 'bg-slate-800 text-slate-400 border-slate-700', icon: 'bi-flag-fill' }
  }

  if (poll.user_vote) {
    return { label: 'Predicción Enviada (Pendiente)', class: 'bg-amber-500/20 text-amber-300 border-amber-500/40', icon: 'bi-hourglass-split' }
  }

  if (poll.is_closed) {
    return { label: 'Votación Cerrada', class: 'bg-rose-500/10 text-rose-400 border-rose-500/30', icon: 'bi-lock-fill' }
  }

  return { label: 'Abierta para Predecir', class: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40', icon: 'bi-broadcast' }
}
</script>

<template>
  <div class="space-y-4">
    <!-- Loading Skeletons -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard v-for="i in 2" :key="i" class="p-6 bg-slate-900 border-slate-800 animate-pulse h-48 rounded-3xl" />
    </div>

    <!-- Polls Grid -->
    <div v-else-if="polls.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="poll in polls"
        :key="poll.id"
        class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-slate-900 via-slate-950 to-emerald-950/70 border border-emerald-500/30 p-5 text-white shadow-xl flex flex-col justify-between gap-4 group hover:border-emerald-400/60 transition-all duration-300"
      >
        <!-- Glow ambiental -->
        <div class="absolute -top-10 -right-10 w-36 h-36 bg-emerald-500/10 blur-2xl pointer-events-none"></div>

        <div>
          <!-- Header Bar -->
          <div class="flex items-center justify-between gap-2 pb-3 border-b border-slate-800 text-xs">
            <!-- Game vs opponent or general badge -->
            <div v-if="poll.game" class="inline-flex items-center gap-1.5 font-semibold text-emerald-400 bg-emerald-950/80 px-2.5 py-0.5 rounded-full border border-emerald-500/30 text-[11px]">
              <i class="bi bi-calendar-event"></i>
              <span>vs {{ poll.game.opponent }}</span>
            </div>
            <div v-else class="inline-flex items-center gap-1 text-[11px] text-slate-400 bg-slate-800 px-2.5 py-0.5 rounded-full">
              <i class="bi bi-trophy text-emerald-400"></i>
              <span>Predicción del Club</span>
            </div>

            <!-- Reward -->
            <span class="font-mono font-bold text-amber-300 bg-slate-900/90 px-2.5 py-0.5 rounded-full border border-emerald-500/30 text-[11px] flex items-center gap-1">
              <i class="bi bi-gem"></i> +{{ poll.reward_pearls }} perlitas
            </span>
          </div>

          <!-- Body: Title & Info -->
          <div class="py-3 space-y-2">
            <h3 class="font-display font-black text-lg text-white uppercase tracking-tight leading-snug">
              {{ poll.title }}
            </h3>

            <p v-if="poll.description" class="text-xs text-slate-300 leading-relaxed line-clamp-2">
              {{ poll.description }}
            </p>

            <!-- Options Preview Chips -->
            <div class="flex flex-wrap gap-1.5 pt-1">
              <span
                v-for="opt in poll.options.slice(0, 3)"
                :key="opt.id"
                class="text-[11px] px-2.5 py-0.5 rounded-full border"
                :class="poll.user_vote?.option_id === opt.id
                  ? 'bg-emerald-500 text-slate-950 font-bold border-emerald-400'
                  : 'bg-slate-900 text-slate-300 border-slate-700'"
              >
                <i v-if="poll.user_vote?.option_id === opt.id" class="bi bi-check-circle-fill mr-1"></i>
                {{ opt.label }}
              </span>
              <span v-if="poll.options.length > 3" class="text-[10px] text-slate-400 self-center">
                +{{ poll.options.length - 3 }} más
              </span>
            </div>

            <!-- Deadline notice -->
            <div class="text-[11px] text-slate-400 flex items-center gap-1.5 pt-1">
              <i class="bi bi-clock-history text-amber-400"></i>
              <span>Cierre de votación: <strong class="text-slate-200">{{ formatCaracas(poll.closes_at) }}</strong></span>
            </div>
          </div>
        </div>

        <!-- Footer Bar: Status & Action Button -->
        <div class="flex items-center justify-between gap-3 pt-3 border-t border-slate-800">
          <div>
            <span
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider border"
              :class="getPollCardBadge(poll).class"
            >
              <i :class="['bi', getPollCardBadge(poll).icon]"></i>
              <span>{{ getPollCardBadge(poll).label }}</span>
            </span>
          </div>

          <BaseButton
            :variant="poll.user_vote ? 'secondary' : 'primary'"
            size="sm"
            @click="emit('selectPoll', poll)"
          >
            <i :class="['bi', poll.user_vote ? 'bi-eye' : 'bi-send-fill', 'mr-1']"></i>
            {{ poll.user_vote ? 'Ver Mi Voto' : (poll.is_closed ? 'Ver Encuesta' : 'Predecir Ahora') }}
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else
      class="p-12 text-center rounded-3xl bg-gradient-to-br from-slate-900 via-slate-950 to-emerald-950/70 border border-emerald-500/30 text-white space-y-3 shadow-xl"
    >
      <div class="w-16 h-16 rounded-2xl bg-emerald-500/20 border border-emerald-400/40 flex items-center justify-center text-3xl text-emerald-400 mx-auto shadow-inner">
        <i class="bi bi-bar-chart-fill"></i>
      </div>
      <h3 class="font-display font-extrabold text-xl uppercase tracking-wider">No hay encuestas disponibles</h3>
      <p class="text-xs sm:text-sm text-slate-300 max-w-md mx-auto">
        Próximamente publicaremos nuevas encuestas y predicciones oficiales antes del próximo partido de Guaiqueríes de Margarita.
      </p>
    </div>
  </div>
</template>
