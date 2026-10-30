<script setup lang="ts">
defineProps<{
  slug: string
  activeTab?: 'trivias' | 'tienda' | 'hub'
  isInactive?: boolean
}>()
</script>

<template>
  <div class="flex items-center gap-2 border-b border-slate-800 pb-2">
    <NuxtLink
      :to="`/app/e/${slug}`"
      class="px-4 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-2"
      :class="[
        activeTab === 'hub'
          ? 'bg-white text-slate-950 shadow-md font-black'
          : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
      ]"
    >
      <i class="bi bi-grid-fill text-sm"></i>
      <span>Resumen</span>
    </NuxtLink>

    <NuxtLink
      :to="`/app/e/${slug}/trivias`"
      class="px-4 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-2"
      :class="[
        activeTab === 'trivias'
          ? 'bg-emerald-500 text-slate-950 shadow-md font-black'
          : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
      ]"
    >
      <i class="bi bi-patch-question-fill text-sm"></i>
      <span>Trivias</span>
    </NuxtLink>

    <NuxtLink
      :to="`/app/e/${slug}/tienda`"
      class="px-4 py-2 rounded-xl text-xs sm:text-sm font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-2"
      :class="[
        activeTab === 'tienda'
          ? 'bg-emerald-500 text-slate-950 shadow-md font-black'
          : 'text-slate-400 hover:text-white hover:bg-slate-900/60'
      ]"
    >
      <i class="bi bi-bag-heart-fill text-sm"></i>
      <span>Tienda de Premios</span>
    </NuxtLink>
  </div>
</template>
