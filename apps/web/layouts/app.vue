<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import AppSidebar from '~/components/app/AppSidebar.vue'
import AppMobileNav from '~/components/app/AppMobileNav.vue'
import NotificationBell from '~/components/app/NotificationBell.vue'
import LoginModalCarousel from '~/components/app/LoginModalCarousel.vue'
import IncompleteProfileBanner from '~/components/app/IncompleteProfileBanner.vue'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { BaseSkeletonLayout } from '@guaiqui/ui'

const authStore = useAuthStore()
const avatarError = ref(false)

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

    <!-- Main Content Area -->
    <div class="flex-1 flex flex-col min-w-0 pb-20 md:pb-6">
      <!-- Mobile Top Header -->
      <header class="md:hidden sticky top-0 z-30 bg-white/95 border-b border-guaiqui-border backdrop-blur-lg px-4 py-3 flex items-center justify-between shadow-guaiqui-sm">
        <div class="flex items-center gap-2">
          <img src="/logo.png" alt="Guaiqueríes Logo" class="w-8 h-8 object-contain shrink-0" />
          <span class="font-display text-base font-bold uppercase tracking-wider text-guaiqui-text">
            Guaiqueríes
          </span>
        </div>

        <div class="flex items-center gap-2">
          <!-- Pearl Balance Badge -->
          <NuxtLink to="/app/billetera" class="flex items-center gap-1.5 text-xs font-bold text-guaiqui-perlita bg-guaiqui-perlita-soft border border-guaiqui-perlita/20 px-2.5 py-1 rounded-full">
            <PearlIcon size="xs" animated />
            <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
          </NuxtLink>

          <!-- Notification Bell -->
          <NotificationBell />

          <NuxtLink
            to="/app/perfil"
            class="w-8 h-8 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary flex items-center justify-center font-bold text-xs overflow-hidden shrink-0"
            title="Mi perfil"
          >
            <img
              v-if="authStore.profile?.avatar_url && !avatarError"
              :src="authStore.profile.avatar_url"
              :alt="authStore.profile?.display_name || 'Perfil'"
              class="w-full h-full object-cover"
              referrerpolicy="no-referrer"
              @error="avatarError = true"
            />
            <span v-else>
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

    <!-- Login Welcome Modal Carousel -->
    <LoginModalCarousel />
  </div>
</template>

