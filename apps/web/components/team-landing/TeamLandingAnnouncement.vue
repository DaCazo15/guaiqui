<script setup lang="ts">
defineProps<{
  announcement?: {
    id: string
    message: string
  } | null
}>()
</script>

<template>
  <aside
    v-if="announcement?.message"
    class="bg-guaiqui-primary text-white py-2.5 px-4 text-center text-sm font-semibold tracking-wide flex items-center justify-center gap-2 relative z-50 shadow-inner"
    role="region"
    aria-label="Anuncio oficial del equipo"
  >
    <i class="bi bi-megaphone-fill text-yellow-300" aria-hidden="true"></i>
    <span>{{ announcement.message }}</span>
  </aside>
</template>
