<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { APP_SIDEBAR_NAV_ITEMS, type AppNavItem } from '~/data/appNavData'
import { useCurrentTeam } from '~/composables/useCurrentTeam'

const props = defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

const navItems = APP_SIDEBAR_NAV_ITEMS
const { openPicker } = useCurrentTeam()

const handleNavClick = (e: MouseEvent, item: AppNavItem) => {
  emit('close')
  if (item.name === 'Trivias') {
    e.preventDefault()
    openPicker('trivias')
  } else if (item.name === 'Tienda') {
    e.preventDefault()
    openPicker('tienda')
  }
}

const isItemActive = (item: AppNavItem) => {
  if (route.name === item.routeName || route.path === item.path) return true
  if (item.name === 'Trivias' && route.path.includes('/trivias')) return true
  if (item.name === 'Tienda' && route.path.includes('/tienda')) return true
  return false
}

// Handle Escape key to close drawer
function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.isOpen) {
    emit('close')
  }
}

// Lock/unlock body scroll when drawer opens/closes
watch(
  () => props.isOpen,
  (open) => {
    if (typeof document !== 'undefined') {
      if (open) {
        document.body.style.overflow = 'hidden'
      } else {
        document.body.style.overflow = ''
      }
    }
  }
)

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handleKeydown)
  }
})

onUnmounted(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('keydown', handleKeydown)
    document.body.style.overflow = ''
  }
})

async function handleLogout() {
  emit('close')
  await authStore.logout()
}
</script>

<template>
  <Teleport to="body">
    <!-- Backdrop Overlay -->
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isOpen"
        class="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-xs lg:hidden"
        aria-hidden="true"
        @click="emit('close')"
      />
    </Transition>

    <!-- Slide-over Drawer Panel -->
    <Transition
      enter-active-class="transition-transform duration-300 ease-out"
      enter-from-class="-translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-200 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="-translate-x-full"
    >
      <div
        v-if="isOpen"
        role="dialog"
        aria-modal="true"
        aria-label="Menú principal de navegación"
        class="fixed top-0 bottom-0 left-0 z-50 w-[310px] max-w-[85vw] bg-gradient-to-b from-[#050e12] via-[#071318] to-[#0a1c22] text-white shadow-2xl flex flex-col justify-between overflow-hidden border-r border-cyan-950/80 lg:hidden"
      >
        <!-- Top Section: Header & User Card -->
        <div class="p-4 border-b border-cyan-950/80 bg-[#0c1e24] shrink-0">
          <!-- Brand + Close Button -->
          <div class="flex items-center justify-between pb-3 mb-3 border-b border-cyan-950/80">
            <NuxtLink to="/" class="flex items-center gap-2.5" @click="emit('close')">
              <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-white shadow-md shadow-orange-500/25 shrink-0">
                <i class="bi bi-fire text-xl"></i>
              </div>
              <div>
                <div class="flex items-baseline gap-1">
                  <span class="font-title font-black text-base text-white tracking-wider leading-tight">FAN</span>
                  <span class="font-title font-black text-base text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-amber-400 tracking-wider leading-tight">ACTIVO</span>
                </div>
                <span class="text-[10px] text-cyan-400 font-bold tracking-widest uppercase block mt-0.5">
                  Fan Zone
                </span>
              </div>
            </NuxtLink>

            <button
              type="button"
              @click="emit('close')"
              class="w-10 h-10 rounded-xl flex items-center justify-center text-cyan-300 hover:text-white hover:bg-cyan-950/60 active:scale-95 transition-all cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
              aria-label="Cerrar menú"
            >
              <i class="bi bi-x-lg text-lg"></i>
            </button>
          </div>

          <!-- User Mini Profile & Balance -->
          <div class="bg-cyan-950/50 border border-cyan-800/60 rounded-2xl p-3 flex items-center justify-between shadow-lg backdrop-blur-md">
            <div class="flex items-center gap-2.5 overflow-hidden">
              <div class="w-9 h-9 rounded-full bg-cyan-950 text-cyan-300 flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-cyan-700/60">
                <img
                  v-if="authStore.profile?.avatar_url && !avatarError"
                  :src="authStore.profile.avatar_url"
                  :alt="authStore.profile?.display_name || 'Avatar'"
                  class="w-full h-full object-cover"
                  referrerpolicy="no-referrer"
                  @error="avatarError = true"
                />
                <span v-else>
                  {{ authStore.profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
                </span>
              </div>
              <div class="truncate">
                <p class="text-xs font-bold text-white truncate leading-tight">
                  {{ authStore.profile?.display_name || 'Fanático' }}
                </p>
                <span class="text-[10px] text-cyan-300/80 font-medium">
                  {{ authStore.profile?.municipality || 'FanActivo' }}
                </span>
              </div>
            </div>

            <!-- Pearls Badge -->
            <div class="flex items-center gap-1.5 text-xs font-black text-amber-950 bg-gradient-to-r from-amber-300 to-yellow-400 border border-amber-400/80 px-2.5 py-1 rounded-full shadow-xs shrink-0">
              <PearlIcon size="xs" animated />
              <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
            </div>
          </div>
        </div>

        <!-- Middle Section: Scrollable Complete Navigation Links -->
        <nav class="flex-1 overflow-y-auto px-3 py-3 space-y-1">
          <NuxtLink
            v-for="item in navItems"
            :key="item.routeName"
            :to="{ name: item.routeName }"
            @click="handleNavClick($event, item)"
            class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
            :class="[
              isItemActive(item)
                ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white font-black shadow-lg shadow-orange-950/40 scale-[1.01]'
                : 'text-slate-300 hover:text-white hover:bg-cyan-950/50',
            ]"
          >
            <!-- Custom circular avatar icon for 'Mi Perfil' -->
            <template v-if="item.path === '/app/perfil'">
              <div
                class="w-5 h-5 rounded-full overflow-hidden border shrink-0 flex items-center justify-center transition-all duration-200"
                :class="[
                  route.path === item.path
                    ? 'border-white ring-1 ring-white/60'
                    : 'border-cyan-500/40 bg-cyan-950/60'
                ]"
              >
                <img
                  v-if="authStore.profile?.avatar_url && !avatarError"
                  :src="authStore.profile.avatar_url"
                  :alt="authStore.profile?.display_name || 'Perfil'"
                  class="w-full h-full object-cover"
                  referrerpolicy="no-referrer"
                  @error="avatarError = true"
                />
                <span
                  v-else-if="authStore.profile?.display_name"
                  class="text-[10px] font-bold"
                  :class="route.path === item.path ? 'text-white' : 'text-cyan-300'"
                >
                  {{ authStore.profile.display_name.charAt(0).toUpperCase() }}
                </span>
                <i v-else :class="['bi', item.icon, 'text-xs']"></i>
              </div>
            </template>
            <i v-else :class="['bi', item.icon, 'text-base shrink-0']"></i>
            <span class="truncate">{{ item.name }}</span>
          </NuxtLink>
        </nav>

        <!-- Bottom Section: Logout & Team Badge -->
        <div class="p-3 border-t border-cyan-950/80 bg-[#0c1e24] shrink-0 space-y-2">
          <button
            type="button"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-950/30 transition-colors font-bold cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose-400"
            @click="handleLogout"
          >
            <i class="bi bi-box-arrow-right text-base"></i>
            <span>Cerrar Sesión</span>
          </button>
          <div class="px-3 pt-1 text-center">
            <span class="text-[10px] text-cyan-400/60 font-mono uppercase tracking-widest">
              FanActivo — Plataforma de Fanáticos
            </span>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
