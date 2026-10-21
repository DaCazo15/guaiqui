<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseBadge, BaseButton, Skeleton } from '@guaiqui/ui'
import type { Database } from '@guaiqui/shared'

type PlayerRow = Database['public']['Tables']['players']['Row']

const supabase = useSupabaseClient<Database>()
const players = ref<PlayerRow[]>([])
const loading = ref(true)

onMounted(async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('players')
      .select('*')
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })
      .limit(6)

    if (error) throw error
    players.value = data || []
  } catch (err) {
    console.error('Error fetching roster preview:', err)
    players.value = []
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="py-16 sm:py-24 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            La Tribu en la Cancha
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight mt-2">
            Plantilla Oficial 2026
          </h2>
        </div>

        <NuxtLink to="/plantilla">
          <BaseButton variant="secondary" size="md">
            Ver Plantilla Completa
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <Skeleton v-for="i in 3" :key="i" class="h-28 rounded-guaiqui-xl bg-white" />
      </div>

      <!-- Empty State -->
      <div
        v-else-if="players.length === 0"
        class="bg-white rounded-guaiqui-xl border border-guaiqui-border p-8 text-center space-y-3 max-w-xl mx-auto shadow-guaiqui-sm"
      >
        <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
          <i class="bi bi-people"></i>
        </div>
        <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
          Plantilla en Preparación
        </h3>
        <p class="text-sm text-guaiqui-text-muted">
          La nómina de jugadores para la temporada 2026 de la SuperLiga Profesional será anunciada muy pronto.
        </p>
      </div>

      <!-- Roster Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="p in players"
          :key="p.id"
          variant="default"
          padding="md"
          class="hover:border-guaiqui-primary transition-all duration-200 bg-white"
        >
          <div class="flex items-center gap-4">
            <!-- Jersey Number Badge -->
            <div class="w-14 h-14 rounded-guaiqui-lg bg-guaiqui-primary-dark text-amber-400 font-display font-extrabold text-2xl flex items-center justify-center border-2 border-emerald-600 shadow-sm shrink-0">
              #{{ p.jersey_number }}
            </div>

            <div class="space-y-1 flex-1 min-w-0">
              <div class="flex items-center justify-between gap-2">
                <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase truncate">
                  {{ p.name }}
                </h3>
                <BaseBadge v-if="p.is_star" variant="accent" size="sm" class="shrink-0">Estrella</BaseBadge>
              </div>

              <div class="text-xs text-guaiqui-primary font-semibold truncate">
                {{ p.position }}
              </div>

              <div class="text-xs text-guaiqui-text-muted flex items-center gap-2 truncate">
                <span v-if="p.height">Estatura: {{ p.height }}</span>
                <span>• {{ p.nationality }}</span>
              </div>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
