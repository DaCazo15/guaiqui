<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { PearlIcon } from '@guaiqui/ui'
import { getGoogleDriveEmbedUrl, extractGoogleDriveFileId, type SponsorVideo } from '@guaiqui/shared'

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

const videoRef = ref<HTMLVideoElement | null>(null)
const iframeRef = ref<HTMLIFrameElement | null>(null)
const useIframeFallback = ref(false)

const isPlaying = ref(false)
const hasStarted = ref(false)
const elapsedSeconds = ref(0)
const isDotActive = ref(false)
let timerInterval: any = null
let isIframeHovered = false

const driveFileId = computed(() => {
  if (!props.video) return null
  return props.video.drive_file_id || extractGoogleDriveFileId(props.video.video_url)
})

const directVideoUrl = computed(() => {
  if (!props.video?.video_url) return ''
  // Si tenemos ID de Google Drive, usamos el stream directo mp4
  if (driveFileId.value) {
    return `https://drive.google.com/uc?export=download&id=${driveFileId.value}`
  }
  return props.video.video_url
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

const startTimer = () => {
  if (isUnlocked.value) return
  isPlaying.value = true
  hasStarted.value = true

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

// Inicia tanto el video real como el temporizador
const handlePlay = async () => {
  if (isUnlocked.value) return
  startTimer()

  if (!useIframeFallback.value && videoRef.value) {
    try {
      await videoRef.value.play()
    } catch (err) {
      console.warn('Error al reproducir video nativo:', err)
    }
  }
}

// Pausa tanto el video real como el temporizador
const handlePause = () => {
  pauseTimer()

  if (!useIframeFallback.value && videoRef.value) {
    try {
      videoRef.value.pause()
    } catch (err) {
      console.warn('Error al pausar video nativo:', err)
    }
  }
}

const togglePlay = () => {
  if (isPlaying.value) {
    handlePause()
  } else {
    handlePlay()
  }
}

const handleVideoError = () => {
  console.warn('El stream directo falló, alternando al reproductor embebido de Google Drive.')
  useIframeFallback.value = true
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
  useIframeFallback.value = false
}

// Detección de interacción con iframe (por si se usa fallback de Drive)
const onIframeMouseEnter = () => {
  isIframeHovered = true
}

const onIframeMouseLeave = () => {
  isIframeHovered = false
}

const onWindowBlur = () => {
  if (isIframeHovered && !isPlaying.value && !isUnlocked.value && props.modelValue) {
    startTimer()
  }
}

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('blur', onWindowBlur)
  }
})

// Escuchar cambios de visibilidad de la modal
watch(
  () => props.modelValue,
  (isOpen) => {
    resetWatchProgress()
  }
)

// Escuchar cambio de video
watch(
  () => props.video?.id,
  () => {
    resetWatchProgress()
  }
)

