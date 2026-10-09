<script setup lang="ts">
import { ref } from 'vue'
import NavbarHeader from './NavbarHeader.vue'
import AdminSidebar from './AdminSidebar.vue'

const isSidebarOpen = ref(false)

const toggleSidebar = () => {
  isSidebarOpen.value = !isSidebarOpen.value
}

const closeSidebar = () => {
  isSidebarOpen.value = false
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-body">
    <NavbarHeader @toggle-sidebar="toggleSidebar" />

    <div class="flex-1 flex overflow-hidden">
      <AdminSidebar :is-open="isSidebarOpen" @close="closeSidebar" />

      <main class="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-slate-950">
        <slot />
      </main>
    </div>
  </div>
</template>
