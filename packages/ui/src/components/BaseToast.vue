<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'

export type ToastType = 'success' | 'warning' | 'danger' | 'info'

interface Props {
  type?: ToastType
  title?: string
  message: string
  duration?: number // in ms, 0 for sticky
  closable?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  type: 'info',
  title: '',
  message: '',
  duration: 4000,
  closable: true,
})

const emit = defineEmits<{
  (e: 'close'): void
}>()

let timer: ReturnType<typeof setTimeout> | null = null
const visible = ref(true)

const dismiss = () => {
  visible.value = false
  emit('close')
}

onMounted(() => {
  if (props.duration > 0) {
    timer = setTimeout(() => {
      dismiss()
    }, props.duration)
  }
})

onUnmounted(() => {
  if (timer) clearTimeout(timer)
})

const borderClasses = computed(() => {
  switch (props.type) {
    case 'success':
      return 'border-l-4 border-l-guaiqui-status-success bg-white text-guaiqui-text'
    case 'warning':
      return 'border-l-4 border-l-guaiqui-status-warning bg-white text-guaiqui-text'
    case 'danger':
      return 'border-l-4 border-l-guaiqui-status-danger bg-white text-guaiqui-text'
    case 'info':
    default:
      return 'border-l-4 border-l-guaiqui-status-info bg-white text-guaiqui-text'
  }
})
</script>

<template>
  <Transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="opacity-0 translate-y-2 sm:translate-y-0 sm:translate-x-2"
    enter-to-class="opacity-100 translate-y-0 sm:translate-x-0"
    leave-active-class="transition duration-200 ease-in"
    leave-from-class="opacity-100 scale-100"
    leave-to-class="opacity-0 scale-95"
  >
    <div
      v-if="visible"
      :class="[
        'w-full max-w-sm rounded-guaiqui-md shadow-guaiqui-lg p-4 border border-guaiqui-border flex items-start gap-3 relative',
        borderClasses,
      ]"
      role="alert"
    >
      <!-- Icon -->
      <div class="flex-shrink-0 mt-0.5">
        <svg v-if="type === 'success'" class="w-5 h-5 text-guaiqui-status-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <svg v-else-if="type === 'warning'" class="w-5 h-5 text-guaiqui-status-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <svg v-else-if="type === 'danger'" class="w-5 h-5 text-guaiqui-status-danger" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <svg v-else class="w-5 h-5 text-guaiqui-status-info" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>

      <div class="flex-1">
        <h4 v-if="title" class="font-bold text-sm text-guaiqui-text leading-tight mb-0.5">
          {{ title }}
        </h4>
        <p class="text-xs text-guaiqui-text-muted leading-relaxed">
          {{ message }}
        </p>
      </div>

      <button
        v-if="closable"
        type="button"
        class="text-guaiqui-text-subtle hover:text-guaiqui-text p-1 rounded-guaiqui-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
        aria-label="Cerrar notificación"
        @click="dismiss"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  </Transition>
</template>
