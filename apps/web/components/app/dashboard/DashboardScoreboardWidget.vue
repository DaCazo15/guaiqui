<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import type { Game } from '@guaiqui/shared'

type GameRow = Game

const supabase = useSupabaseClient()

const games = ref<GameRow[]>([])
const loading = ref(true)

// Próximo partido programado
const nextGame = computed(() => {
  const scheduled = games.value.filter((g) => g.status === 'scheduled' || g.status === 'live')
  if (scheduled.length > 0) {
    // Ordenar de más cercano a más lejano
    return [...scheduled].sort((a, b) => new Date(a.game_date).getTime() - new Date(b.game_date).getTime())[0]
  }
  return null
})

// Partidos finalizados recientes (últimos 2)
const recentGames = computed(() => {
  const finished = games.value.filter((g) => g.status === 'finished')
  return [...finished]
    .sort((a, b) => new Date(b.game_date).getTime() - new Date(a.game_date).getTime())
    .slice(0, 2)
})

// Cuenta regresiva reactiva
const days = ref('00')
const hours = ref('00')
const minutes = ref('00')
const seconds = ref('00')
let countdownTimer: ReturnType<typeof setInterval> | null = null

function updateCountdown() {
  if (!nextGame.value?.game_date) {
    days.value = '00'
    hours.value = '00'
    minutes.value = '00'
    seconds.value = '00'
    return
  }

  const target = new Date(nextGame.value.game_date).getTime()
  const now = Date.now()
  const diff = target - now

  if (diff <= 0) {
    days.value = '00'
    hours.value = '00'
    minutes.value = '00'
    seconds.value = '00'
    return
  }

  const d = Math.floor(diff / (1000 * 60 * 60 * 24))
  const h = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  const m = Math.floor((diff % (1000 * 60)) / (1000 * 60))
  const s = Math.floor((diff % (1000 * 60)) / 1000)

  days.value = d.toString().padStart(2, '0')
  hours.value = h.toString().padStart(2, '0')
  minutes.value = m.toString().padStart(2, '0')
  seconds.value = s.toString().padStart(2, '0')
}

async function loadGames() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('games')
      .select('*')
      .order('game_date', { ascending: false })

    if (error) throw error
    games.value = (data as unknown as Game[]) || []
  } catch (err) {
    console.error('Error cargando partidos:', err)
    games.value = []
  } finally {
    loading.value = false
    updateCountdown()
  }
}

onMounted(() => {
  loadGames()
  countdownTimer = setInterval(updateCountdown, 1000)
})

onBeforeUnmount(() => {
  if (countdownTimer) clearInterval(countdownTimer)
})
</script>

