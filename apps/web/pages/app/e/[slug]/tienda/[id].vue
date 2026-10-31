<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSeoMeta, useSupabaseClient } from '#imports'
import { BaseCard, BaseBadge, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatPerlitas } from '@guaiqui/shared'
import { useCatalog, type Product } from '~/composables/useCatalog'
import { useWallet } from '~/composables/useWallet'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import StoreRedeemModal from '~/components/store/StoreRedeemModal.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const productId = route.params.id as string
const teamSlugParam = computed(() => route.params.slug as string)

const { currentProduct, loading: productLoading, fetchProductById } = useCatalog()
const { summary, fetchSummary } = useWallet()
const { activeTeam, loadTeamBySlug } = useCurrentTeam()

const selectedVariant = ref<string>('')
const isRedeemModalOpen = ref(false)

const productVariants = computed(() => {
  if (!currentProduct.value) return []
  const v = currentProduct.value.variants
  if (Array.isArray(v)) return v
  if (typeof v === 'object' && v !== null) return Object.values(v)
  return ['Única']
})

const teamInfo = computed(() => {
  return currentProduct.value?.team || activeTeam.value || null
})

const teamName = computed(() => {
  return teamInfo.value?.name || 'Equipo'
})

const teamBalance = computed(() => {
  if (!currentProduct.value) return 0
  const teamId = currentProduct.value.team_id || teamInfo.value?.id
  if (!teamId) return 0
  const t = summary.value.teams.find((team) => team.team_id === teamId)
  return t ? t.balance : 0
})

const totalUnifiedBalance = computed(() => {
  return summary.value.balance || 0
})

const isAffordableInTeam = computed(() => {
  if (!currentProduct.value) return false
  return teamBalance.value >= currentProduct.value.cost_pearls
})

const wouldBeAffordableTotal = computed(() => {
  if (!currentProduct.value) return false
  return totalUnifiedBalance.value >= currentProduct.value.cost_pearls
})

// Explanatory condition: total balance would suffice, but team balance does not
const showCrossTeamBalanceWarning = computed(() => {
  return !isAffordableInTeam.value && wouldBeAffordableTotal.value
})

const missingPearlsInTeam = computed(() => {
  if (!currentProduct.value) return 0
  return Math.max(0, currentProduct.value.cost_pearls - teamBalance.value)
})

const isOutOfStock = computed(() => {
  if (!currentProduct.value) return true
  return currentProduct.value.stock <= 0
})

const isTeamInactive = computed(() => {
  return teamInfo.value?.status === 'inactive'
})

const getCategoryLabel = (category: string) => {
  switch (category) {
    case 'physical':
      return 'Indumentaria & Souvenirs'
    case 'experience':
      return 'Experiencia VIP'
    case 'raffle':
      return 'Sorteo Exclusivo'
    default:
      return category
  }
}

const handleRedeemed = (redemptionId: string) => {
  isRedeemModalOpen.value = false
  router.push(`/app/canjes/${redemptionId}`)
}

onMounted(async () => {
  await Promise.all([
    fetchProductById(productId),
    fetchSummary(),
    loadTeamBySlug(teamSlugParam.value),
  ])
  if (productVariants.value.length > 0) {
    selectedVariant.value = productVariants.value[0]
  }
})

useSeoMeta({
  title: computed(() =>
    currentProduct.value
      ? `${currentProduct.value.name} — Canje ${teamName.value}`
      : 'Detalle de Premio'
  ),
})

