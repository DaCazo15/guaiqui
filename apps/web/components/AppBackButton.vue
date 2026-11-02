<script setup lang="ts">
import AppBackButton from './common/AppBackButton.vue'
</script>

<template>
  <AppBackButton v-bind="$attrs">
    <slot />
  </AppBackButton>
</template>
