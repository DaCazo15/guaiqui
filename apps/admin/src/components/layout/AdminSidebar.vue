<script setup lang="ts">
import { RouterLink, useRoute } from 'vue-router'

defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const route = useRoute()

const platformNavItems = [
  { name: 'admin-dashboard', path: '/admin/dashboard', label: 'Dashboard', icon: 'bi-speedometer2' },
  { name: 'admin-analitica', path: '/admin/analitica', label: 'Analítica', icon: 'bi-bar-chart-line-fill' },
  { name: 'admin-trivias', path: '/admin/trivias', label: 'Trivias', icon: 'bi-question-circle' },
  { name: 'admin-productos', path: '/admin/productos', label: 'Productos', icon: 'bi-box-seam' },
  { name: 'admin-economia', path: '/admin/economia', label: 'Economía', icon: 'bi-coin' },
  { name: 'admin-personal', path: '/admin/personal', label: 'Personal & Roles', icon: 'bi-person-gear' },
  { name: 'admin-fanaticos', path: '/admin/fanaticos', label: 'Fanáticos', icon: 'bi-people' },
  { name: 'admin-segmentos', path: '/admin/segmentos', label: 'Segmentos', icon: 'bi-pie-chart' },
  { name: 'admin-riesgo', path: '/admin/riesgo', label: 'Control Riesgo', icon: 'bi-shield-exclamation' },
  { name: 'admin-incidencias', path: '/admin/incidencias', label: 'Incidencias', icon: 'bi-exclamation-triangle' },
  { name: 'admin-auditoria', path: '/admin/auditoria', label: 'Auditoría', icon: 'bi-shield-check' }
]

const cmsNavItems = [
  { name: 'admin-landing', path: '/admin/landing', label: 'Landing & Hero (Tema)', icon: 'bi-layout-text-window-reverse' },
  { name: 'admin-carrusel', path: '/admin/carrusel', label: 'Carrusel Hero', icon: 'bi-images' },
  { name: 'admin-partidos', path: '/admin/partidos', label: 'Partidos & Clasificación', icon: 'bi-calendar-event' },
  { name: 'admin-jugadores', path: '/admin/jugadores', label: 'Plantilla Jugadores', icon: 'bi-person-bounding-box' },
  { name: 'admin-equipo', path: '/admin/equipo', label: 'Cuerpo Técnico & Staff', icon: 'bi-person-lines-fill' },
  { name: 'admin-instagram', path: '/admin/instagram', label: 'Mosaico Instagram', icon: 'bi-instagram' },
  { name: 'admin-anuncios', path: '/admin/anuncios', label: 'Cinta Anuncios', icon: 'bi-megaphone' },
  { name: 'admin-faq', path: '/admin/faq', label: 'Preguntas FAQ', icon: 'bi-patch-question' },
  { name: 'admin-historia', path: '/admin/historia', label: 'Historia', icon: 'bi-hourglass-split' },
  { name: 'admin-politicas', path: '/admin/politicas', label: 'Políticas Legales', icon: 'bi-journal-check' },
  { name: 'admin-cumpleanos', path: '/admin/cumpleanos', label: 'Saludo Cumpleaños', icon: 'bi-gift' }
]

const isActive = (path: string) => route.path.startsWith(path)
</script>

<template>
  <div>
    <!-- Backdrop for mobile -->
    <div
      v-if="isOpen"
      @click="emit('close')"
      class="fixed inset-0 bg-slate-950/70 backdrop-blur-xs z-40 lg:hidden transition-opacity"
    ></div>

    <aside
      :class="[
        'fixed lg:static top-0 bottom-0 left-0 z-50 w-64 h-full shrink-0 bg-slate-900 border-r border-slate-800 flex flex-col transition-transform duration-200 ease-in-out',
        isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="h-16 flex items-center justify-between px-6 lg:hidden border-b border-slate-800">
        <div class="flex items-center gap-2">
          <img src="/logo.png" alt="Guaiqueríes Admin Logo" class="w-7 h-7 object-contain shrink-0" />
          <span class="font-bold text-slate-100">Menú Administrador</span>
        </div>
        <button
          @click="emit('close')"
          class="p-1.5 text-slate-400 hover:text-white rounded-md"
          aria-label="Cerrar menú"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <div class="px-5 py-4 border-b border-slate-800 hidden lg:flex items-center gap-3">
        <img src="/logo.png" alt="Guaiqueríes Admin Logo" class="w-9 h-9 object-contain shrink-0" />
        <div>
          <span class="font-bold text-slate-100 text-sm tracking-wide block">Guaiqueríes</span>
          <span class="text-[11px] text-emerald-400 font-mono font-semibold uppercase">Panel Admin</span>
        </div>
      </div>

      <nav class="flex-1 p-4 space-y-6 overflow-y-auto">
        <!-- Section 1: Platform & Operations -->
        <div class="space-y-1">
          <div class="px-3 py-1 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            Operaciones & Fanáticos
          </div>
          <RouterLink
            v-for="item in platformNavItems"
            :key="item.name"
            :to="item.path"
            @click="emit('close')"
            :class="[
              'flex items-center gap-3 px-3.5 py-2 rounded-xl font-medium text-sm transition-all duration-150',
              isActive(item.path)
                ? 'bg-emerald-600/15 text-emerald-400 border border-emerald-500/30 shadow-xs'
                : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
            ]"
          >
            <i :class="['bi', item.icon, 'text-lg', isActive(item.path) ? 'text-emerald-400' : 'text-slate-400']"></i>
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>

        <!-- Section 2: CMS & Landing -->
        <div class="space-y-1 pt-3 border-t border-slate-800">
          <div class="px-3 py-1 text-[11px] font-bold text-emerald-400 uppercase tracking-wider flex items-center gap-1.5">
            <i class="bi bi-window-sidebar"></i> CMS Landing Pública
          </div>
          <RouterLink
            v-for="item in cmsNavItems"
            :key="item.name"
            :to="item.path"
            @click="emit('close')"
            :class="[
              'flex items-center gap-3 px-3.5 py-2 rounded-xl font-medium text-sm transition-all duration-150',
              isActive(item.path)
                ? 'bg-emerald-600/15 text-emerald-400 border border-emerald-500/30 shadow-xs'
                : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
            ]"
          >
            <i :class="['bi', item.icon, 'text-lg', isActive(item.path) ? 'text-emerald-400' : 'text-slate-400']"></i>
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>

        <div class="pt-4 border-t border-slate-800">
          <RouterLink
            to="/staff/cola"
            @click="emit('close')"
            class="flex items-center gap-3 px-3.5 py-2 rounded-xl font-medium text-xs text-slate-400 hover:bg-slate-800 hover:text-slate-200 transition-all"
          >
            <i class="bi bi-ticket-perforated text-base text-slate-400"></i>
            <span>Ir a Panel de Taquilla</span>
          </RouterLink>
        </div>
      </nav>

      <div class="p-4 border-t border-slate-800 text-xs text-slate-500 flex items-center justify-between">
        <span>Guaiqueríes Admin</span>
        <span class="inline-flex items-center gap-1 text-emerald-500 font-mono">
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> Admin Mode
        </span>
      </div>
    </aside>
  </div>
</template>
