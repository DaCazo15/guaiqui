<script setup lang="ts">
import { computed, watch, onMounted, onUnmounted } from 'vue'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TeamPickerCard from './TeamPickerCard.vue'
import TeamPickerEmpty from './TeamPickerEmpty.vue'

const {
  isPickerOpen,
  pickerTargetSection,
  followedTeams,
  loading,
  closePicker,
  selectTeam,
} = useCurrentTeam()

const sectionTitle = computed(() => {
  if (pickerTargetSection.value === 'tienda') return 'la Tienda de Premios'
  if (pickerTargetSection.value === 'hub') return 'el Hub de Equipo'
  return 'Trivias'
})

const handleKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Escape' && isPickerOpen.value) {
    closePicker()
  }
}

watch(isPickerOpen, (open) => {
  if (typeof document !== 'undefined') {
    if (open) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
  }
})

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handleKeydown)
  }
})

onUnmounted(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('keydown', handleKeydown)
    document.body.style.overflow = ''
  }
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isPickerOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fade-in"
      role="dialog"
      aria-modal="true"
      aria-labelledby="team-picker-title"
    >
      <!-- Backdrop click area -->
      <div class="fixed inset-0" @click="closePicker" aria-hidden="true"></div>

      <!-- Modal Card -->
      <div class="relative w-full max-w-lg bg-gradient-to-b from-slate-900 via-slate-950 to-slate-950 border border-emerald-500/30 rounded-3xl p-5 sm:p-6 shadow-2xl z-10 max-h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-start justify-between gap-4 pb-4 border-b border-slate-800 shrink-0">
          <div>
            <span class="text-[11px] font-bold uppercase tracking-wider text-emerald-400">
              Selección de Equipo
            </span>
            <h3 id="team-picker-title" class="text-lg font-bold text-white mt-0.5">
              Elige tu equipo para {{ sectionTitle }}
            </h3>
            <p class="text-xs text-slate-400 mt-1">
              Las perlitas y recompensas se gestionan de forma independiente por equipo.
            </p>
          </div>

          <button
            type="button"
            @click="closePicker"
            aria-label="Cerrar selección de equipo"
            class="w-8 h-8 rounded-full bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white flex items-center justify-center transition-colors shrink-0 cursor-pointer"
          >
            <i class="bi bi-x-lg text-sm"></i>
          </button>
        </div>

        <!-- Content Area -->
        <div class="flex-1 overflow-y-auto py-4 space-y-2.5 pr-1">
          <div v-if="loading" class="py-12 text-center text-slate-400">
            <i class="bi bi-arrow-repeat text-2xl animate-spin inline-block mb-2 text-emerald-400"></i>
            <p class="text-xs">Cargando tus equipos seguidos...</p>
          </div>

          <TeamPickerEmpty
            v-else-if="followedTeams.length === 0"
            @close="closePicker"
          />

          <template v-else>
            <TeamPickerCard
              v-for="team in followedTeams"
              :key="team.id"
              :team="team"
              :target-section="pickerTargetSection"
              @select="selectTeam($event, pickerTargetSection)"
            />
          </template>
        </div>

        <!-- Footer -->
        <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400 shrink-0">
          <NuxtLink
            to="/app/equipos"
            @click="closePicker"
            class="text-emerald-400 hover:text-emerald-300 font-semibold inline-flex items-center gap-1.5 transition-colors"
          >
            <i class="bi bi-plus-circle text-xs"></i>
            <span>Seguir a otros equipos</span>
          </NuxtLink>

          <button
            type="button"
            @click="closePicker"
            class="text-slate-400 hover:text-white transition-colors"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
