<script setup lang="ts">
defineProps<{
  slug: string
  activeTab?: 'hub' | 'trivias' | 'tienda' | 'partidos' | 'plantilla' | 'salon-de-la-fama'
  isInactive?: boolean
}>()
</script>

<template>
  <div class="border-b border-slate-800 pb-2 overflow-x-auto">
    <div class="flex items-center gap-2 min-w-max">
      <!-- 1. Resumen -->
      <NuxtLink
        :to="`/app/e/${slug}`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'hub'
            ? 'bg-white text-slate-950 shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-grid-fill text-sm"></i>
        <span>Resumen</span>
      </NuxtLink>

      <!-- 2. Trivias -->
      <NuxtLink
        :to="`/app/e/${slug}/trivias`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'trivias'
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-patch-question-fill text-sm"></i>
        <span>Trivias</span>
      </NuxtLink>

      <!-- 3. Tienda de Premios -->
      <NuxtLink
        :to="`/app/e/${slug}/tienda`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'tienda'
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-bag-heart-fill text-sm"></i>
        <span>Tienda</span>
      </NuxtLink>

      <!-- 4. Partidos -->
      <NuxtLink
        :to="`/app/e/${slug}/partidos`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'partidos'
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-calendar-event-fill text-sm"></i>
        <span>Partidos</span>
      </NuxtLink>

      <!-- 5. Plantilla -->
      <NuxtLink
        :to="`/app/e/${slug}/plantilla`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'plantilla'
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-people-fill text-sm"></i>
        <span>Plantilla</span>
      </NuxtLink>

      <!-- 6. Salón de la Fama -->
      <NuxtLink
        :to="`/app/e/${slug}/salon-de-la-fama`"
        class="px-3.5 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-1.5"
        :class="[
          activeTab === 'salon-de-la-fama'
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-md font-black'
            : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
        ]"
      >
        <i class="bi bi-award-fill text-sm"></i>
        <span>Salón de la Fama</span>
      </NuxtLink>
    </div>
  </div>
</template>
