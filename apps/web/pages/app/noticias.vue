<script setup lang="ts">
definePageMeta({
  middleware: [
    () => navigateTo('/app')
  ]
})
</script>

<template>
  <div class="p-8 text-center text-guaiqui-muted">
    Redirigiendo a inicio...
  </div>
</template>
