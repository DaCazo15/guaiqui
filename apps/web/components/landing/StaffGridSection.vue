<script setup lang="ts">
import { BaseCard, BaseBadge } from '@guaiqui/ui'
import { staffMembers } from '~/data/landingData'
</script>

<template>
  <section class="py-16 sm:py-24 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="text-center max-w-2xl mx-auto space-y-2">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest">Detrás del Equipo</span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Cuerpo Técnico y Directiva
        </h2>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="s in staffMembers"
          :key="s.id"
          variant="default"
          padding="md"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary font-display font-bold text-xl flex items-center justify-center border border-green-200">
              {{ s.name.charAt(0) }}
            </div>
            <div>
              <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
                {{ s.name }}
              </h3>
              <div class="text-xs text-guaiqui-text-muted mt-0.5">
                {{ s.role }}
              </div>
              <BaseBadge variant="soft" size="sm" class="mt-2">
                {{ s.category }}
              </BaseBadge>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
