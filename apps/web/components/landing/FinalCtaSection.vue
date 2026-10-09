<script setup lang="ts">
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()

const handleFinalCta = () => {
  trackEvent('click_register', { source: 'final_cta' })
}
</script>

<template>
  <section class="py-16 sm:py-20 bg-gradient-to-r from-guaiqui-primary-dark via-emerald-900 to-slate-950 text-white px-4 sm:px-8 text-center relative overflow-hidden">
    <div class="max-w-4xl mx-auto space-y-6 relative z-10">
      <div class="inline-flex items-center gap-2 bg-amber-400/20 text-amber-300 text-xs font-bold uppercase px-3 py-1 rounded-full border border-amber-400/30">
        <PearlIcon size="xs" /> ¡Únete a la Tribu Hoy!
      </div>

      <h2 class="font-display font-extrabold text-3xl sm:text-5xl uppercase tracking-tight leading-none">
        ¿Listo para ganar tu primer premio?
      </h2>

      <p class="text-emerald-100 text-base sm:text-lg max-w-xl mx-auto leading-relaxed">
        El registro toma menos de 1 minuto y recibirás un bono de bienvenida de <strong>+100 perlitas</strong> para comenzar.
      </p>

      <div class="pt-2">
        <NuxtLink to="/#registro">
          <BaseButton variant="primary" size="lg" @click="handleFinalCta">
            Crear mi Cuenta Gratis
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </section>
</template>
