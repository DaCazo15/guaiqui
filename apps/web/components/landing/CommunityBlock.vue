<script setup lang="ts">
import { BaseButton } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()

const handleSocialClick = (network: string) => {
  trackEvent('click_social_network', { network })
}
</script>

<template>
  <section class="py-16 sm:py-24 bg-white px-4 sm:px-8">
    <div class="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
      <!-- Left text -->
      <div class="lg:col-span-6 space-y-6">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
          La Tribu Verde
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Únete a la conversación en redes sociales
        </h2>
        <p class="text-guaiqui-text-muted text-base leading-relaxed">
          Comparte tus mejores momentos en el Gimnasio Ciudad de La Asunción con la etiqueta <strong>#TribuGuaiquerí</strong> y aparece en nuestras pantallas oficiales.
        </p>

        <div class="flex flex-wrap gap-3 pt-2">
          <a
            href="https://instagram.com"
            target="_blank"
            rel="noopener noreferrer"
            @click="handleSocialClick('instagram')"
          >
            <BaseButton variant="secondary" size="sm">
              <i class="bi bi-instagram mr-1.5 text-pink-600"></i>
              Instagram
            </BaseButton>
          </a>
          <a
            href="https://x.com"
            target="_blank"
            rel="noopener noreferrer"
            @click="handleSocialClick('x')"
          >
            <BaseButton variant="secondary" size="sm">
              <i class="bi bi-twitter-x mr-1.5"></i>
              X (Twitter)
            </BaseButton>
          </a>
          <a
            href="https://youtube.com"
            target="_blank"
            rel="noopener noreferrer"
            @click="handleSocialClick('youtube')"
          >
            <BaseButton variant="secondary" size="sm">
              <i class="bi bi-youtube mr-1.5 text-red-600"></i>
              YouTube
            </BaseButton>
          </a>
        </div>
      </div>

      <!-- Right Grid Gallery Placeholders -->
      <div class="lg:col-span-6 grid grid-cols-2 gap-4">
        <div class="h-40 rounded-guaiqui-lg bg-gradient-to-br from-emerald-800 to-guaiqui-primary-dark p-4 text-white flex flex-col justify-between shadow-xs">
          <span class="text-xs font-bold uppercase text-amber-300">#TribuGuaiquerí</span>
          <span class="font-display text-sm font-semibold">"¡La mejor fanaticada de Venezuela!"</span>
        </div>
        <div class="h-40 rounded-guaiqui-lg bg-gradient-to-br from-green-900 to-slate-900 p-4 text-white flex flex-col justify-between shadow-xs">
          <span class="text-xs font-bold uppercase text-emerald-300">La Asunción</span>
          <span class="font-display text-sm font-semibold">"¡Llenazo total en el gimnasio!"</span>
        </div>
        <div class="h-40 rounded-guaiqui-lg bg-gradient-to-br from-amber-800 to-emerald-950 p-4 text-white flex flex-col justify-between shadow-xs">
          <span class="text-xs font-bold uppercase text-amber-300">Puntos</span>
          <span class="font-display text-sm font-semibold">"¡Canjeé mi camisa oficial!"</span>
        </div>
        <div class="h-40 rounded-guaiqui-lg bg-gradient-to-br from-emerald-950 to-teal-900 p-4 text-white flex flex-col justify-between shadow-xs">
          <span class="text-xs font-bold uppercase text-emerald-200">Nueva Esparta</span>
          <span class="font-display text-sm font-semibold">"Orgullo margariteño"</span>
        </div>
      </div>
    </div>
  </section>
</template>
