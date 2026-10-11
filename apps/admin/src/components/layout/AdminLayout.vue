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
  <div class="h-screen bg-gray-50 text-gray-900 flex flex-col font-body overflow-hidden">
    <NavbarHeader @toggle-sidebar="toggleSidebar" />

    <div class="flex-1 flex min-h-0 overflow-hidden">
      <AdminSidebar :is-open="isSidebarOpen" @close="closeSidebar" />

      <main class="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-gray-50">
        <slot />
      </main>
    </div>
  </div>
</template>
