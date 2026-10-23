<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue'
import { BaseCard, BaseButton, BaseBadge, PearlIcon } from '@guaiqui/ui'
import { getGoogleDriveEmbedUrl, type SponsorVideo } from '@guaiqui/shared'

const props = defineProps<{
  video: SponsorVideo
  isClaimedToday: boolean
  claiming: boolean
}>()

const emit = defineEmits<{
  (e: 'claim', videoId: string): void
}>()

const embedUrl = computed(() => {
  return getGoogleDriveEmbedUrl(props.video.video_url)
})

// Timer state
const timerRunning = ref(false)
const elapsedSeconds = ref(0)
let intervalId: any = null

const requiredSeconds = computed(() => {
  return Math.max(1, props.video.min_seconds || 15)
})

const remainingSeconds = computed(() => {
  return Math.max(0, requiredSeconds.value - elapsedSeconds.value)
})

const progressPercentage = computed(() => {
  return Math.min(100, Math.round((elapsedSeconds.value / requiredSeconds.value) * 100))
})

const isUnlocked = computed(() => {
  return elapsedSeconds.value >= requiredSeconds.value
})

const startTimer = () => {
  if (timerRunning.value || props.isClaimedToday || isUnlocked.value) return
  timerRunning.value = true
  if (intervalId) clearInterval(intervalId)

  intervalId = setInterval(() => {
    if (elapsedSeconds.value < requiredSeconds.value) {
      elapsedSeconds.value++
    } else {
      timerRunning.value = false
      if (intervalId) {
        clearInterval(intervalId)
        intervalId = null
      }
    }
  }, 1000)
}

const pauseTimer = () => {
  timerRunning.value = false
  if (intervalId) {
    clearInterval(intervalId)
    intervalId = null
  }
}

// Reset when active video changes
watch(
  () => props.video.id,
  () => {
    pauseTimer()
    elapsedSeconds.value = 0
    if (!props.isClaimedToday) {
      startTimer()
    }
  },
  { immediate: true }
)

watch(
  () => props.isClaimedToday,
  (claimed) => {
    if (claimed) {
      pauseTimer()
    }
  }
)

onUnmounted(() => {
  pauseTimer()
})

const handleClaim = () => {
  emit('claim', props.video.id)
}
</script>

