<script setup lang="ts">
/**
 * TurnstileWrapper Component
 * Extension point for Cloudflare Turnstile integration in anti-fraud phase.
 */
defineProps<{
  sitekey?: string
}>()

const emit = defineEmits<{
  (e: 'verify', token: string): void
  (e: 'error', error: string): void
  (e: 'expire'): void
}>()
</script>

<template>
  <div class="turnstile-wrapper my-2">
    <!-- Slot for future Turnstile widget or wrapper content -->
    <slot>
      <!-- Hidden or default container for Turnstile script integration -->
      <div id="turnstile-container" class="min-h-[60px] flex items-center justify-center text-xs text-guaiqui-text-muted">
        <!-- Placeholder for anti-fraud captcha verification -->
      </div>
    </slot>
  </div>
</template>
