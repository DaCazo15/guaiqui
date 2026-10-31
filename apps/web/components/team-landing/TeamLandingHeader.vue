<script setup lang="ts">
import { ref } from 'vue'
import type { TeamLandingProfile } from '@guaiqui/shared'
import { BaseButton } from '@guaiqui/ui'

const props = defineProps<{
  team: TeamLandingProfile
}>()

const isMobileMenuOpen = ref(false)

function toggleMenu() {
  isMobileMenuOpen.value = !isMobileMenuOpen.value
}

function closeMenu() {
  isMobileMenuOpen.value = false
}
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-gray-100 shadow-sm transition-all duration-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
      <!-- Logo y Nombre de Equipo -->
      <NuxtLink :to="`/equipo/${team.slug}`" class="flex items-center gap-3 group">
        <img
          v-if="team.logo_url"
          :src="team.logo_url"
          :alt="`Logo de ${team.name}`"
          class="w-12 h-12 object-contain transition-transform group-hover:scale-105"
        />
        <div v-else class="w-12 h-12 rounded-full bg-guaiqui-primary flex items-center justify-center text-white font-bold text-lg">
          {{ team.name.charAt(0) }}
        </div>

        <div class="flex flex-col">
          <span class="font-display font-extrabold text-xl text-gray-900 leading-tight tracking-tight uppercase group-hover:text-guaiqui-primary transition-colors">
            {{ team.name }}
          </span>
          <span class="text-xs font-semibold text-gray-700 tracking-wider uppercase">
            {{ team.short_name || 'Fan Zone Oficial' }}
          </span>
        </div>
      </NuxtLink>

      <!-- Desktop Nav -->
      <nav class="hidden md:flex items-center gap-6">
        <a href="#hero" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">Inicio</a>
        <a href="#plantilla" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">Plantilla</a>
        <a href="#trivias" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">Trivias</a>
        <a href="#tienda" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">Tienda</a>
        <a href="#historia" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">Historia</a>
        <a href="#faq" class="text-sm font-semibold text-gray-700 hover:text-guaiqui-primary transition-colors">FAQ</a>
      </nav>

      <!-- Desktop CTAs -->
      <div class="hidden md:flex items-center gap-3">
        <NuxtLink to="/login">
          <BaseButton variant="outline" size="sm">
            <i class="bi bi-person-fill mr-1.5" aria-hidden="true"></i>
            Ingresar
          </BaseButton>
        </NuxtLink>
        <NuxtLink :to="`/registro?team=${team.slug}`">
          <BaseButton variant="primary" size="sm">
            <i class="bi bi-star-fill mr-1.5" aria-hidden="true"></i>
            Unirme a {{ team.short_name || 'La Tribu' }}
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Mobile Menu Toggle -->
      <button
        type="button"
        @click="toggleMenu"
        class="md:hidden p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-guaiqui-primary"
        aria-label="Abrir menú"
      >
        <i :class="isMobileMenuOpen ? 'bi bi-x-lg text-2xl' : 'bi bi-list text-2xl'" aria-hidden="true"></i>
      </button>
    </div>

    <!-- Mobile Drawer -->
    <div v-if="isMobileMenuOpen" class="md:hidden border-t border-gray-100 bg-white px-4 pt-3 pb-6 space-y-3">
      <nav class="flex flex-col space-y-2">
        <a href="#hero" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">Inicio</a>
        <a href="#plantilla" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">Plantilla</a>
        <a href="#trivias" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">Trivias</a>
        <a href="#tienda" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">Tienda</a>
        <a href="#historia" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">Historia</a>
        <a href="#faq" @click="closeMenu" class="px-3 py-2 text-base font-semibold text-gray-700 hover:bg-gray-50 rounded-lg">FAQ</a>
      </nav>
      <div class="pt-3 border-t border-gray-100 flex flex-col gap-2">
        <NuxtLink to="/login" @click="closeMenu">
          <BaseButton variant="outline" size="md" class="w-full justify-center">
            <i class="bi bi-person-fill mr-1.5" aria-hidden="true"></i>
            Ingresar
          </BaseButton>
        </NuxtLink>
        <NuxtLink :to="`/registro?team=${team.slug}`" @click="closeMenu">
          <BaseButton variant="primary" size="md" class="w-full justify-center">
            <i class="bi bi-star-fill mr-1.5" aria-hidden="true"></i>
            Unirme a {{ team.short_name || 'La Tribu' }}
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </header>
</template>
