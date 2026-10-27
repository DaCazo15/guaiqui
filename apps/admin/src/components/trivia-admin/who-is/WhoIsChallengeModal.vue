<script setup lang="ts">
import { ref, computed } from 'vue'
import { BaseModal, BaseButton, BaseInput, BaseSelect } from '@guaiqui/ui'
import type { PlayerItem, WhoIsFormData } from './types'

const props = defineProps<{
  isOpen: boolean
  form: WhoIsFormData
  rosterPlayers: PlayerItem[]
  actionLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save'): void
}>()

const previewRevealed = ref(false)

const selectedPlayer = computed(() => {
  return props.rosterPlayers.find(p => p.id === props.form.player_id) || null
})

const previewImageUrl = computed(() => {
  if (props.form.custom_image_url?.trim()) {
    return props.form.custom_image_url.trim()
  }
  return selectedPlayer.value?.photo_url || ''
})

const effectiveDorsal = computed(() => {
  if (props.form.dorsal_number !== null && props.form.dorsal_number !== undefined) {
    return props.form.dorsal_number
  }
  return selectedPlayer.value?.jersey_number ?? 0
})
</script>

<template>
  <BaseModal
    v-if="isOpen"
    :is-open="isOpen"
    :title="form.id ? 'Editar Reto «¿Quién es?»' : 'Programar Reto «¿Quién es?»'"
    @close="emit('close')"
    size="xl"
  >
    <div class="space-y-6">
      <!-- Live Dark Green Gradient Preview as requested -->
      <div class="p-5 rounded-2xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border border-emerald-500/40 text-white relative shadow-2xl overflow-hidden">
        <div class="flex items-center justify-between border-b border-emerald-500/20 pb-3 mb-4">
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-emerald-300">
              Vista Previa del Fanático (Fondo Verde Gradiente Oscuro)
            </span>
          </div>
          <BaseButton size="sm" variant="secondary" @click="previewRevealed = !previewRevealed">
            <i :class="['bi', previewRevealed ? 'bi-eye-slash' : 'bi-eye', 'mr-1 text-emerald-400']"></i>
            {{ previewRevealed ? 'Ocultar (Silueta)' : 'Revelar Solución' }}
          </BaseButton>
        </div>

        <div class="flex flex-col sm:flex-row items-center justify-center gap-6 py-2">
          <!-- Visual display box -->
          <div class="relative w-36 h-36 rounded-2xl bg-slate-950/80 border-2 border-emerald-400/40 p-2 shadow-2xl flex items-center justify-center overflow-hidden">
            <template v-if="form.challenge_type === 'dorsal'">
              <div class="flex flex-col items-center justify-center text-center">
                <div class="w-14 h-14 rounded-full bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-400 mb-1">
                  <i class="bi bi-shield-shaded text-2xl"></i>
                </div>
                <span class="font-display font-black text-4xl text-emerald-400 tracking-wider">
                  #{{ effectiveDorsal }}
                </span>
                <span class="text-[10px] text-emerald-200 font-bold uppercase">Dorsal Tribu</span>
              </div>
            </template>
            <template v-else>
              <img
                v-if="previewImageUrl"
                :src="previewImageUrl"
                :alt="form.title"
                class="w-full h-full object-contain transition-all duration-300"
                :class="previewRevealed ? 'filter-none scale-105' : 'filter brightness-0 contrast-200'"
              />
              <div v-else class="text-center text-xs text-slate-400">
                <i class="bi bi-image text-3xl text-emerald-400 block mb-1"></i>
                Sin foto asignada
              </div>
            </template>

            <!-- Secret reveal badge in admin preview -->
            <span v-if="previewRevealed" class="absolute top-1 right-1 px-1.5 py-0.5 rounded bg-emerald-500 text-slate-950 text-[9px] font-bold uppercase">
              Descubierto
            </span>
          </div>

          <!-- Preview Challenge Text Info -->
          <div class="space-y-2 text-center sm:text-left max-w-sm">
            <span class="px-2.5 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-400/30 text-[10px] font-bold uppercase tracking-wider text-emerald-300 inline-block">
              {{ form.challenge_type === 'silhouette' ? 'Adivina por Silueta' : 'Adivina por Dorsal' }}
            </span>
            <h4 class="font-display font-black text-xl text-white uppercase tracking-tight">
              {{ form.title || '¿Quién es este jugador de la Tribu?' }}
            </h4>
            <p v-if="form.clue" class="text-xs text-slate-300 italic">
              <i class="bi bi-lightbulb-fill text-amber-300 mr-1"></i>
              Pista: "{{ form.clue }}"
            </p>
            <div class="text-xs text-emerald-400 font-mono font-bold">
              Recompensa: +{{ form.reward_pearls }} perlitas
            </div>
            <div v-if="selectedPlayer" class="text-[11px] text-slate-400 pt-1 border-t border-emerald-500/20">
              Solución asignada: <strong class="text-white">{{ selectedPlayer.name }}</strong> (#{{ selectedPlayer.jersey_number }})
            </div>
          </div>
        </div>
      </div>

      <!-- Form Fields -->
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
              Modo del Reto <span class="text-emerald-400">*</span>
            </label>
            <select
              v-model="form.challenge_type"
              class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-2.5 text-sm focus:outline-none focus:border-emerald-500"
            >
              <option value="silhouette">Adivinar por Silueta / Imagen del Jugador</option>
              <option value="dorsal">Adivinar por Dorsal / Número de Camiseta</option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
              Jugador Real de la Plantilla <span class="text-emerald-400">*</span>
            </label>
            <select
              v-model="form.player_id"
              class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-2.5 text-sm focus:outline-none focus:border-emerald-500"
            >
              <option value="" disabled>Seleccione un jugador</option>
              <option v-for="p in rosterPlayers" :key="p.id" :value="p.id">
                #{{ p.jersey_number }} — {{ p.name }} ({{ p.position || 'Jugador' }})
              </option>
            </select>
          </div>
        </div>

        <BaseInput
          label="Título del Reto"
          v-model="form.title"
          placeholder="Ej: ¿Quién es este jugador de la Tribu?"
        />

        <BaseInput
          label="Pista Opcional para los Fanáticos"
          v-model="form.clue"
          placeholder="Ej: Posición: Alero, máximo anotador en la temporada 2026."
          hint="Aparecerá en pantalla para orientar a los fanáticos sin regalar la respuesta."
        />

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <BaseInput
            label="Perlitas de Recompensa"
            type="number"
            v-model="form.reward_pearls"
            placeholder="50"
          />

          <BaseInput
            v-if="form.challenge_type === 'dorsal'"
            label="Número Dorsal en Pantalla"
            type="number"
            v-model="form.dorsal_number"
            :placeholder="String(selectedPlayer?.jersey_number ?? 10)"
            hint="Por defecto toma el dorsal oficial del jugador."
          />

          <BaseInput
            v-else
            label="URL Imagen Personalizada (Opcional)"
            v-model="form.custom_image_url"
            placeholder="https://ejemplo.com/silueta.png"
            hint="Si se deja vacío, se usa la foto oficial del jugador."
          />

          <BaseSelect
            label="Estado del Reto"
            v-model="form.status"
            :options="[
              { value: 'published', label: 'Publicado (Activo para fanáticos)' },
              { value: 'draft', label: 'Borrador (Oculto)' },
              { value: 'archived', label: 'Archivado' }
            ]"
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput
            label="Fecha y Hora de Inicio — Hora Caracas (GMT-4)"
            type="datetime-local"
            v-model="form.starts_at"
          />
          <BaseInput
            label="Fecha y Hora de Cierre — Hora Caracas (GMT-4)"
            type="datetime-local"
            v-model="form.ends_at"
          />
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <BaseButton variant="secondary" @click="emit('close')">Cancelar</BaseButton>
        <BaseButton variant="primary" :loading="actionLoading" @click="emit('save')">
          <i class="bi bi-check2 mr-1.5"></i>
          {{ form.id ? 'Guardar Cambios' : 'Programar Reto' }}
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
