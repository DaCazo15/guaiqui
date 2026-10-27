<script setup lang="ts">
import { BaseModal, BaseButton, BaseInput } from '@guaiqui/ui'
import type { GameItem, PlayerItem, PollFormData } from './types'

const props = defineProps<{
  isOpen: boolean
  form: PollFormData
  games: GameItem[]
  rosterPlayers: PlayerItem[]
  actionLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save'): void
  (e: 'add-option'): void
  (e: 'remove-option', index: number): void
  (e: 'player-select', index: number, playerId: string): void
}>()
</script>

<template>
  <BaseModal
    v-if="isOpen"
    :is-open="isOpen"
    :title="form.id ? 'Editar Encuesta' : 'Nueva Encuesta de Predicción'"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <BaseInput
        label="Título / Pregunta de la Encuesta"
        v-model="form.title"
        placeholder="Ej: ¿Quién será el MVP del partido vs Marinos?"
      />

      <BaseInput
        label="Descripción o Instrucción (Opcional)"
        v-model="form.description"
        placeholder="Ej: Elige tu favorito antes del entretiempo."
      />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <!-- Game Select -->
        <div>
          <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Partido Asociado (Opcional)</label>
          <select
            v-model="form.game_id"
            class="w-full bg-slate-900 border border-slate-700 text-white rounded-lg px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
          >
            <option value="">-- Sin vincular a partido --</option>
            <option v-for="g in games" :key="g.id" :value="g.id">
              vs {{ g.opponent }}
            </option>
          </select>
        </div>

        <!-- Reward Pearls -->
        <BaseInput
          label="Premio por Acertar (Perlitas)"
          type="number"
          v-model="form.reward_pearls"
          placeholder="50"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <BaseInput
          label="Fecha y Hora de Inicio"
          type="datetime-local"
          v-model="form.starts_at"
        />
        <BaseInput
          label="Fecha y Hora de Cierre (Límite de Votación)"
          type="datetime-local"
          v-model="form.closes_at"
        />
      </div>

      <!-- Dynamic Options Section -->
      <div class="border-t border-slate-800 pt-3 space-y-3">
        <div class="flex items-center justify-between">
          <label class="text-xs font-bold text-slate-300 uppercase flex items-center gap-1.5">
            <i class="bi bi-list-check text-emerald-400"></i>
            Opciones de Respuesta (Mínimo 2)
          </label>
          <button
            type="button"
            @click="emit('add-option')"
            class="text-xs text-emerald-400 hover:text-emerald-300 flex items-center gap-1 font-semibold"
          >
            <i class="bi bi-plus-circle"></i> Agregar Opción
          </button>
        </div>

        <div class="space-y-2.5 max-h-60 overflow-y-auto pr-1">
          <div
            v-for="(opt, idx) in form.options"
            :key="idx"
            class="flex items-center gap-2 p-2.5 bg-slate-900/80 border border-slate-800 rounded-lg"
          >
            <span class="w-6 text-center text-xs font-bold text-slate-500 font-mono">
              #{{ idx + 1 }}
            </span>

            <div class="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-2">
              <input
                v-model="opt.label"
                placeholder="Texto de opción (Ej: Pedro Chourio)"
                class="bg-slate-950 border border-slate-700 text-white rounded px-2.5 py-1.5 text-xs focus:border-emerald-500 focus:outline-none"
              />

              <select
                :value="opt.player_id"
                @change="emit('player-select', idx, ($event.target as HTMLSelectElement).value)"
                class="bg-slate-950 border border-slate-700 text-slate-300 rounded px-2.5 py-1.5 text-xs focus:border-emerald-500 focus:outline-none"
              >
                <option value="">-- Vincular Jugador (Opcional) --</option>
                <option v-for="p in rosterPlayers" :key="p.id" :value="p.id">
                  #{{ p.jersey_number }} - {{ p.name }}
                </option>
              </select>
            </div>

            <button
              type="button"
              @click="emit('remove-option', idx)"
              class="p-1.5 text-slate-500 hover:text-red-400 transition-colors"
              title="Eliminar opción"
            >
              <i class="bi bi-x-circle"></i>
            </button>
          </div>
        </div>
      </div>

      <!-- Status -->
      <div class="flex items-center gap-4 border-t border-slate-800 pt-3">
        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
          <input type="radio" value="published" v-model="form.status" class="accent-emerald-600" />
          <span>Publicado (Visible a fanáticos)</span>
        </label>
        <label class="flex items-center gap-2 text-sm text-slate-400 cursor-pointer">
          <input type="radio" value="draft" v-model="form.status" class="accent-emerald-600" />
          <span>Borrador (Oculto)</span>
        </label>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <BaseButton variant="secondary" @click="emit('close')">Cancelar</BaseButton>
        <BaseButton variant="primary" :loading="actionLoading" @click="emit('save')">Guardar Encuesta</BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
