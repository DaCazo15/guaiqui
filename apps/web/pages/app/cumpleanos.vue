<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useAnalytics } from '~/composables/useAnalytics'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const supabase = useSupabaseClient()
const authStore = useAuthStore()
const { trackEvent } = useAnalytics()

const loading = ref(true)
const cardData = ref<{
  eligible: boolean
  display_name?: string
  title?: string
  message?: string
  image_url?: string | null
  bonus_pearls?: number
  has_claimed_bonus?: boolean
} | null>(null)

const claimLoading = ref(false)
const claimMessage = ref<string | null>(null)
const claimError = ref<string | null>(null)
const copySuccess = ref(false)

onMounted(async () => {
  try {
    const { data, error } = await supabase.rpc('get_birthday_card')
    if (error || !data || !data.eligible) {
      // Redirección silenciosa a /app si no es elegible
      return navigateTo('/app')
    }

    cardData.value = data
    trackEvent('birthday_card_viewed')
  } catch (err) {
    console.error('Error fetching birthday card:', err)
    navigateTo('/app')
  } finally {
    loading.value = false
  }
})

const formattedMessage = computed(() => {
  if (!cardData.value?.message) return ''
  // Convert basic markdown format (**bold**, \n\n paragraphs) safely
  const escaped = cardData.value.message
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
  
  const bolded = escaped.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
  return bolded.split('\n\n').map(p => `<p class="mb-3">${p.replace(/\n/g, '<br/>')}</p>`).join('')
})

async function handleClaimBonus() {
  if (claimLoading.value || !cardData.value || cardData.value.has_claimed_bonus) return
  claimLoading.value = true
  claimError.value = null
  claimMessage.value = null

  try {
    const { data, error } = await supabase.rpc('claim_birthday_bonus')
    if (error) throw error

    if (data?.success) {
      cardData.value.has_claimed_bonus = true
      claimMessage.value = `¡Felicidades! Has recibido ${cardData.value.bonus_pearls} perlitas de regalo por tu cumpleaños.`
      trackEvent('birthday_bonus_claimed')
      // Refresh wallet balance
      await authStore.fetchProfile()
    } else {
      throw new Error(data?.message || 'No se pudo reclamar el bono.')
    }
  } catch (err: any) {
    claimError.value = err.message || 'Error al reclamar el bono de cumpleaños.'
  } finally {
    claimLoading.value = false
  }
}

async function handleShare() {
  const shareData = {
    title: '¡Feliz Cumpleaños con los Guaiqueríes!',
    text: '¡Celebrando mi cumpleaños junto a la tribu de los Guaiqueríes de Margarita! 🏀',
    url: window.location.origin,
  }

  if (navigator.share) {
    try {
      await navigator.share(shareData)
    } catch {
      // Ignore user cancellation
    }
  } else {
    try {
      await navigator.clipboard.writeText(`${shareData.text} ${shareData.url}`)
      copySuccess.value = true
      setTimeout(() => { copySuccess.value = false }, 3000)
    } catch {
      console.warn('Could not copy to clipboard.')
    }
  }
}
</script>

