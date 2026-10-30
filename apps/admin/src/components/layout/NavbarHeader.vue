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

      <!-- Platform Admin: Team Selector -->
      <div v-if="authStore.isPlatformAdmin && authStore.availableTeams.length > 0" class="flex items-center gap-2 pl-2 sm:pl-3 border-l border-slate-800">
        <label for="platform-team-select" class="text-xs font-semibold text-emerald-400 hidden xl:inline-flex items-center gap-1">
          <i class="bi bi-shield-shaded"></i> Club activo:
        </label>
        <div class="relative">
          <select
            id="platform-team-select"
            :value="authStore.selectedTeamId"
            @change="e => authStore.setSelectedTeamId((e.target as HTMLSelectElement).value)"
            class="bg-slate-800/90 hover:bg-slate-850 text-slate-200 text-xs font-semibold rounded-lg pl-2.5 pr-7 py-1.5 border border-slate-700 hover:border-emerald-600 focus:outline-none focus:ring-2 focus:ring-emerald-500 appearance-none cursor-pointer transition-all shadow-inner max-w-[200px] sm:max-w-[260px] truncate"
          >
            <option v-for="team in authStore.availableTeams" :key="team.id" :value="team.id">
              {{ team.name }} {{ team.status === 'inactive' ? '(Inactivo)' : '' }}
            </option>
          </select>
          <i class="bi bi-chevron-down absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none text-[10px]"></i>
        </div>
      </div>
    </div>

    <!-- Actions & User Profile -->
    <div class="flex items-center gap-3 sm:gap-4">
      <!-- Switcher for admin role -->
      <RouterLink
        v-if="authStore.staffMember?.role === 'admin' && isAdminRoute"
        :to="{ name: 'staff-queue' }"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-300 bg-slate-800 hover:bg-emerald-950/80 hover:text-emerald-400 border border-slate-700 hover:border-emerald-700 rounded-lg transition-all"
        title="Ir al panel operativo de taquilla"
      >
        <i class="bi bi-ticket-perforated text-sm text-emerald-400"></i>
        <span class="hidden md:inline">Panel Taquilla</span>
      </RouterLink>

      <RouterLink
        v-else-if="authStore.staffMember?.role === 'admin' && !isAdminRoute"
        :to="{ name: 'admin-dashboard' }"
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
