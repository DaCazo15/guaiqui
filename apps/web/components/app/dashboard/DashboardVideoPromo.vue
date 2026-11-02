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
    class="relative overflow-hidden rounded-guaiqui-xl bg-gradient-to-r from-[#050E12] via-[#071318] to-[#0A1C22] border border-cyan-900/60 p-5 shadow-guaiqui-md text-white flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 group"
  >
    <!-- Efecto de brillo de fondo y ribete de energía -->
    <div class="absolute -right-10 -bottom-10 w-44 h-44 rounded-full bg-orange-500/15 blur-2xl group-hover:scale-125 transition-transform duration-500 pointer-events-none"></div>
    <div class="absolute top-0 left-0 bottom-0 w-1.5 bg-gradient-to-b from-orange-500 via-amber-400 to-cyan-400"></div>

    <div class="flex items-center gap-4 relative z-10">
      <!-- Icono de Play con borde cian de neón -->
      <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-950/80 to-[#0A1C22] border border-cyan-500/40 flex items-center justify-center text-cyan-400 text-2xl shrink-0 shadow-inner group-hover:scale-105 transition-transform">
        <i class="bi bi-play-btn-fill"></i>
      </div>

      <div class="space-y-0.5">
        <div class="flex items-center gap-2">
          <span class="text-[10px] uppercase tracking-widest text-cyan-300 font-extrabold font-mono bg-cyan-950/70 px-2 py-0.5 rounded border border-cyan-500/30">
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
          Apoya a tus equipos favoritos viendo los videos de marcas aliadas y acumula perlitas para canjear en la tienda oficial.
        </p>
      </div>
    </div>

    <!-- CTA con energía deportiva naranja FanActivo -->
    <NuxtLink to="/app/anuncios" class="shrink-0 w-full sm:w-auto relative z-10">
      <button class="w-full sm:w-auto px-5 py-2.5 rounded-guaiqui-lg bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-400 hover:to-orange-600 text-white font-display font-black text-xs uppercase tracking-wider shadow-md shadow-orange-950/50 flex items-center justify-center gap-2 transition-all duration-200 hover:scale-[1.02] active:scale-[0.98] cursor-pointer">
        <span>Ver Videos</span>
      </button>
    </NuxtLink>
  </div>
</template>
