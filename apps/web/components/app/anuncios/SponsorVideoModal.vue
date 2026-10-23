<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue'
import { PearlIcon, BaseButton, BaseBadge } from '@guaiqui/ui'
import { getGoogleDriveEmbedUrl, type SponsorVideo } from '@guaiqui/shared'

const props = defineProps<{
  modelValue: boolean
  video: SponsorVideo | null
  rewardPoints: number
  claiming: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'claim', videoId: string): void
}>()

const isPlaying = ref(false)
const elapsedSeconds = ref(0)
const isDotActive = ref(false)
let timerInterval: any = null

const embedUrl = computed(() => {
  if (!props.video?.video_url) return ''
  return getGoogleDriveEmbedUrl(props.video.video_url)
})

const redirectUrl = computed(() => {
  return props.video?.redirect_url || 'https://www.instagram.com/guaiqueriesbbc/'
})

const isDirectVideo = computed(() => {
  if (!props.video?.video_url) return false
  const url = props.video.video_url.toLowerCase()
  return url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.ogg')
})

const requiredSeconds = computed(() => {
  return Math.max(1, props.video?.min_seconds || 15)
})

const remainingSeconds = computed(() => {
  return Math.max(0, requiredSeconds.value - elapsedSeconds.value)
})

const progressPercentage = computed(() => {
  if (requiredSeconds.value <= 0) return 100
  return Math.min(100, Math.round((elapsedSeconds.value / requiredSeconds.value) * 100))
})

const isUnlocked = computed(() => {
  return elapsedSeconds.value >= requiredSeconds.value
})

const startTimer = () => {
  if (isPlaying.value || isUnlocked.value) return
  isPlaying.value = true

  if (timerInterval) clearInterval(timerInterval)
  timerInterval = setInterval(() => {
    if (elapsedSeconds.value < requiredSeconds.value) {
      elapsedSeconds.value++
    } else {
      pauseTimer()
    }
  }, 1000)
}

const pauseTimer = () => {
  isPlaying.value = false
  if (timerInterval) {
    clearInterval(timerInterval)
    timerInterval = null
  }
}

const togglePlay = () => {
  if (isPlaying.value) {
    pauseTimer()
  } else {
    startTimer()
  }
}

const resetWatchProgress = () => {
  pauseTimer()
  elapsedSeconds.value = 0
  isDotActive.value = false
}

// Escuchar cambios de visibilidad de la modal
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      resetWatchProgress()
      // Auto-iniciar reproducción y conteo tras breve pausa para montar el reproductor
      setTimeout(() => {
        startTimer()
      }, 500)
    } else {
      resetWatchProgress()
    }
  }
)

// Escuchar cambio de video
watch(
  () => props.video?.id,
  () => {
    resetWatchProgress()
    if (props.modelValue) {
      setTimeout(() => {
        startTimer()
      }, 500)
    }
  }
)

onUnmounted(() => {
  resetWatchProgress()
})

const handleClose = () => {
  resetWatchProgress()
  emit('update:modelValue', false)
}

