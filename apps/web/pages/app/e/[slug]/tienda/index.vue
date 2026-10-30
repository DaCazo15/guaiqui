<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSeoMeta, useSupabaseClient } from '#imports'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon, BaseInput, BaseBadge } from '@guaiqui/ui'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import { useCatalog, type Product } from '~/composables/useCatalog'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const { products, loading: catalogLoading, fetchProducts } = useCatalog()

const {
  activeTeam,
  loading: teamLoading,
  loadTeamBySlug,
  openPicker,
} = useCurrentTeam()

const togglingFollow = ref(false)
const selectedCategory = ref<string>('all')
const onlyAffordable = ref<boolean>(false)
const searchQuery = ref<string>('')

const teamSlug = computed(() => route.params.slug as string)

const categories = [
  { id: 'all', label: 'Todos' },
  { id: 'physical', label: 'Indumentaria & Souvenirs' },
  { id: 'experience', label: 'Experiencias VIP' },
  { id: 'raffle', label: 'Sorteos' },
]

const filteredProducts = computed(() => {
  const teamBal = activeTeam.value?.balance || 0
  return products.value.filter((p) => {
    if (selectedCategory.value !== 'all' && p.category !== selectedCategory.value) {
      return false
    }
    if (onlyAffordable.value && p.cost_pearls > teamBal) {
      return false
    }
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase()
      const matchName = p.name.toLowerCase().includes(q)
      const matchDesc = p.description?.toLowerCase().includes(q)
      if (!matchName && !matchDesc) return false
    }
    return true
  })
})

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await fetchProducts(team.id)
  }
}

const handleToggleFollow = async () => {
  if (!activeTeam.value || togglingFollow.value) return
  togglingFollow.value = true
  const team = activeTeam.value
  const targetState = !team.is_following

  try {
    if (targetState) {
      await supabase.rpc('follow_team', { p_team_id: team.id })
    } else {
      await supabase.rpc('unfollow_team', { p_team_id: team.id })
    }
    await loadTeamBySlug(team.slug)
  } catch (err) {
    console.error('Error al alternar seguimiento:', err)
  } finally {
    togglingFollow.value = false
  }
}

watch(teamSlug, () => {
  loadData()
})

onMounted(() => {
  loadData()
})

useSeoMeta({
  title: computed(() =>
    activeTeam.value ? `Tienda de ${activeTeam.value.name} — Fan Zone` : 'Tienda Oficial'
  ),
})
</script>

