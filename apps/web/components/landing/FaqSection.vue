<script setup lang="ts">
import { BaseAccordion, BaseButton } from '@guaiqui/ui'
import { faqList } from '~/data/landingData'

const accordionItems = faqList.map((f) => ({
  id: f.id,
  title: f.title,
  content: f.content,
}))
</script>

<template>
  <section id="faq" class="py-16 sm:py-24 bg-guaiqui-surface border-t border-guaiqui-border px-4 sm:px-8 scroll-mt-20">
    <div class="max-w-4xl mx-auto space-y-10">
      <div class="text-center space-y-3">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
          Centro de Ayuda
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Preguntas Frecuentes
        </h2>
        <p class="text-guaiqui-text-muted text-sm sm:text-base">
          Resolvemos tus dudas sobre los puntos, trivias y el canje de premios.
        </p>
      </div>

      <BaseAccordion :items="accordionItems" default-open-id="faq-1" />

      <div class="text-center pt-4">
        <NuxtLink to="/faq">
          <BaseButton variant="ghost" size="md">
            Ver todas las preguntas en el Centro de Ayuda →
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </section>
</template>
