<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseBadge } from '@guaiqui/ui'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import { useAnalytics } from '~/composables/useAnalytics'
import type { SponsorVideo } from '@guaiqui/shared'

import SponsorEmptyState from '~/components/app/anuncios/SponsorEmptyState.vue'
import SponsorExplainCard from '~/components/app/anuncios/SponsorExplainCard.vue'
import SponsorDailySummary from '~/components/app/anuncios/SponsorDailySummary.vue'
import SponsorVideoModal from '~/components/app/anuncios/SponsorVideoModal.vue'
import SponsorVideoList from '~/components/app/anuncios/SponsorVideoList.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const client = useSupabaseClient()
const user = useSupabaseUser()
const analytics = useAnalytics()

const MAX_DAILY_VIDEOS = 50

const loading = ref(true)
const claiming = ref(false)
const videos = ref<SponsorVideo[]>([])
const selectedVideo = ref<SponsorVideo | null>(null)
const isModalOpen = ref(false)

const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const infoMessage = ref<string | null>(null)

const getCaracasTodayStr = () => {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Caracas' }).format(new Date())
}

const completedToday = ref(0)
const pointsEarnedToday = ref(0)
const currentTierReward = ref(5)
const blockProgress = ref(0)
const videosUntilNextBlock = ref(10)

const loadDailyProgress = async () => {
  try {
    const { data, error } = await client.rpc('get_daily_video_progress')
    if (error) {
      if (user.value?.id) {
        const todayStr = getCaracasTodayStr()
        const { data: fallbackData } = await client
          .from('ledger_entries')
          .select('source_id, amount')
          .eq('fan_id', user.value.id)
          .in('source_type', ['sponsor_video_block', 'sponsor_video'])
          .gte('created_at', `${todayStr}T00:00:00-04:00`)
        if (fallbackData) {
          pointsEarnedToday.value = fallbackData.reduce((acc, curr: any) => acc + (curr.amount || 0), 0)
        }
      }
      return
    }

    const progressData = data as any
    if (progressData) {
      completedToday.value = Number(progressData.completed_today) || 0
      pointsEarnedToday.value = Number(progressData.points_earned_today) || 0
      currentTierReward.value = Number(progressData.current_tier_reward) || 5
      blockProgress.value = Number(progressData.block_progress) || (completedToday.value % 10)
      videosUntilNextBlock.value = Number(progressData.videos_until_next_block) || (completedToday.value >= 50 ? 0 : 10 - (completedToday.value % 10))
    }
  } catch (err: any) {
    console.warn('Error loading daily video progress:', err)
  }
}

watch(
  () => user.value?.id,
  (newId) => {
    if (newId) {
      loadDailyProgress()
    }
  },
  { immediate: true }
)

const loadVideos = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await client
      .from('sponsor_videos')
      .select('*')
      .eq('is_active', true)
      .order('order_index', { ascending: true })
      .order('created_at', { ascending: false })

    if (error) throw error
    videos.value = (data as SponsorVideo[]) || []

    if (videos.value.length > 0) {
      selectedVideo.value = videos.value[0]
    } else {
      selectedVideo.value = null
    }
  } catch (err: any) {
    console.error('Error loading sponsor videos:', err)
    errorMessage.value = err.message || 'Error al cargar los videos de patrocinadores.'
  } finally {
    loading.value = false
  }
}

// Abrir modal con video seleccionado de forma aleatoria
const handleOpenRandomVideo = () => {
  if (videos.value.length === 0) return
  if (completedToday.value >= MAX_DAILY_VIDEOS) {
    infoMessage.value = 'Has alcanzado el límite diario de 50 videos. ¡Vuelve mañana para seguir acumulando!'
    return
  }

  const randomIndex = Math.floor(Math.random() * videos.value.length)
  selectedVideo.value = videos.value[randomIndex]
  isModalOpen.value = true

  analytics.trackEvent('sponsor_video_opened_random', {
    video_id: selectedVideo.value.id,
    title: selectedVideo.value.title,
    tier_reward: currentTierReward.value,
  })
}

// Abrir modal seleccionando un video puntual de la lista
const handleSelectVideo = (video: SponsorVideo) => {
  selectedVideo.value = video
  isModalOpen.value = true
  analytics.trackEvent('sponsor_video_selected', { video_id: video.id, title: video.title })
}

