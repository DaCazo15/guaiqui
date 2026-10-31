<script setup lang="ts">
definePageMeta({
  middleware: [
    'guest',
    function (to) {
      return navigateTo({
        path: '/login',
        query: { tab: 'register', ...to.query },
      })
    }
  ]
})
</script>

<template>
  <div class="min-h-screen bg-[#01140c]" />
</template>
