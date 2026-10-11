<script setup lang="ts">
import Skeleton from './Skeleton.vue'

defineProps<{
  dark?: boolean
  showSidebar?: boolean
}>()
</script>

<template>
  <div
    :class="[
      'w-full min-h-screen p-4 sm:p-6 md:p-8 transition-colors duration-300',
      dark ? 'bg-slate-950 text-slate-100' : 'bg-slate-50 text-slate-800'
    ]"
  >
    <div class="max-w-7xl mx-auto space-y-8">
      <!-- Top Navigation Skeleton Bar -->
      <div class="flex items-center justify-between border-b pb-4 border-slate-700/40">
        <div class="flex items-center gap-3">
          <Skeleton variant="circular" width="40px" height="40px" />
          <div class="space-y-1.5">
            <Skeleton variant="text" width="140px" height="16px" />
            <Skeleton variant="text" width="90px" height="12px" />
          </div>
        </div>

        <div class="flex items-center gap-3">
          <Skeleton variant="text" width="80px" height="32px" class="rounded-full!" />
          <Skeleton variant="circular" width="36px" height="36px" />
        </div>
      </div>

      <!-- Main Layout Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <!-- Sidebar Column (Optional) -->
        <div v-if="showSidebar !== false" class="hidden lg:block space-y-4">
          <div :class="['p-5 rounded-2xl border space-y-4', dark ? 'bg-slate-900/60 border-slate-800' : 'bg-white border-slate-200']">
            <Skeleton variant="text" width="120px" height="14px" />
            <div class="space-y-2 pt-2">
              <Skeleton variant="text" width="100%" height="36px" class="rounded-xl!" />
              <Skeleton variant="text" width="100%" height="36px" class="rounded-xl!" />
              <Skeleton variant="text" width="100%" height="36px" class="rounded-xl!" />
              <Skeleton variant="text" width="100%" height="36px" class="rounded-xl!" />
            </div>
          </div>
        </div>

        <!-- Main Content Area -->
        <div :class="[showSidebar !== false ? 'lg:col-span-3' : 'lg:col-span-4', 'space-y-6']">
          <!-- Top Row Cards Grid -->
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div
              v-for="i in 3"
              :key="i"
              :class="['p-5 rounded-2xl border space-y-3', dark ? 'bg-slate-900/70 border-slate-800' : 'bg-white border-slate-200']"
            >
              <div class="flex items-center justify-between">
                <Skeleton variant="circular" width="32px" height="32px" />
                <Skeleton variant="text" width="40px" height="12px" />
              </div>
              <Skeleton variant="text" width="60%" height="24px" />
              <Skeleton variant="text" width="80%" height="12px" />
            </div>
          </div>

          <!-- Wide Banner Card Skeleton -->
          <div :class="['p-6 rounded-2xl border space-y-4', dark ? 'bg-slate-900/70 border-slate-800' : 'bg-white border-slate-200']">
            <div class="flex items-center justify-between">
              <Skeleton variant="text" width="180px" height="20px" />
              <Skeleton variant="text" width="60px" height="14px" />
            </div>
            <Skeleton variant="rectangular" height="120px" class="rounded-xl!" />
            <div class="flex items-center gap-3 pt-2">
              <Skeleton variant="text" width="100px" height="36px" class="rounded-xl!" />
              <Skeleton variant="text" width="100px" height="36px" class="rounded-xl!" />
            </div>
          </div>

          <!-- List Items Card Skeleton -->
          <div :class="['p-6 rounded-2xl border space-y-4', dark ? 'bg-slate-900/70 border-slate-800' : 'bg-white border-slate-200']">
            <Skeleton variant="text" width="160px" height="18px" />
            <div class="space-y-3 pt-2">
              <div v-for="j in 3" :key="j" class="flex items-center justify-between py-2 border-b border-slate-800/40">
                <div class="flex items-center gap-3">
                  <Skeleton variant="circular" width="36px" height="36px" />
                  <div class="space-y-1">
                    <Skeleton variant="text" width="140px" height="14px" />
                    <Skeleton variant="text" width="80px" height="10px" />
                  </div>
                </div>
                <Skeleton variant="text" width="60px" height="18px" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
