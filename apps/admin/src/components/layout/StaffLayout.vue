<script setup lang="ts">
import { ref } from 'vue'
import NavbarHeader from './NavbarHeader.vue'
import NavbarSidebar from './NavbarSidebar.vue'

const isSidebarOpen = ref(false)

const toggleSidebar = () => {
  isSidebarOpen.value = !isSidebarOpen.value
}

const closeSidebar = () => {
  isSidebarOpen.value = false
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans antialiased">
    <NavbarHeader @toggle-sidebar="toggleSidebar" />

    <div class="flex-1 flex overflow-hidden">
      <NavbarSidebar :is-open="isSidebarOpen" @close="closeSidebar" />

      <main class="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-slate-950">
        <div class="max-w-7xl mx-auto">
          <slot />
        </div>
      </main>
    </div>
  </div>
</template>
