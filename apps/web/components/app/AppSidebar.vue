<script setup lang="ts">
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'

const route = useRoute()
const authStore = useAuthStore()

const navItems = [
  { name: 'Inicio', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Ver Anuncios', path: '/app/anuncios', icon: 'bi-play-btn-fill' },
  { name: 'Billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Mis Canjes', path: '/app/canjes', icon: 'bi-gift-fill' },
  { name: 'Ranking', path: '/app/ranking', icon: 'bi-trophy-fill' },
  { name: 'Plantilla', path: '/app/plantilla', icon: 'bi-people-fill' },
  { name: 'Mi Perfil', path: '/app/perfil', icon: 'bi-person-fill' },
  { name: 'Ajustes', path: '/app/ajustes', icon: 'bi-gear-fill' },
]

const handleLogout = async () => {
  await authStore.logout()
}
</script>

<template>
  <aside class="hidden md:flex flex-col w-64 border-r border-guaiqui-border bg-white min-h-screen p-4 sticky top-0 h-screen">
    <!-- Brand Logo -->
    <div class="flex items-center gap-1 px-3 py-4 mb-4 border-b border-guaiqui-border">
      <img src="/logo.png" alt="Guaiqueríes Logo" class="w-[53px] h-[53px] object-contain shrink-0" />
      <div>
        <h1 class="font-display text-lg font-bold text-guaiqui-text uppercase tracking-wider">
          Guaiqueríes
        </h1>
        <span class="text-xs text-guaiqui-primary font-semibold tracking-wide">Fan Zone</span>
      </div>
    </div>

    <!-- User Mini Card & Pearls Balance -->
    <div class="bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-lg p-3 mb-6 flex items-center justify-between shadow-guaiqui-sm">
      <div class="flex items-center gap-2 overflow-hidden">
        <div class="w-8 h-8 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-bold text-sm shrink-0">
          {{ authStore.profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
        </div>
        <div class="truncate">
          <p class="text-xs font-semibold text-guaiqui-text truncate">
            {{ authStore.profile?.display_name || 'Fanático' }}
          </p>
          <span class="text-[10px] text-guaiqui-text-muted">
            {{ authStore.profile?.municipality || 'Nueva Esparta' }}
          </span>
        </div>
      </div>
      <div class="flex items-center gap-1.5 text-xs font-bold text-guaiqui-perlita bg-guaiqui-perlita-soft px-2.5 py-1 rounded-full border border-guaiqui-perlita/20 shrink-0">
        <PearlIcon size="xs" animated />
        <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
      </div>
    </div>

    <!-- Nav Links -->
    <nav class="flex-1 space-y-1 overflow-y-auto pr-1">
      <NuxtLink
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        class="flex items-center gap-3 px-3 py-2.5 rounded-guaiqui-md text-sm font-medium transition-all duration-150"
        :class="[
          route.path === item.path
            ? 'bg-guaiqui-primary text-white font-semibold shadow-guaiqui-sm'
            : 'text-guaiqui-text-muted hover:text-guaiqui-text hover:bg-guaiqui-surface',
        ]"
      >
        <i :class="['bi', item.icon, 'text-base']"></i>
        <span>{{ item.name }}</span>
      </NuxtLink>
    </nav>

    <!-- Logout Footer -->
    <div class="pt-4 border-t border-guaiqui-border">
      <button
        type="button"
        class="w-full flex items-center gap-3 px-3 py-2.5 rounded-guaiqui-md text-sm text-guaiqui-accent hover:bg-guaiqui-accent-soft transition-colors font-medium cursor-pointer"
        @click="handleLogout"
      >
        <i class="bi bi-box-arrow-right text-base"></i>
        <span>Cerrar Sesión</span>
      </button>
    </div>
  </aside>
</template>
