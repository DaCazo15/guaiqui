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
        'fixed lg:static top-0 bottom-0 left-0 z-50 w-64 h-full shrink-0 bg-white border-r border-gray-200 flex flex-col transition-transform duration-200 ease-in-out shadow-xs',
        isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="h-16 flex items-center justify-between px-5 lg:hidden border-b border-gray-200">
        <span class="font-bold text-gray-900 font-title">Menú de Taquilla</span>
        <button
          @click="emit('close')"
          class="p-1.5 text-gray-400 hover:text-gray-700 rounded-md"
          aria-label="Cerrar menú"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <nav class="flex-1 p-3.5 space-y-2 overflow-y-auto">
        <div class="px-3 py-1.5 text-xs font-bold text-gray-400 uppercase tracking-wider">
          Módulos de Taquilla
        </div>

        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="item.path"
          @click="emit('close')"
          :class="[
            'flex items-center gap-3 px-3 py-2.5 rounded-xl font-medium text-xs sm:text-sm transition-all duration-150',
            isActive(item.path)
              ? 'bg-emerald-50 text-emerald-800 font-semibold border-l-4 border-emerald-600 shadow-2xs'
              : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
          ]"
        >
          <i :class="['bi', item.icon, 'text-base', isActive(item.path) ? 'text-emerald-700' : 'text-gray-400']"></i>
          <span>{{ item.label }}</span>
        </RouterLink>

        <!-- Link back to Admin for users with admin role -->
        <div v-if="authStore.staffMember?.role === 'admin'" class="pt-4 border-t border-gray-200">
          <RouterLink
            to="/admin/dashboard"
            @click="emit('close')"
            class="flex items-center gap-2.5 px-3 py-2 rounded-xl font-semibold text-xs text-emerald-800 bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 transition-all shadow-2xs"
          >
            <i class="bi bi-speedometer2 text-base text-emerald-700"></i>
            <span>Volver a Panel Admin</span>
          </RouterLink>
        </div>
      </nav>

      <div class="p-3.5 border-t border-gray-200 text-xs text-gray-500 flex items-center justify-between bg-gray-50/50">
        <span class="font-medium text-gray-600">Guaiqueríes Taquilla</span>
        <span class="inline-flex items-center gap-1.5 text-emerald-700 font-mono text-[11px] font-semibold">
          <span class="w-2 h-2 rounded-full bg-emerald-600"></span> Operativo
        </span>
      </div>
    </aside>
  </div>
</template>

