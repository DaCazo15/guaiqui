<script setup lang="ts">
import { BaseBadge, BaseButton } from '@guaiqui/ui'
import { getGoogleDriveEmbedUrl, type SponsorVideo } from '@guaiqui/shared'

withDefaults(defineProps<{
  videos: SponsorVideo[]
  loading: boolean
  readOnly?: boolean
}>(), {
  readOnly: false
})

const emit = defineEmits<{
  (e: 'create'): void
  (e: 'edit', video: SponsorVideo): void
  (e: 'delete', video: SponsorVideo): void
  (e: 'toggle-active', video: SponsorVideo): void
}>()
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl shadow-xl overflow-hidden">
    <div v-if="loading" class="p-12 text-center text-slate-400 font-medium space-y-2">
      <i class="bi bi-arrow-repeat animate-spin text-2xl text-emerald-400"></i>
      <p>Cargando videos de patrocinadores...</p>
    </div>

    <div v-else-if="videos.length === 0" class="p-12 text-center space-y-4">
      <div class="w-16 h-16 rounded-full bg-slate-800 text-emerald-400 flex items-center justify-center text-3xl mx-auto border border-slate-700">
        <i class="bi bi-camera-video"></i>
      </div>
      <div class="space-y-1">
        <h3 class="text-base font-bold text-white uppercase">No hay videos de patrocinadores registrados</h3>
        <p class="text-xs text-slate-400 max-w-md mx-auto">
          Los videos que agregues aparecerán aquí y estarán disponibles para que los fanáticos los vean y ganen perlitas.
        </p>
      </div>
    </div>

    <div v-else class="overflow-x-auto">
      <table class="w-full text-xs text-left">
        <thead class="bg-slate-950/80 text-slate-400 uppercase font-bold border-b border-slate-800">
          <tr>
            <th class="p-4">Orden</th>
            <th class="p-4">Video & Patrocinador</th>
            <th class="p-4">Google Drive</th>
            <th class="p-4">Duración & Recompensa</th>
            <th class="p-4">Botón de Redirección</th>
            <th class="p-4 text-center">Estado</th>
            <th v-if="!readOnly" class="p-4 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-800/60">
          <tr
            v-for="video in videos"
            :key="video.id"
            class="hover:bg-slate-800/40 transition-colors"
          >
            <!-- Orden -->
            <td class="p-4 font-mono font-bold text-emerald-400">
              #{{ video.order_index }}
            </td>

            <!-- Video & Patrocinador -->
            <td class="p-4 space-y-0.5">
              <span class="font-bold text-white block text-sm">{{ video.title }}</span>
              <span
                v-if="video.sponsor_name"
                class="inline-block text-[11px] font-semibold text-emerald-300 bg-emerald-950/80 px-2 py-0.5 rounded border border-emerald-800"
              >
                {{ video.sponsor_name }}
              </span>
              <span v-else class="text-[11px] text-slate-500 italic">Sin patrocinador asignado</span>
            </td>

            <!-- Google Drive ID & Enlace -->
            <td class="p-4 space-y-1">
              <div class="flex items-center gap-1.5 font-mono text-[11px] text-slate-300">
                <i class="bi bi-google text-blue-400"></i>
                <span class="truncate max-w-[140px]" :title="video.drive_file_id">{{ video.drive_file_id }}</span>
              </div>
              <a
                :href="getGoogleDriveEmbedUrl(video.video_url) || undefined"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1 text-[11px] text-emerald-400 hover:text-emerald-300 font-semibold underline"
              >
                <span>Probar Reproductor</span>
                <i class="bi bi-box-arrow-up-right text-[10px]"></i>
              </a>
            </td>

            <!-- Duración & Recompensa -->
            <td class="p-4 space-y-1">
              <div class="flex items-center gap-1.5 text-slate-300 font-semibold">
                <i class="bi bi-clock-history text-slate-400"></i>
                <span>{{ video.min_seconds }} segundos</span>
              </div>
              <div class="flex items-center gap-1.5 text-emerald-400 font-bold">
                <i class="bi bi-gem text-emerald-400"></i>
                <span>+{{ video.reward_points }} Perlitas</span>
              </div>
            </td>

            <!-- Botón de Redirección -->
            <td class="p-4">
              <div v-if="video.redirect_url" class="space-y-1">
                <a
                  :href="video.redirect_url || undefined"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-md font-semibold text-[11px] transition-colors border border-slate-700"
                >
                  <span>{{ video.cta_text || 'Visitar' }}</span>
                  <i class="bi bi-box-arrow-up-right text-[9px] text-slate-400"></i>
                </a>
                <span class="block text-[10px] text-slate-400 font-mono truncate max-w-[160px]" :title="video.redirect_url || undefined">
                  {{ video.redirect_url }}
                </span>
              </div>
              <span v-else class="text-[11px] text-slate-500 italic">Sin enlace configurado</span>
            </td>

            <!-- Estado -->
            <td class="p-4 text-center">
              <span
                v-if="readOnly"
                class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold border"
                :class="video.is_active ? 'bg-emerald-950/80 text-emerald-300 border-emerald-800' : 'bg-slate-800 text-slate-400 border-slate-700'"
              >
                <i :class="video.is_active ? 'bi bi-check-circle-fill text-emerald-400' : 'bi bi-pause-circle-fill text-slate-400'"></i>
                <span>{{ video.is_active ? 'Activo' : 'Pausado' }}</span>
              </span>
              <button
                v-else
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold cursor-pointer transition-colors border"
                :class="video.is_active ? 'bg-emerald-950/80 text-emerald-300 border-emerald-800 hover:bg-emerald-900/80' : 'bg-slate-800 text-slate-400 border-slate-700 hover:bg-slate-700'"
                @click="emit('toggle-active', video)"
                :title="video.is_active ? 'Clic para pausar' : 'Clic para activar'"
              >
                <i :class="video.is_active ? 'bi bi-check-circle-fill text-emerald-400' : 'bi bi-pause-circle-fill text-slate-400'"></i>
                <span>{{ video.is_active ? 'Activo' : 'Pausado' }}</span>
              </button>
            </td>

            <!-- Acciones -->
            <td v-if="!readOnly" class="p-4 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <button
                  type="button"
                  class="p-2 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
                  title="Editar video"
                  @click="emit('edit', video)"
                >
                  <i class="bi bi-pencil-fill text-sm"></i>
                </button>
                <button
                  type="button"
                  class="p-2 text-red-400 hover:text-red-300 hover:bg-red-950 rounded-lg transition-colors cursor-pointer"
                  title="Eliminar video"
                  @click="emit('delete', video)"
                >
                  <i class="bi bi-trash-fill text-sm"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
