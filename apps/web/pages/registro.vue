<script setup lang="ts">
definePageMeta({
  middleware: [
    'guest',
    function () {
      return navigateTo('/login?tab=register')
    }
  ]
})
</script>

<template>
  <div class="min-h-screen bg-[#01140c]" />
</template>
