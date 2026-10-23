<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface SlideRow {
  id: string
  tag?: string
  title: string
  subtitle?: string
  cta_text?: string
  cta_url?: string
  image_url?: string
  bg_gradient?: string
  badge_variant?: string
  order_index: number
  is_published: boolean
  starts_at: string
  ends_at?: string
  created_at: string
}

const slides = ref<SlideRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const uploadingImage = ref(false)

const form = ref({
  id: '',
  tag: 'Próximo Partido',
  title: '',
  subtitle: '',
  cta_text: 'Ver Detalles',
  cta_url: '#proximo-partido',
  image_url: '',
  bg_gradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
  badge_variant: 'accent',
  order_index: 0,
  is_published: true,
  starts_at: '',
  ends_at: ''
})

const columns = [
  { key: 'order_index', label: 'Orden', align: 'center' as const, width: '60px' },
  { key: 'title', label: 'Título del Slide' },
  { key: 'tag', label: 'Etiqueta' },
  { key: 'is_published', label: 'Publicado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadSlides = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('carousel_slides')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    slides.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    tag: 'Próximo Partido',
    title: '',
    subtitle: '',
    cta_text: 'Ver Detalles',
    cta_url: '#proximo-partido',
    image_url: '',
    bg_gradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badge_variant: 'accent',
    order_index: slides.value.length,
    is_published: true,
    starts_at: nowCaracasInput(),
    ends_at: ''
  }
  showEditorModal.value = true
}

const editRow = (row: SlideRow) => {
  form.value = {
    id: row.id,
    tag: row.tag || '',
    title: row.title,
    subtitle: row.subtitle || '',
    cta_text: row.cta_text || '',
    cta_url: row.cta_url || '',
    image_url: row.image_url || '',
    bg_gradient: row.bg_gradient || 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badge_variant: row.badge_variant || 'accent',
    order_index: row.order_index,
    is_published: row.is_published,
    starts_at: row.starts_at ? isoToCaracasInput(row.starts_at) : '',
    ends_at: row.ends_at ? isoToCaracasInput(row.ends_at) : ''
  }
  showEditorModal.value = true
}

const handleImageUpload = async (e: Event) => {
  const target = e.target as HTMLInputElement
  if (!target.files?.length) return

  const file = target.files[0]
  uploadingImage.value = true
  try {
    const ext = file.name.split('.').pop()
    const path = `carousel_${Date.now()}.${ext}`

    const { error } = await supabase.storage.from('site-media').upload(path, file)
    if (error) throw error

    const { data } = supabase.storage.from('site-media').getPublicUrl(path)
    form.value.image_url = data.publicUrl
    successMessage.value = 'Imagen del slide subida.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    uploadingImage.value = false
  }
}

const saveRow = async () => {
  if (!form.value.title) {
    errorMessage.value = 'El título del slide es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      tag: form.value.tag,
      title: form.value.title,
      subtitle: form.value.subtitle,
      cta_text: form.value.cta_text,
      cta_url: form.value.cta_url,
      image_url: form.value.image_url,
      bg_gradient: form.value.bg_gradient,
      badge_variant: form.value.badge_variant,
      order_index: Number(form.value.order_index),
      is_published: form.value.is_published,
      starts_at: form.value.starts_at ? caracasInputToISO(form.value.starts_at) : caracasInputToISO(nowCaracasInput()),
      ends_at: form.value.ends_at ? caracasInputToISO(form.value.ends_at) : null
    }

    if (form.value.id) {
      const { error } = await supabase.from('carousel_slides').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('carousel_slides').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Slide guardado correctamente.'
    showEditorModal.value = false
    await loadSlides()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este slide del carrusel?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('carousel_slides').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Slide eliminado.'
    await loadSlides()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadSlides)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Carrusel de la Landing</h1>
          <p class="text-sm text-slate-400 mt-1">Administrar diapositivas destacadas del carrusel principal.</p>
        </div>
        <BaseButton variant="primary" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Slide
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="slides" :loading="loading" empty-text="No hay slides configurados">
        <template #cell-order_index="{ row }">
          <span class="font-mono font-bold text-emerald-400">#{{ (row as any).order_index }}</span>
        </template>

        <template #cell-title="{ row }">
          <div class="font-semibold text-white">{{ (row as any).title }}</div>
          <div class="text-xs text-slate-400 truncate max-w-xs">{{ (row as any).subtitle }}</div>
        </template>

        <template #cell-tag="{ row }">
          <span class="text-xs font-mono text-emerald-400 font-semibold">{{ (row as any).tag }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="(row as any).is_published ? 'success' : 'soft'">
            {{ (row as any).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(row as any)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow((row as any).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Slide Hero" @close="showEditorModal = false" size="lg">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Título Principal" v-model="form.title" placeholder="Ej: Clásico Oriental" />
          <BaseInput label="Etiqueta / Tag" v-model="form.tag" placeholder="Ej: Próximo Partido" />
        </div>

        <BaseInput label="Subtítulo / Descripción" v-model="form.subtitle" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Texto del Botón (CTA)" v-model="form.cta_text" />
          <BaseInput label="Enlace del Botón (CTA URL)" v-model="form.cta_url" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Orden (#)" type="number" v-model="form.order_index" />
          <BaseSelect
            label="Variante de Badge"
            v-model="form.badge_variant"
            :options="[
              { value: 'accent', label: 'Rojo (Accent)' },
              { value: 'primary', label: 'Verde (Primary)' },
              { value: 'perlita', label: 'Amarillo (Perlita)' },
              { value: 'info', label: 'Azul (Info)' }
            ]"
          />
        </div>

        <div class="space-y-2">
          <label class="block text-xs font-semibold text-slate-400">Imagen de Fondo (Opcional - site-media)</label>
          <div class="flex items-center gap-3">
            <input type="file" accept="image/jpeg,image/png,image/webp" @change="handleImageUpload" :disabled="uploadingImage" class="text-xs text-slate-400" />
            <span v-if="uploadingImage" class="text-xs text-emerald-400 font-mono animate-pulse">Subiendo...</span>
          </div>
          <div v-if="form.image_url" class="mt-2 text-xs text-slate-400 truncate font-mono">Fondo: {{ form.image_url }}</div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
          <BaseInput label="Válido Desde — Hora de Caracas (GMT-4)" type="datetime-local" v-model="form.starts_at" />
          <BaseInput label="Válido Hasta (Opcional) — Hora de Caracas (GMT-4)" type="datetime-local" v-model="form.ends_at" />
        </div>

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Landing</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Slide</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
