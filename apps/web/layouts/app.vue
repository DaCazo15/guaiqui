<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { useSupabaseClient } from '#imports'
import type { RealtimeChannel } from '@supabase/supabase-js'
import AppSidebar from '~/components/app/AppSidebar.vue'
import AppMobileNav from '~/components/app/AppMobileNav.vue'
import AppMobileDrawer from '~/components/app/AppMobileDrawer.vue'
import NotificationBell from '~/components/app/NotificationBell.vue'
import LoginModalCarousel from '~/components/app/LoginModalCarousel.vue'
import IncompleteProfileBanner from '~/components/app/IncompleteProfileBanner.vue'
import TeamPickerModal from '~/components/team/TeamPickerModal.vue'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { BaseSkeletonLayout } from '@guaiqui/ui'

const authStore = useAuthStore()
const supabase = useSupabaseClient()
const avatarError = ref(false)
const isDrawerOpen = ref(false)
let walletChannel: RealtimeChannel | null = null

const currentBalance = computed(() => {
  return authStore.wallet?.balance_cache ?? 0
})

const onFocus = () => {
  if (authStore.isAuthenticated) {
    authStore.refreshWallet()
  }
}

onMounted(async () => {
  if (!authStore.profile) {
    await authStore.fetchProfile()
  }

  const userId = authStore.user?.id || authStore.profile?.id
  if (userId && supabase?.channel) {
    walletChannel = supabase
      .channel(`realtime-wallets-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'wallets',
          filter: `fan_id=eq.${userId}`,
        },
        () => {
          authStore.refreshWallet()
        }
      )
      .subscribe()
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('focus', onFocus)
  }
})

onBeforeUnmount(() => {
  if (walletChannel && supabase?.removeChannel) {
    supabase.removeChannel(walletChannel)
  }
  if (typeof window !== 'undefined') {
    window.removeEventListener('focus', onFocus)
  }
})
</script>

<template>
  <div v-if="authStore.isLoading && !authStore.profile">
    <BaseSkeletonLayout :dark="true" :show-sidebar="true" />
  </div>

  <div v-else class="min-h-screen bg-guaiqui-surface text-guaiqui-text flex flex-col lg:flex-row">
    <!-- Desktop Sidebar -->
    <AppSidebar />

    <!-- Main Content Area with safe area padding -->
    <div
      class="flex-1 flex flex-col min-w-0 lg:pb-6"
      style="padding-bottom: calc(5.5rem + env(safe-area-inset-bottom, 0px));"
    >
      <!-- Mobile & Tablet Top Header: Obsidiana y Cian estilo FanActivo -->
      <header class="lg:hidden sticky top-0 z-50 bg-[#071318]/95 border-b border-cyan-950/80 shadow-lg px-4 py-2.5 flex items-center justify-between text-white backdrop-blur-md">
        <div class="flex items-center gap-2.5">
          <!-- Mobile Menu Drawer Toggle Button -->
          <button
            type="button"
            @click="isDrawerOpen = !isDrawerOpen"
            :aria-label="isDrawerOpen ? 'Cerrar menú de navegación' : 'Abrir menú de navegación'"
            class="w-9 h-9 rounded-xl flex items-center justify-center text-cyan-300 hover:text-white hover:bg-cyan-950/60 active:scale-95 transition-all cursor-pointer -ml-1 border border-cyan-800/60 bg-[#0c1e24] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
          >
            <i :class="isDrawerOpen ? 'bi bi-x-lg text-lg' : 'bi bi-list text-2xl'" class="leading-none"></i>
          </button>

          <NuxtLink to="/" class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-white shadow-md shadow-orange-500/20 shrink-0">
              <i class="bi bi-fire text-base"></i>
            </div>
            <div>
              <div class="flex items-baseline gap-0.5">
                <span class="font-title font-black text-sm tracking-wider text-white leading-none">FAN</span>
                <span class="font-title font-black text-sm tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-amber-400 leading-none">ACTIVO</span>
              </div>
              <span class="text-[9px] text-cyan-400 font-bold tracking-widest uppercase block leading-none mt-0.5">
                Fan Zone
              </span>
            </div>
          </NuxtLink>
        </div>

        <div class="flex items-center gap-2.5">
          <!-- Pearl Balance Badge -->
          <NuxtLink
            :to="{ name: 'app-billetera' }"
            aria-label="Ir a mi billetera de puntos"
            class="flex items-center gap-1.5 text-xs font-black text-amber-950 bg-amber-300 hover:bg-amber-200 border border-amber-400 px-2.5 py-1 rounded-full shadow-xs transition-colors"
          >
            <PearlIcon size="xs" animated />
            <span>{{ formatPerlitas(currentBalance) }}</span>
          </NuxtLink>

          <!-- Notification Bell -->
          <NotificationBell variant="on-green" />

          <!-- User Avatar -->
          <NuxtLink
            :to="{ name: 'app-perfil' }"
            aria-label="Ir a mi perfil"
            class="w-8 h-8 rounded-full bg-[#0c1e24] border-2 border-orange-500/70 ring-1 ring-cyan-500/30 text-white flex items-center justify-center font-bold text-xs overflow-hidden shrink-0 shadow-xs"
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

    <!-- Team Selection Modal for Trivias / Tienda -->
    <TeamPickerModal />

    <!-- Login Welcome Modal Carousel -->
    <LoginModalCarousel />
  </div>
</template>

