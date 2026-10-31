<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { useAnalytics } from '~/composables/useAnalytics'
import BirthdayCardItem, { type BirthdayGreetingCard } from '~/components/birthday/BirthdayCardItem.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const supabase = useSupabaseClient()
const authStore = useAuthStore()
const { trackEvent } = useAnalytics()

const loading = ref(true)
const displayName = ref('Fanático')
const cards = ref<BirthdayGreetingCard[]>([])

const claimingTeamId = ref<string | null>(null)
const claimMessage = ref<string | null>(null)
const claimError = ref<string | null>(null)
const copySuccess = ref(false)

onMounted(async () => {
  try {
    const { data, error } = await (supabase.rpc as any)('get_birthday_card')
    const bday = data as any
    if (error || !bday || !bday.eligible) {
      return navigateTo('/app')
    }

    displayName.value = bday.display_name || authStore.profile?.display_name || 'Fanático'

    if (Array.isArray(bday.cards) && bday.cards.length > 0) {
      cards.value = bday.cards
    } else if (bday.eligible) {
      cards.value = [{
        team_id: bday.team_id || 'a0000000-0000-0000-0000-000000000001',
        team_name: bday.team_name || 'Guaiqueríes de Margarita',
        team_slug: bday.team_slug || 'guaiqueries',
        team_logo: bday.team_logo || '/logo.png',
        title: bday.title || '¡Feliz Cumpleaños!',
        message: bday.message || '',
        image_url: bday.image_url || null,
        bonus_pearls: bday.bonus_pearls || 0,
        claimed: bday.claimed || false,
        display_name: displayName.value,
      }]
    }

    trackEvent('birthday_card_viewed')
  } catch (err) {
    console.error('Error fetching birthday card:', err)
    navigateTo('/app')
  } finally {
    loading.value = false
  }
})

async function handleClaimBonus(teamId: string) {
  if (claimingTeamId.value) return
  claimingTeamId.value = teamId
  claimError.value = null
  claimMessage.value = null

  try {
    const { data, error } = await (supabase.rpc as any)('claim_birthday_bonus', {
      p_team_id: teamId,
    })
    if (error) throw error

    const claimRes = data as any
    if (claimRes?.success) {
      const targetCard = cards.value.find(c => c.team_id === teamId)
      if (targetCard) {
        targetCard.claimed = true
        claimMessage.value = `¡Felicidades! Has recibido ${targetCard.bonus_pearls} perlitas de regalo en ${targetCard.team_name}.`
      }
      trackEvent('birthday_bonus_claimed')
      await authStore.fetchProfile()
    } else {
      throw new Error(claimRes?.message || 'No se pudo reclamar el bono.')
    }
  } catch (err: any) {
    claimError.value = err.message || 'Error al reclamar el bono de cumpleaños.'
  } finally {
    claimingTeamId.value = null
  }
}

async function handleShare(card: BirthdayGreetingCard) {
  const shareData = {
    title: `¡Feliz Cumpleaños con ${card.team_name}!`,
    text: `¡Celebrando mi cumpleaños junto a ${card.team_name}!`,
    url: window.location.origin,
  }

  if (navigator.share) {
    try {
      await navigator.share(shareData)
    } catch {
      // Ignorar cancelación del usuario
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

  <div v-else-if="cards.length > 0" class="max-w-2xl mx-auto space-y-6 pb-10">
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
          ¡FELIZ CUMPLEAÑOS, <span class="text-amber-300">{{ displayName }}</span>!
        </h1>

        <p class="text-emerald-200 text-sm md:text-base font-medium tracking-wide">
          Tus equipos favoritos celebran contigo este gran día
        </p>
      </div>

      <!-- Franja separadora tipo Bandana Roja -->
      <div class="h-2 w-full bg-gradient-to-r from-red-700 via-red-500 to-red-700"></div>
    </div>

    <!-- Feedback Alerts -->
    <div v-if="claimMessage || claimError || copySuccess" class="space-y-2">
      <div v-if="claimMessage" class="p-4 bg-emerald-50 border border-emerald-200 rounded-guaiqui-lg text-emerald-800 text-sm flex items-center gap-3">
        <i class="bi bi-trophy-fill text-xl shrink-0 text-emerald-600"></i>
        <span class="font-medium">{{ claimMessage }}</span>
      </div>

      <div v-if="claimError" class="p-4 bg-red-50 border border-red-200 rounded-guaiqui-lg text-red-800 text-sm flex items-center gap-3">
        <i class="bi bi-exclamation-octagon-fill text-xl shrink-0 text-red-600"></i>
        <span>{{ claimError }}</span>
      </div>

      <div v-if="copySuccess" class="p-3 bg-emerald-50 border border-emerald-200 rounded-guaiqui-md text-emerald-800 text-xs flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-600"></i>
        <span>¡Mensaje copiado al portapapeles!</span>
      </div>
    </div>

    <!-- Cards List: One card per greeting team -->
    <div class="space-y-6">
      <BirthdayCardItem
        v-for="card in cards"
        :key="card.team_id"
        :card="card"
        :claim-loading="claimingTeamId === card.team_id"
        @claim="handleClaimBonus"
        @share="handleShare"
      />
    </div>
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