<template>
  <div class="space-y-6">
    <!-- Loading skeleton -->
    <div v-if="teamLoading && !activeTeam" class="space-y-4 animate-pulse">
      <div class="h-40 rounded-3xl bg-slate-900 border border-slate-800"></div>
      <div class="h-10 w-64 rounded-xl bg-slate-900"></div>
    </div>

    <template v-else-if="activeTeam">
      <!-- Team Header -->
      <TeamHubHeader
        :team="activeTeam"
        :toggling="togglingFollow"
        @toggle-follow="handleToggleFollow"
        @switch-team="openPicker('tienda')"
      />

      <!-- Inactive Alert Banner -->
      <TeamHubInactiveBanner
        v-if="activeTeam.status === 'inactive'"
        :team-name="activeTeam.name"
      />

      <!-- Navigation Tabs -->
      <TeamHubTabs
        :slug="activeTeam.slug"
        active-tab="tienda"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Store Content (When active) -->
      <div v-if="activeTeam.status === 'active'" class="space-y-5">
        <!-- Controls Bar: Search & Category Filter -->
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 pt-2">
          <!-- Category Pills -->
          <div class="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
            <button
              v-for="cat in categories"
              :key="cat.id"
              type="button"
              @click="selectedCategory = cat.id"
              class="px-3.5 py-2 rounded-xl text-xs font-bold transition-all duration-200 shrink-0 cursor-pointer"
              :class="[
                selectedCategory === cat.id
                  ? 'bg-emerald-500 text-slate-950 font-black shadow-xs'
                  : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-slate-800'
              ]"
            >
              {{ cat.label }}
            </button>
          </div>

          <!-- Affordable Toggle -->
          <label class="flex items-center gap-2 text-xs font-semibold text-slate-300 cursor-pointer select-none shrink-0">
            <input
              type="checkbox"
              v-model="onlyAffordable"
              class="rounded border-slate-700 bg-slate-900 text-emerald-500 focus:ring-emerald-500 w-4 h-4 cursor-pointer"
            />
            <span>Solo lo que me alcanza ({{ formatPerlitas(activeTeam.balance) }} perlitas)</span>
          </label>
        </div>

        <!-- Products Loading -->
        <div v-if="catalogLoading" class="py-16 text-center text-slate-400">
          <i class="bi bi-arrow-repeat text-2xl animate-spin inline-block mb-2 text-emerald-400"></i>
          <p class="text-xs">Cargando catálogo de premios...</p>
        </div>

        <!-- Empty Products State -->
        <div
          v-else-if="filteredProducts.length === 0"
          class="py-16 px-4 text-center rounded-3xl bg-slate-900/40 border border-slate-800"
        >
          <div class="w-14 h-14 mx-auto mb-3 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-500">
            <i class="bi bi-bag-x text-2xl"></i>
          </div>
          <h4 class="text-sm font-bold text-white mb-1">
            No se encontraron premios
          </h4>
          <p class="text-xs text-slate-400 max-w-sm mx-auto">
            {{ onlyAffordable ? 'No tienes suficientes perlitas de este equipo para los premios disponibles. Juega trivias para sumar más.' : 'Este equipo aún no ha publicado productos en esta categoría.' }}
          </p>
        </div>

        <!-- Products Grid -->
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <div
            v-for="product in filteredProducts"
            :key="product.id"
            class="rounded-3xl bg-gradient-to-b from-slate-900 to-slate-950 border border-slate-800 hover:border-emerald-500/50 transition-all duration-300 overflow-hidden flex flex-col justify-between group shadow-xl"
          >
            <div>
              <!-- Image Banner -->
              <div class="h-44 bg-slate-950 flex items-center justify-center p-4 relative overflow-hidden border-b border-slate-800/80">
                <img
                  v-if="product.images && product.images.length > 0"
                  :src="product.images[0]"
                  :alt="product.name"
                  class="w-full h-full object-contain group-hover:scale-105 transition-transform duration-300"
                />
                <div v-else class="w-16 h-16 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-600 text-3xl">
                  <i class="bi bi-gift-fill text-emerald-400/60"></i>
                </div>

                <!-- Stock / Badge -->
                <span
                  v-if="product.stock <= 0"
                  class="absolute top-3 right-3 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-rose-950/80 border border-rose-800 text-rose-300 shadow-md"
                >
                  Agotado
                </span>
                <span
                  v-else-if="product.stock <= 5"
                  class="absolute top-3 right-3 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-amber-950/80 border border-amber-800 text-amber-300 shadow-md"
                >
                  Últimos {{ product.stock }}
                </span>
              </div>

              <!-- Product Info -->
              <div class="p-5 space-y-2">
                <h3 class="text-base font-bold text-white group-hover:text-emerald-300 transition-colors line-clamp-1">
                  {{ product.name }}
                </h3>
                <p class="text-xs text-slate-400 line-clamp-2 leading-relaxed">
                  {{ product.description || 'Premio oficial canjeable con perlitas de ' + activeTeam.name + '.' }}
                </p>
              </div>
            </div>

            <!-- Footer Price & CTA -->
            <div class="p-5 pt-0 flex items-center justify-between border-t border-slate-800/80 mt-2">
              <div class="flex items-center gap-1.5 text-sm font-black text-amber-300">
                <PearlIcon size="xs" animated />
                <span>{{ formatPerlitas(product.cost_pearls) }}</span>
              </div>

              <NuxtLink
                :to="`/app/e/${activeTeam.slug}/tienda/${product.id}`"
                class="px-4 py-2 rounded-xl font-display font-bold uppercase tracking-wider text-xs transition-colors shadow-sm"
                :class="[
                  product.stock <= 0
                    ? 'bg-slate-800 text-slate-500 cursor-not-allowed pointer-events-none'
                    : 'bg-emerald-500 hover:bg-emerald-400 text-slate-950'
                ]"
              >
                Ver Detalle
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
