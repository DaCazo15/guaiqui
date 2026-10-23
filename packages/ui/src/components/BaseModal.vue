<script setup lang="ts">
import { computed, watch, onMounted, onUnmounted } from 'vue'

export type ModalSize = 'sm' | 'md' | 'lg' | 'xl'

interface Props {
  modelValue?: boolean
  open?: boolean
  isOpen?: boolean
  title?: string
  size?: ModalSize
  closable?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: undefined,
  open: undefined,
  isOpen: undefined,
  title: '',
  size: 'md',
  closable: true,
})

const isModalOpen = computed(() => {
  if (props.modelValue !== undefined) return props.modelValue
  if (props.open !== undefined) return props.open
  if (props.isOpen !== undefined) return props.isOpen
  return false
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'update:modelValue', value: boolean): void
  (e: 'update:open', value: boolean): void
  (e: 'update:isOpen', value: boolean): void
}>()

const close = () => {
  if (props.closable) {
    emit('close')
    emit('update:modelValue', false)
    emit('update:open', false)
    emit('update:isOpen', false)
  }
}

const handleKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape' && isModalOpen.value && props.closable) {
    close()
  }
}

watch(
  isModalOpen,
  (isOpen) => {
    if (typeof document !== 'undefined') {
      if (isOpen) {
        document.body.style.overflow = 'hidden'
      } else {
        document.body.style.overflow = ''
      }
    }
  },
  { immediate: true }
)

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handleKeydown)
  }
})

onUnmounted(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('keydown', handleKeydown)
    document.body.style.overflow = ''
  }
})

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'max-w-sm'
    case 'lg':
      return 'max-w-2xl'
    case 'xl':
      return 'max-w-4xl'
    case 'md':
    default:
      return 'max-w-lg'
  }
})
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isModalOpen"
        class="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 sm:p-6"
        role="dialog"
        aria-modal="true"
        :aria-label="title || 'Diálogo'"
        @click.self="close"
      >
        <Transition
          enter-active-class="transition duration-200 ease-out"
          enter-from-class="opacity-0 scale-95 translate-y-2"
          enter-to-class="opacity-100 scale-100 translate-y-0"
          leave-active-class="transition duration-150 ease-in"
          leave-from-class="opacity-100 scale-100 translate-y-0"
          leave-to-class="opacity-0 scale-95 translate-y-2"
        >
          <div
            v-if="isModalOpen"
            :class="[
              'w-full bg-guaiqui-surface rounded-guaiqui-xl shadow-guaiqui-lg overflow-hidden border border-guaiqui-border flex flex-col max-h-[90vh] text-guaiqui-text',
              sizeClasses,
            ]"
          >
            <!-- Header -->
            <div
              v-if="title || $slots.header || closable"
              class="flex items-center justify-between px-5 py-4 border-b border-guaiqui-border bg-guaiqui-surface-hover/30"
            >
              <div class="flex-1">
                <slot name="header">
                  <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase tracking-tight">
                    {{ title }}
                  </h3>
                </slot>
              </div>

              <button
                v-if="closable"
                type="button"
                class="ml-4 p-1.5 rounded-guaiqui-md text-guaiqui-text-muted hover:text-guaiqui-text hover:bg-guaiqui-surface-hover transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
                aria-label="Cerrar modal"
                @click="close"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Body -->
            <div class="px-5 py-5 overflow-y-auto flex-1">
              <slot />
            </div>

            <!-- Footer -->
            <div
              v-if="$slots.footer"
              class="px-5 py-4 border-t border-guaiqui-border bg-guaiqui-surface-hover/30 flex items-center justify-end gap-3"
            >
              <slot name="footer" />
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>
