<script setup lang="ts">
import { BaseCard } from '@guaiqui/ui'
import type { PublicProfileFollowedTeam } from '@guaiqui/shared'

defineProps<{
  teams: PublicProfileFollowedTeam[]
}>()
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
    <div class="flex items-center justify-between pb-3 mb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-sm">
          <i class="bi bi-shield-shaded"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Equipos que Sigue
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Clubes activos a los que este fanático apoya oficialmente.
          </p>
        </div>
      </div>
      <span
        v-if="teams.length > 0"
        class="bg-emerald-100 text-emerald-800 text-xs font-bold px-2 py-0.5 rounded-full"
      >
        {{ teams.length }}
      </span>
    </div>

    <div v-if="teams.length === 0" class="py-6 text-center text-guaiqui-text-muted">
      <i class="bi bi-shield text-2xl mb-1 text-slate-300 block"></i>
      <p class="text-xs font-medium">No sigue a ningún equipo aún.</p>
      <NuxtLink to="/app/equipos" class="inline-block mt-2 text-xs font-semibold text-guaiqui-primary hover:underline">
        Explorar equipos
      </NuxtLink>
    </div>

    <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
      <div
        v-for="team in teams"
        :key="team.id"
        class="flex items-center gap-3 p-2.5 rounded-guaiqui-xl border border-guaiqui-border hover:border-guaiqui-primary/40 bg-slate-50/50 transition-colors"
      >
        <img
          v-if="team.logo_url"
          :src="team.logo_url"
          :alt="team.name"
          class="w-9 h-9 rounded-full object-contain bg-white border border-guaiqui-border p-1 shrink-0"
        />
        <div
          v-else
          class="w-9 h-9 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-sm shrink-0"
        >
          <i class="bi bi-shield-shaded"></i>
        </div>
        <div class="min-w-0">
          <span class="font-bold text-xs text-guaiqui-text block truncate">{{ team.name }}</span>
          <span class="text-[10px] text-guaiqui-text-muted uppercase tracking-wider">Equipo Activo</span>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
