<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseButton, BaseBadge, PearlIcon } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()
const supabase = useSupabaseClient()

const nextGame = ref<any>(null)
const loadingGame = ref(true)

const formattedGameDate = computed(() => {
  if (!nextGame.value?.game_date) return null
  const d = new Date(nextGame.value.game_date)
  return d.toLocaleDateString('es-VE', { weekday: 'short', day: 'numeric', month: 'short' })
})

const formattedGameTime = computed(() => {
  if (!nextGame.value?.game_date) return null
  const d = new Date(nextGame.value.game_date)
  return d.toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
})

onMounted(async () => {
  loadingGame.value = true
  try {
    const { data } = await supabase
      .from('games')
      .select('*')
      .in('status', ['scheduled', 'live'])
      .order('game_date', { ascending: true })
      .limit(1)
      .maybeSingle()

    nextGame.value = data || null
  } catch (_err) {
    nextGame.value = null
  } finally {
    loadingGame.value = false
  }
})

const handleHeroRegister = () => {
  trackEvent('click_register', { source: 'hero_primary' })
}

const handleHeroHowItWorks = () => {
  trackEvent('click_how_it_works', { source: 'hero_secondary' })
}
</script>

<template>
  <section class="relative bg-gradient-to-b from-guaiqui-primary-dark via-emerald-900 to-slate-950 text-white overflow-hidden py-16 sm:py-24 px-4 sm:px-8">
    <!-- Subtle Background Pattern Overlay for Text Legibility -->
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/10 via-transparent to-black/60 pointer-events-none" />

    <div class="max-w-6xl mx-auto relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
      <!-- Left Content -->
      <div class="lg:col-span-7 space-y-6 text-center lg:text-left">
        <!-- Social Proof Badge -->
        <div class="inline-flex items-center gap-2 bg-white/10 backdrop-blur-md px-3.5 py-1.5 rounded-full border border-white/20 text-xs font-semibold text-emerald-200">
          <BaseBadge variant="soft" size="sm">Fan Zone 2026</BaseBadge>
          <span class="flex items-center gap-1">
            Plataforma Oficial de Fidelización
          </span>
        </div>

        <!-- Headline -->
        <h1 class="font-display font-extrabold text-4xl sm:text-5xl lg:text-6xl uppercase tracking-tight leading-none">
          Juega, gana <span class="text-amber-400">puntos</span> y canjea con tu equipo
        </h1>

        <!-- Subtitle -->
        <p class="text-emerald-100 text-base sm:text-lg max-w-2xl mx-auto lg:mx-0 leading-relaxed">
          La plataforma oficial de fidelización de <strong>Guaiqueríes de Margarita</strong>. Responde trivias diarias, demuestra tu pasión insular y reclama camisetas, pases y premios reales gratis.
        </p>

        <!-- Double CTA Buttons -->
        <div class="flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-4 pt-2">
          <NuxtLink to="/registro" class="w-full sm:w-auto">
            <BaseButton variant="primary" size="lg" block @click="handleHeroRegister">
              Regístrate Gratis Ahora
            </BaseButton>
          </NuxtLink>

          <NuxtLink to="/#como-funciona" class="w-full sm:w-auto">
            <BaseButton variant="secondary" size="lg" block @click="handleHeroHowItWorks">
              Ver cómo funciona
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Free Guarantee Notice -->
        <div class="flex items-center justify-center lg:justify-start gap-4 text-xs text-emerald-200/90 pt-2 font-medium">
          <span class="flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> 100% Gratuito</span>
          <span class="flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> Sin tarjetas ni pagos</span>
          <span class="flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> Premios reales</span>
        </div>
      </div>

      <!-- Right Content: Dynamic Next Match Card OR Institutional Fan Zone Card -->
      <div class="lg:col-span-5 w-full max-w-md mx-auto">
        <!-- Case 1: Real scheduled match in database -->
        <div
          v-if="nextGame"
          class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-guaiqui-xl p-6 shadow-2xl relative overflow-hidden"
        >
          <div class="absolute top-0 right-0 bg-guaiqui-accent text-white text-[10px] font-extrabold uppercase px-3 py-1 rounded-bl-lg">
            {{ nextGame.status === 'live' ? 'En Vivo' : 'Próximo Juego' }}
          </div>

          <div class="text-xs uppercase font-bold text-emerald-300 tracking-wider mb-2">
            Superliga Profesional de Baloncesto
          </div>

          <h2 class="font-display font-extrabold text-2xl text-white uppercase mb-1">
            Guaiqueríes <span class="text-emerald-400">vs</span> {{ nextGame.opponent }}
          </h2>

          <p class="text-xs text-emerald-100/80 mb-6 flex items-center gap-1.5">
            <i class="bi bi-geo-alt-fill text-emerald-400"></i>
            <span>{{ nextGame.location }}</span>
          </p>

          <div class="bg-black/40 rounded-guaiqui-lg p-4 border border-white/10 flex items-center justify-between mb-6">
            <div>
              <div class="text-[10px] uppercase text-emerald-300 font-bold">Fecha y Hora</div>
              <div class="text-sm font-bold text-white">{{ formattedGameDate }}</div>
              <div class="text-xs text-emerald-200">{{ formattedGameTime }}</div>
            </div>

            <div class="text-right">
              <div class="text-[10px] uppercase text-amber-300 font-bold">Recompensa</div>
              <div class="text-sm font-bold text-amber-400 flex items-center justify-end gap-1">
                +300 <PearlIcon size="xs" />
              </div>
              <div class="text-[10px] text-emerald-200">por acertar trivia</div>
            </div>
          </div>

          <NuxtLink to="/registro">
            <BaseButton variant="primary" block size="md" @click="handleHeroRegister">
              Participar en la Trivia del Partido
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Case 2: Institutional Fan Zone Card (zero games in database) -->
        <div
          v-else
          class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-guaiqui-xl p-6 shadow-2xl relative overflow-hidden space-y-5"
        >
          <div class="absolute top-0 right-0 bg-guaiqui-primary text-white text-[10px] font-extrabold uppercase px-3 py-1 rounded-bl-lg">
            Fan Zone Oficial
          </div>

          <div>
            <div class="text-xs uppercase font-bold text-emerald-300 tracking-wider mb-1">
              Temporada 2026
            </div>
            <h2 class="font-display font-extrabold text-2xl text-white uppercase">
              La Tribu Verde
            </h2>
            <p class="text-xs text-emerald-100/80 flex items-center gap-1.5 mt-1">
              <i class="bi bi-geo-alt-fill text-emerald-400"></i>
              <span>Gimnasio Ciudad de La Asunción</span>
            </p>
          </div>

          <div class="bg-black/40 rounded-guaiqui-lg p-4 border border-white/10 space-y-3">
            <div class="flex items-center justify-between border-b border-white/10 pb-2.5">
              <span class="text-xs text-slate-300">Historia Nacional</span>
              <span class="font-display font-bold text-sm text-amber-300">9 Estrellas</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-xs text-slate-300">Moneda de Fidelidad</span>
              <span class="font-bold text-xs text-emerald-300 flex items-center gap-1">
                Puntos Gratis <PearlIcon size="xs" />
              </span>
            </div>
          </div>

          <p class="text-xs text-emerald-200/90 leading-relaxed">
            Acumula puntos respondiendo las trivias de la historia del club y prepárate para los próximos partidos oficiales.
          </p>

          <NuxtLink to="/registro">
            <BaseButton variant="primary" block size="md" @click="handleHeroRegister">
              Únete a la Tribu Gratis
            </BaseButton>
          </NuxtLink>
        </div>
      </div>
    </div>
  </section>
</template>
