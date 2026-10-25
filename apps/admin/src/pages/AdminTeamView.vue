<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import TeamRosterTab from '../components/team-admin/TeamRosterTab.vue'
import TeamCalendarTab from '../components/team-admin/TeamCalendarTab.vue'
import TeamStaffTab from '../components/team-admin/TeamStaffTab.vue'

type TeamTab = 'roster' | 'calendar' | 'staff'

const route = useRoute()
const router = useRouter()

const activeTab = ref<TeamTab>('roster')

const tabs = [
  { id: 'roster' as const, label: 'Plantilla de Jugadores', icon: 'bi-person-bounding-box', description: 'Roster oficial, dorsales y jugadores estrella' },
  { id: 'calendar' as const, label: 'Calendario de Partidos', icon: 'bi-calendar-event', description: 'Encuentros, sedes, estados y marcadores' },
  { id: 'staff' as const, label: 'Cuerpo Técnico & Directiva', icon: 'bi-person-lines-fill', description: 'Personal directivo, técnico y staff' }
]

const setTab = (tab: TeamTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const syncTabFromRoute = () => {
  const queryTab = route.query.tab as string
  if (queryTab && ['roster', 'calendar', 'staff'].includes(queryTab)) {
    activeTab.value = queryTab as TeamTab
  } else if (route.query.tab === 'plantilla') {
    activeTab.value = 'roster'
  } else if (route.query.tab === 'calendario' || route.query.tab === 'partidos') {
    activeTab.value = 'calendar'
  } else if (route.query.tab === 'cuerpo-tecnico') {
    activeTab.value = 'staff'
  }
}

onMounted(() => {
  syncTabFromRoute()
})

watch(() => route.query.tab, () => {
  syncTabFromRoute()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Section Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-shield-shaded text-emerald-400"></i>
            Gestión del Equipo
          </h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Administra la plantilla oficial de jugadores, calendario de partidos y cuerpo técnico desde una sola sección.
          </p>
        </div>
      </div>

      <!-- Dynamic Tab Buttons -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-2.5 p-1.5 bg-slate-950/80 border border-slate-800/80 rounded-2xl shadow-inner">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          @click="setTab(tab.id)"
          :class="[
            'px-4 py-3 rounded-xl text-left transition-all duration-200 flex flex-col justify-center gap-1 group relative',
            activeTab === tab.id
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-950/60 ring-1 ring-emerald-400/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900/80'
          ]"
        >
          <div class="flex items-center gap-2">
            <i :class="['bi', tab.icon, 'text-base', activeTab === tab.id ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400']"></i>
            <span class="text-xs sm:text-sm font-bold tracking-tight">{{ tab.label }}</span>
          </div>
          <span :class="['text-[11px] truncate', activeTab === tab.id ? 'text-emerald-100' : 'text-slate-500']">
            {{ tab.description }}
          </span>
        </button>
      </div>

      <!-- Dynamic Tab Content Render -->
      <div class="pt-2">
        <TeamRosterTab v-if="activeTab === 'roster'" />
        <TeamCalendarTab v-else-if="activeTab === 'calendar'" />
        <TeamStaffTab v-else-if="activeTab === 'staff'" />
      </div>
    </div>
  </AdminLayout>
</template>
