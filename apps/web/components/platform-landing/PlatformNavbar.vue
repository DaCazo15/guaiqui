<script setup lang="ts">
import { useSupabaseUser } from '#imports'
import { useAnalytics } from '~/composables/useAnalytics'

const user = useSupabaseUser()
const { trackEvent } = useAnalytics()

const handleLogin = () => {
  trackEvent('click_login', { source: 'platform_navbar' })
}

const handleRegister = () => {
  trackEvent('click_register', { source: 'platform_navbar' })
}
</script>

<template>
  <header class="sticky top-0 z-40 bg-[#071318]/90 backdrop-blur-md border-b border-cyan-950/80 shadow-md">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
      <!-- Brand Logo & Name: FanActivo -->
      <NuxtLink
        :to="{ name: 'index' }"
        class="flex items-center gap-2.5 font-title font-black text-xl sm:text-2xl tracking-tight text-white group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-500 rounded-lg p-1"
      >
        <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-white shadow-md shadow-orange-500/20 group-hover:scale-105 transition-transform">
          <i class="bi bi-fire text-lg"></i>
        </div>
        <div class="flex items-baseline gap-1">
          <span class="text-white">FAN</span>
          <span class="text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-amber-400">ACTIVO</span>
        </div>
      </NuxtLink>

      <!-- Center navigation links (desktop) -->
      <nav class="hidden md:flex items-center gap-6 text-sm font-medium text-slate-300">
        <a href="#equipos" class="hover:text-orange-400 transition-colors">Clubes</a>
        <a href="#como-funciona" class="hover:text-cyan-400 transition-colors">¿Cómo Funciona?</a>
      </nav>

      <!-- Action Buttons -->
      <div class="flex items-center gap-2.5 sm:gap-3">
        <template v-if="!user">
          <NuxtLink
            :to="{ name: 'login' }"
            class="px-3.5 py-1.5 sm:px-4 sm:py-2 text-xs sm:text-sm font-semibold rounded-xl text-cyan-300 hover:text-white hover:bg-cyan-950/60 border border-cyan-800/60 transition-all"
            @click="handleLogin"
          >
            Iniciar sesión
          </NuxtLink>

          <NuxtLink
            :to="{ name: 'registro' }"
            class="px-3.5 py-1.5 sm:px-4 sm:py-2 text-xs sm:text-sm font-bold rounded-xl text-white bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 shadow-md shadow-orange-950/30 transition-all"
            @click="handleRegister"
          >
            Regístrate
          </NuxtLink>
        </template>

        <template v-else>
          <NuxtLink
            to="/app"
            class="px-4 py-2 text-xs sm:text-sm font-bold rounded-xl text-white bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 shadow-md shadow-orange-950/30 transition-all flex items-center gap-2"
          >
            <i class="bi bi-grid-fill"></i>
            <span>Mi Fan Zone</span>
          </NuxtLink>
        </template>
      </div>
    </div>
  </header>
</template>
