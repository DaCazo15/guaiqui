<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'

const client = useSupabaseClient()
const activeCount = ref(0)
const loading = ref(true)

onMounted(async () => {
  try {
    const { count, error } = await client
      .from('sponsor_videos')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true)

    if (!error && count !== null) {
      activeCount.value = count
    }
  } catch (err) {
    console.warn('Error loading sponsor videos count:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div
    v-if="!loading && activeCount > 0"
    class="relative overflow-hidden rounded-guaiqui-xl bg-gradient-to-r from-emerald-950 via-slate-900 to-emerald-900 border border-emerald-500/40 p-5 shadow-guaiqui-md text-white flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 group"
  >
    <!-- Efecto de brillo de fondo y ribete bandana -->
    <div class="absolute -right-10 -bottom-10 w-44 h-44 rounded-full bg-guaiqui-accent/15 blur-2xl group-hover:scale-125 transition-transform duration-500 pointer-events-none"></div>
    <div class="absolute top-0 left-0 bottom-0 w-1.5 bg-gradient-to-b from-guaiqui-primary via-emerald-400 to-guaiqui-accent"></div>

    <div class="flex items-center gap-4 relative z-10">
      <!-- Icono de Play con borde de neón -->
      <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-500/30 to-emerald-800/40 border border-emerald-400/40 flex items-center justify-center text-emerald-400 text-2xl shrink-0 shadow-inner group-hover:scale-105 transition-transform">
        <i class="bi bi-play-btn-fill"></i>
      </div>

      <div class="space-y-0.5">
        <div class="flex items-center gap-2">
          <span class="text-[10px] uppercase tracking-widest text-emerald-400 font-extrabold font-mono bg-emerald-500/15 px-2 py-0.5 rounded border border-emerald-400/30">
            ¡Puntos al Instante!
          </span>
          <span class="text-[11px] font-mono font-semibold text-slate-300">
            {{ activeCount }} video{{ activeCount > 1 ? 's' : '' }} disponible{{ activeCount > 1 ? 's' : '' }}
          </span>
        </div>

        <h3 class="font-display font-extrabold text-lg uppercase tracking-wide text-white">
          Videos de Patrocinadores Oficiales
        </h3>
        <p class="text-xs text-slate-300 max-w-xl">
          Apoya a la Tribu Verde viendo los videos de nuestras marcas aliadas y acumula puntos para la tienda de canjes.
        </p>
      </div>
    </div>

    <!-- CTA con energía deportiva -->
    <NuxtLink to="/app/anuncios" class="shrink-0 w-full sm:w-auto relative z-10">
      <button class="w-full sm:w-auto px-5 py-2.5 rounded-guaiqui-lg bg-gradient-to-r from-emerald-500 to-guaiqui-primary hover:from-emerald-400 hover:to-emerald-600 text-white font-display font-black text-xs uppercase tracking-wider shadow-md shadow-emerald-950/50 flex items-center justify-center gap-2 transition-all duration-200 hover:scale-[1.02] active:scale-[0.98] cursor-pointer">
        <span>Ver Videos</span>
        <i class="bi bi-arrow-right"></i>
      </button>
    </NuxtLink>
  </div>
</template>