// Auto-validar y registrar puntos en servidor al completar el tiempo del video
const handleVideoCompleted = async (videoId: string) => {
  if (claiming.value) return
  claiming.value = true
  errorMessage.value = null
  infoMessage.value = null

  try {
    const { data, error } = await client.rpc('claim_video_points', { p_video_id: videoId })
    if (error) throw error

    const claimRes = data as any
    if (claimRes?.success) {
      if (claimRes?.block_completed) {
        successMessage.value = `¡Bloque #${claimRes.block_number} completado! Has terminado 10 videos y sumado +${claimRes.points_awarded} puntos a tu billetera.`
        analytics.trackEvent('sponsor_video_block_completed', {
          video_id: videoId,
          block_number: claimRes.block_number,
          points: claimRes.points_awarded,
          completed_today: claimRes.completed_today,
        })
      } 
      await loadDailyProgress()
    } else if (claimRes?.already_claimed) {
      infoMessage.value = claimRes.message || 'Ya has validado este video hoy.'
      await loadDailyProgress()
    }
  } catch (err: any) {
    console.error('Error auto-crediting video points:', err)
    errorMessage.value = err.message || 'Error al validar el video.'
  } finally {
    claiming.value = false
  }
}

onMounted(() => {
  loadVideos()
})

useSeoMeta({
  title: 'Videos de Patrocinadores — Guaiqueríes de Margarita',
  description: 'Mira los videos comerciales de las marcas aliadas a la Tribu Verde y gana puntos para la tienda de canjes.',
})
</script>

<template>
  <div class="space-y-8 max-w-5xl mx-auto">
    <!-- Header Principal -->
    <div class="space-y-2">
      <div class="flex items-center gap-2">
        <BaseBadge variant="success" size="md">
          <i class="bi bi-camera-reels-fill mr-1"></i> Patrocinadores Oficiales
        </BaseBadge>
      </div>
      <h1 class="font-display text-2xl md:text-4xl font-bold text-guaiqui-text uppercase tracking-wider">
        Gana <span class="text-guaiqui-primary">Puntos</span> con Marcas Aliadas
      </h1>
      <p class="text-xs md:text-sm text-guaiqui-text-muted leading-relaxed max-w-2xl">
        Mira los videos publicitarios de nuestros aliados comerciales, apoya a la Tribu Verde y acumula puntos para canjear en la tienda oficial.
      </p>
    </div>

    <!-- Mensajes de Feedback -->
    <div
      v-if="errorMessage"
      class="p-4 bg-red-50 border border-red-200 rounded-guaiqui-xl text-red-700 text-sm flex items-start gap-3 shadow-xs"
    >
      <i class="bi bi-exclamation-triangle-fill text-red-500 text-lg shrink-0 mt-0.5"></i>
      <div class="flex-1">
        <p class="font-semibold">{{ errorMessage }}</p>
      </div>
      <button class="text-red-400 hover:text-red-700 cursor-pointer" @click="errorMessage = null">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <div
      v-if="successMessage"
      class="p-4 bg-emerald-50 border border-emerald-300 rounded-guaiqui-xl text-emerald-900 text-sm flex items-center justify-between shadow-xs"
    >
      <div class="flex items-center gap-2.5">
        <i class="bi bi-check-circle-fill text-emerald-600 text-xl"></i>
        <span class="font-bold">{{ successMessage }}</span>
      </div>
      <button class="text-emerald-500 hover:text-emerald-800 cursor-pointer text-xs underline" @click="successMessage = null">
        Cerrar
      </button>
    </div>

    <div
      v-if="infoMessage"
      class="p-4 bg-blue-50 border border-blue-200 rounded-guaiqui-xl text-blue-800 text-sm flex items-center justify-between shadow-xs"
    >
      <div class="flex items-center gap-2.5">
        <i class="bi bi-info-circle-fill text-blue-600 text-lg"></i>
        <span>{{ infoMessage }}</span>
      </div>
      <button class="text-blue-400 hover:text-blue-700 cursor-pointer text-xs underline" @click="infoMessage = null">
        Cerrar
      </button>
    </div>

    <!-- 1. Tarjeta Explicativa: Cómo funciona, tramos y reglas -->
    <SponsorExplainCard
      :completed-today="completedToday"
      :max-daily="MAX_DAILY_VIDEOS"
      :current-tier-reward="currentTierReward"
    />

    <!-- 2. Resumen Diario con Métricas y Botón "Ver Video" -->
    <SponsorDailySummary
      :completed-today="completedToday"
      :points-earned-today="pointsEarnedToday"
      :active-videos-count="videos.length"
      :max-daily="MAX_DAILY_VIDEOS"
      :current-tier-reward="currentTierReward"
      :block-progress="blockProgress"
      :videos-until-next-block="videosUntilNextBlock"
      :loading="loading"
      @watch="handleOpenRandomVideo"
    />

    <!-- 3. Modal de Video Guaiqueríes (con temporizador, barra verde, dot bandana y acciones) -->
    <SponsorVideoModal
      v-model="isModalOpen"
      :video="selectedVideo"
      @completed="handleVideoCompleted"
    />
  </div>
</template>
