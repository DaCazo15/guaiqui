<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

defineEmits<{
  (e: 'toggleSidebar'): void
}>()

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
  <header class="h-16 bg-slate-900 border-b border-slate-800 text-white flex items-center justify-between px-4 sm:px-6 sticky top-0 z-30">
    <div class="flex items-center gap-3">
      <button 
        @click="$emit('toggleSidebar')"
        class="lg:hidden p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500"
        aria-label="Abrir menú"
      >
        <i class="bi bi-list text-2xl"></i>
      </button>

      <div class="flex items-center gap-2">
        <img src="/logo.png" alt="Guaiqueríes Staff Logo" class="w-8 h-8 object-contain shrink-0" />
        <span class="font-bold text-lg tracking-wide hidden sm:inline-block">Guaiqueríes <span class="text-emerald-400 text-xs uppercase px-2 py-0.5 bg-emerald-950 border border-emerald-800 rounded-full font-mono ml-1">Staff</span></span>
      </div>
    </div>

    <div class="flex items-center gap-4">
      <div class="flex items-center gap-3 text-right">
        <div class="hidden md:block">
          <div class="font-semibold text-sm text-slate-100">{{ authStore.staffMember?.display_name }}</div>
          <div class="text-xs text-emerald-400 font-medium">{{ staffRoleLabel }}</div>
        </div>
        <div class="w-9 h-9 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-semibold">
          <i class="bi bi-person-badge text-lg"></i>
        </div>
      </div>

      <button
        @click="handleSignOut"
        class="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-300 hover:text-red-400 bg-slate-800 hover:bg-red-950/40 border border-slate-700 hover:border-red-900/50 rounded-lg transition-all"
        title="Cerrar sesión"
      >
        <i class="bi bi-box-arrow-right text-sm"></i>
        <span class="hidden sm:inline">Salir</span>
      </button>
    </div>
  </header>
</template>
