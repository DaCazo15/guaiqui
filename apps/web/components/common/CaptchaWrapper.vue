<script setup lang="ts">
import TurnstileWrapper from '~/components/common/TurnstileWrapper.vue'

defineProps<{
  sitekey?: string
  theme?: 'dark' | 'light' | 'auto'
}>()

const emit = defineEmits<{
  (e: 'verify', token: string): void
  (e: 'error', err: any): void
}>()
</script>

<template>
  <div class="captcha-wrapper my-3 flex flex-col items-center justify-center">
    <TurnstileWrapper :site-key="sitekey" @verify="(t) => emit('verify', t)" @error="(e) => emit('error', e)" />
  </div>
</template>
