<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, Skeleton } from '@guaiqui/ui'
import { SOFASCORE_TEAM_INFO } from '@guaiqui/shared'
import type { Game } from '@guaiqui/shared'

type GameRow = Game

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Partidos & Calendario — Guaiqueríes de Margarita',
  description: 'Calendario oficial de partidos y resultados en vivo de Guaiqueríes de Margarita en la SuperLiga Profesional de Baloncesto.',
})

const supabase = useSupabaseClient()

const games = ref<GameRow[]>([])
const loading = ref(true)
const activeTab = ref<'all' | 'scheduled' | 'finished'>('all')

onMounted(async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('games')
      .select('*')
      .order('game_date', { ascending: false })

    if (error) throw error
    games.value = (data as unknown as Game[]) || []
  } catch (err) {
    console.error('Error fetching games:', err)
    games.value = []
  } finally {
    loading.value = false
  }
})

const filteredGames = computed(() => {
  if (activeTab.value === 'all') return games.value
  if (activeTab.value === 'scheduled') {
    return games.value.filter((g) => g.status === 'scheduled' || g.status === 'live')
  }
  if (activeTab.value === 'finished') {
    return games.value.filter((g) => g.status === 'finished')
  }
  return games.value
})

const formatDate = (dateStr: string) => {
  if (!dateStr) return 'Fecha por definir'
  const d = new Date(dateStr)
  return d.toLocaleDateString('es-VE', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <div class="flex items-center gap-2">
          <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
            Partidos & <span class="text-guaiqui-primary">Resultados</span>
          </h1>
        </div>
        <p class="text-sm text-guaiqui-text-muted mt-0.5">
          Calendario oficial de partidos y resultados de la temporada de Guaiqueríes de Margarita.
        </p>
      </div>
    </div>

    <!-- Arena Quick Info Banner -->
    <div class="bg-gradient-to-r from-emerald-950 to-slate-900 text-white rounded-guaiqui-xl p-5 border border-emerald-800/40 shadow-guaiqui-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-xl bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-400 text-2xl shrink-0">
          <i class="bi bi-geo-alt-fill"></i>
        </div>
        <div>
          <span class="text-xs uppercase font-mono tracking-wider text-emerald-400 font-bold block">
            Nuestra Casa
          </span>
          <h2 class="font-display text-lg font-bold uppercase">
            {{ SOFASCORE_TEAM_INFO.arena.name }}
          </h2>
          <p class="text-xs text-slate-300">
            {{ SOFASCORE_TEAM_INFO.arena.city }}, {{ SOFASCORE_TEAM_INFO.arena.state }} · Capacidad: {{ SOFASCORE_TEAM_INFO.arena.capacity.toLocaleString() }} fanáticos
          </p>
        </div>
      </div>
    </div>

    <!-- Status Tabs (only when games exist) -->
    <div v-if="games.length > 0" class="flex items-center gap-2 border-b border-guaiqui-border pb-3">
      <button
        @click="activeTab = 'all'"
        class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200"
        :class="activeTab === 'all' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
      >
        Todos ({{ games.length }})
      </button>
      <button
        @click="activeTab = 'scheduled'"
        class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200"
        :class="activeTab === 'scheduled' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
      >
        <i class="bi bi-clock mr-1"></i> Próximos
      </button>
      <button
        @click="activeTab = 'finished'"
        class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200"
        :class="activeTab === 'finished' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
      >
        <i class="bi bi-check-circle mr-1"></i> Finalizados
      </button>
    </div>

    <!-- Loading Skeleton -->
    <div v-if="loading" class="space-y-3">
      <Skeleton v-for="i in 4" :key="i" class="h-28 rounded-guaiqui-xl bg-guaiqui-surface" />
    </div>

    <!-- Empty State: Zero games registered -->
    <div
      v-else-if="games.length === 0"
      class="text-center py-16 text-guaiqui-text-muted space-y-3 bg-white rounded-guaiqui-xl border border-guaiqui-border p-6 max-w-5xl mx-auto"
    >
      <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-calendar-event"></i>
      </div>
      <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        Calendario en Programación
      </h3>
      <p class="text-sm">
        No hay partidos programados ni resultados registrados actualmente. La administración publicará el calendario oficial de la temporada próximamente.
      </p>
    </div>

    <!-- Filter Empty State -->
    <div
      v-else-if="filteredGames.length === 0"
      class="text-center py-12 text-guaiqui-text-muted space-y-2 bg-white rounded-guaiqui-xl border border-guaiqui-border"
    >
      <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
        <i class="bi bi-calendar-x"></i>
      </div>
      <p>No hay partidos en esta categoría seleccionada.</p>
    </div>

    <!-- Games List -->
    <div v-else class="space-y-4">
      <BaseCard
        v-for="game in filteredGames"
        :key="game.id"
        class="p-5 bg-white border-guaiqui-border hover:border-guaiqui-primary rounded-guaiqui-xl shadow-guaiqui-sm transition-all duration-200 space-y-4"
      >
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-guaiqui-border/60 pb-3">
          <div class="flex items-center gap-2">
            <span
              class="px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase tracking-wider"
              :class="game.status === 'live' ? 'bg-red-100 text-red-700 animate-pulse' : game.status === 'finished' ? 'bg-slate-100 text-slate-700' : 'bg-guaiqui-primary-soft text-guaiqui-primary'"
            >
              {{ game.status === 'live' ? 'En Vivo' : game.status === 'finished' ? 'Finalizado' : 'Programado' }}
            </span>
            <span class="text-xs font-medium text-guaiqui-text-muted">
              {{ formatDate(game.game_date) }}
            </span>
          </div>

          <div class="flex items-center gap-2 text-xs font-semibold">
            <span
              class="px-2.5 py-0.5 rounded-md"
              :class="game.is_home ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-slate-100 text-slate-700 border border-slate-200'"
            >
              <i class="bi" :class="game.is_home ? 'bi-house-door-fill mr-1 text-emerald-600' : 'bi-airplane-fill mr-1 text-slate-500'"></i>
              {{ game.is_home ? 'Local (La Asunción)' : 'Visitante' }}
            </span>
          </div>
        </div>

        <!-- Teams & Score Display -->
        <div class="grid grid-cols-1 md:grid-cols-12 gap-4 items-center">
          <!-- Guaiqueríes -->
          <div class="md:col-span-5 flex items-center gap-3">
            <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-800 to-guaiqui-primary-dark text-amber-400 flex items-center justify-center font-display font-black text-xl border-2 border-emerald-500 shrink-0">
              G
            </div>
            <div>
              <h3 class="font-display font-extrabold text-lg text-guaiqui-text uppercase">
                Guaiqueríes de Margarita
              </h3>
              <span class="text-xs text-guaiqui-primary font-semibold">La Tribu Insular</span>
            </div>
          </div>

          <!-- Score / VS Center -->
          <div class="md:col-span-2 text-center py-2">
            <div v-if="game.status === 'finished' || game.status === 'live'" class="space-y-1">
              <div class="font-display font-black text-3xl tracking-wider text-guaiqui-text flex items-center justify-center gap-3">
                <span :class="{ 'text-guaiqui-primary': (game.our_score ?? 0) > (game.opponent_score ?? 0) }">
                  {{ game.our_score ?? 0 }}
                </span>
                <span class="text-guaiqui-text-subtle text-lg">-</span>
                <span :class="{ 'text-guaiqui-primary': (game.opponent_score ?? 0) > (game.our_score ?? 0) }">
                  {{ game.opponent_score ?? 0 }}
                </span>
              </div>
              <span
                v-if="game.status === 'finished'"
                class="inline-block text-[10px] font-bold px-2 py-0.5 rounded-full uppercase"
                :class="(game.our_score ?? 0) > (game.opponent_score ?? 0) ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'"
              >
                {{ (game.our_score ?? 0) > (game.opponent_score ?? 0) ? 'Victoria' : 'Derrota' }}
              </span>
            </div>
            <div v-else class="space-y-0.5">
              <span class="font-display font-black text-2xl text-guaiqui-primary">VS</span>
              <span class="block text-[11px] text-guaiqui-text-muted font-medium">Por jugar</span>
            </div>
          </div>

          <!-- Opponent -->
          <div class="md:col-span-5 flex items-center justify-start md:justify-end gap-3 md:text-right">
            <div class="order-2 md:order-1">
              <h3 class="font-display font-extrabold text-lg text-guaiqui-text uppercase">
                {{ game.opponent }}
              </h3>
              <span class="text-xs text-guaiqui-text-muted font-medium">Rival SPB</span>
            </div>
            <div class="w-12 h-12 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-display font-black text-xl border border-slate-300 shrink-0 order-1 md:order-2 overflow-hidden p-1 shadow-sm">
              <img
                v-if="game.opponent_logo_url"
                :src="game.opponent_logo_url"
                :alt="game.opponent"
                class="w-full h-full object-contain"
                loading="lazy"
              />
              <i v-else class="bi bi-shield-fill text-slate-500"></i>
            </div>
          </div>
        </div>

        <!-- Venue Location Info -->
        <div class="pt-2 text-xs text-guaiqui-text-muted flex items-center justify-between">
          <span class="inline-flex items-center gap-1.5">
            <i class="bi bi-geo-alt text-guaiqui-primary"></i>
            {{ game.location }}
          </span>
          <span class="text-guaiqui-text-subtle italic">
            SuperLiga Profesional de Baloncesto (SPB)
          </span>
        </div>
      </BaseCard>
    </div>
  </div>
</template>
