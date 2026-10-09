<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseBadge, Skeleton } from '@guaiqui/ui'
import type { Database } from '@guaiqui/shared'

type PlayerRow = Database['public']['Tables']['players']['Row']

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const supabase = useSupabaseClient<Database>()

const players = ref<PlayerRow[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('players')
      .select('*')
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })

    if (data) {
      players.value = data
    }
  } catch (err) {
    console.error('Error fetching roster:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Plantilla <span class="text-guaiqui-primary">Oficial</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Los guerreros de Guaiqueríes de Margarita.
        </p>
      </div>

      <NuxtLink to="/app/perfil">
        <span class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark underline font-medium inline-flex items-center gap-1">
          <i class="bi bi-arrow-left"></i>
          Volver al Perfil
        </span>
      </NuxtLink>
    </div>

    <!-- Roster Grid -->
    <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
      <Skeleton v-for="i in 6" :key="i" class="h-44 rounded-guaiqui-xl bg-guaiqui-surface" />
    </div>

    <div v-else-if="players.length === 0" class="text-center py-12 text-guaiqui-text-muted space-y-2">
      <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
        <i class="bi bi-dribbble"></i>
      </div>
      <p>No hay jugadores registrados en la plantilla actualmente.</p>
    </div>

    <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
      <BaseCard
        v-for="player in players"
        :key="player.id"
        class="bg-white border-guaiqui-border hover:border-guaiqui-primary p-5 rounded-guaiqui-xl space-y-3 transition-all duration-200 relative group overflow-hidden shadow-guaiqui-sm"
      >
        <!-- Jersey Number Tag -->
        <div class="flex items-center justify-between">
          <span class="font-display text-3xl font-bold text-guaiqui-primary">
            #{{ player.jersey_number }}
          </span>
          <BaseBadge v-if="player.is_star" variant="warning" class="flex items-center gap-1">
            <i class="bi bi-star-fill text-[10px]"></i>
            <span>Estrella</span>
          </BaseBadge>
        </div>

        <div>
          <h3 class="font-display text-lg font-bold text-guaiqui-text group-hover:text-guaiqui-primary transition-colors">
            {{ player.name }}
          </h3>
          <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-semibold">
            {{ player.position }}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-2 text-xs pt-2 border-t border-guaiqui-border text-guaiqui-text-muted">
          <div>
            <span class="text-guaiqui-text-subtle block text-[10px]">Altura</span>
            {{ player.height || 'N/D' }}
          </div>
          <div>
            <span class="text-guaiqui-text-subtle block text-[10px]">Nacionalidad</span>
            {{ player.nationality }}
          </div>
        </div>
      </BaseCard>
    </div>
  </div>
</template>
