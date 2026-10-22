<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseBadge, PearlIcon } from '@guaiqui/ui'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import { useAnalytics } from '~/composables/useAnalytics'
import type { SponsorVideo } from '@guaiqui/shared'

import SponsorEmptyState from '~/components/app/anuncios/SponsorEmptyState.vue'
import SponsorVideoPlayer from '~/components/app/anuncios/SponsorVideoPlayer.vue'
import SponsorVideoList from '~/components/app/anuncios/SponsorVideoList.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const client = useSupabaseClient()
const user = useSupabaseUser()
const analytics = useAnalytics()

const loading = ref(true)
const claiming = ref(false)
const videos = ref<SponsorVideo[]>([])
const selectedVideo = ref<SponsorVideo | null>(null)
const todayClaims = ref<Array<{ source_id: string; amount: number }>>([])

const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const infoMessage = ref<string | null>(null)

const getCaracasTodayStr = () => {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Caracas' }).format(new Date())
}

const claimedVideoIds = computed(() => {
  const set = new Set<string>()
  for (const c of todayClaims.value) {
    if (c.source_id) {
      const parts = c.source_id.split(':')
      if (parts.length >= 3) {
        set.add(parts[2])
      }
    }
  }
  return set
})

const pointsEarnedToday = computed(() => {
  return todayClaims.value.reduce((acc, curr) => acc + (curr.amount || 0), 0)
})

const isCurrentVideoClaimedToday = computed(() => {
  if (!selectedVideo.value) return false
  return claimedVideoIds.value.has(selectedVideo.value.id)
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
      // Priorizar un video no reclamado hoy, o el primero de la lista
      const unclaimed = videos.value.find((v) => !claimedVideoIds.value.has(v.id))
      selectedVideo.value = unclaimed || videos.value[0]
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

const handleSelectVideo = (video: SponsorVideo) => {
  selectedVideo.value = video
  successMessage.value = null
  infoMessage.value = null
  analytics.trackEvent('sponsor_video_selected', { video_id: video.id, title: video.title })
}

const handleClaimPoints = async (videoId: string) => {
  if (claiming.value) return
  claiming.value = true
  errorMessage.value = null
  successMessage.value = null
  infoMessage.value = null

  try {
    const { data, error } = await client.rpc('claim_video_points', { p_video_id: videoId })
    if (error) throw error

    if (data?.success) {
      successMessage.value = `¡Felicidades! Se han agregado +${data.points_awarded} puntos a tu billetera.`
      analytics.trackEvent('sponsor_video_points_claimed', {
        video_id: videoId,
        points: data.points_awarded,
      })
      await loadClaims()
    } else if (data?.already_claimed) {
      infoMessage.value = data.message || 'Ya has reclamado los puntos de este video hoy.'
      await loadClaims()
    }
  } catch (err: any) {
    console.error('Error claiming video points:', err)
    errorMessage.value = err.message || 'Error al procesar el reclamo de puntos.'
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

    <!-- Feedback Banners -->
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

    <!-- Progreso y Resumen de Hoy -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex items-center justify-between">
        <div>
          <span class="text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted block">
            Videos Reclamados Hoy
          </span>
          <div class="flex items-baseline gap-1.5 mt-1">
            <span class="font-display font-black text-2xl text-guaiqui-primary">
              {{ claimedVideoIds.size }}
            </span>
            <span class="text-xs text-guaiqui-text-muted font-medium">
              / {{ videos.length }} disponibles
            </span>
          </div>
        </div>
        <div class="w-10 h-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center text-xl border border-emerald-100">
          <i class="bi bi-check2-all"></i>
        </div>
      </div>

      <div class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex items-center justify-between">
        <div>
          <span class="text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted block">
            Puntos Ganados Hoy
          </span>
          <div class="flex items-center gap-2 mt-1">
            <PearlIcon size="md" />
            <span class="font-display font-black text-2xl text-guaiqui-text">
              +{{ pointsEarnedToday }}
            </span>
            <span class="text-xs text-guaiqui-text-muted font-medium">puntos</span>
          </div>
        </div>
        <div class="w-10 h-10 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center text-xl border border-amber-100">
          <i class="bi bi-coin"></i>
        </div>
      </div>
    </div>

    <!-- Estado de Carga -->
    <div v-if="loading" class="p-16 text-center text-guaiqui-text-muted space-y-3">
      <i class="bi bi-arrow-repeat animate-spin text-3xl text-guaiqui-primary"></i>
      <p class="text-sm font-medium">Cargando videos de patrocinadores...</p>
    </div>

    <!-- Estado Vacío -->
    <SponsorEmptyState v-else-if="videos.length === 0" />

    <!-- Reproductor y Catálogo -->
    <div v-else class="space-y-8">
      <!-- Reproductor Principal del Video Seleccionado -->
      <SponsorVideoPlayer
        v-if="selectedVideo"
        :video="selectedVideo"
        :is-claimed-today="isCurrentVideoClaimedToday"
        :claiming="claiming"
        @claim="handleClaimPoints"
      />

      <!-- Selector / Lista de Videos si hay más de 1 -->
      <SponsorVideoList
        v-if="videos.length > 1 && selectedVideo"
        :videos="videos"
        :selected-video-id="selectedVideo.id"
        :claimed-video-ids="claimedVideoIds"
        @select="handleSelectVideo"
      />
    </div>
  </div>
</template>
