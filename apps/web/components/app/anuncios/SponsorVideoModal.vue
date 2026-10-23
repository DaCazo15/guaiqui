<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { getGoogleDriveEmbedUrl, extractGoogleDriveFileId, type SponsorVideo } from '@guaiqui/shared'

const props = defineProps<{
  modelValue: boolean
  video: SponsorVideo | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'completed', videoId: string): void
}>()

const videoRef = ref<HTMLVideoElement | null>(null)
const iframeRef = ref<HTMLIFrameElement | null>(null)

const isPlaying = ref(false)
const hasStarted = ref(false)
const elapsedSeconds = ref(0)
const isDotActive = ref(false)
const hasEmittedCompletion = ref(false)

let timerInterval: any = null
let isIframeHovered = false
let focusCheckInterval: any = null

const driveFileId = computed(() => {
  if (!props.video) return null
  return props.video.drive_file_id || extractGoogleDriveFileId(props.video.video_url)
})

const isGoogleDrive = computed(() => {
  return !!driveFileId.value
})

const embedUrl = computed(() => {
  if (!props.video?.video_url) return ''
  return getGoogleDriveEmbedUrl(props.video.video_url)
})

const redirectUrl = computed(() => {
  return props.video?.redirect_url || 'https://www.instagram.com/guaiqueriesbbc/'
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

const triggerCompletion = () => {
  if (hasEmittedCompletion.value || !props.video) return
  hasEmittedCompletion.value = true
  emit('completed', props.video.id)
}

const startTimer = () => {
  if (isUnlocked.value) return
  isPlaying.value = true
  hasStarted.value = true

  if (timerInterval) clearInterval(timerInterval)
  timerInterval = setInterval(() => {
    if (elapsedSeconds.value < requiredSeconds.value) {
      elapsedSeconds.value++
    }
    if (elapsedSeconds.value >= requiredSeconds.value) {
      pauseTimer()
      triggerCompletion()
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

const resetWatchProgress = () => {
  pauseTimer()
  if (videoRef.value) {
    try {
      videoRef.value.pause()
      videoRef.value.currentTime = 0
    } catch {}
  }
  hasStarted.value = false
  elapsedSeconds.value = 0
  isDotActive.value = false
  hasEmittedCompletion.value = false
}

// Detección de interacción con el reproductor iframe de Google Drive
const onIframeMouseEnter = () => {
  isIframeHovered = true
}

const onIframeMouseLeave = () => {
  isIframeHovered = false
}

const onWindowBlur = () => {
  if (props.modelValue && !isPlaying.value && !isUnlocked.value) {
    setTimeout(() => {
      if (isIframeHovered || (iframeRef.value && document.activeElement === iframeRef.value)) {
        startTimer()
      }
    }, 50)
  }
}

const onWindowFocus = () => {
  if (isGoogleDrive.value && isPlaying.value && !isUnlocked.value) {
    if (iframeRef.value && document.activeElement !== iframeRef.value) {
      pauseTimer()
    }
  }
}

const handleVisibilityChange = () => {
  if (document.hidden && isPlaying.value) {
    pauseTimer()
  }
}

const startIframeTracker = () => {
  if (typeof window !== 'undefined') {
    window.addEventListener('blur', onWindowBlur)
    window.addEventListener('focus', onWindowFocus)
    document.addEventListener('visibilitychange', handleVisibilityChange)
    if (focusCheckInterval) clearInterval(focusCheckInterval)
    focusCheckInterval = setInterval(() => {
      if (props.modelValue && !isPlaying.value && !isUnlocked.value) {
        if (iframeRef.value && document.activeElement === iframeRef.value) {
          startTimer()
        }
      }
    }, 250)
  }
}

const stopIframeTracker = () => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('blur', onWindowBlur)
    window.removeEventListener('focus', onWindowFocus)
    document.removeEventListener('visibilitychange', handleVisibilityChange)
  }
  if (focusCheckInterval) {
    clearInterval(focusCheckInterval)
    focusCheckInterval = null
  }
}

onMounted(() => {
  startIframeTracker()
})

watch(
  () => props.modelValue,
  (isOpen) => {
    resetWatchProgress()
    if (isOpen) {
      startIframeTracker()
    } else {
      stopIframeTracker()
    }
  }
)

watch(
  () => props.video?.id,
  () => {
    resetWatchProgress()
  }
)

onUnmounted(() => {
  resetWatchProgress()
  stopIframeTracker()
})

const handleClose = () => {
  resetWatchProgress()
  emit('update:modelValue', false)
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
          <!-- Header Branded: Verde Guaiqueríes sólido con logo oficial y nombre del video (SIN PUNTOS) -->
          <div class="bg-[#0B7A3B] bg-gradient-to-r from-[#064E27] via-[#0B7A3B] to-emerald-800 text-white p-4 sm:p-5 relative flex items-center justify-between border-b-4 border-[#C8102E] shadow-md">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-11 h-11 rounded-full bg-white p-1 shrink-0 shadow-md border-2 border-[#C8102E] flex items-center justify-center">
                <img src="/logo.png" alt="Guaiqueríes" class="w-full h-full object-contain" />
              </div>
              <div class="min-w-0 space-y-0.5">
                <div v-if="video.sponsor_name" class="flex items-center gap-2">
                  <span class="text-[10px] font-mono font-extrabold uppercase tracking-wider bg-black/30 text-emerald-200 px-2 py-0.5 rounded border border-emerald-400/30">
                    {{ video.sponsor_name }}
                  </span>
                </div>
                <h3 class="font-display font-black text-lg sm:text-xl text-white uppercase tracking-wide truncate drop-shadow-xs">
                  {{ video.title }}
                </h3>
              </div>
            </div>

            <!-- Botón de Cerrar Superior -->
            <button
              type="button"
              class="w-9 h-9 rounded-full bg-white/20 hover:bg-[#C8102E] text-white flex items-center justify-center text-lg transition-colors shrink-0 ml-2 cursor-pointer shadow-inner border border-white/30"
              title="Cerrar video"
              @click="handleClose"
            >
              <i class="bi bi-x-lg"></i>
            </button>
          </div>

          <!-- Cuerpo: Reproductor de Video (Interactuable directamente sin capas bloqueantes) -->
          <div class="relative bg-black aspect-video w-full overflow-hidden flex items-center justify-center">
            <!-- 1. Iframe de Google Drive -->
            <iframe
              v-if="isGoogleDrive && embedUrl"
              ref="iframeRef"
              :src="embedUrl"
              class="w-full h-full border-0"
              allow="autoplay; encrypted-media; fullscreen"
              allowfullscreen
              title="Reproductor de Video Patrocinado"
              @mouseenter="onIframeMouseEnter"
              @mouseleave="onIframeMouseLeave"
            ></iframe>

            <!-- 2. Video Nativo HTML5 -->
            <video
              v-else-if="!isGoogleDrive"
              ref="videoRef"
              :src="video.video_url"
              class="w-full h-full object-contain"
              playsinline
              controls
              @play="startTimer"
              @pause="pauseTimer"
              @ended="pauseTimer"
            ></video>

            <div v-else class="text-white text-xs p-6 text-center">
              No se pudo cargar el reproductor del video.
            </div>
          </div>

          <!-- Barra de Progreso y Tiempo Guaiqueríes -->
          <div class="p-4 sm:p-5 bg-slate-50 border-t border-slate-200 space-y-4">
            <!-- Título del Timer y Controles -->
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 text-xs sm:text-sm">
              <div class="flex items-center gap-2.5 flex-wrap">
                <!-- Indicador de estado de reproducción -->
                <div
                  v-if="!hasStarted"
                  class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-semibold animate-pulse"
                >
                  <i class="bi bi-play-circle-fill text-base text-[#0B7A3B]"></i>
                  <span>Haz clic en el reproductor para ver el video</span>
                </div>
                <div
                  v-else-if="isPlaying"
                  class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg bg-emerald-100 border border-emerald-300 text-emerald-900 text-xs font-semibold"
                >
                  <span class="relative flex h-2 w-2">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-2 w-2 bg-[#0B7A3B]"></span>
                  </span>
                  <span>Reproduciendo video...</span>
                </div>
                <div
                  v-else-if="!isUnlocked"
                  class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg bg-amber-50 border border-amber-200 text-amber-800 text-xs font-semibold"
                >
                  <i class="bi bi-pause-fill text-base text-amber-600"></i>
                  <span>Video pausado</span>
                </div>

                <span class="font-bold text-slate-800 text-xs sm:text-sm flex items-center gap-1.5 ml-1">
                  <i class="bi bi-clock-history text-[#0B7A3B]"></i>
                  <span>Progreso de validez:</span>
                  <span class="font-mono text-[#0B7A3B] font-black text-sm">{{ elapsedSeconds }}s / {{ requiredSeconds }}s</span>
                </span>
              </div>

              <!-- Estado de Desbloqueo -->
              <div>
                <span
                  v-if="isUnlocked"
                  class="text-emerald-800 font-bold text-xs flex items-center gap-1.5 bg-emerald-100 px-3 py-1 rounded-full border border-emerald-300 shadow-xs"
                >
                  <i class="bi bi-check-circle-fill text-emerald-600 text-sm"></i>
                  ¡Video Completado!
                </span>
                <span
                  v-else
                  class="text-xs font-mono font-bold text-slate-500"
                >
                  Faltan {{ remainingSeconds }}s
                </span>
              </div>
            </div>

            <!-- CONTENEDOR DE BARRA DE PROGRESO CON PUNTO INTERACTIVO -->
            <div class="relative py-2">
              <!-- Pista de la barra -->
              <div class="w-full h-3.5 bg-slate-200 rounded-full overflow-hidden border border-slate-300 shadow-inner">
                <!-- Barra de progreso verde Guaiqueríes -->
                <div
                  class="h-full bg-[#0B7A3B] bg-gradient-to-r from-[#0B7A3B] via-emerald-500 to-emerald-400 transition-all duration-300 rounded-full shadow-sm"
                  :style="{ width: `${progressPercentage}%` }"
                ></div>
              </div>

              <!-- PUNTO DE PROGRESO DE LA BANDA DEL LOGO (#C8102E) -->
              <!-- Al hacer click o hover se convierte en el logo de Guaiqueríes manteniendo el color de la banda -->
              <div
                class="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 transition-all duration-300 cursor-pointer group/dot z-20 flex items-center justify-center select-none"
                :style="{ left: `${progressPercentage}%` }"
                @click="isDotActive = !isDotActive"
              >
                <div
                  class="rounded-full shadow-lg flex items-center justify-center overflow-hidden transition-all duration-300 border-2 border-[#C8102E]"
                  :class="[
                    isDotActive
                      ? 'w-11 h-11 bg-white ring-4 ring-[#C8102E]/40 scale-110 shadow-xl'
                      : 'w-6 h-6 bg-[#C8102E] group-hover/dot:w-11 group-hover/dot:h-11 group-hover/dot:bg-white group-hover/dot:ring-4 group-hover/dot:ring-[#C8102E]/40'
                  ]"
                  title="Progreso Guaiqueríes — Haz clic o pasa el mouse para ver el escudo"
                >
                  <!-- Logo de Guaiqueríes revelado con borde de bandana roja -->
                  <img
                    src="/logo.png"
                    alt="Logo Guaiqueríes"
                    class="object-contain transition-all duration-300 pointer-events-none"
                    :class="[
                      isDotActive
                        ? 'w-8 h-8 opacity-100 scale-100'
                        : 'w-8 h-8 opacity-0 scale-75 group-hover/dot:opacity-100 group-hover/dot:scale-100'
                    ]"
                  />
                </div>
              </div>
            </div>

            <!-- Advertencia / Instrucción con alto contraste (SIN MENCIÓN DE PUNTOS NI RECLAMOS) -->
            <p class="text-[11px] text-slate-600 leading-tight">
              <span v-if="!isUnlocked">
                <i class="bi bi-info-circle mr-1 text-[#0B7A3B] font-bold"></i>
                Haz clic en el botón de reproducción del video. Si el video se pausa, el conteo se detiene y perderás el progreso si la modal se cierra.
              </span>
              <span v-else class="text-emerald-800 font-semibold flex items-center gap-1.5">
                <i class="bi bi-check2-all text-emerald-600 text-sm"></i>
                ¡Video validado exitosamente! Tu progreso del día ha sido registrado.
              </span>
            </p>

            <!-- BOTONES DE ACCIÓN: ÚNICAMENTE BOTÓN DE CERRAR Y BOTÓN DE REDIRECCIONAR -->
            <div class="flex items-center justify-between gap-3 pt-2 border-t border-slate-200">
              <!-- Botón de Cerrar Modal -->
              <button
                type="button"
                class="px-5 py-2.5 rounded-guaiqui-xl border border-slate-300 bg-white hover:bg-slate-100 text-slate-700 font-display font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-xs"
                @click="handleClose"
              >
                <i class="bi bi-x-circle text-sm text-slate-500"></i>
                <span>Cerrar</span>
              </button>

              <!-- Botón de Redireccionar hacia el Patrocinador -->
              <a
                :href="redirectUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="px-6 py-2.5 rounded-guaiqui-xl bg-slate-900 hover:bg-slate-800 text-white font-display font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-sm border border-slate-700 cursor-pointer"
              >
                <span>{{ video.cta_text || 'Visitar Patrocinador' }}</span>
                <i class="bi bi-box-arrow-up-right text-xs text-emerald-400"></i>
              </a>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