const handleClaim = () => {
  if (!props.video || !isUnlocked.value || props.claiming) return
  emit('claim', props.video.id)
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="modelValue && video"
        class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 overflow-y-auto bg-slate-950/80 backdrop-blur-sm"
        role="dialog"
        aria-modal="true"
      >
        <!-- Modal Card Container con Branding Guaiqueríes -->
        <div
          class="relative w-full max-w-3xl bg-white rounded-guaiqui-2xl border-2 border-guaiqui-primary shadow-2xl overflow-hidden flex flex-col my-auto animate-in fade-in zoom-in-95 duration-200"
          @click.stop
        >
          <!-- Header Branded: Verde Guaiqueríes con logo y acento bandana -->
          <div class="bg-linear-to-r from-guaiqui-primary via-emerald-700 to-guaiqui-primary text-white p-4 sm:p-5 relative flex items-center justify-between border-b-4 border-[#DC2626]">
            <!-- Fondo con patrón sutil y branding -->
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-full bg-white p-1 shrink-0 shadow-md border border-[#DC2626]/40 flex items-center justify-center">
                <img src="/logo.png" alt="Guaiqueríes" class="w-full h-full object-contain" />
              </div>
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <span
                    v-if="video.sponsor_name"
                    class="text-[10px] font-mono font-extrabold uppercase tracking-wider bg-white/20 text-white px-2 py-0.5 rounded backdrop-blur-xs"
                  >
                    {{ video.sponsor_name }}
                  </span>
                  <span class="text-[10px] font-black uppercase tracking-wider text-amber-300 flex items-center gap-1 font-mono">
                    <PearlIcon size="sm" />
                    +{{ rewardPoints }} PUNTOS
                  </span>
                </div>
                <h3 class="font-display font-extrabold text-base sm:text-lg text-white uppercase tracking-wide truncate mt-0.5">
                  {{ video.title }}
                </h3>
              </div>
            </div>

            <!-- Botón de Cerrar Superior -->
            <button
              type="button"
              class="w-9 h-9 rounded-full bg-black/20 hover:bg-[#DC2626] text-white flex items-center justify-center text-lg transition-all shrink-0 ml-2 cursor-pointer shadow-inner"
              title="Cerrar video"
              @click="handleClose"
            >
              <i class="bi bi-x-lg"></i>
            </button>
          </div>

          <!-- Cuerpo: Reproductor de Video -->
          <div class="relative bg-black aspect-video w-full overflow-hidden flex items-center justify-center">
            <!-- HTML5 Video si es enlace directo -->
            <video
              v-if="isDirectVideo"
              :src="video.video_url"
              class="w-full h-full object-contain"
              controls
              autoplay
              @play="startTimer"
              @pause="pauseTimer"
              @ended="pauseTimer"
            ></video>

            <!-- Google Drive Iframe -->
            <iframe
              v-else-if="embedUrl"
              :src="embedUrl"
              class="w-full h-full border-0"
              allow="autoplay; encrypted-media"
              allowfullscreen
              title="Reproductor de Video Patrocinado"
            ></iframe>

            <div v-else class="text-white text-xs p-6 text-center">
              No se pudo cargar el reproductor del video.
            </div>

            <!-- Indicador Flotante de Pausa / Estado del Timer -->
            <div
              v-if="!isPlaying && !isUnlocked"
              class="absolute top-3 left-3 bg-slate-900/90 text-amber-300 text-[11px] font-bold px-3 py-1.5 rounded-full border border-amber-400/40 shadow-lg flex items-center gap-1.5 backdrop-blur-xs"
            >
              <i class="bi bi-pause-circle-fill text-amber-400 animate-pulse"></i>
              <span>Tiempo pausado — Presiona reproducir</span>
            </div>
          </div>

          <!-- Barra de Progreso y Tiempo Guaiqueríes -->
          <div class="p-4 sm:p-5 bg-guaiqui-surface border-t border-guaiqui-border space-y-4">
            <!-- Título del Timer y Contador -->
            <div class="flex items-center justify-between text-xs sm:text-sm">
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  class="px-2.5 py-1 rounded-md text-xs font-bold font-mono transition-colors flex items-center gap-1 cursor-pointer"
                  :class="isPlaying ? 'bg-amber-100 text-amber-800 hover:bg-amber-200' : 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200'"
                  @click="togglePlay"
                >
                  <i :class="isPlaying ? 'bi bi-pause-fill' : 'bi bi-play-fill'"></i>
                  <span>{{ isPlaying ? 'Pausar' : 'Reanudar' }}</span>
                </button>

                <span class="font-bold text-guaiqui-text text-xs flex items-center gap-1.5">
                  <i class="bi bi-clock-history text-guaiqui-primary"></i>
                  <span>Progreso de validez:</span>
                  <span class="font-mono text-guaiqui-primary">{{ elapsedSeconds }}s / {{ requiredSeconds }}s</span>
                </span>
              </div>

              <!-- Estado de Desbloqueo -->
              <div>
                <span v-if="isUnlocked" class="text-emerald-700 font-bold text-xs flex items-center gap-1 bg-emerald-100 px-2 py-0.5 rounded-full border border-emerald-300">
                  <i class="bi bi-check-circle-fill text-emerald-600"></i>
                  ¡Completado!
                </span>
                <span v-else class="text-xs font-mono font-bold text-guaiqui-text-muted">
                  Faltan {{ remainingSeconds }}s
                </span>
              </div>
            </div>

            <!-- CONTENEDOR DE BARRA DE PROGRESO CON PUNTO INTERACTIVO -->
            <div class="relative py-2">
              <!-- Pista de la barra -->
              <div class="w-full h-3 bg-slate-200 rounded-full overflow-hidden border border-slate-300 shadow-inner">
                <!-- Barra de progreso verde Guaiqueríes -->
                <div
                  class="h-full bg-linear-to-r from-guaiqui-primary via-emerald-500 to-guaiqui-primary transition-all duration-300 rounded-full shadow-sm"
                  :style="{ width: `${progressPercentage}%` }"
                ></div>
              </div>

              <!-- PUNTO DE PROGRESO DE LA BANDA DEL LOGO (#DC2626) -->
              <!-- Al hacer click o hover se convierte en el logo de Guaiqueríes manteniendo el color de la banda -->
              <div
                class="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 transition-all duration-300 cursor-pointer group/dot z-20 flex items-center justify-center select-none"
                :style="{ left: `${progressPercentage}%` }"
                @click="isDotActive = !isDotActive"
              >
                <div
                  class="rounded-full shadow-lg flex items-center justify-center overflow-hidden transition-all duration-300 border-2 border-[#DC2626]"
                  :class="[
                    isDotActive
                      ? 'w-10 h-10 bg-white ring-4 ring-[#DC2626]/40 scale-110 shadow-xl'
                      : 'w-5 h-5 bg-[#DC2626] group-hover/dot:w-10 group-hover/dot:h-10 group-hover/dot:bg-white group-hover/dot:ring-4 group-hover/dot:ring-[#DC2626]/40'
                  ]"
                  title="Progreso Guaiqueríes — Haz clic o pasa el mouse"
                >
                  <!-- Logo de Guaiqueríes revelado con borde de bandana roja -->
                  <img
                    src="/logo.png"
                    alt="Logo Guaiqueríes"
                    class="object-contain transition-all duration-300 pointer-events-none"
                    :class="[
                      isDotActive
                        ? 'w-7 h-7 opacity-100 scale-100'
                        : 'w-7 h-7 opacity-0 scale-75 group-hover/dot:opacity-100 group-hover/dot:scale-100'
                    ]"
                  />
                </div>
              </div>
            </div>

            <!-- Advertencia / Instrucción sutil -->
            <p class="text-[11px] text-guaiqui-text-muted leading-tight">
              <span v-if="!isUnlocked">
                <i class="bi bi-info-circle mr-1 text-guaiqui-primary"></i>
                No pauses ni cierres la ventana. El tiempo se congelará y perderás el progreso si la modal se cierra.
              </span>
              <span v-else class="text-emerald-700 font-semibold flex items-center gap-1">
                <i class="bi bi-stars text-amber-500"></i>
                ¡Video validado exitosamente! Ya puedes reclamar tus <strong>+{{ rewardPoints }} puntos</strong>.
              </span>
            </p>

            <!-- BOTONES DE ACCIÓN: REDIRECCIONAR, RECLAMAR Y CERRAR -->
            <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-2 border-t border-guaiqui-border">
              <!-- Botón de Cerrar Modal -->
              <button
                type="button"
                class="px-5 py-2.5 rounded-guaiqui-xl border border-slate-300 hover:bg-slate-100 text-slate-700 font-display font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-colors cursor-pointer"
                @click="handleClose"
              >
                <i class="bi bi-x-circle text-sm text-slate-500"></i>
                <span>Cerrar</span>
              </button>

              <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5">
                <!-- Botón de Redireccionar hacia el Patrocinador -->
                <a
                  :href="redirectUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="px-5 py-2.5 rounded-guaiqui-xl bg-slate-900 hover:bg-slate-800 text-white font-display font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-sm border border-slate-700 cursor-pointer"
                >
                  <span>{{ video.cta_text || 'Visitar Patrocinador' }}</span>
                  <i class="bi bi-box-arrow-up-right text-xs text-emerald-400"></i>
                </a>

                <!-- Botón de Reclamar Puntos -->
                <button
                  type="button"
                  :disabled="!isUnlocked || claiming"
                  class="px-6 py-2.5 rounded-guaiqui-xl font-display font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-md cursor-pointer"
                  :class="[
                    isUnlocked && !claiming
                      ? 'bg-linear-to-r from-guaiqui-primary to-emerald-500 hover:from-emerald-500 hover:to-emerald-600 text-white hover:scale-[1.02] active:scale-[0.98]'
                      : 'bg-slate-200 text-slate-400 cursor-not-allowed border border-slate-300'
                  ]"
                  @click="handleClaim"
                >
                  <PearlIcon size="sm" />
                  <span>{{ claiming ? 'Acreditando...' : `Reclamar +${rewardPoints} Puntos` }}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