<template>
  <div v-if="loading" class="min-h-[60vh] flex items-center justify-center p-6">
    <div class="flex items-center gap-3 text-guaiqui-primary">
      <i class="bi bi-arrow-repeat animate-spin text-2xl"></i>
      <span class="font-medium text-sm">Cargando felicitación...</span>
    </div>
  </div>

  <div v-else-if="cardData && cardData.eligible" class="max-w-2xl mx-auto space-y-6 pb-10">
    <!-- Birthday Header Banner -->
    <div class="relative overflow-hidden rounded-guaiqui-2xl bg-gradient-to-br from-emerald-950 via-emerald-900 to-slate-900 text-white shadow-guaiqui-lg border border-emerald-800/50">
      <!-- Confetti decorativo (SVG + animación CSS, deshabilitado si prefers-reduced-motion) -->
      <div aria-hidden="true" class="absolute inset-0 pointer-events-none overflow-hidden confetti-container">
        <div class="confetti-piece p1"></div>
        <div class="confetti-piece p2"></div>
        <div class="confetti-piece p3"></div>
        <div class="confetti-piece p4"></div>
        <div class="confetti-piece p5"></div>
        <div class="confetti-piece p6"></div>
      </div>

      <!-- Header Content -->
      <div class="relative z-10 p-6 md:p-8 text-center space-y-3">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-800/60 border border-emerald-400/30 text-amber-300 text-3xl shadow-md mb-1">
          <i class="bi bi-gift-fill"></i>
        </div>

        <h1 class="font-display text-3xl md:text-5xl font-bold uppercase tracking-wider text-white drop-shadow-md">
          ¡FELIZ CUMPLEAÑOS, <span class="text-amber-300">{{ cardData.display_name }}</span>!
        </h1>

        <p class="text-emerald-200 text-sm md:text-base font-medium tracking-wide">
          De parte de tus Guaiqueríes de Margarita
        </p>
      </div>

      <!-- Franja separadora tipo Bandana Roja -->
      <div class="h-2 w-full bg-gradient-to-r from-red-700 via-red-500 to-red-700"></div>
    </div>

    <!-- Main Card Body -->
    <BaseCard class="bg-white border-guaiqui-border p-6 md:p-8 rounded-guaiqui-xl space-y-6 shadow-guaiqui-md text-guaiqui-text">
      <!-- Media Image (Optional defined by admin) -->
      <div v-if="cardData.image_url" class="rounded-guaiqui-lg overflow-hidden border border-guaiqui-border bg-slate-950 max-h-72 flex items-center justify-center">
        <img
          :src="cardData.image_url"
          :alt="cardData.title || 'Felicitación de cumpleaños'"
          loading="lazy"
          class="w-full h-full object-cover"
        />
      </div>

      <!-- Card Title & Message -->
      <div class="space-y-4">
        <h2 class="text-xl md:text-2xl font-bold text-guaiqui-text flex items-center gap-2">
          <i class="bi bi-balloon-fill text-red-500"></i>
          <span>{{ cardData.title }}</span>
        </h2>

        <div
          class="text-sm md:text-base text-guaiqui-text leading-relaxed prose prose-emerald max-w-none"
          v-html="formattedMessage"
        ></div>
      </div>

      <!-- Feedback Live Region -->
      <div
        aria-live="polite"
        aria-atomic="true"
        class="space-y-2"
      >
        <div v-if="claimMessage" class="p-4 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-lg text-guaiqui-status-success text-sm flex items-center gap-3">
          <i class="bi bi-trophy-fill text-xl shrink-0"></i>
          <span class="font-medium">{{ claimMessage }}</span>
        </div>

        <div v-if="claimError" class="p-4 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-lg text-guaiqui-status-danger text-sm flex items-center gap-3">
          <i class="bi bi-exclamation-octagon-fill text-xl shrink-0"></i>
          <span>{{ claimError }}</span>
        </div>

        <div v-if="copySuccess" class="p-3 bg-emerald-50 border border-emerald-200 rounded-guaiqui-md text-emerald-800 text-xs flex items-center gap-2">
          <i class="bi bi-check-circle-fill text-emerald-600"></i>
          <span>¡Mensaje de felicitación copiado al portapapeles!</span>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="pt-4 border-t border-guaiqui-border flex flex-col sm:flex-row flex-wrap gap-3 items-center justify-between">
        <div class="flex flex-wrap gap-3 w-full sm:w-auto">
          <!-- Button: Claim Bonus (if pearls > 0) -->
          <BaseButton
            v-if="cardData.bonus_pearls && cardData.bonus_pearls > 0"
            variant="primary"
            size="md"
            :disabled="cardData.has_claimed_bonus"
            :loading="claimLoading"
            class="w-full sm:w-auto"
            @click="handleClaimBonus"
          >
            <i v-if="cardData.has_claimed_bonus" class="bi bi-check-circle-fill mr-2"></i>
            <i v-else class="bi bi-gift mr-2"></i>
            <span>{{ cardData.has_claimed_bonus ? 'Bono Reclamado' : 'Reclamar mis' }}</span>
            <PearlAmount
              v-if="!cardData.has_claimed_bonus"
              :amount="cardData.bonus_pearls"
              class="ml-2 font-bold"
            />
          </BaseButton>

          <!-- Button: Go to Trivias -->
          <NuxtLink to="/app/trivias" class="w-full sm:w-auto">
            <BaseButton variant="outline" size="md" class="w-full">
              <i class="bi bi-controller mr-2"></i>
              <span>Ir a mis trivias</span>
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Button: Share -->
        <BaseButton
          variant="secondary"
          size="md"
          class="w-full sm:w-auto"
          @click="handleShare"
        >
          <i class="bi bi-share-fill mr-2"></i>
          <span>Compartir</span>
        </BaseButton>
      </div>
    </BaseCard>
  </div>
</template>

<style scoped>
.confetti-container {
  mask-image: linear-gradient(to bottom, rgba(0,0,0,1), rgba(0,0,0,0));
}

.confetti-piece {
  position: absolute;
  top: -20px;
  width: 10px;
  height: 10px;
  background-color: #f59e0b;
  border-radius: 50%;
  opacity: 0.8;
  animation: fall 4s infinite linear;
}

.p1 { left: 10%; animation-delay: 0s; background-color: #10b981; }
.p2 { left: 25%; animation-delay: 1.2s; background-color: #f59e0b; width: 12px; height: 12px; }
.p3 { left: 45%; animation-delay: 0.6s; background-color: #ef4444; }
.p4 { left: 65%; animation-delay: 2s; background-color: #10b981; width: 8px; height: 8px; }
.p5 { left: 80%; animation-delay: 1.8s; background-color: #f59e0b; }
.p6 { left: 92%; animation-delay: 0.3s; background-color: #3b82f6; }

@keyframes fall {
  0% {
    transform: translateY(0) rotate(0deg);
    opacity: 0.9;
  }
  100% {
    transform: translateY(220px) rotate(360deg);
    opacity: 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  .confetti-piece {
    animation: none !important;
    display: none !important;
  }
}
</style>
