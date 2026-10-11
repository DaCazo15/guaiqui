<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

defineEmits<{
  (e: 'toggleSidebar'): void
}>()

const isAdminRoute = computed(() => route.path.startsWith('/admin'))

const staffRoleLabel = computed(() => {
  if (authStore.staffMember?.role === 'admin') return 'Administrador'
  return 'Personal de Taquilla'
})

const handleSignOut = async () => {
  await authStore.signOut('Sesión cerrada correctamente.')
  router.replace({ name: 'login' })
}
</script>

<template>
  <header class="h-16 bg-white border-b border-gray-200 text-gray-900 flex items-center justify-between px-4 sm:px-6 sticky top-0 z-30 shadow-2xs">
    <!-- Brand & Mobile toggle -->
    <div class="flex items-center gap-3">
      <button 
        @click="$emit('toggleSidebar')"
        class="lg:hidden p-2 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500"
        aria-label="Abrir menú"
      >
        <i class="bi bi-list text-2xl"></i>
      </button>

      <div class="flex items-center gap-2.5">
        <img src="/logo.png" alt="Guaiqueríes de Margarita" class="w-9 h-9 object-contain shrink-0" />
        <div class="flex items-center gap-2">
          <span class="font-bold text-lg tracking-wide text-gray-900 font-title hidden sm:inline-block">Guaiqueríes</span>
          <span 
            v-if="isAdminRoute"
            class="text-xs uppercase px-2.5 py-0.5 bg-emerald-50 text-emerald-800 border border-emerald-300 rounded-full font-semibold tracking-wider font-mono"
          >
            Panel Admin
          </span>
          <span 
            v-else
            class="text-xs uppercase px-2.5 py-0.5 bg-blue-50 text-blue-800 border border-blue-300 rounded-full font-semibold tracking-wider font-mono"
          >
            Taquilla / Staff
          </span>
        </div>
      </div>
    </div>

    <!-- Actions & User Profile -->
    <div class="flex items-center gap-3 sm:gap-4">
      <!-- Switcher for admin role -->
      <RouterLink
        v-if="authStore.staffMember?.role === 'admin' && isAdminRoute"
        to="/staff/cola"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-gray-700 bg-gray-100 hover:bg-emerald-50 hover:text-emerald-800 border border-gray-300 hover:border-emerald-300 rounded-lg transition-all"
        title="Ir al panel operativo de taquilla"
      >
        <i class="bi bi-ticket-perforated text-sm text-emerald-700"></i>
        <span class="hidden md:inline">Panel Taquilla</span>
      </RouterLink>

      <RouterLink
        v-else-if="authStore.staffMember?.role === 'admin' && !isAdminRoute"
        to="/admin/dashboard"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-emerald-800 bg-emerald-50 hover:bg-emerald-100 border border-emerald-300 rounded-lg transition-all shadow-2xs"
        title="Volver al panel de administración"
      >
        <i class="bi bi-speedometer2 text-sm text-emerald-700"></i>
        <span>Volver a Admin</span>
      </RouterLink>

      <div class="flex items-center gap-2.5 text-right pl-2 border-l border-gray-200">
        <div class="hidden md:block">
          <div class="font-semibold text-sm text-gray-900">{{ authStore.staffMember?.display_name }}</div>
          <div class="text-xs text-emerald-700 font-medium">{{ staffRoleLabel }}</div>
        </div>
        <div class="w-9 h-9 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 flex items-center justify-center font-semibold">
          <i class="bi bi-person-badge text-lg"></i>
        </div>
      </div>

      <button
        @click="handleSignOut"
        class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-gray-600 hover:text-red-700 bg-gray-50 hover:bg-red-50 border border-gray-200 hover:border-red-200 rounded-lg transition-all"
        title="Cerrar sesión"
      >
        <i class="bi bi-box-arrow-right text-sm"></i>
        <span class="hidden sm:inline">Salir</span>
      </button>
    </div>
  </header>
</template>
