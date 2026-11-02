<script setup lang="ts">
import { BaseCard } from '@guaiqui/ui'
import type { PublicProfileFollowedTeam } from '@guaiqui/shared'

withDefaults(
  defineProps<{
    teams: PublicProfileFollowedTeam[]
    actionLoading?: Record<string, boolean>
    canFollow?: boolean
  }>(),
  {
    actionLoading: () => ({}),
    canFollow: true,
  }
)

const emit = defineEmits<{
  (e: 'toggle-follow-team', team: PublicProfileFollowedTeam): void
  (e: 'close'): void
}>()
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
    <!-- Encabezado de la Sección -->
    <div class="flex items-center justify-between pb-3.5 mb-3.5 border-b border-guaiqui-border/80">
      <div class="flex items-center gap-2.5">
        <div>
          <h2 class="font-display font-black text-base text-guaiqui-text uppercase tracking-wide leading-tight">
            Equipos que Sigue
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Clubes que este fanático apoya en la plataforma.
          </p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span
          v-if="teams && teams.length > 0"
          class="bg-emerald-50 text-emerald-800 border border-emerald-200/80 text-xs font-extrabold px-2.5 py-0.5 rounded-full"
        >
          {{ teams.length }}
        </span>
        <button
          type="button"
          @click="emit('close')"
          class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-slate-500 hover:text-slate-800 bg-slate-100 hover:bg-slate-200/80 rounded-lg transition-colors cursor-pointer"
          title="Cerrar y volver al perfil"
        >
          <span>Volver</span>
          <i class="bi bi-x-lg text-[10px]"></i>
        </button>
      </div>
    </div>

    <!-- Estado Vacío -->
    <div v-if="!teams || teams.length === 0" class="py-8 text-center text-guaiqui-text-muted">
      <div class="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center text-xl mx-auto mb-2">
        <i class="bi bi-shield"></i>
      </div>
      <p class="text-xs font-semibold text-guaiqui-text">No sigue a ningún equipo aún.</p>
      <NuxtLink
        to="/app/equipos"
        class="inline-flex items-center gap-1.5 mt-2.5 text-xs font-bold text-guaiqui-primary hover:text-emerald-700 transition-colors"
      >
        <span>Explorar clubes disponibles</span>
        <i class="bi bi-arrow-right text-xs"></i>
      </NuxtLink>
    </div>

    <!-- Grid de Equipos -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
      <div
        v-for="team in teams"
        :key="team.id"
        class="flex items-center justify-between gap-3 p-3 rounded-guaiqui-xl border border-guaiqui-border/80 bg-white hover:border-emerald-500/40 hover:shadow-xs transition-all"
      >
        <!-- Info del Equipo (Logo + Nombre enlazado) -->
        <div class="flex items-center gap-2.5 min-w-0">
          <img
            v-if="team.logo_url"
            :src="team.logo_url"
            :alt="team.name"
            class="w-10 h-10 rounded-xl object-contain bg-slate-50 border border-slate-200/80 p-1 shrink-0"
          />
          <div
            v-else
            class="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-800 border border-emerald-200/60 flex items-center justify-center font-bold text-base shrink-0"
          >
            <i class="bi bi-shield-shaded"></i>
          </div>

          <div class="min-w-0">
            <NuxtLink
              :to="`/e/${team.slug}`"
              class="font-display font-bold text-sm text-guaiqui-text hover:text-guaiqui-primary transition-colors block truncate"
              :title="team.name"
            >
              {{ team.name }}
            </NuxtLink>
          </div>
        </div>

        <!-- Botón de Seguir / Dejar de seguir -->
        <div v-if="canFollow" class="shrink-0">
          <!-- Si el visitante ya sigue a este equipo -->
          <button
            v-if="team.is_following"
            type="button"
            :disabled="actionLoading[team.id]"
            @click.stop="emit('toggle-follow-team', team)"
            class="group/btn inline-flex items-center justify-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer border border-emerald-200 bg-emerald-50 text-emerald-800 hover:bg-rose-50 hover:border-rose-200 hover:text-rose-700 active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed shadow-2xs"
            title="Dejar de seguir equipo"
          >
            <span
              v-if="actionLoading[team.id]"
              class="w-3.5 h-3.5 border-2 border-emerald-600 border-t-transparent rounded-full animate-spin"
            ></span>
            <template v-else>
              <span class="group-hover/btn:hidden flex items-center gap-1">
                <i class="bi bi-check2 text-emerald-700 font-bold"></i>
                <span class="text-[11px]">Siguiendo</span>
              </span>
              <span class="hidden group-hover/btn:flex items-center gap-1">
                <i class="bi bi-x-lg text-rose-600"></i>
                <span class="text-[11px]">Dejar</span>
              </span>
            </template>
          </button>

          <!-- Si el visitante no sigue a este equipo -->
          <button
            v-else
            type="button"
            :disabled="actionLoading[team.id]"
            @click.stop="emit('toggle-follow-team', team)"
            class="inline-flex items-center justify-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer bg-guaiqui-primary hover:bg-emerald-700 text-white shadow-2xs active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed"
            title="Seguir equipo"
          >
            <span
              v-if="actionLoading[team.id]"
              class="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin"
            ></span>
            <template v-else>
              <i class="bi bi-plus-lg text-xs"></i>
              <span class="text-[11px]">Seguir</span>
            </template>
          </button>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
