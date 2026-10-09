<script setup lang="ts">
interface Props {
  title?: string
  message?: string
}

withDefaults(defineProps<Props>(), {
  title: 'No hay elementos',
  message: 'Aún no se ha encontrado nada por aquí.',
})
</script>

<template>
  <div class="flex flex-col items-center justify-center p-8 sm:p-12 text-center rounded-guaiqui-xl border-2 border-dashed border-guaiqui-border bg-guaiqui-surface/40">
    <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center mb-4">
      <slot name="icon">
        <svg class="w-8 h-8 stroke-current fill-none stroke-2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
        </svg>
      </slot>
    </div>

    <h3 class="font-display font-bold text-xl text-guaiqui-text mb-1">
      {{ title }}
    </h3>

    <p class="text-sm text-guaiqui-text-muted max-w-sm mb-6 leading-relaxed">
      {{ message }}
    </p>

    <div v-if="$slots.action">
      <slot name="action" />
    </div>
  </div>
</template>
