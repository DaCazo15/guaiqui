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
  <header class="h-16 bg-slate-900 border-b border-slate-800 text-slate-100 flex items-center justify-between px-4 sm:px-6 sticky top-0 z-30 shadow-md">
    <!-- Brand & Mobile toggle -->
    <div class="flex items-center gap-3">
      <button 
        class="lg:hidden p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500"
        aria-label="Abrir menú"
        @click="$emit('toggleSidebar')"
      >
        <i class="bi bi-list text-2xl"></i>
      </button>

      <div class="flex items-center gap-2.5">
        <img src="/logo.png" alt="Guaiqueríes de Margarita" class="w-9 h-9 object-contain shrink-0" />
        <div class="flex items-center gap-2">
          <span class="font-bold text-lg tracking-wide text-white font-title hidden sm:inline-block">Guaiqueríes</span>
          <span 
            v-if="isAdminRoute"
            class="text-xs uppercase px-2.5 py-0.5 bg-emerald-950/80 text-emerald-400 border border-emerald-800 rounded-full font-semibold tracking-wider font-mono"
          >
            Panel Admin
          </span>
          <span 
            v-else
            class="text-xs uppercase px-2.5 py-0.5 bg-blue-950/80 text-blue-400 border border-blue-800 rounded-full font-semibold tracking-wider font-mono"
          >
            Panel Taquilla
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
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-300 bg-slate-800 hover:bg-emerald-950/80 hover:text-emerald-400 border border-slate-700 hover:border-emerald-700 rounded-lg transition-all"
        title="Ir al panel operativo de taquilla"
      >
        <i class="bi bi-ticket-perforated text-sm text-emerald-400"></i>
        <span class="hidden md:inline">Panel Taquilla</span>
      </RouterLink>

      <RouterLink
        v-else-if="authStore.staffMember?.role === 'admin' && !isAdminRoute"
        to="/admin/dashboard"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-emerald-300 bg-emerald-950/80 hover:bg-emerald-900/80 border border-emerald-700 rounded-lg transition-all shadow-inner"
        title="Volver al panel de administración"
      >
        <i class="bi bi-speedometer2 text-sm text-emerald-400"></i>
        <span>Volver a Admin</span>
      </RouterLink>

      <div class="flex items-center gap-2.5 text-right pl-2 border-l border-slate-800">
        <div class="hidden md:block">
          <div class="font-semibold text-sm text-slate-200">{{ authStore.staffMember?.display_name }}</div>
          <div class="text-xs text-emerald-400 font-medium">{{ staffRoleLabel }}</div>
        </div>
        <div class="w-9 h-9 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-semibold">
          <i class="bi bi-person-badge text-lg"></i>
        </div>
      </div>

      <button
        class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-400 hover:text-red-300 bg-slate-800/80 hover:bg-red-950/60 border border-slate-700 hover:border-red-800 rounded-lg transition-all"
        title="Cerrar sesión"
        @click="handleSignOut"
      >
        <i class="bi bi-box-arrow-right text-sm"></i>
        <span class="hidden sm:inline">Salir</span>
      </button>
    </div>
  </header>
</template>