<template>
  <BaseCard class="p-4 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-md space-y-6">
    <!-- Header del Video Activo -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-guaiqui-border pb-4">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span
            v-if="video.sponsor_name"
            class="text-[10px] font-extrabold uppercase tracking-wider text-guaiqui-primary bg-guaiqui-primary-soft px-2.5 py-0.5 rounded-full border border-guaiqui-primary/30 font-mono"
          >
            {{ video.sponsor_name }}
          </span>
          <BaseBadge v-if="isClaimedToday" variant="success" size="sm">
            <i class="bi bi-check-circle-fill mr-1"></i> Reclamado hoy
          </BaseBadge>
          <BaseBadge v-else variant="info" size="sm">
            <i class="bi bi-coin mr-1 text-amber-500"></i> +{{ video.reward_points }} Puntos
          </BaseBadge>
        </div>
        <h2 class="font-display font-extrabold text-xl sm:text-2xl text-guaiqui-text uppercase tracking-wide">
          {{ video.title }}
        </h2>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-xs text-guaiqui-text-muted font-medium flex items-center gap-1">
          <i class="bi bi-stopwatch text-guaiqui-primary"></i>
          {{ video.min_seconds }} segundos
        </span>
      </div>
    </div>

    <!-- Contenedor del Reproductor Google Drive -->
    <div class="relative w-full aspect-video rounded-guaiqui-xl overflow-hidden border border-guaiqui-border bg-black shadow-inner">
      <iframe
        v-if="embedUrl"
        :src="embedUrl"
        class="w-full h-full border-0"
        allow="autoplay; encrypted-media"
        allowfullscreen
        title="Video Patrocinador"
      ></iframe>
      <div v-else class="w-full h-full flex items-center justify-center text-slate-400 text-xs">
        No se pudo cargar el reproductor de Google Drive
      </div>
    </div>

    <!-- Barra de Tiempo y Desbloqueo de Recompensa -->
    <div class="p-4 rounded-guaiqui-xl border transition-all" :class="[
      isClaimedToday
        ? 'bg-slate-50 border-slate-200'
        : isUnlocked
          ? 'bg-emerald-50 border-emerald-300 ring-2 ring-emerald-500/20'
          : 'bg-guaiqui-surface border-guaiqui-border'
    ]">
      <!-- Estado: Ya reclamado hoy -->
      <div v-if="isClaimedToday" class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
        <div class="flex items-center gap-2 text-emerald-800 font-bold">
          <i class="bi bi-check2-circle text-lg text-emerald-600"></i>
          <span>¡Ya ganaste los puntos de este video hoy! Vuelve mañana para reclamar de nuevo.</span>
        </div>
        <div class="flex items-center gap-1.5 font-bold text-emerald-700 font-mono">
          <PearlIcon size="sm" />
          <span>+{{ video.reward_points }} Puntos acreditados</span>
        </div>
      </div>

      <!-- Estado: En progreso / Desbloqueado -->
      <div v-else class="space-y-3">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-guaiqui-text flex items-center gap-1.5">
            <i class="bi bi-clock-history text-guaiqui-primary"></i>
            {{ isUnlocked ? '¡Recompensa desbloqueada!' : `Viendo video (${elapsedSeconds}s / ${requiredSeconds}s)` }}
          </span>

          <span v-if="!isUnlocked" class="font-mono font-bold text-guaiqui-primary">
            Faltan {{ remainingSeconds }}s
          </span>
          <span v-else class="font-bold text-emerald-700 flex items-center gap-1">
            <PearlIcon size="sm" />
            +{{ video.reward_points }} Puntos listos
          </span>
        </div>

        <!-- Barra de progreso -->
        <div class="w-full h-2.5 bg-gray-200 rounded-full overflow-hidden">
          <div
            class="h-full bg-guaiqui-primary bg-gradient-to-r from-guaiqui-primary to-emerald-400 transition-all duration-300 rounded-full"
            :style="{ width: `${progressPercentage}%` }"
          ></div>
        </div>

        <!-- Botones de Acción / Reclamo -->
        <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-1">
          <div class="text-[11px] text-guaiqui-text-muted">
            <span v-if="!isUnlocked">
              Permanece en la página al menos <strong>{{ requiredSeconds }} segundos</strong> para habilitar el reclamo de puntos.
            </span>
            <span v-else class="text-emerald-800 font-semibold">
              ¡Excelente! Haz clic en el botón para transferir los puntos a tu billetera.
            </span>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <BaseButton
              v-if="!isUnlocked && !timerRunning"
              variant="secondary"
              size="sm"
              @click="startTimer"
            >
              <i class="bi bi-play-fill mr-1"></i> Continuar Tiempo
            </BaseButton>

            <BaseButton
              variant="primary"
              size="md"
              :disabled="!isUnlocked || claiming"
              :loading="claiming"
              class="w-full sm:w-auto font-bold uppercase tracking-wider text-xs px-6"
              @click="handleClaim"
            >
              <i class="bi bi-coin mr-1.5 text-amber-300"></i>
              {{ claiming ? 'Reclamando...' : `Reclamar +${video.reward_points} Puntos` }}
            </BaseButton>
          </div>
        </div>
      </div>
    </div>

    <!-- Sección de Redirección del Patrocinador (Mejora solicitada) -->
    <div
      v-if="video.redirect_url"
      class="p-5 bg-slate-950 bg-gradient-to-r from-slate-900 via-slate-800 to-emerald-950 text-white rounded-guaiqui-xl border border-emerald-500/30 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-md"
    >
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="text-[10px] font-mono uppercase tracking-widest text-emerald-400 bg-emerald-500/20 px-2 py-0.5 rounded font-extrabold border border-emerald-400/30">
            Aliado Comercial Oficial
          </span>
          <span v-if="video.sponsor_name" class="font-display font-bold text-sm text-slate-200">
            {{ video.sponsor_name }}
          </span>
        </div>
        <h3 class="font-display font-bold text-base uppercase tracking-wide text-white">
          Visita a nuestro patrocinador y apoya a la Tribu
        </h3>
        <p class="text-xs text-slate-300 max-w-lg leading-relaxed">
          Haz clic en el enlace para descubrir ofertas especiales y apoyar a las empresas que respaldan al equipo insular.
        </p>
      </div>

      <a
        :href="video.redirect_url"
        target="_blank"
        rel="noopener noreferrer"
        class="shrink-0 w-full sm:w-auto px-6 py-3 rounded-guaiqui-lg bg-guaiqui-primary bg-gradient-to-r from-guaiqui-primary to-emerald-500 hover:from-emerald-500 hover:to-emerald-600 text-white font-display font-black text-xs uppercase tracking-wider shadow-lg flex items-center justify-center gap-2 transition-transform hover:scale-[1.02] active:scale-[0.98]"
      >
        <span>{{ video.cta_text || 'Visitar Patrocinador Oficial' }}</span>
        <i class="bi bi-box-arrow-up-right text-xs"></i>
      </a>
    </div>
  </BaseCard>
</template>
