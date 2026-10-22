<script setup lang="ts">
import { BaseBadge, BaseButton } from '@guaiqui/ui'
import { getGoogleDriveEmbedUrl, type SponsorVideo } from '@guaiqui/shared'

defineProps<{
  videos: SponsorVideo[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'create'): void
  (e: 'edit', video: SponsorVideo): void
  (e: 'delete', video: SponsorVideo): void
  (e: 'toggle-active', video: SponsorVideo): void
}>()
</script>

<template>
  <div class="bg-white border border-gray-200 rounded-xl shadow-xs overflow-hidden">
    <div v-if="loading" class="p-12 text-center text-gray-500 font-medium space-y-2">
      <i class="bi bi-arrow-repeat animate-spin text-2xl text-emerald-600"></i>
      <p>Cargando videos de patrocinadores...</p>
    </div>

    <div v-else-if="videos.length === 0" class="p-12 text-center space-y-4">
      <div class="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center text-3xl mx-auto border border-emerald-100">
        <i class="bi bi-camera-video"></i>
      </div>
      <div class="space-y-1">
        <h3 class="text-base font-bold text-gray-900 uppercase">No hay videos de patrocinadores registrados</h3>
        <p class="text-xs text-gray-500 max-w-md mx-auto">
          Los videos que agregues desde tu carpeta de Google Drive aparecerán aquí y estarán disponibles para que los fanáticos los vean y ganen perlitas.
        </p>
      </div>
      <BaseButton variant="primary" size="sm" @click="emit('create')">
        <i class="bi bi-plus-lg mr-1.5"></i> Agregar Primer Video
      </BaseButton>
    </div>

    <div v-else class="overflow-x-auto">
      <table class="w-full text-xs text-left">
        <thead class="bg-gray-50 text-gray-600 uppercase font-bold border-b border-gray-200">
          <tr>
            <th class="p-4">Orden</th>
            <th class="p-4">Video & Patrocinador</th>
            <th class="p-4">Google Drive</th>
            <th class="p-4">Duración & Recompensa</th>
            <th class="p-4">Botón de Redirección</th>
            <th class="p-4 text-center">Estado</th>
            <th class="p-4 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <tr
            v-for="video in videos"
            :key="video.id"
            class="hover:bg-gray-50/80 transition-colors"
          >
            <!-- Orden -->
            <td class="p-4 font-mono font-bold text-gray-600">
              #{{ video.order_index }}
            </td>

            <!-- Video & Patrocinador -->
            <td class="p-4 space-y-0.5">
              <span class="font-bold text-gray-900 block text-sm">{{ video.title }}</span>
              <span
                v-if="video.sponsor_name"
                class="inline-block text-[11px] font-semibold text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200"
              >
                {{ video.sponsor_name }}
              </span>
              <span v-else class="text-[11px] text-gray-400 italic">Sin patrocinador asignado</span>
            </td>

            <!-- Google Drive ID & Enlace -->
            <td class="p-4 space-y-1">
              <div class="flex items-center gap-1.5 font-mono text-[11px] text-gray-700">
                <i class="bi bi-google text-blue-500"></i>
                <span class="truncate max-w-[140px]" :title="video.drive_file_id">{{ video.drive_file_id }}</span>
              </div>
              <a
                :href="getGoogleDriveEmbedUrl(video.video_url) || undefined"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1 text-[11px] text-emerald-600 hover:text-emerald-800 font-semibold underline"
              >
                <span>Probar Reproductor</span>
                <i class="bi bi-box-arrow-up-right text-[10px]"></i>
              </a>
            </td>

            <!-- Duración & Recompensa -->
            <td class="p-4 space-y-1">
              <div class="flex items-center gap-1.5 text-gray-700 font-semibold">
                <i class="bi bi-clock-history text-gray-400"></i>
                <span>{{ video.min_seconds }} segundos</span>
              </div>
              <div class="flex items-center gap-1.5 text-emerald-700 font-bold">
                <i class="bi bi-coin text-amber-500"></i>
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
                  class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-gray-100 hover:bg-gray-200 text-gray-800 rounded-md font-semibold text-[11px] transition-colors"
                >
                  <span>{{ video.cta_text || 'Visitar' }}</span>
                  <i class="bi bi-box-arrow-up-right text-[9px] text-gray-500"></i>
                </a>
                <span class="block text-[10px] text-gray-400 font-mono truncate max-w-[160px]" :title="video.redirect_url || undefined">
                  {{ video.redirect_url }}
                </span>
              </div>
              <span v-else class="text-[11px] text-gray-400 italic">Sin enlace configurado</span>
            </td>

            <!-- Estado -->
            <td class="p-4 text-center">
              <button
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold cursor-pointer transition-colors"
                :class="video.is_active ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
                @click="emit('toggle-active', video)"
                :title="video.is_active ? 'Clic para pausar' : 'Clic para activar'"
              >
                <i :class="video.is_active ? 'bi bi-check-circle-fill text-emerald-600' : 'bi bi-pause-circle-fill text-gray-400'"></i>
                <span>{{ video.is_active ? 'Activo' : 'Pausado' }}</span>
              </button>
            </td>

            <!-- Acciones -->
            <td class="p-4 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <button
                  type="button"
                  class="p-2 text-gray-600 hover:text-emerald-700 hover:bg-emerald-50 rounded-lg transition-colors cursor-pointer"
                  title="Editar video"
                  @click="emit('edit', video)"
                >
                  <i class="bi bi-pencil-fill text-sm"></i>
                </button>
                <button
                  type="button"
                  class="p-2 text-gray-600 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
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
