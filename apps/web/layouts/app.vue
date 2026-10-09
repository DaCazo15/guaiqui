<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import AppSidebar from '~/components/app/AppSidebar.vue'
import AppMobileNav from '~/components/app/AppMobileNav.vue'
import NotificationBell from '~/components/app/NotificationBell.vue'
import { formatPerlitas } from '@guaiqui/shared'

const authStore = useAuthStore()

onMounted(async () => {
  if (!authStore.profile) {
    await authStore.fetchProfile()
  }
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-surface text-guaiqui-text flex flex-col md:flex-row">
    <!-- Desktop Sidebar -->
    <AppSidebar />

    <!-- Main Content Area -->
    <div class="flex-1 flex flex-col min-w-0 pb-20 md:pb-6">
      <!-- Mobile Top Header -->
      <header class="md:hidden sticky top-0 z-30 bg-white/95 border-b border-guaiqui-border backdrop-blur-lg px-4 py-3 flex items-center justify-between shadow-guaiqui-sm">
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-lg">
            <i class="bi bi-dribbble"></i>
          </div>
          <span class="font-display text-base font-bold uppercase tracking-wider text-guaiqui-text">
            Guaiqueríes
          </span>
        </div>

        <div class="flex items-center gap-2">
          <!-- Pearl Balance Badge -->
          <NuxtLink to="/app/billetera" class="flex items-center gap-1.5 text-xs font-bold text-guaiqui-perlita bg-guaiqui-perlita-soft border border-guaiqui-perlita/20 px-2.5 py-1 rounded-full">
            <i class="bi bi-circle-fill text-[10px]"></i>
            <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
          </NuxtLink>

          <!-- Notification Bell -->
          <NotificationBell />

          <NuxtLink to="/app/perfil" class="w-8 h-8 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary flex items-center justify-center font-bold text-xs">
            {{ authStore.profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
          </NuxtLink>
        </div>
      </header>

      <!-- Page Content -->
      <main class="flex-1 p-4 md:p-8 max-w-5xl w-full mx-auto">
        <slot />
      </main>
    </div>

    <!-- Mobile Bottom Navigation Bar -->
    <AppMobileNav />
  </div>
</template>
