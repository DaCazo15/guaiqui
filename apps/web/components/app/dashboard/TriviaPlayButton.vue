<script setup lang="ts">
import { ref, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { useCurrentTeam } from '~/composables/useCurrentTeam'

interface Props {
  triviaId: string
  teamSlug?: string
  label?: string
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  label: 'Jugar Trivia del Día',
  disabled: false
})

const router = useRouter()
const { activeTeam } = useCurrentTeam()

// Estados: 'idle' | 'holding' | 'morphing'
const state = ref<'idle' | 'holding' | 'morphing'>('idle')
let holdTimer: ReturnType<typeof setTimeout> | null = null
let morphTimer: ReturnType<typeof setTimeout> | null = null
const holdProgress = ref(0)
let progressInterval: ReturnType<typeof setInterval> | null = null

function startHold() {
  if (props.disabled || state.value === 'morphing') return
  state.value = 'holding'
  holdProgress.value = 0

  const stepTime = 16 // ~60fps
  const totalHoldTime = 400 // ms para completar la transformación en balón

  progressInterval = setInterval(() => {
    holdProgress.value = Math.min(100, holdProgress.value + (stepTime / totalHoldTime) * 100)
  }, stepTime)

  holdTimer = setTimeout(() => {
    // Si sigue presionado, queda en balón listo
    holdProgress.value = 100
  }, totalHoldTime)
}

function releaseHold() {
  if (props.disabled) return

  if (progressInterval) {
    clearInterval(progressInterval)
    progressInterval = null
  }
  if (holdTimer) {
    clearTimeout(holdTimer)
    holdTimer = null
  }

  // Al soltarlo, se convierte en perlita
  state.value = 'morphing'

  // Transición breve mostrando la perlita radiante antes de navegar
  morphTimer = setTimeout(() => {
    const slug = props.teamSlug || activeTeam.value?.slug
    if (slug) {
      router.push(`/app/e/${slug}/trivias/${props.triviaId}`)
    } else {
      router.push(`/app/trivias/${props.triviaId}`)
    }
  }, 450)
}

function cancelHold() {
  if (state.value === 'holding') {
    if (progressInterval) clearInterval(progressInterval)
    if (holdTimer) clearTimeout(holdTimer)
    state.value = 'idle'
    holdProgress.value = 0
  }
}

onBeforeUnmount(() => {
  if (holdTimer) clearTimeout(holdTimer)
  if (morphTimer) clearTimeout(morphTimer)
  if (progressInterval) clearInterval(progressInterval)
})
</script>

