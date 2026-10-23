<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseSelect, BaseButton } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import {
  FONT_FAMILY_OPTIONS,
  FONT_SIZE_OPTIONS,
  LETTER_SPACING_OPTIONS,
  FONT_WEIGHT_OPTIONS,
  POPULAR_ICONS,
  type CtaFormData
} from './ctaTypes'

const props = defineProps<{
  modelValue: CtaFormData
}>()

const uploadingImage = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  uploadingImage.value = true
  try {
    const fileExt = file.name.split('.').pop()
    const fileName = `cta-${Date.now()}-${Math.random().toString(36).substring(2, 8)}.${fileExt}`
    const filePath = `landing-cta/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('site-media')
      .upload(filePath, file, { cacheControl: '3600', upsert: true })

    if (uploadError) throw uploadError

    const { data } = supabase.storage.from('site-media').getPublicUrl(filePath)
    props.modelValue.media_value = data.publicUrl
  } catch (err: any) {
    alert('Error al subir la imagen: ' + (err.message || 'Desconocido'))
  } finally {
    uploadingImage.value = false
    if (fileInput.value) fileInput.value.value = ''
  }
}

const selectIcon = (iconName: string) => {
  props.modelValue.media_value = iconName
}
</script>

<template>
  <div class="space-y-4">
    <!-- Phrase text -->
    <div class="flex flex-col gap-1.5">
      <label class="text-xs font-semibold text-slate-300">
        Frase o Lema Destacado <span class="text-emerald-400">*</span>
      </label>
      <textarea
        v-model="modelValue.phrase_text"
        rows="2"
        placeholder="Ej: ¡EL ORGULLO DE NUEVA ESPARTA!"
        class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
      ></textarea>
    </div>

    <!-- Typography Controls: Font Family & Size -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <BaseSelect
        v-model="modelValue.font_family"
        label="Familia Tipográfica (Font Family)"
        :options="FONT_FAMILY_OPTIONS"
      />
      <BaseSelect
        v-model="modelValue.font_size"
        label="Tamaño de Letra"
        :options="FONT_SIZE_OPTIONS"
      />
    </div>

    <!-- Typography Controls: Letter Spacing & Weight -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <BaseSelect
        v-model="modelValue.letter_spacing"
        label="Interletrado (Letter Spacing)"
        :options="LETTER_SPACING_OPTIONS"
      />
      <BaseSelect
        v-model="modelValue.font_weight"
        label="Grosor de Fuente (Font Weight)"
        :options="FONT_WEIGHT_OPTIONS"
      />
    </div>

    <!-- Media Selector -->
    <div class="space-y-3 pt-2 border-t border-slate-800">
      <label class="text-xs font-semibold text-slate-300 flex items-center justify-between">
        <span>Elemento Multimedia Adicional</span>
        <span class="text-[11px] text-slate-400 font-normal">Escoge si acompañar la frase con un logo, icono o imagen</span>
      </label>

      <!-- Media Type Radio Pill Buttons -->
      <div class="grid grid-cols-4 gap-2">
        <button
          type="button"
          @click="modelValue.media_type = 'none'"
          :class="[
            'py-2 px-3 rounded-lg text-xs font-medium border text-center transition-all',
            modelValue.media_type === 'none'
              ? 'bg-guaiqui-primary/20 border-guaiqui-primary text-white font-semibold'
              : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
          ]"
        >
          <i class="bi bi-slash-circle block text-base mb-1"></i>
          Ninguno
        </button>

        <button
          type="button"
          @click="modelValue.media_type = 'logo'"
          :class="[
            'py-2 px-3 rounded-lg text-xs font-medium border text-center transition-all',
            modelValue.media_type === 'logo'
              ? 'bg-guaiqui-primary/20 border-guaiqui-primary text-white font-semibold'
              : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
          ]"
        >
          <i class="bi bi-shield-shaded block text-base mb-1 text-emerald-400"></i>
          Logo Oficial
        </button>

        <button
          type="button"
          @click="modelValue.media_type = 'icon'"
          :class="[
            'py-2 px-3 rounded-lg text-xs font-medium border text-center transition-all',
            modelValue.media_type === 'icon'
              ? 'bg-guaiqui-primary/20 border-guaiqui-primary text-white font-semibold'
              : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
          ]"
        >
          <i class="bi bi-star-fill block text-base mb-1 text-amber-400"></i>
          Icono Bootstrap
        </button>

        <button
          type="button"
          @click="modelValue.media_type = 'image'"
          :class="[
            'py-2 px-3 rounded-lg text-xs font-medium border text-center transition-all',
            modelValue.media_type === 'image'
              ? 'bg-guaiqui-primary/20 border-guaiqui-primary text-white font-semibold'
              : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
          ]"
        >
          <i class="bi bi-image block text-base mb-1 text-sky-400"></i>
          Imagen
        </button>
      </div>

      <!-- Icon Configuration -->
      <div v-if="modelValue.media_type === 'icon'" class="space-y-3 p-3.5 rounded-xl bg-slate-900/80 border border-slate-700/80">
        <div class="flex items-center gap-2">
          <BaseInput
            v-model="modelValue.media_value"
            label="Clase del Icono Bootstrap"
            placeholder="Ej: bi-trophy-fill"
            class="flex-1"
          />
          <div
            v-if="modelValue.media_value"
            class="w-10 h-10 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center text-amber-300 text-xl self-end mb-1"
          >
            <i :class="['bi', modelValue.media_value]"></i>
          </div>
        </div>

        <div>
          <span class="text-[11px] text-slate-400 block mb-1.5 font-medium">Iconos sugeridos:</span>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="item in POPULAR_ICONS"
              :key="item.icon"
              type="button"
              @click="selectIcon(item.icon)"
              :class="[
                'px-2 py-1 rounded text-xs inline-flex items-center gap-1 border transition-colors',
                modelValue.media_value === item.icon
                  ? 'bg-amber-400/20 border-amber-400 text-amber-300'
                  : 'bg-slate-800 border-slate-700 text-slate-300 hover:bg-slate-700'
              ]"
            >
              <i :class="['bi', item.icon]"></i>
              {{ item.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- Image Configuration -->
      <div v-if="modelValue.media_type === 'image'" class="space-y-3 p-3.5 rounded-xl bg-slate-900/80 border border-slate-700/80">
        <BaseInput
          v-model="modelValue.media_value"
          label="URL de la Imagen"
          placeholder="https://... o sube una imagen"
        />

        <div class="flex items-center gap-3">
          <input
            ref="fileInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="handleFileUpload"
          />
          <BaseButton
            type="button"
            variant="secondary"
            size="sm"
            :loading="uploadingImage"
            @click="triggerFileInput"
          >
            <i class="bi bi-cloud-arrow-up mr-1.5"></i> Subir imagen a Storage
          </BaseButton>

          <span v-if="modelValue.media_value" class="text-xs text-emerald-400 inline-flex items-center gap-1">
            <i class="bi bi-check-circle-fill"></i> Imagen cargada
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
