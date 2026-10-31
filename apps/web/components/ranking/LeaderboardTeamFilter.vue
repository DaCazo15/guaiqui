<script setup lang="ts">
import { ref, onMounted } from 'vue'

const props = defineProps<{
  selectedTeamId?: string | null
}>()

const emit = defineEmits<{
  (e: 'select', teamId: string | null): void
}>()

const supabase = useSupabaseClient()
const teams = ref<Array<{ id: string; name: string; short_name?: string | null; logo_url?: string | null }>>([])

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('teams_public')
      .select('id, name, short_name, logo_url')
      .order('name', { ascending: true })

    if (data) {
      teams.value = data
    }
  } catch {
    teams.value = []
  }
})

function handleSelect(id: string | null) {
  emit('select', id)
}
</script>

<template>
  <div class="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-thin">
    <!-- Opción: Todos los Equipos -->
    <button
      type="button"
      @click="handleSelect(null)"
      class="px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all shrink-0 cursor-pointer flex items-center gap-1.5"
      :class="!selectedTeamId
        ? 'bg-guaiqui-primary text-white shadow-xs'
        : 'bg-white border border-gray-200 text-gray-700 hover:bg-gray-50'"
    >
      <i class="bi bi-globe" aria-hidden="true"></i>
      <span>Todos los Equipos</span>
    </button>

    <!-- Opciones por Equipo -->
    <button
      v-for="team in teams"
      :key="team.id"
      type="button"
      @click="handleSelect(team.id)"
      class="px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all shrink-0 cursor-pointer flex items-center gap-1.5"
      :class="selectedTeamId === team.id
        ? 'bg-guaiqui-primary text-white shadow-xs'
        : 'bg-white border border-gray-200 text-gray-700 hover:bg-gray-50'"
    >
      <img
        v-if="team.logo_url"
        :src="team.logo_url"
        :alt="team.name"
        class="w-4 h-4 object-contain rounded-full"
      />
      <i v-else class="bi bi-shield-fill text-xs" aria-hidden="true"></i>
      <span>{{ team.short_name || team.name }}</span>
    </button>
  </div>
</template>
