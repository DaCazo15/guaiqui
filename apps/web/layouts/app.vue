<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import AppSidebar from '~/components/app/AppSidebar.vue'
import AppMobileNav from '~/components/app/AppMobileNav.vue'
import AppMobileDrawer from '~/components/app/AppMobileDrawer.vue'
import NotificationBell from '~/components/app/NotificationBell.vue'
import LoginModalCarousel from '~/components/app/LoginModalCarousel.vue'
import IncompleteProfileBanner from '~/components/app/IncompleteProfileBanner.vue'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { BaseSkeletonLayout } from '@guaiqui/ui'

const authStore = useAuthStore()
const avatarError = ref(false)
const isDrawerOpen = ref(false)

onMounted(async () => {
  if (!authStore.profile) {
    await authStore.fetchProfile()
  }
})
</script>

<template>
  <div v-if="authStore.isLoading && !authStore.profile">
    <BaseSkeletonLayout :dark="true" :show-sidebar="true" />
  </div>

  <div v-else class="min-h-screen bg-guaiqui-surface text-guaiqui-text flex flex-col md:flex-row">
    <!-- Desktop Sidebar -->
    <AppSidebar />

    <!-- Main Content Area with safe area padding -->
    <div
      class="flex-1 flex flex-col min-w-0 md:pb-6"
      style="padding-bottom: calc(5.5rem + env(safe-area-inset-bottom, 0px));"
    >
      <!-- Mobile Top Header: Verde Guaiqueríes con detalle en rojo bandana -->
      <header class="md:hidden sticky top-0 z-30 bg-[#0B7A3B] bg-gradient-to-r from-[#064E27] via-[#0B7A3B] to-emerald-800 border-b-2 border-[#C8102E] shadow-md px-4 py-2.5 flex items-center justify-between text-white">
        <div class="flex items-center gap-2">
          <!-- Mobile Menu Drawer Toggle Button -->
          <button
            type="button"
            @click="isDrawerOpen = true"
            aria-label="Abrir menú de navegación"
            class="w-9 h-9 rounded-lg flex items-center justify-center text-white hover:bg-white/10 active:scale-95 transition-all cursor-pointer -ml-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
          >
            <i class="bi bi-list text-2xl leading-none"></i>
          </button>

          <div class="w-8 h-8 rounded-full bg-white p-0.5 shrink-0 shadow-xs border border-white/40 flex items-center justify-center">
            <img src="/logo.png" alt="Guaiqueríes Logo" width="32" height="32" class="w-full h-full object-contain" />
          </div>
          <span class="font-display text-lg font-black uppercase tracking-wider text-white drop-shadow-xs">
            Guaiqueríes
          </span>
        </div>

        <div class="flex items-center gap-2.5">
          <!-- Pearl Balance Badge -->
          <NuxtLink
            :to="{ name: 'app-billetera' }"
            aria-label="Ir a mi billetera de puntos"
            class="flex items-center gap-1.5 text-xs font-black text-amber-900 bg-amber-300 hover:bg-amber-200 border border-amber-400 px-2.5 py-1 rounded-full shadow-xs transition-colors"
          >
            <PearlIcon size="xs" animated />
            <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
          </NuxtLink>

          <!-- Notification Bell -->
          <NotificationBell variant="on-green" />

          <!-- User Avatar -->
          <NuxtLink
            :to="{ name: 'app-perfil' }"
            aria-label="Ir a mi perfil"
            class="w-8 h-8 rounded-full bg-white/20 border-2 border-white/60 text-white flex items-center justify-center font-bold text-xs overflow-hidden shrink-0 shadow-xs"
            title="Mi perfil"
          >
            <img
              v-if="authStore.profile?.avatar_url && !avatarError"
              :src="authStore.profile.avatar_url"
              :alt="authStore.profile?.display_name || 'Perfil'"
              width="32"
              height="32"
              class="w-full h-full object-cover"
              referrerpolicy="no-referrer"
              @error="avatarError = true"
            />
            <span v-else class="text-white font-extrabold">
              {{ authStore.profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
            </span>
          </NuxtLink>
        </div>
      </header>

      <!-- Page Content -->
      <main class="flex-1 p-4 md:p-8 max-w-5xl w-full mx-auto">
        <IncompleteProfileBanner />
        <slot />
      </main>
    </div>

    <!-- Mobile Bottom Navigation Bar -->
    <AppMobileNav />

    <!-- Mobile Navigation Drawer with all 12 options -->
    <AppMobileDrawer :is-open="isDrawerOpen" @close="isDrawerOpen = false" />

    <!-- Login Welcome Modal Carousel -->
    <LoginModalCarousel />
  </div>
</template>

