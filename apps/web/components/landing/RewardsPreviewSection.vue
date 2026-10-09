<script setup lang="ts">
import { BaseCard, BaseBadge, BaseButton, PearlAmount } from '@guaiqui/ui'
import { featuredRewards } from '~/data/landingData'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()

const handleRewardClick = (name: string) => {
  trackEvent('click_reward_preview', { rewardName: name })
}
</script>

<template>
  <section id="premios" class="py-16 sm:py-24 bg-white px-4 sm:px-8 scroll-mt-20">
    <div class="max-w-6xl mx-auto space-y-12">
      <!-- Section Header -->
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Catálogo de Canje
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight mt-2">
            Premios Exclusivos de la Tribu
          </h2>
        </div>

        <NuxtLink to="/registro">
          <BaseButton variant="primary" size="md">
            Ver Todos los Premios (24+)
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Rewards Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="item in featuredRewards"
          :key="item.id"
          variant="interactive"
          padding="md"
          class="flex flex-col justify-between"
          @click="handleRewardClick(item.name)"
        >
          <template #image>
            <div :class="['w-full h-44 bg-gradient-to-br flex items-center justify-center p-4 relative overflow-hidden', item.imageBg]">
              <!-- Decorative background glow -->
              <div class="absolute -right-6 -bottom-6 w-28 h-28 rounded-full bg-white/10 blur-xl pointer-events-none"></div>

              <BaseBadge variant="perlita" size="sm" class="absolute top-3 left-3 shadow-xs">
                {{ item.category }}
              </BaseBadge>

              <BaseBadge variant="accent" size="sm" class="absolute top-3 right-3 shadow-xs">
                {{ item.badge }}
              </BaseBadge>

              <!-- Product Category Icon -->
              <div class="w-16 h-16 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center text-white text-3xl font-bold border border-white/30 shadow-md">
                <i :class="['bi', item.icon || 'bi-gift-fill']"></i>
              </div>
            </div>
          </template>

          <div class="space-y-3 pt-2 flex-1 flex flex-col justify-between">
            <div>
              <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase leading-snug">
                {{ item.name }}
              </h3>
              <p class="text-xs text-guaiqui-text-muted mt-1">
                Disponibles: <strong class="text-guaiqui-text">{{ item.stock }} unidades</strong>
              </p>
            </div>

            <div class="flex items-center justify-between pt-3 border-t border-guaiqui-border">
              <PearlAmount :amount="item.perlitasCost" size="lg" show-label />
              <BaseButton variant="ghost" size="sm">
                Canjear
              </BaseButton>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
