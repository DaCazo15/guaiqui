<script setup lang="ts">
import { ref } from 'vue'

export interface AccordionItem {
  id: string
  title: string
  content?: string
  disabled?: boolean
}

interface Props {
  items: AccordionItem[]
  defaultOpenId?: string
  multiple?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  items: () => [],
  defaultOpenId: undefined,
  multiple: false,
})

const openIds = ref<Set<string>>(new Set(props.defaultOpenId ? [props.defaultOpenId] : []))

const toggle = (id: string, disabled?: boolean) => {
  if (disabled) return

  if (openIds.value.has(id)) {
    openIds.value.delete(id)
  } else {
    if (!props.multiple) {
      openIds.value.clear()
    }
    openIds.value.add(id)
  }
}

const isOpen = (id: string) => openIds.value.has(id)
</script>

<template>
  <div class="w-full divide-y divide-guaiqui-border border border-guaiqui-border rounded-guaiqui-lg overflow-hidden bg-white">
    <div
      v-for="item in items"
      :key="item.id"
      class="transition-colors duration-150"
    >
      <button
        type="button"
        :aria-expanded="isOpen(item.id)"
        :aria-controls="`accordion-content-${item.id}`"
        :disabled="item.disabled"
        :class="[
          'w-full px-5 py-4 text-left font-semibold text-sm flex items-center justify-between transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary',
          isOpen(item.id) ? 'bg-guaiqui-surface text-guaiqui-primary font-bold' : 'text-guaiqui-text hover:bg-guaiqui-surface-hover',
          item.disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
        ]"
        @click="toggle(item.id, item.disabled)"
      >
        <span>{{ item.title }}</span>
        <svg
          :class="[
            'w-4 h-4 text-guaiqui-text-muted transition-transform duration-200 flex-shrink-0 ml-3',
            isOpen(item.id) ? 'rotate-180 text-guaiqui-primary' : '',
          ]"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <Transition
        enter-active-class="transition-all duration-200 ease-out overflow-hidden"
        enter-from-class="max-h-0 opacity-0"
        enter-to-class="max-h-96 opacity-100"
        leave-active-class="transition-all duration-150 ease-in overflow-hidden"
        leave-from-class="max-h-96 opacity-100"
        leave-to-class="max-h-0 opacity-0"
      >
        <div
          v-if="isOpen(item.id)"
          :id="`accordion-content-${item.id}`"
          class="px-5 py-4 text-sm text-guaiqui-text-muted leading-relaxed bg-white border-t border-guaiqui-border/60"
        >
          <slot :name="`item-${item.id}`" :item="item">
            {{ item.content }}
          </slot>
        </div>
      </Transition>
    </div>
  </div>
</template>