const backUrl = computed(() => {
  const slug = teamInfo.value?.slug || teamSlugParam.value || 'guaiqueries'
  return `/app/e/${slug}/tienda`
})
</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <!-- Breadcrumb / Back Link -->
    <NuxtLink
      :to="backUrl"
      class="inline-flex items-center text-xs font-semibold text-slate-400 hover:text-emerald-400 transition-colors"
    >
      <i class="bi bi-arrow-left mr-1.5"></i>
      Volver a la Tienda de {{ teamInfo?.short_name || teamName }}
    </NuxtLink>

    <!-- Inactive Team Warning -->
    <div
      v-if="isTeamInactive"
      class="p-4 rounded-2xl bg-amber-950/40 border-2 border-amber-500/50 text-amber-200 flex items-start gap-3 shadow-lg"
    >
      <i class="bi bi-exclamation-triangle-fill text-xl text-amber-400 shrink-0 mt-0.5"></i>
      <div>
        <h4 class="text-sm font-bold text-white uppercase tracking-wider">
          Canjes deshabilitados para este equipo
        </h4>
        <p class="text-xs text-amber-200/90 mt-0.5 leading-relaxed">
          <strong>{{ teamName }}</strong> se encuentra inactivo. Los canjes no están disponibles en este momento. Tu saldo acumulado se encuentra preservado de forma segura.
        </p>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="productLoading" class="py-20 text-center text-slate-400 space-y-3">
      <div class="inline-block animate-spin text-3xl text-emerald-400">
        <i class="bi bi-arrow-repeat"></i>
      </div>
      <p class="text-sm font-medium">Cargando detalles del premio...</p>
    </div>

    <!-- Product Not Found -->
    <div v-else-if="!currentProduct" class="py-20 text-center space-y-4">
      <div class="w-16 h-16 rounded-full bg-slate-900 text-slate-500 flex items-center justify-center text-3xl mx-auto border border-slate-800">
        <i class="bi bi-exclamation-circle"></i>
      </div>
      <h2 class="font-display font-bold text-2xl text-white uppercase">
        Producto no encontrado
      </h2>
      <NuxtLink :to="backUrl">
        <BaseButton variant="primary" size="sm">Regresar a la Tienda</BaseButton>
      </NuxtLink>
    </div>

    <!-- Product Detail Layout -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-12 gap-8">
      <!-- Image / Visual Section -->
      <div class="lg:col-span-6">
        <BaseCard class="p-0 overflow-hidden border-slate-800 rounded-3xl shadow-2xl sticky top-6 bg-slate-900">
          <div class="w-full h-80 sm:h-96 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 flex items-center justify-center p-8 relative overflow-hidden">
            <BaseBadge variant="perlita" size="md" class="absolute top-4 left-4 shadow-sm z-10">
              {{ getCategoryLabel(currentProduct.category) }}
            </BaseBadge>

            <!-- Stock Status -->
            <span v-if="isOutOfStock" class="absolute top-4 right-4 z-10">
              <BaseBadge variant="danger" size="md">Agotado</BaseBadge>
            </span>
            <span v-else-if="currentProduct.stock <= 5" class="absolute top-4 right-4 z-10">
              <BaseBadge variant="accent" size="md">¡Últimas {{ currentProduct.stock }} disponibles!</BaseBadge>
            </span>

            <img
              v-if="currentProduct.images && currentProduct.images.length > 0"
              :src="currentProduct.images[0]"
              :alt="currentProduct.name"
              class="max-w-full max-h-full object-contain"
            />
            <div v-else class="w-28 h-28 rounded-3xl bg-slate-900 border border-slate-800 flex items-center justify-center text-emerald-400 text-5xl font-bold shadow-xl">
              <i class="bi bi-gift-fill"></i>
            </div>
          </div>
        </BaseCard>
      </div>

      <!-- Information & Action Section -->
      <div class="lg:col-span-6 space-y-6">
        <div class="space-y-2">
          <!-- Team Header Badge -->
          <div class="flex items-center gap-2">
            <div v-if="teamInfo?.logo_url" class="w-6 h-6 rounded-lg bg-slate-950 p-0.5 border border-slate-800 shrink-0">
              <img :src="teamInfo.logo_url" :alt="teamName" class="w-full h-full object-contain" />
            </div>
            <span class="text-xs uppercase tracking-widest text-emerald-400 font-bold">
              Premio Oficial {{ teamName }}
            </span>
          </div>

          <h1 class="font-display font-black text-3xl sm:text-4xl text-white uppercase tracking-wider leading-tight">
            {{ currentProduct.name }}
          </h1>
          <p class="text-sm text-slate-300 leading-relaxed">
            {{ currentProduct.description || 'Premio oficial disponible para canje en ' + teamName + '.' }}
          </p>
        </div>

        <!-- Costo & Comparativa de Saldo por Equipo -->
        <BaseCard class="p-5 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-slate-400 tracking-wider">Costo de Canje</span>
            <PearlAmount :amount="currentProduct.cost_pearls" size="xl" show-label />
          </div>

          <div class="pt-3 border-t border-slate-800 space-y-2 text-xs">
            <div class="flex justify-between text-slate-300">
              <span>Tu saldo en <strong>{{ teamName }}</strong>:</span>
              <strong class="text-amber-300 font-bold">{{ formatPerlitas(teamBalance) }} perlitas</strong>
            </div>

            <div v-if="!isAffordableInTeam" class="flex justify-between text-rose-400 font-semibold">
              <span>Te faltan en este equipo:</span>
              <span>{{ formatPerlitas(missingPearlsInTeam) }} perlitas</span>
            </div>
            <div v-else class="flex justify-between text-emerald-400 font-semibold">
              <span>Saldo restante estimado en {{ teamName }}:</span>
              <span>{{ formatPerlitas(teamBalance - currentProduct.cost_pearls) }} perlitas</span>
            </div>
          </div>
        </BaseCard>

        <!-- Explanatory Warning if total unified would suffice but team balance does not -->
        <div
          v-if="showCrossTeamBalanceWarning"
          class="p-4 rounded-2xl bg-amber-950/40 border border-amber-500/50 text-amber-200 text-xs leading-relaxed space-y-1.5"
        >
          <div class="flex items-center gap-1.5 font-bold text-amber-300 uppercase tracking-wide">
            <i class="bi bi-info-circle-fill text-sm"></i>
            <span>Saldo total vs. saldo por equipo</span>
          </div>
          <p>
            Tu saldo acumulado entre todos tus equipos (<strong>{{ formatPerlitas(totalUnifiedBalance) }} perlitas</strong>) alcanzaría para este premio, pero en <strong>{{ teamName }}</strong> dispones de <strong>{{ formatPerlitas(teamBalance) }} perlitas</strong>.
          </p>
          <p class="text-slate-400">
            Las perlitas de cada equipo son independientes y no transferibles. Juega las trivias de {{ teamName }} para sumar las {{ formatPerlitas(missingPearlsInTeam) }} perlitas restantes.
          </p>
        </div>

        <!-- Selector de Variantes (Tallas) -->
        <div v-if="productVariants.length > 1 || (productVariants.length === 1 && productVariants[0] !== 'Única')" class="space-y-2">
          <label class="text-xs font-bold uppercase tracking-wider text-slate-300 block">
            Selecciona Variante / Talla
          </label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="v in productVariants"
              :key="v"
              type="button"
              @click="selectedVariant = v"
              class="px-4 py-2 rounded-xl text-xs font-bold transition-all duration-200 uppercase cursor-pointer"
              :class="[
                selectedVariant === v
                  ? 'bg-emerald-500 text-slate-950 font-black shadow-md'
                  : 'bg-slate-900 border border-slate-700 text-slate-300 hover:border-slate-500'
              ]"
            >
              {{ v }}
            </button>
          </div>
        </div>

        <!-- Botón de Canje Principal -->
        <div class="pt-2">
          <BaseButton
            v-if="isTeamInactive"
            variant="secondary"
            block
            size="lg"
            disabled
          >
            <i class="bi bi-lock-fill mr-1.5"></i>
            Equipo Inactivo — Canjes Deshabilitados
          </BaseButton>

          <BaseButton
            v-else-if="isOutOfStock"
            variant="secondary"
            block
            size="lg"
            disabled
          >
            <i class="bi bi-x-circle mr-1.5"></i>
            Producto Agotado
          </BaseButton>

          <BaseButton
            v-else-if="!isAffordableInTeam"
            variant="secondary"
            block
            size="lg"
            disabled
          >
            <i class="bi bi-lock-fill mr-1.5"></i>
            Perlitas Insuficientes en {{ teamInfo?.short_name || teamName }}
          </BaseButton>

          <BaseButton
            v-else
            variant="primary"
            block
            size="lg"
            @click="isRedeemModalOpen = true"
          >
            <i class="bi bi-bag-check-fill mr-1.5"></i>
            Canjear Premio Ahora
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Modal de Confirmación de Canje -->
    <StoreRedeemModal
      :is-open="isRedeemModalOpen"
      :product="currentProduct"
      :variant="selectedVariant"
      :user-balance="teamBalance"
      @close="isRedeemModalOpen = false"
      @redeemed="handleRedeemed"
    />
  </div>
</template>
