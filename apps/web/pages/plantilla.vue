<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import { BaseCard, BaseBadge, BaseButton, Skeleton } from '@guaiqui/ui'
import { SOFASCORE_TEAM_INFO } from '@guaiqui/shared'
import type { Player } from '@guaiqui/shared'

type PlayerRow = Player

useSeoMeta({
  title: 'Plantilla Oficial 2026 — Guaiqueríes de Margarita',
  description: 'Revisa la plantilla oficial de Guaiqueríes de Margarita para la temporada 2026 de la SuperLiga Profesional de Baloncesto (SPB).',
})

const supabase = useSupabaseClient()
const players = ref<PlayerRow[]>([])
const loading = ref(true)
const activeFilter = ref<'all' | 'pg' | 'sg' | 'sf' | 'pf' | 'c'>('all')

const filterOptions = [
  { key: 'all', label: 'Todos' },
  { key: 'pg', label: 'Bases (PG)' },
  { key: 'sg', label: 'Escoltas (SG)' },
  { key: 'sf', label: 'Aleros (SF)' },
  { key: 'pf', label: 'Ala-Pívots (PF)' },
  { key: 'c', label: 'Pívots (C)' },
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
    console.error('Error fetching players from Supabase:', err)
    players.value = []
  } finally {
    loading.value = false
  }
})

