<script setup lang="ts">
import { ref, onMounted, nextTick, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const route = useRoute()
const navRef = ref<HTMLElement | null>(null)

const platformNavItems = [
  { name: 'admin-dashboard', path: '/admin/dashboard', label: 'Dashboard', icon: 'bi-speedometer2' },
  { name: 'admin-analitica', path: '/admin/analitica', label: 'Analítica', icon: 'bi-bar-chart-line-fill' },
  { name: 'admin-trivias', path: '/admin/trivias', label: 'Trivias', icon: 'bi-question-circle' },
  { name: 'admin-productos', path: '/admin/productos', label: 'Productos', icon: 'bi-box-seam' },
  { name: 'admin-economia', path: '/admin/economia', label: 'Economía', icon: 'bi-coin' },
  { name: 'admin-rewarded-ads', path: '/admin/anuncios-recompensados', label: 'Anuncios Recompensados', icon: 'bi-play-btn-fill' },
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
  { name: 'admin-login-modal', path: '/admin/contenido/modal-de-bienvenida', label: 'Pop-up Bienvenida (5 Anuncios)', icon: 'bi-window-stack' },
  { name: 'admin-anuncios', path: '/admin/anuncios', label: 'Cinta Anuncios (Marquee)', icon: 'bi-megaphone' },
  { name: 'admin-partidos', path: '/admin/partidos', label: 'Partidos & Clasificación', icon: 'bi-calendar-event' },
  { name: 'admin-jugadores', path: '/admin/jugadores', label: 'Plantilla Jugadores', icon: 'bi-person-bounding-box' },
  { name: 'admin-equipo', path: '/admin/equipo', label: 'Cuerpo Técnico & Staff', icon: 'bi-person-lines-fill' },
  { name: 'admin-instagram', path: '/admin/instagram', label: 'Mosaico Instagram', icon: 'bi-instagram' },
  { name: 'admin-faq', path: '/admin/faq', label: 'Preguntas FAQ', icon: 'bi-patch-question' },
  { name: 'admin-historia', path: '/admin/historia', label: 'Historia', icon: 'bi-hourglass-split' },
  { name: 'admin-politicas', path: '/admin/politicas', label: 'Políticas Legales', icon: 'bi-journal-check' },
  { name: 'admin-cumpleanos', path: '/admin/cumpleanos', label: 'Saludo Cumpleaños', icon: 'bi-gift' }
]

const isActive = (path: string) => route.path.startsWith(path)

const handleNavScroll = () => {
  if (navRef.value) {
    sessionStorage.setItem('admin_sidebar_scroll', String(navRef.value.scrollTop))
  }
}

const restoreScroll = () => {
  nextTick(() => {
    const saved = sessionStorage.getItem('admin_sidebar_scroll')
    if (saved && navRef.value) {
      navRef.value.scrollTop = Number(saved)
    }
  })
}

onMounted(() => {
  restoreScroll()
})

watch(() => route.path, () => {
  restoreScroll()
})
</script>

<template>
  <div>
    <!-- Backdrop for mobile -->
    <div
      v-if="isOpen"
      @click="emit('close')"
      class="fixed inset-0 bg-black/40 backdrop-blur-2xs z-40 lg:hidden transition-opacity"
    ></div>

    <aside
      :class="[
        'fixed lg:static top-0 bottom-0 left-0 z-50 w-64 h-full shrink-0 bg-white border-r border-gray-200 flex flex-col transition-transform duration-200 ease-in-out shadow-xs',
        isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <!-- Mobile Header with Close button -->
      <div class="h-16 flex items-center justify-between px-5 lg:hidden border-b border-gray-200">
        <div class="flex items-center gap-2">
          <img src="/logo.png" alt="Guaiqueríes Logo" class="w-7 h-7 object-contain shrink-0" />
          <span class="font-bold text-gray-900 font-title">Menú Administrador</span>
        </div>
        <button
          @click="emit('close')"
          class="p-1.5 text-gray-400 hover:text-gray-700 rounded-md"
          aria-label="Cerrar menú"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <nav
        ref="navRef"
        @scroll="handleNavScroll"
        class="flex-1 p-3.5 space-y-6 overflow-y-auto"
      >
        <!-- Section 1: Platform & Operations -->
        <div class="space-y-1">
          <div class="px-3 py-1.5 text-[11px] font-bold text-gray-400 uppercase tracking-wider">
            Operaciones & Fanáticos
          </div>
          <RouterLink
            v-for="item in platformNavItems"
            :key="item.name"
            :to="item.path"
            @click="emit('close')"
            :class="[
              'flex items-center gap-3 px-3 py-2 rounded-xl font-medium text-xs sm:text-sm transition-all duration-150',
              isActive(item.path)
                ? 'bg-emerald-50 text-emerald-800 font-semibold border-l-4 border-emerald-600 shadow-2xs'
                : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
            ]"
          >
            <i :class="['bi', item.icon, 'text-base', isActive(item.path) ? 'text-emerald-700' : 'text-gray-400']"></i>
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>

        <!-- Section 2: CMS & Landing -->
        <div class="space-y-1 pt-3 border-t border-gray-200">
          <div class="px-3 py-1.5 text-[11px] font-bold text-emerald-800 uppercase tracking-wider flex items-center gap-1.5">
            <i class="bi bi-window-sidebar text-emerald-600"></i> CMS Landing Pública
          </div>
          <RouterLink
            v-for="item in cmsNavItems"
            :key="item.name"
            :to="item.path"
            @click="emit('close')"
            :class="[
              'flex items-center gap-3 px-3 py-2 rounded-xl font-medium text-xs sm:text-sm transition-all duration-150',
              isActive(item.path)
                ? 'bg-emerald-50 text-emerald-800 font-semibold border-l-4 border-emerald-600 shadow-2xs'
                : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
            ]"
          >
            <i :class="['bi', item.icon, 'text-base', isActive(item.path) ? 'text-emerald-700' : 'text-gray-400']"></i>
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>

        <!-- Section 3: Switch to Staff / Operations -->
        <div class="pt-3 border-t border-gray-200">
          <RouterLink
            to="/staff/cola"
            @click="emit('close')"
            class="flex items-center gap-2.5 px-3 py-2 rounded-xl font-semibold text-xs text-gray-700 hover:bg-emerald-50 hover:text-emerald-800 border border-gray-200 hover:border-emerald-300 transition-all"
          >
            <i class="bi bi-ticket-perforated text-sm text-emerald-700"></i>
            <span>Ir a Panel de Taquilla</span>
          </RouterLink>
        </div>
      </nav>

      <div class="p-3.5 border-t border-gray-200 text-xs text-gray-500 flex items-center justify-between bg-gray-50/50">
        <span class="font-medium text-gray-600">Guaiqueríes Admin</span>
        <span class="inline-flex items-center gap-1.5 text-emerald-700 font-mono text-[11px] font-semibold">
          <span class="w-2 h-2 rounded-full bg-emerald-600"></span> Modo Admin
        </span>
      </div>
    </aside>
  </div>
</template>
