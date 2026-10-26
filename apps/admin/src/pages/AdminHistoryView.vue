<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import HistoryJerseysTab from '../components/history-admin/HistoryJerseysTab.vue'
import HistoryLegendsTab from '../components/history-admin/HistoryLegendsTab.vue'
import HistoryChampionshipsTab from '../components/history-admin/HistoryChampionshipsTab.vue'
import HistoryMilestonesTab from '../components/history-admin/HistoryMilestonesTab.vue'

type HistoryTab = 'jerseys' | 'legends' | 'championships' | 'milestones'

const route = useRoute()
const router = useRouter()

const activeTab = ref<HistoryTab>('jerseys')

const tabs = [
  { id: 'jerseys' as const, label: 'Dorsales Retirados', icon: 'bi-award-fill', description: 'Camisetas inmortales en el techo de El Fortín' },
  { id: 'legends' as const, label: 'Leyendas Inmortales', icon: 'bi-star-fill', description: 'Jugadores, entrenadores y forjadores históricos' },
  { id: 'championships' as const, label: 'Campeonatos & Palmarés', icon: 'bi-trophy-fill', description: 'Las 9 estrellas nacionales consagradas' },
  { id: 'milestones' as const, label: 'Línea de Tiempo', icon: 'bi-hourglass-split', description: 'Cronología e hitos históricos del club' }
]

const setTab = (tab: HistoryTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const syncTabFromRoute = () => {
  const queryTab = route.query.tab as string
  if (queryTab && ['jerseys', 'legends', 'championships', 'milestones'].includes(queryTab)) {
    activeTab.value = queryTab as HistoryTab
  } else if (route.query.tab === 'dorsales') {
    activeTab.value = 'jerseys'
  } else if (route.query.tab === 'leyendas') {
    activeTab.value = 'legends'
  } else if (route.query.tab === 'trofeos' || route.query.tab === 'campeonatos') {
    activeTab.value = 'championships'
  } else if (route.query.tab === 'hitos' || route.query.tab === 'historia') {
    activeTab.value = 'milestones'
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
            <i class="bi bi-trophy text-emerald-400"></i>
            Salón de la Fama & Historia del Club
          </h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Administra los dorsales retirados, leyendas inmortales, trofeos de campeonato e hitos históricos de la Tribu.
          </p>
        </div>
      </div>

      <!-- Dynamic Tab Buttons -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-2.5 p-1.5 bg-slate-950/80 border border-slate-800/80 rounded-2xl shadow-inner">
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
          <span :class="['text-[11px] truncate hidden sm:block', activeTab === tab.id ? 'text-emerald-100' : 'text-slate-500']">
            {{ tab.description }}
          </span>
        </button>
      </div>

      <!-- Dynamic Tab Content Render -->
      <div class="pt-2">
        <HistoryJerseysTab v-if="activeTab === 'jerseys'" />
        <HistoryLegendsTab v-else-if="activeTab === 'legends'" />
        <HistoryChampionshipsTab v-else-if="activeTab === 'championships'" />
        <HistoryMilestonesTab v-else-if="activeTab === 'milestones'" />
      </div>
    </div>
  </AdminLayout>
</template>
