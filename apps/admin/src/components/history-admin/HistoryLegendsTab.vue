<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

interface LegendRow {
  id: string
  name: string
  nickname?: string | null
  role: 'player' | 'coach' | 'historic'
  category: 'gold_era' | 'modern_era' | 'builder'
  era?: string | null
  position?: string | null
  titles: string[]
  achievements: string[]
  bio?: string | null
  image_url?: string | null
  order_index: number
  is_published: boolean
}

const legends = ref<LegendRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const uploadLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref({
  id: '',
  name: '',
  nickname: '',
  role: 'player' as 'player' | 'coach' | 'historic',
  category: 'gold_era' as 'gold_era' | 'modern_era' | 'builder',
  era: '1977 - 1985',
  position: 'Base Armador',
  titlesText: '1977, 1978, 1979',
  achievementsText: 'Base del Hexacampeonato, Líder en asistencias',
  bio: '',
  image_url: '',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'image_url', label: 'Foto', width: '70px', align: 'center' as const },
  { key: 'name', label: 'Leyenda' },
  { key: 'role', label: 'Rol & Categoría' },
  { key: 'era', label: 'Época' },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const roleOptions = [
  { value: 'player', label: 'Jugador Histórico' },
  { value: 'coach', label: 'Entrenador / DT' },
  { value: 'historic', label: 'Personaje Legendario' }
]

const categoryOptions = [
  { value: 'gold_era', label: 'Época Dorada (1977-1985)' },
  { value: 'modern_era', label: 'Era Moderna (1995 en adelante)' },
  { value: 'builder', label: 'Forjadores de la Dinastía' }
]

const categoryLabels: Record<string, string> = {
  gold_era: 'Época Dorada',
  modern_era: 'Era Moderna',
  builder: 'Forjador'
}

const loadLegends = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('hall_of_fame_legends')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    legends.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    name: '',
    nickname: '',
    role: 'player',
    category: 'gold_era',
    era: '1977 - 1985',
    position: 'Base Armador',
    titlesText: '',
    achievementsText: '',
    bio: '',
    image_url: '',
    order_index: legends.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: LegendRow) => {
  form.value = {
    id: row.id,
    name: row.name,
    nickname: row.nickname || '',
    role: row.role,
    category: row.category,
    era: row.era || '',
    position: row.position || '',
    titlesText: (row.titles || []).join(', '),
    achievementsText: (row.achievements || []).join(', '),
    bio: row.bio || '',
    image_url: row.image_url || '',
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const handleImageUpload = async (e: Event) => {
  const target = e.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  uploadLoading.value = true
  try {
    const ext = file.name.split('.').pop()
    const path = `legends/${Date.now()}-${Math.random().toString(36).substring(2, 7)}.${ext}`

    const { error: uploadErr } = await supabase.storage.from('site-media').upload(path, file)
    if (uploadErr) throw uploadErr

    const { data } = supabase.storage.from('site-media').getPublicUrl(path)
    form.value.image_url = data.publicUrl
    successMessage.value = 'Foto de la leyenda cargada correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    uploadLoading.value = false
  }
}

const saveRow = async () => {
  if (!form.value.name.trim()) {
    errorMessage.value = 'El nombre de la leyenda es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const parsedTitles = form.value.titlesText
      ? form.value.titlesText.split(',').map(s => s.trim()).filter(Boolean)
      : []

    const parsedAchievements = form.value.achievementsText
      ? form.value.achievementsText.split(',').map(s => s.trim()).filter(Boolean)
      : []

    const payload = {
      name: form.value.name.trim(),
      nickname: form.value.nickname?.trim() || null,
      role: form.value.role,
      category: form.value.category,
      era: form.value.era?.trim() || null,
      position: form.value.position?.trim() || null,
      titles: parsedTitles,
      achievements: parsedAchievements,
      bio: form.value.bio?.trim() || null,
      image_url: form.value.image_url?.trim() || null,
      order_index: Number(form.value.order_index) || 0,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('hall_of_fame_legends').update(payload).eq('id', form.value.id)
      if (error) throw error
      successMessage.value = 'Leyenda actualizada correctamente.'
    } else {
      const { error } = await supabase.from('hall_of_fame_legends').insert(payload)
      if (error) throw error
      successMessage.value = 'Nueva leyenda agregada al Salón de la Fama.'
    }

    showModal.value = false
    await loadLegends()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string, name: string) => {
  if (!confirm(`¿Eliminar definitivamente a la leyenda ${name}?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('hall_of_fame_legends').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Leyenda eliminada.'
    await loadLegends()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadLegends()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-star-fill text-emerald-400"></i>
          Leyendas Inmortales
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Homenaje a jugadores, entrenadores y forjadores de la dinastía verde de Margarita.
        </p>
      </div>
      <BaseButton variant="primary" size="sm" @click="openNew">
        <i class="bi bi-plus-lg mr-1.5"></i> Nueva Leyenda
      </BaseButton>
    </div>

    <!-- Alerts -->
    <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-sm flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-sm flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <BaseTable :columns="columns" :data="legends" :loading="loading" empty-text="No hay leyendas registradas">
      <template #cell-image_url="{ row }">
        <img
          :src="(row as LegendRow).image_url || 'https://placehold.co/100x100?text=Guaiqueri'"
          class="w-10 h-10 rounded-full object-cover border border-slate-700 bg-slate-800 mx-auto"
          :alt="(row as LegendRow).name"
        />
      </template>

      <template #cell-name="{ row }">
        <div>
          <span class="font-bold text-white block">{{ (row as LegendRow).name }}</span>
          <span v-if="(row as LegendRow).nickname" class="text-xs text-emerald-400 italic">"{{ (row as LegendRow).nickname }}"</span>
        </div>
      </template>

      <template #cell-role="{ row }">
        <div class="space-y-1">
          <span class="text-xs text-slate-300 font-semibold block">
            {{ (row as LegendRow).role === 'player' ? 'Jugador' : (row as LegendRow).role === 'coach' ? 'Entrenador' : 'Histórico' }}
          </span>
          <BaseBadge variant="info">
            {{ categoryLabels[(row as LegendRow).category] || (row as LegendRow).category }}
          </BaseBadge>
        </div>
      </template>

      <template #cell-era="{ row }">
        <span class="text-xs text-slate-300 font-mono">{{ (row as LegendRow).era || '-' }}</span>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="(row as LegendRow).is_published ? 'success' : 'soft'">
          {{ (row as LegendRow).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editRow(row as LegendRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteRow((row as LegendRow).id, (row as LegendRow).name)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" :title="form.id ? 'Editar Leyenda' : 'Nueva Leyenda'" @close="showModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Nombre de la Leyenda" v-model="form.name" placeholder="Ej: Sam Shepherd" />
          <BaseInput label="Apodo / Sobrenombre" v-model="form.nickname" placeholder="Ej: El Mago de La Asunción" />
          <BaseSelect label="Rol en el Club" v-model="form.role" :options="roleOptions" />
          <BaseSelect label="Categoría Histórica" v-model="form.category" :options="categoryOptions" />
          <BaseInput label="Época / Años" v-model="form.era" placeholder="Ej: 1977 - 1985" />
          <BaseInput label="Posición / Cargo" v-model="form.position" placeholder="Ej: Base Armador, DT" />
        </div>

        <BaseInput label="Títulos Ganados (Separados por coma)" v-model="form.titlesText" placeholder="Ej: 1977, 1978, 1979, 1980" />
        <BaseInput label="Logros Destacados (Separados por coma)" v-model="form.achievementsText" placeholder="Ej: Base del Hexacampeonato, MVP 1997" />

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Biografía / Semblanza</label>
          <textarea
            v-model="form.bio"
            rows="3"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500 placeholder-slate-500"
            placeholder="Reseña de su trayectoria e impacto en Guaiqueríes..."
          ></textarea>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Foto de la Leyenda</label>
          <div class="flex items-center gap-3">
            <input
              v-model="form.image_url"
              type="text"
              placeholder="https://... o sube una imagen"
              class="flex-1 px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
            />
            <label class="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium rounded-xl cursor-pointer transition border border-slate-700 shrink-0 flex items-center gap-1.5">
              <i v-if="uploadLoading" class="bi bi-arrow-repeat animate-spin"></i>
              <i v-else class="bi bi-upload"></i>
              <span>Subir</span>
              <input type="file" accept="image/*" class="hidden" @change="handleImageUpload" :disabled="uploadLoading" />
            </label>
          </div>
          <div v-if="form.image_url" class="mt-2 flex items-center gap-2">
            <img :src="form.image_url" class="w-10 h-10 rounded-full object-cover border border-slate-700" alt="Preview" />
            <span class="text-xs text-slate-400 truncate">{{ form.image_url }}</span>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
          <BaseInput label="Orden de Aparición" type="number" v-model="form.order_index" />
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-6">
            <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
            <span>Publicado en el Salón de la Fama</span>
          </label>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Leyenda</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
