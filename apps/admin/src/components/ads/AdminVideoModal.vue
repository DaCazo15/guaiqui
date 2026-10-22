<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { BaseModal, BaseButton, BaseInput } from '@guaiqui/ui'
import { extractGoogleDriveFileId, getGoogleDriveEmbedUrl, type SponsorVideo } from '@guaiqui/shared'

const props = defineProps<{
  isOpen: boolean
  video: SponsorVideo | null
  saving: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', payload: Partial<SponsorVideo>): void
}>()

const form = ref({
  title: '',
  sponsor_name: '',
  video_url: '',
  redirect_url: '',
  cta_text: 'Visitar Patrocinador',
  min_seconds: 15,
  reward_points: 10,
  is_active: true,
  order_index: 0,
})

const localError = ref<string | null>(null)

watch(
  () => props.video,
  (newVal) => {
    if (newVal) {
      form.value = {
        title: newVal.title || '',
        sponsor_name: newVal.sponsor_name || '',
        video_url: newVal.video_url || '',
        redirect_url: newVal.redirect_url || '',
        cta_text: newVal.cta_text || 'Visitar Patrocinador',
        min_seconds: newVal.min_seconds ?? 15,
        reward_points: newVal.reward_points ?? 10,
        is_active: newVal.is_active ?? true,
        order_index: newVal.order_index ?? 0,
      }
    } else {
      form.value = {
        title: '',
        sponsor_name: '',
        video_url: '',
        redirect_url: '',
        cta_text: 'Visitar Patrocinador',
        min_seconds: 15,
        reward_points: 10,
        is_active: true,
        order_index: 0,
      }
    }
    localError.value = null
  },
  { immediate: true }
)

const detectedFileId = computed(() => {
  return extractGoogleDriveFileId(form.value.video_url)
})

const embedPreviewUrl = computed(() => {
  return getGoogleDriveEmbedUrl(form.value.video_url)
})

const handleSave = () => {
  localError.value = null

  if (!form.value.title.trim()) {
    localError.value = 'El título del video es obligatorio.'
    return
  }

  if (!form.value.video_url.trim()) {
    localError.value = 'El enlace o ID de Google Drive es obligatorio.'
    return
  }

  const fileId = extractGoogleDriveFileId(form.value.video_url)
  if (!fileId) {
    localError.value =
      'No se pudo extraer el ID de Google Drive. Pega un enlace válido (ej: https://drive.google.com/file/d/.../view).'
    return
  }

  if (form.value.min_seconds < 1) {
    localError.value = 'La duración mínima en segundos debe ser al menos 1.'
    return
  }

  if (form.value.reward_points < 0) {
    localError.value = 'Las perlitas de recompensa no pueden ser negativas.'
    return
  }

  emit('save', {
    title: form.value.title.trim(),
    sponsor_name: form.value.sponsor_name.trim() || null,
    video_url: form.value.video_url.trim(),
    drive_file_id: fileId,
    redirect_url: form.value.redirect_url.trim() || null,
    cta_text: form.value.cta_text.trim() || 'Visitar Patrocinador',
    min_seconds: Number(form.value.min_seconds),
    reward_points: Number(form.value.reward_points),
    is_active: form.value.is_active,
    order_index: Number(form.value.order_index),
  })
}
</script>

