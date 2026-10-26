<script setup lang="ts">
import { computed } from 'vue'
import { championshipsList as fallbackChampionships, type ChampionshipTitle } from '~/data/hallOfFameData'

const supabase = useSupabaseClient()

const { data: dbChampionships } = await useAsyncData('hall-of-fame-championships', async () => {
  try {
    const { data, error } = await supabase
      .from('hall_of_fame_championships')
      .select('*')
      .eq('is_published', true)
      .order('year', { ascending: true })

    if (error || !data || data.length === 0) return null
    return data.map((c: any): ChampionshipTitle => ({
      year: c.year,
      tournament: c.tournament,
      runnerUp: c.runner_up || '',
      highlight: c.highlight || '',
      isHexa: Boolean(c.is_hexa)
    }))
  } catch (_e) {
    return null
  }
})

const championshipsList = computed(() => dbChampionships.value || fallbackChampionships)
</script>

<template>
  <section class="py-14 sm:py-20 bg-slate-900 text-white px-4 sm:px-8 border-b border-slate-800">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="text-center max-w-2xl mx-auto space-y-3">
        <span class="text-xs uppercase font-bold text-amber-400 tracking-widest bg-amber-400/10 px-3 py-1 rounded-full border border-amber-400/30">
          Palmarés Histórico
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-white uppercase">
          Vitrina de los 9 Campeonatos
        </h2>
        <p class="text-sm text-slate-300">
          Las 9 coronas nacionales que consagran a Guaiqueríes de Margarita como gigante indiscutible del baloncesto venezolano.
        </p>
      </div>

      <!-- Hexacampeonato Special Banner -->
      <div class="bg-gradient-to-r from-amber-500/20 via-emerald-500/20 to-slate-800 border border-amber-500/40 rounded-guaiqui-xl p-6 sm:p-8 flex flex-col md:flex-row items-center justify-between gap-6 shadow-xl">
        <div class="flex items-center gap-4 text-center md:text-left">
          <div class="w-16 h-16 rounded-2xl bg-amber-500/20 border border-amber-400/40 text-amber-400 flex items-center justify-center font-display font-black text-3xl shrink-0">
            <i class="bi bi-fire"></i>
          </div>
          <div>
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-amber-400">Récord Nacional Único</span>
            <h3 class="font-display font-bold text-2xl uppercase tracking-wide text-white">
              El Legendario Hexacampeonato (1977 - 1982)
            </h3>
            <p class="text-xs sm:text-sm text-slate-300 max-w-2xl mt-1">
              Guaiqueríes de Margarita es el único equipo en toda la historia de la liga en conquistar 6 títulos de forma consecutiva e ininterrumpida.
            </p>
          </div>
        </div>
        <div class="px-5 py-2.5 rounded-xl bg-amber-400 text-slate-950 font-display font-black text-sm uppercase tracking-widest shrink-0 shadow-lg">
          6 Copas Seguidas
        </div>
      </div>

      <!-- Trophies Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <div
          v-for="c in championshipsList"
          :key="c.year"
          :class="[
            'p-5 rounded-guaiqui-xl border transition-all duration-200 space-y-3 flex flex-col justify-between',
            c.isHexa
              ? 'bg-slate-800/80 border-emerald-500/30 hover:border-emerald-400'
              : 'bg-slate-800/50 border-slate-700 hover:border-amber-400/50'
          ]"
        >
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="font-display font-black text-3xl tracking-tight" :class="c.isHexa ? 'text-emerald-400' : 'text-amber-400'">
                {{ c.year }}
              </span>
              <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider" :class="c.isHexa ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' : 'bg-amber-400/10 text-amber-300 border border-amber-400/30'">
                <i class="bi bi-trophy-fill text-[9px]"></i>
                <span>Estrella</span>
              </span>
            </div>

            <div>
              <h4 class="font-display font-bold text-base text-white uppercase">
                {{ c.tournament }}
              </h4>
              <p class="text-xs text-slate-400">
                Final ante: <span class="text-slate-200 font-medium">{{ c.runnerUp }}</span>
              </p>
            </div>

            <p class="text-xs text-slate-300 leading-relaxed pt-1">
              {{ c.highlight }}
            </p>
          </div>

          <div class="pt-3 border-t border-slate-700/60 flex items-center gap-2 text-[11px] text-slate-400">
            <i class="bi bi-geo-alt-fill text-emerald-400"></i>
            <span>Gimnasio Ciudad de La Asunción</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
