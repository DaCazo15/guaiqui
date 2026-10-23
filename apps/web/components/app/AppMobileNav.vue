<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

const navItems = [
  { name: 'Inicio', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Perfil', path: '/app/perfil', icon: 'bi-person-fill' },
]
</script>

<template>
  <nav class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0B7A3B] bg-gradient-to-r from-[#064E27] via-[#0B7A3B] to-emerald-800 border-t-2 border-[#C8102E] shadow-2xl px-2 py-1.5 text-white">
    <div class="flex justify-around items-center">
      <NuxtLink
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        class="flex flex-col items-center py-1 px-3 rounded-guaiqui-lg transition-all duration-150"
        :class="[
          route.path === item.path
            ? 'text-white font-black bg-black/30 ring-1 ring-white/30 shadow-inner'
            : 'text-emerald-100/75 hover:text-white hover:bg-white/10 font-semibold',
        ]"
      >
        <!-- Ícono personalizado para Perfil con foto circular del usuario -->
        <template v-if="item.path === '/app/perfil'">
          <div
            class="w-[22px] h-[22px] rounded-full overflow-hidden mb-0.5 border flex items-center justify-center shrink-0 transition-all duration-150"
            :class="[
              route.path === item.path
                ? 'border-white ring-2 ring-white shadow-xs'
                : 'border-white/60 opacity-90'
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
              class="text-[10px] font-bold text-white bg-white/20 w-full h-full flex items-center justify-center leading-none"
            >
              {{ authStore.profile.display_name.charAt(0).toUpperCase() }}
            </span>
            <i v-else :class="['bi', item.icon, 'text-xs text-white']"></i>
          </div>
        </template>
        <i v-else :class="['bi', item.icon, 'text-lg mb-0.5']"></i>
        <span class="text-[10px] tracking-tight">{{ item.name }}</span>
      </NuxtLink>
    </div>
  </nav>
</template>
