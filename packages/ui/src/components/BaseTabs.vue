<script setup lang="ts">
export interface TabItem {
  id: string
  label: string
  badge?: string | number
  disabled?: boolean
}

interface Props {
  tabs: TabItem[]
  modelValue: string
  fullWidth?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  tabs: () => [],
  modelValue: '',
  fullWidth: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', id: string): void
  (e: 'change', tab: TabItem): void
}>()

const selectTab = (tab: TabItem) => {
  if (!tab.disabled && tab.id !== props.modelValue) {
    emit('update:modelValue', tab.id)
    emit('change', tab)
  }
}
</script>

<template>
  <div class="w-full">
    <div class="border-b border-guaiqui-border overflow-x-auto no-scrollbar">
      <nav class="flex gap-2 sm:gap-4" role="tablist" aria-label="Tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          role="tab"
          :aria-selected="tab.id === modelValue"
          :disabled="tab.disabled"
          :class="[
            'py-3 px-3 text-sm font-semibold transition-all duration-150 border-b-2 flex items-center gap-2 whitespace-nowrap focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-t-guaiqui-sm',
            fullWidth ? 'flex-1 justify-center' : '',
            tab.id === modelValue
              ? 'border-guaiqui-primary text-guaiqui-primary font-bold'
              : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text hover:border-gray-300',
            tab.disabled ? 'opacity-40 cursor-not-allowed pointer-events-none' : 'cursor-pointer',
          ]"
          @click="selectTab(tab)"
        >
          <span>{{ tab.label }}</span>
          <span
            v-if="tab.badge !== undefined"
            :class="[
              'px-1.5 py-0.5 text-xs rounded-guaiqui-full font-bold',
              tab.id === modelValue
                ? 'bg-guaiqui-primary-soft text-guaiqui-primary-dark'
                : 'bg-gray-100 text-gray-600',
            ]"
          >
            {{ tab.badge }}
          </span>
        </button>
      </nav>
    </div>
  </div>
</template>
