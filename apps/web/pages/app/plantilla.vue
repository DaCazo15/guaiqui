<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseBadge, Skeleton } from '@guaiqui/ui'
import type { Player } from '@guaiqui/shared'

type PlayerRow = Player

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const supabase = useSupabaseClient()

const players = ref<PlayerRow[]>([])
const loading = ref(true)
const activeFilter = ref<'all' | 'pg' | 'sg' | 'sf' | 'pf' | 'c'>('all')

const filterOptions = [
  { key: 'all', label: 'Todos' },
  { key: 'pg', label: 'Bases' },
  { key: 'sg', label: 'Escoltas' },
  { key: 'sf', label: 'Aleros' },
  { key: 'pf', label: 'Ala-Pívots' },
  { key: 'c', label: 'Pívots' },
]

onMounted(async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('players')
      .select('*')
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })

    if (error) throw error
    players.value = data || []
  } catch (err) {
    console.error('Error fetching roster:', err)
    players.value = []
  } finally {
    loading.value = false
  }
})

const filteredPlayers = computed(() => {
  if (activeFilter.value === 'all') return players.value
  if (activeFilter.value === 'pg') {
    return players.value.filter((p) => p.position.includes('Base') || p.position.includes('PG'))
  }
  if (activeFilter.value === 'sg') {
    return players.value.filter((p) => p.position.includes('Escolta') || p.position.includes('SG'))
  }
  if (activeFilter.value === 'sf') {
    return players.value.filter((p) => p.position.includes('Alero') || p.position.includes('SF'))
  }
  if (activeFilter.value === 'pf') {
    return players.value.filter((p) => p.position.includes('Ala-Pívot') || p.position.includes('PF'))
  }
  if (activeFilter.value === 'c') {
    return players.value.filter((p) => p.position.includes('Pívot') || p.position.includes('C'))
  }
  return players.value
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <div class="flex items-center gap-2">
          <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
            Plantilla <span class="text-guaiqui-primary">Oficial</span>
          </h1>
        </div>
        <p class="text-sm text-guaiqui-text-muted mt-0.5">
          Guerreros de Guaiqueríes de Margarita — SuperLiga Profesional de Baloncesto
        </p>
      </div>
    </div>

    <!-- Position Filters (only when players exist) -->
    <div v-if="players.length > 0" class="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
      <button
        v-for="opt in filterOptions"
        :key="opt.key"
        @click="activeFilter = (opt.key as any)"
        class="px-3.5 py-1.5 rounded-full text-xs font-bold uppercase whitespace-nowrap transition-all duration-200"
        :class="activeFilter === opt.key ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
      >
        {{ opt.label }}
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
      <Skeleton v-for="i in 6" :key="i" class="h-44 rounded-guaiqui-xl bg-guaiqui-surface" />
    </div>

    <!-- Empty State: Zero players registered -->
    <div
      v-else-if="players.length === 0"
      class="text-center py-16 text-guaiqui-text-muted space-y-3 bg-white rounded-guaiqui-xl border border-guaiqui-border p-6 max-w-5xl mx-auto"
    >
      <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-people"></i>
      </div>
      <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        Plantilla en Preparación
      </h3>
      <p class="text-sm">
        No hay jugadores registrados en la plantilla oficial actualmente. La administración los publicará pronto.
      </p>
    </div>

    <!-- Empty Filter State -->
    <div
      v-else-if="filteredPlayers.length === 0"
      class="text-center py-12 text-guaiqui-text-muted space-y-2 bg-white rounded-guaiqui-xl border border-guaiqui-border"
    >
      <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
        <i class="bi bi-person-slash"></i>
      </div>
      <p>No hay jugadores en esta categoría seleccionada.</p>
    </div>

    <!-- Roster Grid -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
      <BaseCard
        v-for="player in filteredPlayers"
        :key="player.jersey_number"
        class="bg-white border-guaiqui-border hover:border-guaiqui-primary p-5 rounded-guaiqui-xl space-y-3 transition-all duration-200 relative group overflow-hidden shadow-guaiqui-sm flex flex-col justify-between"
      >
        <div class="space-y-3">
          <!-- Jersey Number Tag & Badges -->
          <div class="flex items-center justify-between">
            <span class="font-display text-3xl font-bold text-guaiqui-primary">
              #{{ player.jersey_number }}
            </span>
            <div class="flex items-center gap-1.5">
              <a
                v-if="player.instagram_url"
                :href="player.instagram_url"
                target="_blank"
                rel="noopener noreferrer"
                class="w-7 h-7 rounded-full bg-pink-50 hover:bg-pink-100 text-pink-600 flex items-center justify-center text-sm transition-colors"
                title="Ver Instagram del jugador"
              >
                <i class="bi bi-instagram"></i>
              </a>
              <BaseBadge v-if="player.is_star" variant="warning" class="flex items-center gap-1">
                <i class="bi bi-star-fill text-[10px]"></i>
                <span>Estrella</span>
              </BaseBadge>
            </div>
          </div>

          <div>
            <h3 class="font-display text-lg font-bold text-guaiqui-text group-hover:text-guaiqui-primary transition-colors">
              {{ player.name }}
            </h3>
            <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-semibold">
              {{ player.position }}
            </p>
          </div>

          <p v-if="player.bio" class="text-xs text-guaiqui-text-muted line-clamp-2">
            {{ player.bio }}
          </p>
        </div>

        <div class="space-y-3">
          <div class="grid grid-cols-3 gap-2 text-xs pt-3 border-t border-guaiqui-border text-guaiqui-text-muted text-center">
            <div>
              <span class="text-guaiqui-text-subtle block text-[10px] uppercase font-semibold">Altura</span>
              <span class="font-bold text-guaiqui-text">{{ player.height || 'N/D' }}</span>
            </div>
            <div>
              <span class="text-guaiqui-text-subtle block text-[10px] uppercase font-semibold">Edad</span>
              <span class="font-bold text-guaiqui-text">{{ player.age ? `${player.age} años` : 'N/D' }}</span>
            </div>
            <div>
              <span class="text-guaiqui-text-subtle block text-[10px] uppercase font-semibold">País</span>
              <span class="font-bold text-guaiqui-text truncate block">{{ player.nationality }}</span>
            </div>
          </div>

          <!-- Botón de acceso directo a Instagram si el jugador lo tiene -->
          <a
            v-if="player.instagram_url"
            :href="player.instagram_url"
            target="_blank"
            rel="noopener noreferrer"
            class="w-full py-1.5 px-3 bg-gradient-to-r from-pink-50 to-rose-50 hover:from-pink-100 hover:to-rose-100 text-pink-700 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all border border-pink-200/60 shadow-xs"
          >
            <i class="bi bi-instagram"></i>
            <span>Instagram Oficial</span>
            <i class="bi bi-box-arrow-up-right text-[10px]"></i>
          </a>
        </div>
      </BaseCard>
    </div>
  </div>
</template>
