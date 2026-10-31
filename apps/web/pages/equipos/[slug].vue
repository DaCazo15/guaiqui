<script setup lang="ts">
const route = useRoute()
const slug = route.params.slug as string
await navigateTo(`/equipo/${slug}`, { redirectCode: 301 })
</script>

<template>
  <div></div>
</template>
