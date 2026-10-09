<script setup lang="ts">
import { ref } from 'vue'
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()
const isMobileMenuOpen = ref(false)

const toggleMobileMenu = () => {
  isMobileMenuOpen.value = !isMobileMenuOpen.value
}

const closeMobileMenu = () => {
  isMobileMenuOpen.value = false
}

const handleLogin = () => {
  trackEvent('click_login', { source: 'navbar' })
}

const handleRegister = () => {
  trackEvent('click_register', { source: 'navbar' })
}

const navLinks = [
  { label: 'Inicio', to: '/' },
  { label: 'La App', to: '/#como-funciona' },
  { label: 'Historia', to: '/historia' },
  { label: 'Plantilla', to: '/plantilla' },
  { label: 'Equipo', to: '/equipo-de-trabajo' },
  { label: 'Políticas', to: '/politicas/terminos' },
]
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-guaiqui-border shadow-xs">
    <div class="max-w-6xl mx-auto px-4 sm:px-8 h-16 flex items-center justify-between gap-4">
      <!-- Brand Logo -->
      <NuxtLink to="/" class="flex items-center gap-2 text-guaiqui-primary font-display font-extrabold text-xl sm:text-2xl tracking-tight uppercase group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-md p-1">
        <span class="w-8 h-8 rounded-full bg-guaiqui-primary text-white flex items-center justify-center font-bold text-sm shadow-xs group-hover:scale-105 transition-transform">
          G
        </span>
        <span class="flex items-center gap-1">
          <span>GUAIQUERÍES</span>
          <PearlIcon size="xs" />
        </span>
      </NuxtLink>

      <!-- Desktop Nav Links -->
      <nav class="hidden md:flex items-center gap-6 text-sm font-semibold text-guaiqui-text">
        <NuxtLink
          v-for="link in navLinks"
          :key="link.to"
          :to="link.to"
          class="hover:text-guaiqui-primary transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-sm px-1 py-0.5"
        >
          {{ link.label }}
        </NuxtLink>
      </nav>

      <!-- Action Buttons -->
      <div class="flex items-center gap-2 sm:gap-3">
        <NuxtLink to="/login" class="hidden sm:inline-flex">
          <BaseButton variant="secondary" size="sm" @click="handleLogin">
            Iniciar sesión
          </BaseButton>
        </NuxtLink>

        <!-- Primary Register Button (ALWAYS visible outside drawer on mobile too) -->
        <NuxtLink to="/registro">
          <BaseButton variant="primary" size="sm" @click="handleRegister">
            Regístrate
          </BaseButton>
        </NuxtLink>

        <!-- Mobile Hamburger Button -->
        <button
          type="button"
          class="md:hidden p-2 rounded-guaiqui-md text-guaiqui-text hover:bg-guaiqui-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary ml-1"
          :aria-expanded="isMobileMenuOpen"
          aria-label="Abrir menú de navegación"
          @click="toggleMobileMenu"
        >
          <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              v-if="!isMobileMenuOpen"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
            <path
              v-else
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>
    </div>

    <!-- Mobile Drawer Overlay -->
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 -translate-y-2"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100 translate-y-0"
      leave-to-class="opacity-0 -translate-y-2"
    >
      <div
        v-if="isMobileMenuOpen"
        class="md:hidden bg-white border-b border-guaiqui-border px-4 py-4 shadow-lg flex flex-col gap-3"
      >
        <NuxtLink
          v-for="link in navLinks"
          :key="link.to"
          :to="link.to"
          class="py-2 px-3 text-base font-semibold text-guaiqui-text hover:bg-guaiqui-surface rounded-guaiqui-md transition-colors"
          @click="closeMobileMenu"
        >
          {{ link.label }}
        </NuxtLink>

        <div class="pt-2 border-t border-guaiqui-border flex flex-col gap-2">
          <NuxtLink to="/login" @click="closeMobileMenu">
            <BaseButton variant="secondary" block @click="handleLogin">
              Iniciar sesión
            </BaseButton>
          </NuxtLink>
        </div>
      </div>
    </Transition>
  </header>
</template>
