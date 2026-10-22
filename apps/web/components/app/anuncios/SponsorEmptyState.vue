<script setup lang="ts">
import { BaseCard, BaseButton } from '@guaiqui/ui'
</script>

<template>
  <BaseCard class="p-8 md:p-12 text-center space-y-5 max-w-5xl mx-auto">
    <div class="w-16 h-16 rounded-full bg-guaiqui-primary/10 text-guaiqui-primary flex items-center justify-center text-3xl mx-auto border border-guaiqui-primary/20">
      <i class="bi bi-camera-reels"></i>
    </div>

    <div class="space-y-2">
      <h3 class="font-display font-extrabold text-xl md:text-2xl text-guaiqui-text uppercase tracking-wide">
        Próximamente: Nuevos Videos de Patrocinadores
      </h3>
      <p class="text-xs md:text-sm text-guaiqui-text-muted leading-relaxed max-w-lg mx-auto">
        Estamos preparando nuevos videos para que puedas acumular más puntos y canjear premios oficiales de la Tribu Verde.
      </p>
    </div>

    <div class="pt-2">
      <NuxtLink to="/app">
        <BaseButton variant="primary" size="md">
          Volver al Inicio
        </BaseButton>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