<template>
  <BaseModal
    :model-value="isOpen"
    :title="video ? 'Editar Video de Patrocinador' : 'Nuevo Video de Patrocinador'"
    size="lg"
    @update:model-value="(val: boolean) => !val && emit('close')"
  >
    <div class="space-y-6">
      <div v-if="localError" class="p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-xs flex items-center gap-2">
        <i class="bi bi-exclamation-circle-fill text-red-600"></i>
        <span>{{ localError }}</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <!-- Título -->
        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Título del Video <span class="text-red-500">*</span>
          </label>
          <input
            v-model="form.title"
            type="text"
            required
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            placeholder="Ej: Spot Oficial Temporada 2026"
          />
        </div>

        <!-- Nombre del Patrocinador -->
        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Nombre del Patrocinador / Marca
          </label>
          <input
            v-model="form.sponsor_name"
            type="text"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            placeholder="Ej: Naviarca / Banesco / Empresas Polar"
          />
        </div>
      </div>

      <!-- Enlace de Google Drive -->
      <div>
        <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
          Enlace o ID de Google Drive <span class="text-red-500">*</span>
        </label>
        <input
          v-model="form.video_url"
          type="text"
          required
          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
          placeholder="https://drive.google.com/file/d/1A2B3C.../view?usp=sharing"
        />
        <p class="text-[11px] text-gray-500 mt-1 flex items-center gap-1">
          <i class="bi bi-info-circle text-gray-400"></i>
          Asegúrate de que en Google Drive el archivo tenga permisos: <strong>"Cualquier persona con el enlace"</strong>.
        </p>
      </div>

      <!-- Vista previa reactiva del reproductor Google Drive -->
      <div v-if="embedPreviewUrl" class="p-4 bg-gray-50 border border-gray-200 rounded-xl space-y-2">
        <div class="flex items-center justify-between text-xs font-semibold text-gray-700">
          <span class="flex items-center gap-1.5 text-emerald-700 font-bold">
            <i class="bi bi-check-circle-fill text-emerald-600"></i>
            ID detectado: <span class="font-mono text-gray-800">{{ detectedFileId }}</span>
          </span>
          <span class="text-gray-400 text-[10px]">Vista Previa del Reproductor</span>
        </div>
        <div class="relative w-full aspect-video rounded-lg overflow-hidden border border-gray-300 bg-black">
          <iframe
            :src="embedPreviewUrl"
            class="w-full h-full border-0"
            allow="autoplay; encrypted-media"
            allowfullscreen
          ></iframe>
        </div>
      </div>

      <!-- Redirección del Patrocinador & Botón CTA -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Enlace de Redirección (Sitio Web del Patrocinador)
          </label>
          <input
            v-model="form.redirect_url"
            type="url"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            placeholder="https://patrocinador.com/promo"
          />
        </div>

        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Texto del Botón de Redirección (CTA)
          </label>
          <input
            v-model="form.cta_text"
            type="text"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            placeholder="Visitar Patrocinador"
          />
        </div>
      </div>

      <!-- Previsualización del botón CTA -->
      <div v-if="form.redirect_url" class="p-3 bg-emerald-50/60 border border-emerald-200 rounded-lg flex items-center justify-between text-xs">
        <div class="space-y-0.5">
          <span class="font-bold text-emerald-900 block">Previsualización del Botón para los Fanáticos:</span>
          <span class="text-gray-500 text-[11px] truncate block max-w-sm">{{ form.redirect_url }}</span>
        </div>
        <a
          :href="form.redirect_url"
          target="_blank"
          rel="noopener noreferrer"
          class="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg text-xs flex items-center gap-1.5 transition-colors"
        >
          <span>{{ form.cta_text || 'Visitar Patrocinador' }}</span>
          <i class="bi bi-box-arrow-up-right text-[10px]"></i>
        </a>
      </div>

      <!-- Reglas de visualización: Tiempo, Recompensa, Orden y Estado -->
      <div class="grid grid-cols-1 sm:grid-cols-4 gap-4 pt-2 border-t border-gray-200">
        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Duración Mínima (Seg)
          </label>
          <input
            v-model.number="form.min_seconds"
            type="number"
            min="1"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Recompensa (Perlitas)
          </label>
          <input
            v-model.number="form.reward_points"
            type="number"
            min="0"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg font-bold text-emerald-700 focus:ring-2 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Orden de Visualización
          </label>
          <input
            v-model.number="form.order_index"
            type="number"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block text-xs font-bold text-gray-700 uppercase mb-1">
            Estado del Video
          </label>
          <label class="flex items-center gap-2 mt-2.5 cursor-pointer">
            <input
              v-model="form.is_active"
              type="checkbox"
              class="w-4 h-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500"
            />
            <span class="text-xs font-semibold" :class="form.is_active ? 'text-emerald-700' : 'text-gray-500'">
              {{ form.is_active ? 'Activo (Visible)' : 'Inactivo (Pausado)' }}
            </span>
          </label>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <BaseButton variant="secondary" size="md" @click="emit('close')">
          Cancelar
        </BaseButton>
        <BaseButton variant="primary" size="md" :loading="saving" @click="handleSave">
          <i class="bi bi-check-lg mr-1.5"></i>
          {{ video ? 'Guardar Cambios' : 'Crear Video' }}
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
