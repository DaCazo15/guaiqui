<script setup lang="ts">
definePageMeta({
  middleware: [
    () => navigateTo('/')
  ]
})
</script>

<template>
  <div class="p-8 text-center text-slate-500">
    Redirigiendo a inicio...
  </div>
</template>
