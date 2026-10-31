<script setup lang="ts">
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import type { FanFollowedTeam } from '~/composables/useFanProfile'

defineProps<{
  teams: FanFollowedTeam[]
}>()
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-sm space-y-4">
    <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center shrink-0 text-xl font-bold">
          <i class="bi bi-shield-shaded"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide">
            Equipos que Sigues
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Tus clubes de baloncesto favoritos y tu saldo activo de perlitas en cada uno.
          </p>
        </div>
      </div>

      <NuxtLink to="/app/equipos" class="text-xs font-bold text-guaiqui-primary hover:underline">
        Explorar equipos
      </NuxtLink>
    </div>

    <!-- Lista de Equipos Seguidos -->
    <div v-if="teams.length > 0" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <div
        v-for="t in teams"
        :key="t.team_id"
        class="p-3.5 bg-gray-50 rounded-guaiqui-xl border border-gray-100 flex items-center justify-between hover:bg-white hover:border-guaiqui-primary/40 transition-all"
      >
        <div class="flex items-center gap-3">
          <img
            v-if="t.logo_url"
            :src="t.logo_url"
            :alt="t.name"
            class="w-10 h-10 object-contain rounded-lg"
          />
          <div v-else class="w-10 h-10 rounded-lg bg-guaiqui-primary text-white flex items-center justify-center font-bold">
            {{ t.name.charAt(0) }}
          </div>
          <div>
            <h3 class="font-display font-bold text-sm text-guaiqui-text leading-snug">
              {{ t.name }}
            </h3>
            <p class="text-[11px] text-guaiqui-text-muted">
              Fanático desde {{ new Date(t.followed_at).toLocaleDateString('es-VE') }}
            </p>
          </div>
        </div>

        <div class="text-right">
          <p class="text-[10px] uppercase font-bold text-gray-400">Saldo</p>
          <div class="flex items-center justify-end font-display font-bold text-sm text-guaiqui-primary">
            <PearlAmount :amount="t.balance_cache" size="xs" />
          </div>
        </div>
      </div>
    </div>

    <!-- Estado vacío -->
    <div v-else class="text-center py-6 px-4 bg-gray-50 rounded-guaiqui-xl border border-dashed border-gray-200 space-y-2">
      <p class="text-xs text-guaiqui-text-muted">
        Aún no sigues a ningún equipo. ¡Sigue a tu equipo favorito para desbloquear sus trivias, canjes y ganar la insignia Corazón de la Tribu!
      </p>
      <NuxtLink to="/app/equipos">
        <button type="button" class="text-xs font-bold text-guaiqui-primary hover:underline">
          Ir al catálogo de equipos
          <i class="bi bi-arrow-right ml-1"></i>
        </button>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
