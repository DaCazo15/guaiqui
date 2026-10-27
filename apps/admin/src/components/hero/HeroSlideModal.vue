<script setup lang="ts">
import { ref } from 'vue'
import { BaseModal, BaseButton, BaseInput } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

export interface HeroSlideFormData {
  id: string
  title: string
  tag: string
  tag_variant: 'primary' | 'gold' | 'accent'
  subtitle: string
  image_url: string
  image_layout: 'background' | 'right'
  text_align: 'left' | 'center'
  cta_text: string
  cta_url: string
  cta_secondary_text: string
  cta_secondary_url: string
  highlight_title: string
  highlight_subtitle: string
  highlight_badge: string
  show_guarantees: boolean
  guarantee_1: string
  guarantee_2: string
  guarantee_3: string
  order_index: number
  is_published: boolean
}

const props = defineProps<{
  isOpen: boolean
  form: HeroSlideFormData
  actionLoading: boolean
  errorMessage: string | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save'): void
}>()

const uploadingImage = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const MAX_FILE_SIZE_MB = 20

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  if (file.size > MAX_FILE_SIZE_MB * 1024 * 1024) {
    alert(`La imagen seleccionada supera el límite permitido de ${MAX_FILE_SIZE_MB}MB. Por favor elige una imagen más ligera.`)
    if (fileInput.value) fileInput.value.value = ''
    return
  }

  uploadingImage.value = true
  try {
    const fileExt = file.name.split('.').pop()
    const fileName = `hero-slide-${Date.now()}-${Math.random().toString(36).substring(2, 7)}.${fileExt}`
    const filePath = `hero/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('public-assets')
      .upload(filePath, file, { upsert: true })

    if (uploadError) throw uploadError

    const { data: publicData } = supabase.storage
      .from('public-assets')
      .getPublicUrl(filePath)

    props.form.image_url = publicData.publicUrl
  } catch (err: any) {
    console.error('Error al subir imagen:', err)
    alert(err.message || 'No se pudo subir la imagen al servidor.')
  } finally {
    uploadingImage.value = false
    if (fileInput.value) fileInput.value.value = ''
  }
}
</script>

<template>
  <BaseModal
    v-if="isOpen"
    :is-open="isOpen"
    :title="form.id ? 'Editar Diapositiva del Carrusel' : 'Nueva Diapositiva para el Hero'"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-5">
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-200 text-xs rounded-lg flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Section 1: Badge, Variant & Order -->
      <div class="grid grid-cols-1 sm:grid-cols-12 gap-3">
        <div class="sm:col-span-6">
          <BaseInput
            label="Etiqueta / Badge"
            v-model="form.tag"
            placeholder="Ej: Próximo Partido, Fan Zone, Concurso"
          />
        </div>

        <div class="sm:col-span-4 flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-slate-300">Estilo de Etiqueta</label>
          <select
            v-model="form.tag_variant"
            class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
          >
            <option value="primary">Verde Tribu (Oficial)</option>
            <option value="gold">Dorado Campeón (Premios / Estrellas)</option>
            <option value="accent">Rojo Bandana (En Vivo / Urgente)</option>
          </select>
        </div>

        <div class="sm:col-span-2">
          <BaseInput
            label="Orden (1-5)"
            type="number"
            min="1"
            max="5"
            v-model.number="form.order_index"
          />
        </div>
      </div>

      <!-- Section 2: Headline & Subtitle -->
      <BaseInput
        label="Título Principal de la Diapositiva"
        v-model="form.title"
        placeholder="Ej: ¡Gran Final Oriental en el Gimnasio!"
        required
      />

      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-semibold text-slate-300">Descripción / Subtítulo</label>
        <textarea
          v-model="form.subtitle"
          rows="2"
          placeholder="Ej: Acompáñanos este sábado y gana perlitas exclusivas respondiendo trivias..."
          class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
        ></textarea>
      </div>

      <!-- Section 3: Image & Layout Mode -->
      <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
        <div class="flex items-center justify-between">
          <label class="text-xs font-bold text-white flex items-center gap-1.5">
            <i class="bi bi-image text-emerald-400"></i> Imagen y Presentación
          </label>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label
            :class="[
              'p-3 rounded-xl border cursor-pointer flex items-center gap-3 transition-all',
              form.image_layout === 'background'
                ? 'bg-emerald-950/40 border-emerald-500 text-white'
                : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700'
            ]"
          >
            <input type="radio" value="background" v-model="form.image_layout" class="sr-only" />
            <i class="bi bi-aspect-ratio text-xl text-emerald-400"></i>
            <div>
              <div class="text-xs font-bold">Fondo Inmersivo</div>
              <div class="text-[11px] text-slate-400">Cubre todo el Hero con overlay oscuro</div>
            </div>
          </label>

          <label
            :class="[
              'p-3 rounded-xl border cursor-pointer flex items-center gap-3 transition-all',
              form.image_layout === 'right'
                ? 'bg-emerald-950/40 border-emerald-500 text-white'
                : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700'
            ]"
          >
            <input type="radio" value="right" v-model="form.image_layout" class="sr-only" />
            <i class="bi bi-person-workspace text-xl text-emerald-400"></i>
            <div>
              <div class="text-xs font-bold">Foto a la Derecha</div>
              <div class="text-[11px] text-slate-400">Texto a la izquierda e imagen destacada</div>
            </div>
          </label>
        </div>

        <!-- File upload -->
        <div class="flex items-center gap-3 pt-2">
          <div class="w-16 h-16 rounded-lg bg-slate-950 border border-slate-800 overflow-hidden shrink-0 flex items-center justify-center">
            <img v-if="form.image_url" :src="form.image_url" alt="Preview" class="w-full h-full object-cover" />
            <i v-else class="bi bi-image text-slate-600 text-2xl"></i>
          </div>

          <div class="flex-1 space-y-2">
            <input
              ref="fileInput"
              type="file"
              accept="image/*"
              class="hidden"
              @change="handleFileUpload"
            />
            <div class="flex items-center gap-2">
              <BaseButton
                type="button"
                variant="secondary"
                size="sm"
                :loading="uploadingImage"
                @click="triggerFileInput"
              >
                <i class="bi bi-cloud-arrow-up mr-1.5"></i> Subir Archivo
              </BaseButton>
              <span class="text-[11px] text-slate-500">JPG, PNG, WEBP (máx. 20MB)</span>
            </div>
            <input
              type="text"
              v-model="form.image_url"
              placeholder="O pega una URL directa de imagen..."
              class="w-full rounded-lg bg-slate-950 border border-slate-800 text-xs text-white px-2.5 py-1.5 focus:border-guaiqui-primary focus:outline-hidden"
            />
          </div>
        </div>
      </div>

      <!-- Section 4: CTAs -->
      <div class="space-y-3 p-4 bg-slate-900/60 border border-slate-800 rounded-xl">
        <label class="text-xs font-bold text-white flex items-center gap-1.5">
          <i class="bi bi-cursor-fill text-emerald-400"></i> Botones de Acción (CTAs)
        </label>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput label="Texto Botón Principal" v-model="form.cta_text" placeholder="Ej: Participar Ahora" />
          <BaseInput label="Enlace Botón Principal" v-model="form.cta_url" placeholder="Ej: /app/trivias o /registro" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1 border-t border-slate-800/60">
          <BaseInput label="Texto Botón Secundario (Opcional)" v-model="form.cta_secondary_text" placeholder="Ej: Conoce las Reglas" />
          <BaseInput label="Enlace Botón Secundario" v-model="form.cta_secondary_url" placeholder="Ej: /#como-funciona" />
        </div>
      </div>

      <!-- Section 5: Highlight Card (Optional) -->
      <div class="space-y-3 p-4 bg-slate-900/60 border border-slate-800 rounded-xl">
        <label class="text-xs font-bold text-white flex items-center gap-1.5">
          <i class="bi bi-card-text text-amber-400"></i> Tarjeta Flotante Destacada (Opcional)
        </label>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BaseInput label="Insignia / Badge" v-model="form.highlight_badge" placeholder="Ej: 🔥 EN VIVO" />
          <BaseInput label="Título Tarjeta" v-model="form.highlight_title" placeholder="Ej: vs Trotamundos" />
          <BaseInput label="Subtítulo Tarjeta" v-model="form.highlight_subtitle" placeholder="Ej: 19:30 La Asunción" />
        </div>
      </div>

      <!-- Section 6: Guarantees -->
      <div class="space-y-3 p-4 bg-slate-900/60 border border-slate-800 rounded-xl">
        <div class="flex items-center justify-between">
          <label class="text-xs font-bold text-white flex items-center gap-1.5">
            <i class="bi bi-patch-check text-emerald-400"></i> Garantías de Confianza
          </label>
          <label class="flex items-center gap-2 text-xs text-slate-300 cursor-pointer">
            <input type="checkbox" v-model="form.show_guarantees" class="rounded border-slate-700 text-guaiqui-primary" />
            <span>Mostrar cinta de garantías</span>
          </label>
        </div>

        <div v-if="form.show_guarantees" class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
          <BaseInput label="Garantía 1" v-model="form.guarantee_1" placeholder="100% Gratuito" />
          <BaseInput label="Garantía 2" v-model="form.guarantee_2" placeholder="Sin tarjetas ni pagos" />
          <BaseInput label="Garantía 3" v-model="form.guarantee_3" placeholder="Recompensas Reales" />
        </div>
      </div>

      <!-- Published Toggle -->
      <div class="flex items-center gap-2 pt-2">
        <input
          id="slide-is-published"
          type="checkbox"
          v-model="form.is_published"
          class="rounded border-slate-700 text-guaiqui-primary focus:ring-guaiqui-primary"
        />
        <label for="slide-is-published" class="text-xs text-slate-300 font-medium cursor-pointer">
          Publicar este post inmediatamente en el carrusel de la página de inicio
        </label>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <BaseButton variant="secondary" @click="emit('close')">Cancelar</BaseButton>
        <BaseButton variant="primary" :loading="actionLoading" @click="emit('save')">
          <i class="bi bi-save mr-1.5"></i> Guardar Diapositiva
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
