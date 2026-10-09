<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()

const navItems = [
  { name: 'Inicio', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Perfil', path: '/app/perfil', icon: 'bi-person-fill' },
]
</script>

<template>
  <nav class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 border-t border-guaiqui-border backdrop-blur-lg px-2 py-1 shadow-guaiqui-md">
    <div class="flex justify-around items-center">
      <NuxtLink
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        class="flex flex-col items-center py-1.5 px-3 rounded-guaiqui-md transition-all duration-150"
        :class="[
          route.path === item.path
            ? 'text-guaiqui-primary font-bold bg-guaiqui-primary-soft'
            : 'text-guaiqui-text-muted hover:text-guaiqui-text',
        ]"
      >
        <i :class="['bi', item.icon, 'text-lg mb-0.5']"></i>
        <span class="text-[10px] tracking-tight">{{ item.name }}</span>
      </NuxtLink>
    </div>
  </nav>
</template>
