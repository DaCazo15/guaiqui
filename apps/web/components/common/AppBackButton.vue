<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
import { useRouter } from 'vue-router'

const props = withDefaults(
  defineProps<{
    to?: RouteLocationRaw | string
    label?: string
    dark?: boolean
  }>(),
  {
    to: undefined,
    label: 'Volver',
    dark: false,
  }
)

const emit = defineEmits<{
  (e: 'click', evt: MouseEvent): void
}>()

const router = useRouter()

const handleClick = (e: MouseEvent) => {
  emit('click', e)
  if (!props.to) {
    router.back()
  }
}
</script>

<template>
  <NuxtLink
    v-if="to"
    :to="to"
    class="inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded-full text-xs font-bold tracking-wide transition-all duration-200 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 shadow-xs cursor-pointer select-none active:scale-[0.98]"
    :class="[
      dark
        ? 'bg-slate-900/90 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/80 hover:border-emerald-500/50 shadow-slate-950/40'
        : 'bg-white hover:bg-slate-50 text-slate-700 hover:text-slate-950 border border-slate-200/90 hover:border-emerald-500/50 shadow-slate-900/5'
    ]"
  >
    <span
      class="w-5 h-5 rounded-full flex items-center justify-center transition-all duration-200 shrink-0"
      :class="[
        dark
          ? 'bg-slate-800 group-hover:bg-emerald-500/20 text-slate-400 group-hover:text-emerald-400'
          : 'bg-slate-100 group-hover:bg-emerald-100 text-slate-600 group-hover:text-emerald-700'
      ]"
    >
      <i class="bi bi-arrow-left text-[11px] transition-transform duration-200 group-hover:-translate-x-0.5"></i>
    </span>
    <span class="truncate">
      <slot>{{ label }}</slot>
    </span>
  </NuxtLink>

  <button
    v-else
    type="button"
    @click="handleClick"
    class="inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded-full text-xs font-bold tracking-wide transition-all duration-200 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 shadow-xs cursor-pointer select-none active:scale-[0.98]"
    :class="[
      dark
        ? 'bg-slate-900/90 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/80 hover:border-emerald-500/50 shadow-slate-950/40'
        : 'bg-white hover:bg-slate-50 text-slate-700 hover:text-slate-950 border border-slate-200/90 hover:border-emerald-500/50 shadow-slate-900/5'
    ]"
  >
    <span
      class="w-5 h-5 rounded-full flex items-center justify-center transition-all duration-200 shrink-0"
      :class="[
        dark
          ? 'bg-slate-800 group-hover:bg-emerald-500/20 text-slate-400 group-hover:text-emerald-400'
          : 'bg-slate-100 group-hover:bg-emerald-100 text-slate-600 group-hover:text-emerald-700'
      ]"
    >
      <i class="bi bi-arrow-left text-[11px] transition-transform duration-200 group-hover:-translate-x-0.5"></i>
    </span>
    <span class="truncate">
      <slot>{{ label }}</slot>
    </span>
  </button>
</template>
