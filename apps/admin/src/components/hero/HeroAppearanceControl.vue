<script setup lang="ts">
import { ref } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

const props = withDefaults(defineProps<{
  heroImageUrl?: string | null
  heroCardColor?: string | null
  darkModeEnabled?: boolean
  themeColor?: string
}>(), {
  heroImageUrl: '',
  heroCardColor: '',
  darkModeEnabled: true,
  themeColor: '#059669'
})

const emit = defineEmits<{
  (e: 'update:heroImageUrl', val: string): void
  (e: 'update:heroCardColor', val: string): void
  (e: 'update:darkModeEnabled', val: boolean): void
  (e: 'update:themeColor', val: string): void
}>()

const uploadingImage = ref(false)
const heroFileInput = ref<HTMLInputElement | null>(null)

const triggerHeroFileInput = () => {
  heroFileInput.value?.click()
}

const MAX_FILE_SIZE_MB = 20

const handleHeroImageUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  if (file.size > MAX_FILE_SIZE_MB * 1024 * 1024) {
    alert(`La imagen seleccionada supera el límite permitido de ${MAX_FILE_SIZE_MB}MB (${(file.size / (1024 * 1024)).toFixed(1)}MB). Por favor elige una imagen más ligera o comprimida.`)
    if (heroFileInput.value) heroFileInput.value.value = ''
    return
  }

  uploadingImage.value = true
  try {
    const ext = file.name.split('.').pop()
    const fileName = `hero-bg-${Date.now()}.${ext}`
    const path = `hero-media/${fileName}`

    const { error: uploadErr } = await supabase.storage.from('site-media').upload(path, file, {
      cacheControl: '3600',
      upsert: true
    })
    if (uploadErr) throw uploadErr

    const { data } = supabase.storage.from('site-media').getPublicUrl(path)
    emit('update:heroImageUrl', data.publicUrl)
  } catch (err: any) {
    console.error('Error al subir imagen de fondo:', err)
    alert('Error al subir imagen de fondo: ' + (err.message || 'Error de conexión HTTP2'))
  } finally {
    uploadingImage.value = false
    if (heroFileInput.value) heroFileInput.value.value = ''
  }
}

const CARD_COLORS = [
  { label: 'Translúcido Oficial', value: '' },
  { label: 'Verde Oscuro Esmeralda', value: '#064E27' },
  { label: 'Verde Tribu Intenso', value: '#0B7A3B' },
  { label: 'Noche Pizarra', value: '#0F172A' },
  { label: 'Rojo Bandana', value: '#9B0B22' }
]
</script>

<template>
  <div class="space-y-5 p-5 rounded-2xl bg-slate-900 border border-slate-800">
    <h4 class="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
      <i class="bi bi-palette-fill text-emerald-400"></i>
      Fondo del Hero y Personalización de Apariencia
    </h4>

    <!-- Hero Background Image Upload -->
    <div class="space-y-2 p-4 rounded-xl bg-slate-950/60 border border-slate-800">
      <div class="flex items-center justify-between">
        <label class="text-xs font-semibold text-slate-300">
          Imagen de Fondo del Hero
        </label>
        <span class="text-[11px] text-slate-400">Se combina con el gradiente oficial de la tribu</span>
      </div>

      <div class="flex items-center gap-4">
        <!-- Preview of image -->
        <div class="w-24 h-16 rounded-xl bg-slate-900 border border-slate-700 overflow-hidden shrink-0 flex items-center justify-center relative">
          <img
            v-if="heroImageUrl"
            :src="heroImageUrl"
            alt="Hero Background Preview"
            class="w-full h-full object-cover"
          />
          <div v-else class="text-center p-1 text-[10px] text-slate-500">
            <i class="bi bi-image block text-base mb-0.5"></i> Gradiente base
          </div>
        </div>

        <div class="flex-1 space-y-2">
          <input
            ref="heroFileInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="handleHeroImageUpload"
          />

          <div class="flex items-center gap-2 flex-wrap">
            <BaseButton
              type="button"
              variant="secondary"
              size="sm"
              :loading="uploadingImage"
              @click="triggerHeroFileInput"
            >
              <i class="bi bi-cloud-arrow-up mr-1.5"></i> Subir Imagen al Hero
            </BaseButton>

            <button
              v-if="heroImageUrl"
              type="button"
              @click="emit('update:heroImageUrl', '')"
              class="text-xs text-red-400 hover:text-red-300 inline-flex items-center gap-1"
            >
              <i class="bi bi-trash"></i> Quitar imagen (usar solo gradiente)
            </button>
          </div>

          <input
            type="text"
            :value="heroImageUrl"
            @input="emit('update:heroImageUrl', ($event.target as HTMLInputElement).value)"
            placeholder="O escribe la URL de la imagen..."
            class="w-full rounded-lg bg-slate-900 border border-slate-700 text-slate-300 px-3 py-1.5 text-xs focus:border-guaiqui-primary focus:outline-hidden"
          />
        </div>
      </div>
    </div>

    <!-- Hero Card Color (for the right card when carousel is not active) -->
    <div class="space-y-2 p-4 rounded-xl bg-slate-950/60 border border-slate-800">
      <div class="flex items-center justify-between">
        <label class="text-xs font-semibold text-slate-300">
          Color de la Tarjeta del Hero (Modo Fijo)
        </label>
        <span class="text-[11px] text-slate-400">Aplica si el carrusel está desactivado</span>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <button
          v-for="color in CARD_COLORS"
          :key="color.value"
          type="button"
          @click="emit('update:heroCardColor', color.value)"
          :class="[
            'px-2.5 py-1 rounded-lg text-xs font-medium border flex items-center gap-1.5 transition-all',
            heroCardColor === color.value
              ? 'ring-2 ring-emerald-400 border-white text-white font-semibold'
              : 'border-slate-700 text-slate-400 hover:border-slate-500'
          ]"
        >
          <span
            class="w-3 h-3 rounded-full border border-black/30 shrink-0"
            :style="{ backgroundColor: color.value || 'rgba(255,255,255,0.1)' }"
          ></span>
          <span>{{ color.label }}</span>
        </button>

        <div class="flex items-center gap-1.5 ml-auto">
          <input
            type="color"
            :value="heroCardColor || '#064E27'"
            @input="emit('update:heroCardColor', ($event.target as HTMLInputElement).value)"
            class="w-7 h-7 rounded-lg cursor-pointer bg-slate-800 border border-slate-700 p-0.5"
          />
          <span class="text-[11px] text-slate-400">Color libre</span>
        </div>
      </div>
    </div>

    <!-- Theme & Dark Mode -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-xl bg-slate-950/60 border border-slate-800">
      <label class="flex items-center gap-3 text-sm text-slate-300 cursor-pointer">
        <input
          type="checkbox"
          :checked="darkModeEnabled"
          @change="emit('update:darkModeEnabled', ($event.target as HTMLInputElement).checked)"
          class="w-5 h-5 accent-emerald-500 rounded"
        />
        <span>Modo Oscuro Predeterminado para Nuevos Visitantes</span>
      </label>

      <div class="flex items-center gap-3">
        <label class="text-xs text-slate-400">Color Primario de Énfasis:</label>
        <input
          type="color"
          :value="themeColor"
          @input="emit('update:themeColor', ($event.target as HTMLInputElement).value)"
          class="w-8 h-8 rounded-lg cursor-pointer bg-slate-900 border border-slate-700 p-0.5"
        />
      </div>
    </div>
  </div>
</template>
