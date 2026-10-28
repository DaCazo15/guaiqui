<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

interface TurnstileInstance {
  render: (
    container: HTMLElement,
    options: {
      sitekey: string
      callback: (token: string) => void
      'error-callback': (err: unknown) => void
    }
  ) => string
  remove: (widgetId: string) => void
}

interface WindowWithTurnstile extends Window {
  turnstile?: TurnstileInstance
}

const props = defineProps<{
  siteKey?: string
}>()

const emit = defineEmits<{
  (e: 'verify', token: string): void
  (e: 'error', err: unknown): void
}>()

const container = ref<HTMLElement | null>(null)
const config = useRuntimeConfig()
const siteKey = props.siteKey || config.public.turnstileSiteKey || '0x4AAAAAAFTd4sjJvea-Cegw'
let widgetId: string | null = null

function loadTurnstileScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    const win = window as unknown as WindowWithTurnstile
    if (win.turnstile) {
      resolve()
      return
    }

    const scriptId = 'cf-turnstile-script'
    if (document.getElementById(scriptId)) {
      const interval = setInterval(() => {
        if (win.turnstile) {
          clearInterval(interval)
          resolve()
        }
      }, 100)
      return
    }

    const script = document.createElement('script')
    script.id = scriptId
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
    script.async = true
    script.defer = true
    script.onload = () => resolve()
    script.onerror = (e) => reject(e)
    document.head.appendChild(script)
  })
}

onMounted(async () => {
  try {
    await loadTurnstileScript()
    const win = window as unknown as WindowWithTurnstile
    if (container.value && win.turnstile) {
      widgetId = win.turnstile.render(container.value, {
        sitekey: siteKey,
        callback: (token: string) => {
          emit('verify', token)
        },
        'error-callback': (err: unknown) => {
          emit('error', err)
        },
      })
    }
  } catch (err: unknown) {
    emit('error', err)
  }
})

onUnmounted(() => {
  const win = window as unknown as WindowWithTurnstile
  if (widgetId && win.turnstile) {
    try {
      win.turnstile.remove(widgetId)
    } catch (_) {}
  }
})
</script>

<template>
  <div class="flex justify-center my-4">
    <div ref="container" class="cf-turnstile"></div>
  </div>
</template>
