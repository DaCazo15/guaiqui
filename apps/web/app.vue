<script setup lang="ts">
import OfflineBanner from '~/components/common/OfflineBanner.vue'
</script>

<template>
  <div>
    <OfflineBanner />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>
