<script setup lang="ts">
import { BaseButton } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()

const handleLogin = () => {
  trackEvent('click_login', { source: 'navbar' })
}

const handleRegister = () => {
  trackEvent('click_register', { source: 'navbar' })
}
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-guaiqui-border shadow-xs">
    <div class="max-w-6xl mx-auto px-4 sm:px-8 h-16 flex items-center justify-between gap-4">
      <!-- Brand Logo & Name -->
      <NuxtLink
        :to="{ name: 'index' }"
        class="flex items-center gap-2 text-guaiqui-primary font-display font-extrabold text-xl sm:text-2xl tracking-tight uppercase group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-md p-1"
      >
        <img src="/logo.png" alt="Guaiqueríes Logo" class="w-8 h-8 object-contain group-hover:scale-105 transition-transform" />
        <span class="flex items-center gap-1">
          <span>GUAIQUERÍES</span>
        </span>
      </NuxtLink>

      <!-- Action Buttons: Iniciar Sesión & Regístrate -->
      <div class="flex items-center gap-2 sm:gap-3">
        <NuxtLink :to="{ name: 'login' }">
          <BaseButton variant="secondary" size="sm" @click="handleLogin">
            Iniciar sesión
          </BaseButton>
        </NuxtLink>

        <NuxtLink :to="{ name: 'registro' }">
          <BaseButton variant="primary" size="sm" @click="handleRegister">
            Regístrate
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </header>
</template>
