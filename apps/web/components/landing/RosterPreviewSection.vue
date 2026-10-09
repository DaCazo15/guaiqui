<script setup lang="ts">
import { BaseCard, BaseBadge, BaseButton } from '@guaiqui/ui'
import { keyRoster } from '~/data/landingData'
</script>

<template>
  <section class="py-16 sm:py-24 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            La Tribu en la Cancha
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight mt-2">
            Plantilla Oficial 2026
          </h2>
        </div>

        <NuxtLink to="/plantilla">
          <BaseButton variant="secondary" size="md">
            Ver Plantilla Completa
          </BaseButton>
        </NuxtLink>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="p in keyRoster"
          :key="p.id"
          variant="default"
          padding="md"
          class="hover:border-guaiqui-primary transition-all duration-200"
        >
          <div class="flex items-center gap-4">
            <!-- Jersey Number Badge -->
            <div class="w-14 h-14 rounded-guaiqui-lg bg-guaiqui-primary-dark text-amber-400 font-display font-extrabold text-2xl flex items-center justify-center border-2 border-emerald-600 shadow-sm">
              #{{ p.number }}
            </div>

            <div class="space-y-1 flex-1">
              <div class="flex items-center justify-between">
                <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
                  {{ p.name }}
                </h3>
                <BaseBadge v-if="p.isStar" variant="accent" size="sm">Estrella</BaseBadge>
              </div>

              <div class="text-xs text-guaiqui-primary font-semibold">
                {{ p.position }}
              </div>

              <div class="text-xs text-guaiqui-text-muted flex items-center gap-2">
                <span>Estatura: {{ p.height }}</span>
                <span>• {{ p.nationality }}</span>
              </div>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
