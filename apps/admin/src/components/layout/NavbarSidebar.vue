<script setup lang="ts">
import { RouterLink, useRoute } from 'vue-router'

defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const route = useRoute()

const navItems = [
  { name: 'staff-queue', path: '/staff/cola', label: 'Cola de Canjes', icon: 'bi-list-check' },
  { name: 'staff-scanner', path: '/staff/escaner', label: 'Escáner QR', icon: 'bi-qr-code-scan' },
  { name: 'staff-trivia', path: '/staff/trivia', label: 'Gestión de Trivias', icon: 'bi-question-circle' },
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
      class="fixed inset-0 bg-slate-950/70 backdrop-blur-xs z-40 lg:hidden transition-opacity"
    ></div>

    <!-- Sidebar menu container -->
    <aside
      :class="[
        'fixed lg:static top-0 bottom-0 left-0 z-50 w-64 bg-slate-900 border-r border-slate-800 flex flex-col transition-transform duration-200 ease-in-out',
        isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="h-16 flex items-center justify-between px-6 lg:hidden border-b border-slate-800">
        <span class="font-bold text-slate-100">Menú de Taquilla</span>
        <button
          @click="emit('close')"
          class="p-1.5 text-slate-400 hover:text-white rounded-md"
          aria-label="Cerrar menú"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <nav class="flex-1 p-4 space-y-1.5 overflow-y-auto">
        <div class="px-3 py-2 text-xs font-semibold text-slate-500 uppercase tracking-wider">
          Módulos de Taquilla
        </div>

        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="item.path"
          @click="emit('close')"
          :class="[
            'flex items-center gap-3 px-3.5 py-2.5 rounded-xl font-medium text-sm transition-all duration-150',
            isActive(item.path)
              ? 'bg-emerald-600/15 text-emerald-400 border border-emerald-500/30 shadow-xs'
              : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
          ]"
        >
          <i :class="['bi', item.icon, 'text-lg', isActive(item.path) ? 'text-emerald-400' : 'text-slate-400']"></i>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>

      <div class="p-4 border-t border-slate-800 text-xs text-slate-500 flex items-center justify-between">
        <span>Guaiqueríes v1.0</span>
        <span class="inline-flex items-center gap-1 text-emerald-500 font-mono">
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> Sistema Activo
        </span>
      </div>
    </aside>
  </div>
</template>
