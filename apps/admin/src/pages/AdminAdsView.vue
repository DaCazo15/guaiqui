<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import AdminVideoTable from '../components/ads/AdminVideoTable.vue'
import AdminVideoModal from '../components/ads/AdminVideoModal.vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'
import type { SponsorVideo } from '@guaiqui/shared'

const videos = ref<SponsorVideo[]>([])
const loading = ref(true)
const saving = ref(false)
const message = ref<{ text: string; type: 'success' | 'error' } | null>(null)

// Modal state
const isModalOpen = ref(false)
const selectedVideo = ref<SponsorVideo | null>(null)

// Delete confirmation modal state
const videoToDelete = ref<SponsorVideo | null>(null)
const deleting = ref(false)

const loadVideos = async () => {
  loading.value = true
  message.value = null
  try {
    const { data, error } = await supabase
      .from('sponsor_videos')
      .select('*')
      .order('order_index', { ascending: true })
      .order('created_at', { ascending: false })

    if (error) throw error
    videos.value = (data as SponsorVideo[]) || []
  } catch (err: any) {
    message.value = { text: err.message || 'Error al cargar los videos.', type: 'error' }
  } finally {
    loading.value = false
  }
}

const handleOpenCreate = () => {
  selectedVideo.value = null
  isModalOpen.value = true
}

const handleOpenEdit = (video: SponsorVideo) => {
  selectedVideo.value = video
  isModalOpen.value = true
}

const handleCloseModal = () => {
  isModalOpen.value = false
  selectedVideo.value = null
}

