<script setup lang="ts">
import { RouterLink, useRoute } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const route = useRoute()
const authStore = useAuthStore()

const navItems = [
  { name: 'staff-queue', path: '/staff/cola', label: 'Cola de Canjes', icon: 'bi-list-check' },
  { name: 'staff-scanner', path: '/staff/escaner', label: 'Escáner QR', icon: 'bi-qr-code-scan' },
  { name: 'staff-issues', path: '/staff/incidencias', label: 'Incidencias', icon: 'bi-exclamation-triangle' },
  { name: 'staff-inventory', path: '/staff/inventario', label: 'Inventario', icon: 'bi-box-seam' },
  { name: 'staff-fans', path: '/staff/fanaticos', label: 'Consulta de Fans', icon: 'bi-people' },
]

const isActive = (path: string) => route.path.startsWith(path)
</script>

<template>
  <div>
    <!-- Backdrop for mobile drawer -->
    <div
      v-if="isOpen"
      @click="emit('close')"
      class="fixed inset-0 bg-black/40 backdrop-blur-2xs z-40 lg:hidden transition-opacity"
    ></div>

    <!-- Sidebar menu container -->
    <aside
      :class="[
        'fixed lg:static top-0 bottom-0 left-0 z-50 w-64 h-full shrink-0 bg-slate-900 border-r border-slate-800 flex flex-col transition-transform duration-200 ease-in-out shadow-xl',
        isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="h-16 flex items-center justify-between px-5 lg:hidden border-b border-slate-800">
        <span class="font-bold text-white font-title">Menú de Taquilla</span>
        <button
          @click="emit('close')"
          class="p-1.5 text-slate-400 hover:text-white rounded-md"
          aria-label="Cerrar menú"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <nav class="flex-1 p-3.5 space-y-2 overflow-y-auto">
        <div class="px-3 py-1.5 text-xs font-bold text-slate-400 uppercase tracking-wider">
          Módulos de Taquilla
        </div>

        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="{ name: item.name }"
          @click="emit('close')"
          :class="[
            'flex items-center gap-3 px-3 py-2.5 rounded-xl font-medium text-xs sm:text-sm transition-all duration-150',
            isActive(item.path)
              ? 'bg-emerald-950/80 text-emerald-300 font-semibold border-l-4 border-emerald-500 shadow-inner'
              : 'text-slate-400 hover:bg-slate-800/80 hover:text-slate-200'
          ]"
        >
          <i :class="['bi', item.icon, 'text-base', isActive(item.path) ? 'text-emerald-400' : 'text-slate-500']"></i>
          <span>{{ item.label }}</span>
        </RouterLink>

        <!-- Link back to Admin for users with admin role -->
        <div v-if="authStore.staffMember?.role === 'admin'" class="pt-4 border-t border-slate-800">
          <RouterLink
            :to="{ name: 'admin-dashboard' }"
            @click="emit('close')"
            class="flex items-center gap-2.5 px-3 py-2 rounded-xl font-semibold text-xs text-emerald-300 bg-emerald-950/80 hover:bg-emerald-900/80 border border-emerald-700 transition-all shadow-inner"
          >
            <i class="bi bi-speedometer2 text-base text-emerald-400"></i>
            <span>Volver a Panel Admin</span>
          </RouterLink>
        </div>
      </nav>

      <div class="p-3.5 border-t border-slate-800 text-xs text-slate-400 flex items-center justify-between bg-slate-950/40">
        <span class="font-medium text-slate-400">Guaiqueríes Taquilla</span>
        <span class="inline-flex items-center gap-1.5 text-emerald-400 font-mono text-[11px] font-semibold">
          <span class="w-2 h-2 rounded-full bg-emerald-500"></span> Operativo
        </span>
      </div>
    </aside>
  </div>
</template>

