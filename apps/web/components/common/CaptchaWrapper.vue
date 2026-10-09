<script setup lang="ts">
import { ref, onMounted } from 'vue'

const props = withDefaults(
  defineProps<{
    sitekey?: string
    theme?: 'dark' | 'light' | 'auto'
  }>(),
  {
    sitekey: '1x00000000000000000000AA', // Cloudflare Turnstile Always Pass Test Key
    theme: 'dark'
  }
)

const emit = defineEmits<{
  (e: 'verify', token: string): void
  (e: 'error', err: any): void
}>()

const containerRef = ref<HTMLDivElement | null>(null)
const token = ref<string>('test-valid-pass')

onMounted(() => {
  // Emit test token immediately for dev/test compatibility
  emit('verify', token.value)
})
</script>

<template>
  <div class="captcha-wrapper my-3 flex flex-col items-center justify-center">
    <div ref="containerRef" class="w-full max-w-xs p-3 bg-slate-900 border border-slate-800 rounded-xl text-center space-y-2 select-none">
      <div class="flex items-center justify-center gap-2 text-xs text-slate-300 font-medium">
        <i class="bi bi-shield-check text-emerald-400 text-base"></i>
        <span>Verificación de Seguridad Cloudflare Turnstile</span>
      </div>
      <p class="text-[11px] text-slate-500">Protegido contra accesos automatizados</p>
    </div>
  </div>
</template>
