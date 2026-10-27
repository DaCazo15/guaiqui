<script setup lang="ts">
import { BaseModal, BaseButton } from '@guaiqui/ui'
import type { PollRow } from './types'

defineProps<{
  isOpen: boolean
  poll: PollRow | null
  winningOptionId: string
  actionLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'update:winningOptionId', id: string): void
  (e: 'confirm'): void
}>()
</script>

<template>
  <BaseModal
    v-if="isOpen"
    :is-open="isOpen"
    title="Resolver Encuesta y Entregar Perlitas"
    @close="emit('close')"
  >
    <div v-if="poll" class="space-y-4">
      <div class="p-3 bg-slate-900 border border-slate-800 rounded-lg space-y-1">
        <div class="text-xs text-slate-400 font-semibold uppercase">Encuesta a resolver</div>
        <div class="font-bold text-white text-base">{{ poll.title }}</div>
        <div v-if="poll.game" class="text-xs text-emerald-400 flex items-center gap-1.5">
          <i class="bi bi-geo-alt-fill"></i>
          <span>Partido: vs {{ poll.game.opponent }}</span>
        </div>
      </div>

      <p class="text-xs text-slate-300">
        Selecciona cuál fue la <strong>opción ganadora real</strong> del partido. Todos los fanáticos que hayan votado por ella recibirán automáticamente <strong>+{{ poll.reward_pearls }} perlitas</strong> en su billetera.
      </p>

      <div class="space-y-2">
        <label
          v-for="opt in poll.options"
          :key="opt.id"
          class="flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-all duration-200"
          :class="winningOptionId === opt.id
            ? 'bg-emerald-950/80 border-emerald-500 shadow-sm'
            : 'bg-slate-900/60 border-slate-800 hover:border-slate-700'"
        >
          <div class="flex items-center gap-3">
            <input
              type="radio"
              :value="opt.id"
              :checked="winningOptionId === opt.id"
              @change="emit('update:winningOptionId', opt.id || '')"
              class="accent-emerald-500 w-4 h-4"
            />
            <div class="flex items-center gap-2">
              <img
                v-if="opt.player?.photo_url"
                :src="opt.player.photo_url"
                class="w-6 h-6 rounded-full object-cover border border-emerald-500/50"
              />
              <span class="font-medium text-sm" :class="winningOptionId === opt.id ? 'text-emerald-200 font-bold' : 'text-slate-200'">
                {{ opt.label }}
              </span>
            </div>
          </div>

          <div class="text-xs font-mono text-slate-400">
            <span class="font-bold text-white">{{ opt.votes_count || 0 }}</span> votos
            <span v-if="poll.total_votes" class="text-[10px] text-slate-500 ml-1">
              ({{ Math.round(((opt.votes_count || 0) / poll.total_votes) * 100) }}%)
            </span>
          </div>
        </label>
      </div>

      <div class="p-3 bg-amber-950/40 border border-amber-800/60 rounded-lg text-amber-200 text-xs flex items-start gap-2">
        <i class="bi bi-shield-exclamation text-amber-400 text-sm shrink-0 mt-0.5"></i>
        <span>Esta acción es irreversible y ejecutará transacciones atómicas de ledger para todos los ganadores.</span>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <BaseButton variant="secondary" @click="emit('close')">Cancelar</BaseButton>
        <BaseButton variant="primary" :loading="actionLoading" @click="emit('confirm')">
          <i class="bi bi-trophy-fill mr-1.5 text-amber-300"></i>
          Confirmar y Premiar Ganadores
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
