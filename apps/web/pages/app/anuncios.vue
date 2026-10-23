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
const todayClaims = ref<Array<{ source_id: string; amount: number }>>([])

const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const infoMessage = ref<string | null>(null)

const getCaracasTodayStr = () => {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Caracas' }).format(new Date())
}

const completedToday = computed(() => {
  return todayClaims.value.length
})

const pointsEarnedToday = computed(() => {
  return todayClaims.value.reduce((acc, curr) => acc + (curr.amount || 0), 0)
})

const currentTierReward = computed(() => {
  if (completedToday.value < 10) return 5
  if (completedToday.value < 20) return 10
  return 15
})

const loadClaims = async () => {
  if (!user.value?.id) return
  try {
    const todayStr = getCaracasTodayStr()
    const { data, error } = await client
      .from('ledger_entries')
      .select('source_id, amount')
      .eq('fan_id', user.value.id)
      .eq('source_type', 'sponsor_video')
      .gte('created_at', `${todayStr}T00:00:00-04:00`)

    if (error) throw error
    todayClaims.value = (data as any) || []
  } catch (err: any) {
    console.warn('Error loading today claims:', err)
  }
}

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

    await loadClaims()

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

    if (data?.success) {
      successMessage.value = `¡Video completado! Has sumado +${data.points_awarded} puntos por tu video #${data.completed_today} de hoy.`
      analytics.trackEvent('sponsor_video_points_claimed', {
        video_id: videoId,
        points: data.points_awarded,
        completed_today: data.completed_today,
      })
      await loadClaims()
    } else if (data?.already_claimed) {
      infoMessage.value = data.message || 'Ya has validado este video hoy.'
      await loadClaims()
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