const filteredRoster = computed(() => {
  const list = players.value
  if (activeFilter.value === 'all') return list
  if (activeFilter.value === 'pg') {
    return list.filter((p) => p.position.includes('Base') || p.position.includes('PG'))
  }
  if (activeFilter.value === 'sg') {
    return list.filter((p) => p.position.includes('Escolta') || p.position.includes('SG'))
  }
  if (activeFilter.value === 'sf') {
    return list.filter((p) => p.position.includes('Alero') || p.position.includes('SF'))
  }
  if (activeFilter.value === 'pf') {
    return list.filter((p) => p.position.includes('Ala-Pívot') || p.position.includes('PF'))
  }
  if (activeFilter.value === 'c') {
    return list.filter((p) => p.position.includes('Pívot') || p.position.includes('C'))
  }
  return list
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-6xl mx-auto space-y-10">
        <!-- Header -->
        <div class="space-y-4 text-center max-w-3xl mx-auto">

          <h1 class="font-display font-extrabold text-4xl sm:text-5xl text-guaiqui-text uppercase tracking-tight">
            Plantilla Oficial <span class="text-guaiqui-primary">2026</span>
          </h1>

          <p class="text-base text-guaiqui-text-muted">
            Los guerreros de la Tribu Insular que defienden los colores verde y oro de Nueva Esparta en el tabloncillo profesional.
          </p>

          <!-- Arena and Team Stats Pill -->
          <div class="flex flex-wrap items-center justify-center gap-4 pt-2 text-xs text-guaiqui-text-muted font-medium">
            <span class="inline-flex items-center gap-1.5 bg-white px-3 py-1.5 rounded-lg border border-guaiqui-border shadow-guaiqui-sm">
              <i class="bi bi-geo-alt-fill text-guaiqui-primary"></i>
              {{ SOFASCORE_TEAM_INFO.arena.name }} (Cap. 8.500)
            </span>
            <span class="inline-flex items-center gap-1.5 bg-white px-3 py-1.5 rounded-lg border border-guaiqui-border shadow-guaiqui-sm">
              <i class="bi bi-trophy-fill text-amber-500"></i>
              {{ SOFASCORE_TEAM_INFO.tournament }}
            </span>
            <span v-if="players.length > 0" class="inline-flex items-center gap-1.5 bg-white px-3 py-1.5 rounded-lg border border-guaiqui-border shadow-guaiqui-sm">
              <i class="bi bi-people-fill text-blue-500"></i>
              Jugadores Inscritos: {{ players.length }}
            </span>
          </div>
        </div>

        <!-- Position Filter Pills (only when players exist) -->
        <div v-if="players.length > 0" class="flex items-center justify-center gap-2 flex-wrap">
          <button
            v-for="opt in filterOptions"
            :key="opt.key"
            @click="activeFilter = (opt.key as any)"
            class="px-4 py-2 rounded-full text-xs font-bold uppercase transition-all duration-200"
            :class="activeFilter === opt.key ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
          >
            {{ opt.label }}
          </button>
        </div>

        <!-- Loading State -->
        <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <Skeleton v-for="i in 6" :key="i" class="h-56 rounded-guaiqui-xl bg-guaiqui-surface" />
        </div>

        <!-- Empty State (No players in database) -->
        <div
          v-else-if="players.length === 0"
          class="text-center py-16 px-6 bg-white rounded-guaiqui-xl border border-guaiqui-border shadow-guaiqui-sm max-w-2xl mx-auto space-y-4"
        >
          <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
            <i class="bi bi-people"></i>
          </div>
          <h3 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
            Plantilla en Preparación
          </h3>
          <p class="text-sm text-guaiqui-text-muted leading-relaxed">
            Actualmente no hay jugadores registrados en la plantilla oficial. La nómina para la temporada será publicada próximamente por la gerencia deportiva de la Tribu.
          </p>
        </div>

        <!-- Filter Empty State -->
        <div
          v-else-if="filteredRoster.length === 0"
          class="text-center py-12 px-4 bg-white rounded-guaiqui-xl border border-guaiqui-border text-guaiqui-text-muted space-y-2 max-w-md mx-auto"
        >
          <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-person-slash"></i>
          </div>
          <p class="text-sm font-medium">No se encontraron jugadores en esta posición.</p>
        </div>

        <!-- Roster Grid -->
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <BaseCard
            v-for="p in filteredRoster"
            :key="p.jersey_number"
            variant="default"
            padding="none"
            class="bg-white border-guaiqui-border hover:border-guaiqui-primary transition-all duration-300 rounded-guaiqui-xl overflow-hidden shadow-guaiqui-sm group flex flex-col justify-between"
          >
            <div class="p-5 space-y-4">
              <!-- Top Row: Jersey & Stars -->
              <div class="flex items-center justify-between">
                <div class="w-14 h-14 rounded-guaiqui-lg bg-gradient-to-br from-emerald-800 to-guaiqui-primary-dark text-amber-400 font-display font-extrabold text-2xl flex items-center justify-center border-2 border-emerald-500 shadow-sm">
                  #{{ p.jersey_number }}
                </div>
                <div class="flex items-center gap-1.5">
                  <a
                    v-if="p.instagram_url"
                    :href="p.instagram_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="w-8 h-8 rounded-full bg-pink-50 hover:bg-pink-100 text-pink-600 flex items-center justify-center text-sm transition-colors"
                    title="Ver Instagram del jugador"
                  >
                    <i class="bi bi-instagram"></i>
                  </a>
                  <BaseBadge v-if="p.is_star" variant="accent" size="sm" class="flex items-center gap-1">
                    <i class="bi bi-star-fill text-[10px]"></i>
                    <span>Estrella</span>
                  </BaseBadge>
                </div>
              </div>

              <!-- Name & Position -->
              <div>
                <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase group-hover:text-guaiqui-primary transition-colors">
                  {{ p.name }}
                </h3>
                <p class="text-xs text-guaiqui-primary font-semibold uppercase tracking-wider mt-0.5">
                  {{ p.position }}
                </p>
              </div>

              <!-- Bio Snippet -->
              <p v-if="p.bio" class="text-xs text-guaiqui-text-muted line-clamp-2 leading-relaxed">
                {{ p.bio }}
              </p>
            </div>

            <!-- Footer Stats Matrix -->
            <div class="grid grid-cols-3 gap-2 px-5 py-3 bg-guaiqui-surface border-t border-guaiqui-border text-center text-xs">
              <div>
                <span class="text-[10px] text-guaiqui-text-subtle uppercase block font-semibold">Altura</span>
                <span class="font-bold text-guaiqui-text">{{ p.height || 'N/D' }}</span>
              </div>
              <div>
                <span class="text-[10px] text-guaiqui-text-subtle uppercase block font-semibold">Edad</span>
                <span class="font-bold text-guaiqui-text">{{ p.age ? `${p.age} años` : 'N/D' }}</span>
              </div>
              <div>
                <span class="text-[10px] text-guaiqui-text-subtle uppercase block font-semibold">País</span>
                <span class="font-bold text-guaiqui-text truncate block">{{ p.nationality }}</span>
              </div>
            </div>

            <!-- Instagram CTA Button if available -->
            <div v-if="p.instagram_url" class="p-3 bg-white border-t border-guaiqui-border/60">
              <a
                :href="p.instagram_url"
                target="_blank"
                rel="noopener noreferrer"
                class="w-full py-2 px-3 bg-gradient-to-r from-pink-50 to-rose-50 hover:from-pink-100 hover:to-rose-100 text-pink-700 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all border border-pink-200/60 shadow-xs"
              >
                <i class="bi bi-instagram"></i>
                <span>Instagram Oficial</span>
                <i class="bi bi-box-arrow-up-right text-[10px]"></i>
              </a>
            </div>
          </BaseCard>
        </div>

        <!-- Technical Staff Callout -->
        <div class="bg-gradient-to-r from-emerald-950 to-slate-900 text-white rounded-guaiqui-xl p-6 sm:p-8 border border-emerald-800/40 shadow-guaiqui-md space-y-4">
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div class="space-y-1">
              <span class="text-xs uppercase font-bold text-emerald-400 tracking-widest">
                Cuerpo Técnico Oficial
              </span>
              <h2 class="font-display font-extrabold text-2xl uppercase">
                Dirección y Estrategia Insular
              </h2>
              <p class="text-sm text-slate-300">
                Liderazgo táctico comprometido con la historia y la pasión de la Tribu Verde.
              </p>
            </div>
            <div class="flex items-center gap-3">
              <NuxtLink :to="{ name: 'equipo-de-trabajo' }">
                <BaseButton variant="secondary" size="md">
                  Ver Todo el Personal
                </BaseButton>
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