onUnmounted(() => {
  resetWatchProgress()
  if (typeof window !== 'undefined') {
    window.removeEventListener('blur', onWindowBlur)
  }
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
          <!-- Header Branded: Verde Guaiqueríes sólido con gradiente y acento bandana roja -->
          <div class="bg-[#0B7A3B] bg-gradient-to-r from-[#064E27] via-[#0B7A3B] to-emerald-800 text-white p-4 sm:p-5 relative flex items-center justify-between border-b-4 border-[#C8102E] shadow-md">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-11 h-11 rounded-full bg-white p-1 shrink-0 shadow-md border-2 border-[#C8102E] flex items-center justify-center">
                <img src="/logo.png" alt="Guaiqueríes" class="w-full h-full object-contain" />
              </div>
              <div class="min-w-0 space-y-0.5">
                <div class="flex items-center gap-2">
                  <span
                    v-if="video.sponsor_name"
                    class="text-[10px] font-mono font-extrabold uppercase tracking-wider bg-black/30 text-emerald-200 px-2 py-0.5 rounded border border-emerald-400/30"
                  >
                    {{ video.sponsor_name }}
                  </span>
                  <span class="text-[11px] font-black uppercase tracking-wider bg-amber-400 text-slate-950 px-2.5 py-0.5 rounded-full shadow-xs flex items-center gap-1 font-mono">
                    <PearlIcon size="xs" />
                    +{{ rewardPoints }} PUNTOS
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

          <!-- Cuerpo: Reproductor de Video -->
          <div class="relative bg-black aspect-video w-full overflow-hidden flex items-center justify-center group">
            <!-- 1. Reproductor de Video Nativo (Inicia y pausa automáticamente con el botón Play) -->
            <video
              v-if="!useIframeFallback"
              ref="videoRef"
              :src="directVideoUrl"
              class="w-full h-full object-contain"
              playsinline
              controls
              @play="startTimer"
              @pause="pauseTimer"
              @ended="pauseTimer"
              @error="handleVideoError"
            ></video>

            <!-- 2. Fallback Iframe de Google Drive si el stream directo no está disponible -->
            <iframe
              v-else-if="embedUrl"
              ref="iframeRef"
              :src="embedUrl"
              class="w-full h-full border-0"
              allow="autoplay; encrypted-media"
              allowfullscreen
              title="Reproductor de Video Patrocinado"
              @mouseenter="onIframeMouseEnter"
              @mouseleave="onIframeMouseLeave"
            ></iframe>

            <div v-else class="text-white text-xs p-6 text-center">
              No se pudo cargar el reproductor del video.
            </div>

            <!-- Botón Central Inicial: Inicia el video real Y arranca el contador simultáneamente -->
            <div
              v-if="!hasStarted && !isPlaying"
              class="absolute inset-0 bg-slate-950/40 backdrop-blur-xs flex flex-col items-center justify-center p-6 text-center z-10 cursor-pointer transition-opacity duration-300"
              @click="handlePlay"
            >
              <button
                type="button"
                class="w-20 h-20 rounded-full bg-[#0B7A3B] hover:bg-emerald-600 border-4 border-white shadow-2xl flex items-center justify-center text-white text-3xl transition-transform duration-300 hover:scale-110 active:scale-95 cursor-pointer ring-4 ring-[#C8102E]"
                aria-label="Reproducir video"
              >
                <i class="bi bi-play-fill ml-1"></i>
              </button>
              <h4 class="mt-4 font-display font-black text-white text-lg sm:text-xl uppercase tracking-wider drop-shadow-md">
                Reproducir Video
              </h4>
              <p class="text-xs text-slate-200 mt-1 max-w-sm">
                Haz clic para iniciar el video y comenzar a validar tus puntos.
              </p>
            </div>

            <!-- Banner Flotante si el video está en Pausa (después de haber iniciado) -->
            <div
              v-else-if="!isPlaying && !isUnlocked"
              class="absolute top-3 left-3 bg-slate-900/95 text-amber-300 text-xs font-bold px-3.5 py-2 rounded-full border border-amber-400/50 shadow-xl flex items-center gap-2 backdrop-blur-xs z-10 cursor-pointer"
              @click="handlePlay"
            >
              <i class="bi bi-pause-circle-fill text-amber-400 text-base animate-pulse"></i>
              <span>Video en pausa — Haz clic para Reanudar</span>
            </div>
          </div>

          <!-- Barra de Progreso y Tiempo Guaiqueríes -->
          <div class="p-4 sm:p-5 bg-slate-50 border-t border-slate-200 space-y-4">
            <!-- Título del Timer y Contador -->
            <div class="flex items-center justify-between text-xs sm:text-sm">
              <div class="flex items-center gap-2.5">
                <!-- Botón de Play/Pausa que inicia/pausa video y temporizador -->
                <button
                  type="button"
                  class="px-3.5 py-1.5 rounded-lg text-xs font-bold font-mono transition-colors flex items-center gap-1.5 cursor-pointer shadow-xs border"
                  :class="[
                    !hasStarted || !isPlaying
                      ? 'bg-[#0B7A3B] hover:bg-emerald-700 text-white border-emerald-800'
                      : 'bg-amber-100 text-amber-900 border-amber-300 hover:bg-amber-200'
                  ]"
                  @click="togglePlay"
                >
                  <i :class="!isPlaying ? 'bi bi-play-fill text-sm' : 'bi bi-pause-fill text-sm'"></i>
                  <span>{{ !hasStarted ? 'Iniciar Video' : isPlaying ? 'Pausar' : 'Reanudar' }}</span>
                </button>

                <span class="font-bold text-slate-800 text-xs sm:text-sm flex items-center gap-1.5">
                  <i class="bi bi-clock-history text-[#0B7A3B]"></i>
                  <span>Progreso de validez:</span>
                  <span class="font-mono text-[#0B7A3B] font-black text-sm">{{ elapsedSeconds }}s / {{ requiredSeconds }}s</span>
                </span>
              </div>

              <!-- Estado de Desbloqueo -->
              <div>
                <span
                  v-if="isUnlocked"
                  class="text-emerald-800 font-bold text-xs flex items-center gap-1 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 shadow-xs"
                >
                  <i class="bi bi-check-circle-fill text-emerald-600"></i>
                  ¡Completado!
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
                <!-- Barra de progreso verde Guaiqueríes (Visible, garantizada con background sólido y gradiente) -->
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

            <!-- Advertencia / Instrucción con alto contraste -->
            <p class="text-[11px] text-slate-600 leading-tight">
              <span v-if="!isUnlocked">
                <i class="bi bi-info-circle mr-1 text-[#0B7A3B] font-bold"></i>
                No pauses ni cierres la ventana. Si el video se pausa, el conteo se detiene y perderás el progreso si la modal se cierra.
              </span>
              <span v-else class="text-emerald-800 font-semibold flex items-center gap-1">
                <i class="bi bi-stars text-amber-500"></i>
                ¡Video validado exitosamente! Ya puedes reclamar tus <strong>+{{ rewardPoints }} puntos</strong>.
              </span>
            </p>

            <!-- BOTONES DE ACCIÓN: REDIRECCIONAR, RECLAMAR Y CERRAR -->
            <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-2 border-t border-slate-200">
              <!-- Botón de Cerrar Modal -->
              <button
                type="button"
                class="px-5 py-2.5 rounded-guaiqui-xl border border-slate-300 bg-white hover:bg-slate-100 text-slate-700 font-display font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-xs"
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
                      ? 'bg-[#0B7A3B] bg-gradient-to-r from-[#0B7A3B] to-emerald-600 hover:from-emerald-600 hover:to-emerald-500 text-white hover:scale-[1.02] active:scale-[0.98]'
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