<template>
  <BaseCard class="p-4 sm:p-2.5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Encabezado de Sección -->
    <div class="flex items-center justify-between pb-3 mb-2 border-b border-guaiqui-border">
      <div class="flex items-center gap-2.5">
        <div class="w-9 h-9 rounded-guaiqui-md bg-guaiqui-primary-soft border border-guaiqui-primary/20 flex items-center justify-center text-guaiqui-primary text-base shrink-0">
          <i class="bi bi-calendar-event-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide leading-tight">
            Calendario Deportivo
          </h2>
          <p class="text-[11px] text-guaiqui-text-muted">
            Partidos y Resultados Oficiales
          </p>
        </div>
      </div>

      <NuxtLink to="/app/partidos">
        <button class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-guaiqui-md bg-guaiqui-surface hover:bg-gray-200 text-guaiqui-text text-xs font-bold uppercase tracking-wider border border-guaiqui-border transition-colors">
          <span>Ver todos</span>
          <i class="bi bi-chevron-right text-[10px]"></i>
        </button>
      </NuxtLink>
    </div>

    <!-- Matchup Hero: Próximo Partido Dinámico -->
    <div
      v-if="nextGame"
      class="relative overflow-hidden rounded-guaiqui-xl bg-gradient-to-br from-stone-950 via-emerald-950 to-slate-900 border border-emerald-500/30 p-4 sm:p-2.5 text-white shadow-md"
    >
      <!-- Glow ambiental sutil -->
      <div class="absolute -top-12 left-1/2 -translate-x-1/2 w-72 h-36 bg-emerald-500/15 blur-3xl pointer-events-none"></div>

      <!-- Fila superior: Badge de Torneo y Gimnasio Dinámico -->
      <div class="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-300 pb-3 border-b border-white/10">
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-guaiqui-accent animate-ping shrink-0"></span>
          <span class="font-mono font-bold text-emerald-400 uppercase tracking-widest text-[11px]">
            {{ nextGame.status === 'live' ? 'EN VIVO' : 'PRÓXIMO ENCUENTRO' }}
          </span>
        </div>
        <span class="font-medium text-[11px] text-slate-300 flex items-center gap-1 truncate max-w-[260px]">
          <i class="bi bi-geo-alt-fill text-guaiqui-accent"></i>
          {{ nextGame.location }}
        </span>
      </div>

      <!-- Duelo Dinámico: Guaiqueríes vs Rival -->
      <div class="grid grid-cols-3 items-center py-4 gap-2">
        <!-- Equipo Local o Guaiqueríes -->
        <div class="flex flex-col items-center text-center space-y-1.5">
          <div class="relative w-14 h-14 sm:w-16 sm:h-16 rounded-full bg-emerald-900/80 border-2 border-emerald-400 p-1.5 shadow-lg flex items-center justify-center">
            <img src="/logo.png" alt="Guaiqueríes de Margarita" class="w-full h-full object-contain drop-shadow" />
            <span class="absolute -bottom-1 px-1.5 py-0.2 rounded-full bg-emerald-600 text-white text-[8px] font-black uppercase tracking-wider">
              {{ nextGame.is_home ? 'Local' : 'Visita' }}
            </span>
          </div>
          <div>
            <h3 class="font-display font-black text-sm sm:text-base uppercase text-white tracking-wide">
              Guaiqueríes
            </h3>
            <p class="text-[10px] text-emerald-400 font-bold uppercase">Margarita</p>
          </div>
        </div>

        <!-- Centro: VS y Torneo -->
        <div class="flex flex-col items-center text-center space-y-1">
          <div class="px-2.5 py-0.5 rounded-full bg-white/10 border border-white/20 text-[9px] font-extrabold uppercase tracking-wider text-amber-300 truncate max-w-[120px]">
            SPB Oficial
          </div>
          <div class="font-display font-black text-2xl sm:text-3xl text-white tracking-widest">
            VS
          </div>
          <div class="text-[10px] font-bold text-slate-400">
            Jornada Oficial
          </div>
        </div>

        <!-- Equipo Rival Dinámico -->
        <div class="flex flex-col items-center text-center space-y-1.5">
          <div class="relative w-14 h-14 sm:w-16 sm:h-16 rounded-full bg-slate-900 border-2 border-slate-600 p-1.5 shadow-lg flex items-center justify-center">
            <img
              v-if="nextGame.opponent_logo_url"
              :src="nextGame.opponent_logo_url"
              :alt="nextGame.opponent"
              class="w-full h-full object-contain drop-shadow"
            />
            <div
              v-else
              class="w-full h-full rounded-full bg-gradient-to-br from-blue-900 to-indigo-950 flex items-center justify-center text-amber-400 text-xl font-black font-display border border-blue-400/30"
            >
              <i class="bi bi-shield-shaded"></i>
            </div>
            <span class="absolute -bottom-1 px-1.5 py-0.2 rounded-full bg-blue-700 text-white text-[8px] font-black uppercase tracking-wider">
              {{ !nextGame.is_home ? 'Local' : 'Visita' }}
            </span>
          </div>
          <div>
            <h3 class="font-display font-black text-sm sm:text-base uppercase text-white tracking-wide truncate max-w-[100px] sm:max-w-none">
              {{ nextGame.opponent }}
            </h3>
            <p class="text-[10px] text-slate-400 font-bold uppercase">Rival</p>
          </div>
        </div>
      </div>

      <!-- Contador Regresivo Compacto -->
      <div class="pt-3 border-t border-white/10 flex items-center justify-between">
        <span class="text-[11px] font-semibold text-slate-400 uppercase tracking-wider hidden sm:inline">
          Tiempo para el salto entre dos:
        </span>
        <div class="flex items-center gap-1.5 font-mono text-center">
          <div class="bg-black/60 border border-emerald-500/30 rounded px-2 py-0.5 min-w-[38px]">
            <span class="font-display font-black text-sm sm:text-base text-emerald-400 tabular-nums">{{ days }}</span>
            <span class="block text-[7px] uppercase tracking-wider text-slate-400">Días</span>
          </div>
          <span class="text-emerald-400 font-bold text-xs">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded px-2 py-0.5 min-w-[38px]">
            <span class="font-display font-black text-sm sm:text-base text-emerald-400 tabular-nums">{{ hours }}</span>
            <span class="block text-[7px] uppercase tracking-wider text-slate-400">Horas</span>
          </div>
          <span class="text-emerald-400 font-bold text-xs">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded px-2 py-0.5 min-w-[38px]">
            <span class="font-display font-black text-sm sm:text-base text-emerald-400 tabular-nums">{{ minutes }}</span>
            <span class="block text-[7px] uppercase tracking-wider text-slate-400">Min</span>
          </div>
          <span class="text-emerald-400 font-bold text-xs">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded px-2 py-0.5 min-w-[38px]">
            <span class="font-display font-black text-sm sm:text-base text-amber-400 tabular-nums animate-pulse">{{ seconds }}</span>
            <span class="block text-[7px] uppercase tracking-wider text-slate-400">Seg</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Si no hay partido próximo -->
    <div v-else class="p-6 rounded-guaiqui-xl bg-guaiqui-surface text-center text-xs text-guaiqui-text-muted space-y-2 border border-guaiqui-border/60">
      <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-xl mx-auto">
        <i class="bi bi-calendar-event"></i>
      </div>
      <p class="font-semibold text-guaiqui-text">Sin partidos programados actualmente</p>
      <p class="text-[11px] text-guaiqui-text-subtle">El calendario de la temporada será publicado próximamente.</p>
    </div>

    <!-- Resultados Recientes Dinámicos -->
    <div v-if="recentGames.length > 0" class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-0.5">
      <div
        v-for="game in recentGames"
        :key="game.id"
        class="p-3 bg-guaiqui-surface rounded-guaiqui-lg border border-guaiqui-border space-y-1.5 hover:border-guaiqui-primary/40 transition-colors"
      >
        <div class="flex items-center justify-between text-xs font-semibold text-guaiqui-text-muted">
          <span class="truncate max-w-[140px] text-[11px]">{{ game.location }}</span>
          <span
            class="px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider"
            :class="(game.our_score ?? 0) > (game.opponent_score ?? 0) ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'"
          >
            {{ (game.our_score ?? 0) > (game.opponent_score ?? 0) ? 'Victoria' : 'Derrota' }}
          </span>
        </div>
        <div class="flex items-center justify-between text-xs">
          <span class="font-display font-bold uppercase text-guaiqui-text">Guaiqueríes</span>
          <span class="font-display font-black text-base text-guaiqui-primary tabular-nums">{{ game.our_score ?? 0 }}</span>
        </div>
        <div class="flex items-center justify-between text-xs">
          <span class="font-display font-semibold uppercase text-guaiqui-text-muted truncate max-w-[120px]">{{ game.opponent }}</span>
          <span class="font-display font-bold text-sm text-guaiqui-text-muted tabular-nums">{{ game.opponent_score }}</span>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
