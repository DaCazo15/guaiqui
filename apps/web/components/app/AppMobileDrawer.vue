<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { APP_SIDEBAR_NAV_ITEMS } from '~/data/appNavData'

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
        class="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-xs md:hidden"
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
        class="fixed top-0 bottom-0 left-0 z-50 w-[310px] max-w-[85vw] bg-white text-guaiqui-text shadow-2xl flex flex-col justify-between overflow-hidden border-r border-guaiqui-border md:hidden"
      >
        <!-- Top Section: Header & User Card -->
        <div class="p-4 border-b border-guaiqui-border bg-guaiqui-surface/50 shrink-0">
          <!-- Brand + Close Button -->
          <div class="flex items-center justify-between pb-3 mb-3 border-b border-guaiqui-border">
            <div class="flex items-center gap-2">
              <div class="w-9 h-9 rounded-full bg-white p-1 border border-guaiqui-border shadow-xs flex items-center justify-center shrink-0">
                <img src="/logo.png" alt="Guaiqueríes Logo" width="36" height="36" class="w-full h-full object-contain" />
              </div>
              <div>
                <h2 class="font-display text-base font-black text-guaiqui-text uppercase tracking-wider leading-tight">
                  Guaiqueríes
                </h2>
                <span class="text-[11px] text-guaiqui-primary font-bold tracking-wide">Fan Zone</span>
              </div>
            </div>

            <button
              type="button"
              @click="emit('close')"
              class="w-10 h-10 rounded-xl flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-200/60 active:scale-95 transition-all cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
              aria-label="Cerrar menú"
            >
              <i class="bi bi-x-lg text-lg"></i>
            </button>
          </div>

          <!-- User Mini Profile & Balance -->
          <div class="bg-white border border-guaiqui-border rounded-guaiqui-xl p-3 flex items-center justify-between shadow-guaiqui-sm">
            <div class="flex items-center gap-2.5 overflow-hidden">
              <div class="w-9 h-9 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-guaiqui-primary/20">
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
                <p class="text-xs font-bold text-guaiqui-text truncate leading-tight">
                  {{ authStore.profile?.display_name || 'Fanático' }}
                </p>
                <span class="text-[10px] text-guaiqui-text-muted">
                  {{ authStore.profile?.municipality || 'Nueva Esparta' }}
                </span>
              </div>
            </div>

            <!-- Pearls Badge -->
            <div class="flex items-center gap-1.5 text-xs font-extrabold text-amber-900 bg-amber-100 border border-amber-300 px-2.5 py-1 rounded-full shadow-xs shrink-0">
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
            @click="emit('close')"
            class="flex items-center gap-3 px-3 py-2.5 rounded-guaiqui-lg text-sm font-semibold transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
            :class="[
              route.name === item.routeName || route.path === item.path
                ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm font-bold'
                : 'text-guaiqui-text-muted hover:text-guaiqui-text hover:bg-guaiqui-surface',
            ]"
          >
            <!-- Custom circular avatar icon for 'Mi Perfil' -->
            <template v-if="item.path === '/app/perfil'">
              <div
                class="w-5 h-5 rounded-full overflow-hidden border shrink-0 flex items-center justify-center transition-all duration-150"
                :class="[
                  route.path === item.path
                    ? 'border-white ring-1 ring-white/60'
                    : 'border-guaiqui-border bg-guaiqui-surface'
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
                  :class="route.path === item.path ? 'text-white' : 'text-guaiqui-primary'"
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
        <div class="p-3 border-t border-guaiqui-border bg-guaiqui-surface/50 shrink-0 space-y-2">
          <button
            type="button"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-guaiqui-lg text-sm text-guaiqui-accent hover:bg-guaiqui-accent-soft transition-colors font-bold cursor-pointer"
            @click="handleLogout"
          >
            <i class="bi bi-box-arrow-right text-base"></i>
            <span>Cerrar Sesión</span>
          </button>
          <div class="px-3 pt-1 text-center">
            <span class="text-[10px] text-guaiqui-text-subtle font-mono uppercase tracking-widest">
              Orgullo Insular — 1977
            </span>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
