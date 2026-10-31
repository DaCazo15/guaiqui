<script setup lang="ts">
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useReferrals } from '~/composables/useReferrals'

const {
  summary,
  loading,
  copied,
  copyCode,
  copyLink,
} = useReferrals()
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-6">
    <!-- Header & Share Code -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-guaiqui-border">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center shrink-0 text-xl font-bold">
          <i class="bi bi-people-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide">
            Mis Referidos
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Gana 5 perlitas por cada amigo que se registre con tu código.
          </p>
        </div>
      </div>

      <!-- Badge & Código -->
      <div class="flex items-center gap-2">
        <div class="px-3.5 py-1.5 bg-gray-100 rounded-guaiqui-lg font-mono font-bold text-sm tracking-widest text-guaiqui-text border border-gray-200">
          {{ summary.code || '...' }}
        </div>
        <BaseButton variant="outline" size="sm" @click="copyCode" title="Copiar código">
          <i :class="copied ? 'bi bi-check2 text-emerald-600' : 'bi bi-copy'"></i>
          <span class="ml-1 text-xs">{{ copied ? 'Copiado' : 'Copiar' }}</span>
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="copyLink" title="Copiar enlace directo">
          <i class="bi bi-share-fill mr-1 text-xs"></i>
          <span class="text-xs">Invitar</span>
        </BaseButton>
      </div>
    </div>

    <!-- Stats Band: Total Referidos y Puntos Obtenidos -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 text-center">
      <div class="p-3.5 bg-gray-50 rounded-guaiqui-lg border border-gray-100">
        <p class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider">Total Amigos</p>
        <p class="font-display font-bold text-xl text-guaiqui-text mt-0.5">{{ summary.total_referred }}</p>
      </div>

      <div class="p-3.5 bg-gray-50 rounded-guaiqui-lg border border-gray-100">
        <p class="text-xs font-semibold text-guaiqui-text-muted uppercase tracking-wider">Amigos Calificados</p>
        <p class="font-display font-bold text-xl text-emerald-600 mt-0.5">{{ summary.qualified_count }}</p>
      </div>

      <div class="p-3.5 bg-emerald-50 rounded-guaiqui-lg border border-emerald-100">
        <p class="text-xs font-bold text-emerald-800 uppercase tracking-wider">Puntos Obtenidos</p>
        <div class="mt-0.5 flex items-center justify-center font-display font-extrabold text-xl text-emerald-700">
          <PearlAmount :amount="summary.points_earned" size="md" />
        </div>
      </div>
    </div>

    <!-- Lista de Referidos o Estado Vacío -->
    <div v-if="loading && summary.referrals.length === 0" class="py-4 text-center text-xs text-gray-400">
      Cargando referidos...
    </div>

    <div v-else-if="summary.referrals.length > 0" class="space-y-2">
      <h3 class="text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted">
        Amigos que han usado tu código ({{ summary.referrals.length }})
      </h3>
      <div class="divide-y divide-gray-100 border border-gray-100 rounded-guaiqui-lg overflow-hidden bg-gray-50/50">
        <div
          v-for="refItem in summary.referrals"
          :key="refItem.id"
          class="p-3 flex items-center justify-between text-xs hover:bg-white transition-colors"
        >
          <div class="flex items-center gap-2.5">
            <div class="w-7 h-7 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-bold text-xs">
              {{ refItem.referred_name.charAt(0) }}
            </div>
            <div>
              <p class="font-semibold text-guaiqui-text">{{ refItem.referred_name }}</p>
              <p class="text-[10px] text-guaiqui-text-muted">
                {{ new Date(refItem.created_at).toLocaleDateString('es-VE') }}
              </p>
            </div>
          </div>

          <span
            class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider"
            :class="refItem.status === 'qualified' ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-200 text-gray-700'"
          >
            {{ refItem.status === 'qualified' ? 'Calificado' : 'Registrado' }}
          </span>
        </div>
      </div>
    </div>

    <div v-else class="text-center py-6 px-4 bg-gray-50/60 rounded-guaiqui-lg border border-dashed border-gray-200 space-y-2">
      <p class="text-xs text-guaiqui-text-muted">
        Aún no tienes amigos referidos. ¡Comparte tu código o enlace para ganar 5 perlitas por cada amigo!
      </p>
      <NuxtLink to="/app/referidos">
        <button type="button" class="text-xs font-bold text-guaiqui-primary hover:underline">
          Ver detalles del programa de referidos
          <i class="bi bi-arrow-right ml-1"></i>
        </button>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
