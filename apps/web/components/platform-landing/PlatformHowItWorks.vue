<script setup lang="ts">
const steps = [
  {
    step: '01',
    icon: 'bi-person-plus-fill',
    title: 'Elige tu Franquicia',
    description: 'Crea tu cuenta gratuita y sigue a tu equipo de baloncesto profesional favorito para desbloquear su Fan Zone oficial.'
  },
  {
    step: '02',
    icon: 'bi-question-diamond-fill',
    title: 'Juega Trivias Oficiales',
    description: 'Demuestra cuánto sabes de tu club respondiendo preguntas en tiempo real sobre partidos, historia, jugadores y récords.'
  },
  {
    step: '03',
    icon: 'bi-gem',
    title: 'Gana Perlitas por Equipo',
    description: 'Cada respuesta acertada te otorga perlitas exclusivas en la billetera de tu franquicia elegida. 100% virtual y sin recargas.'
  },
  {
    step: '04',
    icon: 'bi-gift-fill',
    title: 'Canjea Premios Reales',
    description: 'Usa tus perlitas en la tienda oficial del equipo para canjear camisas, gorras, accesos a entrenamientos y saludos VIP.'
  }
]
</script>

<template>
  <section class="py-16 sm:py-24 bg-slate-950 text-white border-b border-slate-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center max-w-3xl mx-auto mb-14 space-y-3">
        <span class="text-xs sm:text-sm font-bold uppercase tracking-wider text-emerald-400 font-sans">
          Mecánica del Juego
        </span>
        <h2 class="text-3xl sm:text-4xl font-black font-title tracking-tight text-white">
          ¿Cómo Funciona la Plataforma?
        </h2>
        <p class="text-sm sm:text-base text-slate-400">
          Sin apuestas ni dinero real. Solo tu conocimiento, tu lealtad y las recompensas que te mereces como verdadero fanático.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div
          v-for="item in steps"
          :key="item.step"
          class="relative p-6 rounded-2xl bg-slate-900/70 border border-slate-800 hover:border-emerald-500/40 transition-all duration-300 flex flex-col justify-between group"
        >
          <div>
            <div class="flex items-center justify-between mb-4">
              <div class="w-12 h-12 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center text-xl group-hover:scale-110 transition-transform">
                <i :class="['bi', item.icon]"></i>
              </div>
              <span class="text-2xl font-black font-title text-slate-700 group-hover:text-emerald-500/40 transition-colors">
                {{ item.step }}
              </span>
            </div>

            <h3 class="text-lg font-bold text-white mb-2 font-title">
              {{ item.title }}
            </h3>
            <p class="text-xs sm:text-sm text-slate-400 leading-relaxed font-sans">
              {{ item.description }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