<template>
  <div class="relative inline-flex items-center justify-center select-none">
    <!-- Botón Principal con transformación dinámica -->
    <button
      type="button"
      :disabled="disabled"
      @mousedown="startHold"
      @mouseup="releaseHold"
      @mouseleave="cancelHold"
      @touchstart.passive="startHold"
      @touchend="releaseHold"
      @touchcancel="cancelHold"
      @keydown.enter.prevent="startHold"
      @keyup.enter.prevent="releaseHold"
      @keydown.space.prevent="startHold"
      @keyup.space.prevent="releaseHold"
      class="group relative overflow-hidden transition-all duration-300 ease-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-accent focus-visible:ring-offset-2 cursor-pointer disabled:cursor-not-allowed disabled:opacity-60"
      :class="[
        state === 'idle'
          ? 'h-12 px-6 rounded-guaiqui-lg bg-gradient-to-r from-guaiqui-primary via-emerald-600 to-guaiqui-primary-dark text-white font-display font-extrabold text-base uppercase tracking-wider shadow-lg shadow-emerald-900/30 hover:shadow-emerald-800/50 hover:scale-[1.02] active:scale-[0.98] border border-emerald-400/30 flex items-center gap-2.5'
          : state === 'holding'
          ? 'w-14 h-14 rounded-full p-0 flex items-center justify-center shadow-xl shadow-amber-900/40 animate-pulse scale-105 border-2 border-amber-400'
          : 'w-14 h-14 rounded-full p-0 flex items-center justify-center bg-white shadow-2xl shadow-amber-500/50 scale-110 border-2 border-amber-300 animate-bounce'
      ]"
      :aria-label="label"
      :title="state === 'holding' ? '¡Suelta para lanzar!' : label"
    >
      <!-- ESTADO 1: Idle (Botón CTA con textura y badge energético) -->
      <template v-if="state === 'idle'">
        <!-- Brillo dinámico de fondo -->
        <span class="absolute inset-0 w-full h-full bg-gradient-to-r from-white/0 via-white/20 to-white/0 -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-in-out"></span>
        
        <!-- Indicador rojo bandana lateral de energía -->
        <span class="w-2 h-2 rounded-full bg-guaiqui-accent animate-ping"></span>
        <i class="bi bi-play-circle-fill text-lg text-amber-300"></i>
        <span>{{ label }}</span>
        <i class="bi bi-arrow-right text-sm text-emerald-200 group-hover:translate-x-1 transition-transform"></i>
      </template>

      <!-- ESTADO 2: Holding (Balón de Baloncesto auténtico con texturas y costuras) -->
      <template v-else-if="state === 'holding'">
        <div class="relative w-full h-full rounded-full bg-gradient-to-br from-amber-500 via-orange-600 to-amber-900 shadow-inner overflow-hidden flex items-center justify-center transform transition-transform duration-200">
          <!-- Textura de cuero de baloncesto -->
          <div class="absolute inset-0 opacity-25 bg-[radial-gradient(#000_1px,transparent_1px)] [background-size:3px_3px]"></div>
          
          <!-- Costuras / Líneas del balón en SVG -->
          <svg class="absolute inset-0 w-full h-full stroke-stone-900/80 fill-none" viewBox="0 0 100 100" stroke-width="5" stroke-linecap="round">
            <!-- Costura horizontal central -->
            <line x1="0" y1="50" x2="100" y2="50" />
            <!-- Costura vertical central -->
            <line x1="50" y1="0" x2="50" y2="100" />
            <!-- Costura curva izquierda -->
            <path d="M 22,5 A 50,50 0 0,0 22,95" />
            <!-- Costura curva derecha -->
            <path d="M 78,5 A 50,50 0 0,1 78,95" />
          </svg>

          <!-- Resplandor del balón en mano -->
          <div class="absolute top-1 left-2 w-3 h-2 rounded-full bg-white/40 blur-[1px]"></div>
        </div>
      </template>

      <!-- ESTADO 3: Morphing (Transformación en Moneda Dorada y Destello) -->
      <template v-else>
        <div class="relative w-full h-full rounded-full flex items-center justify-center bg-gradient-to-br from-amber-100 via-white to-amber-200 p-1">
          <!-- Anillo de destello radiante -->
          <div class="absolute -inset-2 rounded-full bg-amber-400/30 blur-sm animate-ping"></div>
          
          <!-- Imagen oficial de la moneda de puntos -->
          <img
            src="/perla-coin.webp"
            alt="Puntos Ganados"
            class="w-10 h-10 object-contain drop-shadow-md transform rotate-12 transition-transform duration-300"
          />
        </div>
      </template>
    </button>

    <!-- Tooltip flotante interactivo indicando la acción -->
    <transition enter-active-class="transition duration-150 ease-out" enter-from-class="opacity-0 translate-y-1" enter-to-class="opacity-100 translate-y-0" leave-active-class="transition duration-100 ease-in" leave-from-class="opacity-100 translate-y-0" leave-to-class="opacity-0 translate-y-1">
      <div
        v-if="state === 'holding'"
        class="absolute -top-8 left-1/2 -translate-x-1/2 whitespace-nowrap bg-stone-900 text-amber-300 text-[10px] font-bold uppercase tracking-widest px-2.5 py-0.5 rounded-full border border-amber-400/40 shadow-md pointer-events-none"
      >
        ¡Suelta para lanzar!
      </div>
    </transition>
  </div>
</template>