const handleSaveVideo = async (payload: Partial<SponsorVideo>) => {
  saving.value = true
  message.value = null
  try {
    if (selectedVideo.value?.id) {
      // Update
      const { error } = await supabase
        .from('sponsor_videos')
        .update({
          title: payload.title,
          sponsor_name: payload.sponsor_name,
          video_url: payload.video_url,
          drive_file_id: payload.drive_file_id,
          redirect_url: payload.redirect_url,
          cta_text: payload.cta_text,
          min_seconds: payload.min_seconds,
          reward_points: payload.reward_points,
          is_active: payload.is_active,
          order_index: payload.order_index,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedVideo.value.id)

      if (error) throw error
      message.value = { text: 'Video de patrocinador actualizado exitosamente.', type: 'success' }
    } else {
      // Insert
      const { error } = await supabase.from('sponsor_videos').insert({
        title: payload.title!,
        sponsor_name: payload.sponsor_name,
        video_url: payload.video_url!,
        drive_file_id: payload.drive_file_id!,
        redirect_url: payload.redirect_url,
        cta_text: payload.cta_text || 'Visitar Patrocinador',
        min_seconds: payload.min_seconds ?? 15,
        reward_points: payload.reward_points ?? 10,
        is_active: payload.is_active ?? true,
        order_index: payload.order_index ?? 0,
      })

      if (error) throw error
      message.value = { text: 'Video de patrocinador creado exitosamente.', type: 'success' }
    }

    handleCloseModal()
    await loadVideos()
  } catch (err: any) {
    message.value = { text: err.message || 'Error al guardar el video.', type: 'error' }
  } finally {
    saving.value = false
  }
}

const handleToggleActive = async (video: SponsorVideo) => {
  try {
    const updatedStatus = !video.is_active
    const { error } = await supabase
      .from('sponsor_videos')
      .update({ is_active: updatedStatus, updated_at: new Date().toISOString() })
      .eq('id', video.id)

    if (error) throw error
    video.is_active = updatedStatus
    message.value = {
      text: `El video "${video.title}" ahora está ${updatedStatus ? 'activo' : 'pausado'}.`,
      type: 'success',
    }
  } catch (err: any) {
    message.value = { text: err.message || 'Error al cambiar estado del video.', type: 'error' }
  }
}

const confirmDelete = (video: SponsorVideo) => {
  videoToDelete.value = video
}

const handleDeleteVideo = async () => {
  if (!videoToDelete.value) return
  deleting.value = true
  message.value = null
  try {
    const { error } = await supabase.from('sponsor_videos').delete().eq('id', videoToDelete.value.id)
    if (error) throw error
    message.value = { text: 'Video eliminado correctamente.', type: 'success' }
    videoToDelete.value = null
    await loadVideos()
  } catch (err: any) {
    message.value = { text: err.message || 'Error al eliminar el video.', type: 'error' }
  } finally {
    deleting.value = false
  }
}

onMounted(() => {
  loadVideos()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Encabezado de página -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-white uppercase tracking-wide">
            Videos de Patrocinadores (Google Drive)
          </h1>
          <p class="text-sm text-slate-400">
            Administra los videos comerciales de marcas aliadas alojados en Google Drive, recompensas en perlitas y botones de redirección.
          </p>
        </div>

        <BaseButton variant="primary" size="md" @click="handleOpenCreate">
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Video
        </BaseButton>
      </div>

      <!-- Mensajes de feedback -->
      <div
        v-if="message"
        :class="[
          'p-4 rounded-xl text-sm font-semibold flex items-center justify-between',
          message.type === 'success' ? 'bg-emerald-950/80 text-emerald-300 border border-emerald-800' : 'bg-red-950/80 text-red-300 border border-red-800',
        ]"
      >
        <div class="flex items-center gap-2">
          <i :class="message.type === 'success' ? 'bi bi-check-circle-fill text-emerald-400' : 'bi bi-exclamation-triangle-fill text-red-400'"></i>
          <span>{{ message.text }}</span>
        </div>
        <button @click="message = null" class="text-xs underline ml-4 cursor-pointer text-slate-400 hover:text-white">Cerrar</button>
      </div>

      <!-- Guía Rápida para Google Drive -->
      <div class="p-5 bg-slate-900 border border-slate-800 rounded-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 shadow-xl">
        <div class="flex items-start gap-3">
          <div class="w-10 h-10 rounded-xl bg-slate-800 shadow-xs border border-slate-700 flex items-center justify-center text-emerald-400 text-lg shrink-0">
            <i class="bi bi-google"></i>
          </div>
          <div class="space-y-1">
            <h3 class="text-xs font-bold uppercase tracking-wider text-emerald-400">
              ¿Cómo agregar videos desde tu carpeta de Google Drive?
            </h3>
            <p class="text-xs text-slate-400 leading-relaxed max-w-2xl">
              1. Sube el video a Google Drive &bull; 2. Clic derecho en el archivo &gt; <strong class="text-white">Compartir</strong> &gt; Configura el acceso como <strong class="text-emerald-400">"Cualquier persona con el enlace"</strong> &bull; 3. Copia el enlace y pégalo aquí. El reproductor y la recompensa se integrarán automáticamente.
            </p>
          </div>
        </div>
        <div class="shrink-0 flex items-center gap-2">
          <span class="text-[11px] font-bold text-emerald-300 bg-emerald-950/80 px-2.5 py-1 rounded-full border border-emerald-800 font-mono">
            {{ videos.filter(v => v.is_active).length }} Activos / {{ videos.length }} Totales
          </span>
        </div>
      </div>

      <!-- Tabla de Videos -->
      <AdminVideoTable
        :videos="videos"
        :loading="loading"
        @create="handleOpenCreate"
        @edit="handleOpenEdit"
        @delete="confirmDelete"
        @toggle-active="handleToggleActive"
      />

      <!-- Modal de Creación / Edición -->
      <AdminVideoModal
        :is-open="isModalOpen"
        :video="selectedVideo"
        :saving="saving"
        @close="handleCloseModal"
        @save="handleSaveVideo"
      />

      <!-- Modal de Confirmación de Eliminación -->
      <BaseModal
        :model-value="!!videoToDelete"
        title="Confirmar Eliminación"
        size="sm"
        @update:model-value="(val: boolean) => !val && (videoToDelete = null)"
      >
        <div class="space-y-3 text-center py-2">
          <div class="w-12 h-12 rounded-full bg-red-950/80 border border-red-800 text-red-400 flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-trash-fill"></i>
          </div>
          <h3 class="font-bold text-white text-base">¿Deseas eliminar este video?</h3>
          <p class="text-xs text-slate-400">
            Esta acción eliminará el video <strong class="text-white">"{{ videoToDelete?.title }}"</strong> permanentemente del catálogo de patrocinadores.
          </p>
        </div>

        <template #footer>
          <div class="flex items-center justify-end gap-2">
            <BaseButton variant="secondary" size="sm" @click="videoToDelete = null">
              Cancelar
            </BaseButton>
            <BaseButton variant="danger" size="sm" :loading="deleting" @click="handleDeleteVideo">
              <i class="bi bi-trash mr-1"></i> Eliminar
            </BaseButton>
          </div>
        </template>
      </BaseModal>
    </div>
  </AdminLayout>
</template>
