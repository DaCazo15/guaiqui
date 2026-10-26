<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

interface JerseyRow {
  id: string
  jersey_number: number
  player_name: string
  nickname?: string | null
  position?: string | null
  years_active?: string | null
  titles_count: number
  titles_badge?: string | null
  highlight?: string | null
  description?: string | null
  badge_icon: string
  order_index: number
  is_published: boolean
}

const jerseys = ref<JerseyRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref({
  id: '',
  jersey_number: 10,
  player_name: '',
  nickname: '',
  position: 'Base',
  years_active: '1977 - 1982',
  titles_count: 1,
  titles_badge: '1 título',
  highlight: '',
  description: '',
  badge_icon: 'bi-star-fill',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'jersey_number', label: 'Dorsal', align: 'center' as const, width: '80px' },
  { key: 'player_name', label: 'Jugador Retirado' },
  { key: 'position', label: 'Posición & Época' },
  { key: 'titles_count', label: 'Títulos', align: 'center' as const },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadJerseys = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('hall_of_fame_jerseys')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    jerseys.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    jersey_number: 10,
    player_name: '',
    nickname: '',
    position: 'Base',
    years_active: '1977 - 1982',
    titles_count: 1,
    titles_badge: '1 título',
    highlight: '',
    description: '',
    badge_icon: 'bi-star-fill',
    order_index: jerseys.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: JerseyRow) => {
  form.value = {
    id: row.id,
    jersey_number: row.jersey_number,
    player_name: row.player_name,
    nickname: row.nickname || '',
    position: row.position || '',
    years_active: row.years_active || '',
    titles_count: row.titles_count,
    titles_badge: row.titles_badge || '',
    highlight: row.highlight || '',
    description: row.description || '',
    badge_icon: row.badge_icon || 'bi-star-fill',
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const saveRow = async () => {
  if (!form.value.player_name.trim()) {
    errorMessage.value = 'El nombre del jugador es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      jersey_number: Number(form.value.jersey_number),
      player_name: form.value.player_name.trim(),
      nickname: form.value.nickname?.trim() || null,
      position: form.value.position?.trim() || null,
      years_active: form.value.years_active?.trim() || null,
      titles_count: Number(form.value.titles_count) || 1,
      titles_badge: form.value.titles_badge?.trim() || `${form.value.titles_count} títulos`,
      highlight: form.value.highlight?.trim() || null,
      description: form.value.description?.trim() || null,
      badge_icon: form.value.badge_icon || 'bi-star-fill',
      order_index: Number(form.value.order_index) || 0,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('hall_of_fame_jerseys').update(payload).eq('id', form.value.id)
      if (error) throw error
      successMessage.value = 'Dorsal retirado actualizado correctamente.'
    } else {
      const { error } = await supabase.from('hall_of_fame_jerseys').insert(payload)
      if (error) throw error
      successMessage.value = 'Nuevo dorsal retirado agregado al Salón de la Fama.'
    }

    showModal.value = false
    await loadJerseys()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string, name: string) => {
  if (!confirm(`¿Eliminar definitivamente el dorsal retirado de ${name}?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('hall_of_fame_jerseys').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Dorsal eliminado.'
    await loadJerseys()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadJerseys()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-award-fill text-emerald-400"></i>
          Dorsales Retirados
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Números inmortales que cuelgan del techo de El Fortín en tributo a jugadores históricos.
        </p>
      </div>
      <BaseButton variant="primary" size="sm" @click="openNew">
        <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Dorsal Retirado
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

    <BaseTable :columns="columns" :data="jerseys" :loading="loading" empty-text="No hay dorsales retirados registrados">
      <template #cell-jersey_number="{ row }">
        <span class="font-display font-black text-lg text-emerald-400 bg-slate-950 px-2.5 py-1 rounded-lg border border-slate-800">
          #{{ (row as JerseyRow).jersey_number }}
        </span>
      </template>

      <template #cell-player_name="{ row }">
        <div>
          <span class="font-bold text-white block">{{ (row as JerseyRow).player_name }}</span>
          <span v-if="(row as JerseyRow).nickname" class="text-xs text-emerald-400 italic">"{{ (row as JerseyRow).nickname }}"</span>
        </div>
      </template>

      <template #cell-position="{ row }">
        <span class="text-xs text-slate-300">{{ (row as JerseyRow).position || '-' }} • {{ (row as JerseyRow).years_active || '-' }}</span>
      </template>

      <template #cell-titles_count="{ row }">
        <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold bg-amber-950 text-amber-300 border border-amber-800">
          <i class="bi bi-trophy-fill text-amber-400 text-[10px]"></i>
          <span>{{ (row as JerseyRow).titles_badge || `${(row as JerseyRow).titles_count} títulos` }}</span>
        </span>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="(row as JerseyRow).is_published ? 'success' : 'soft'">
          {{ (row as JerseyRow).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editRow(row as JerseyRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteRow((row as JerseyRow).id, (row as JerseyRow).player_name)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" :title="form.id ? 'Editar Dorsal Retirado' : 'Nuevo Dorsal Retirado'" @close="showModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Número de Camiseta (#)" type="number" v-model="form.jersey_number" placeholder="Ej: 5" />
          <BaseInput label="Nombre del Jugador" v-model="form.player_name" placeholder="Ej: Luis Lairet" />
          <BaseInput label="Apodo / Sobrenombre" v-model="form.nickname" placeholder="Ej: Pilar Fundacional" />
          <BaseInput label="Posición" v-model="form.position" placeholder="Ej: Alero, Ala-Pívot" />
          <BaseInput label="Años Activos con la Tribu" v-model="form.years_active" placeholder="Ej: 1977 - 1982" />
          <BaseInput label="Cantidad de Títulos" type="number" v-model="form.titles_count" placeholder="6" />
          <BaseInput label="Insignia / Texto de Títulos" v-model="form.titles_badge" placeholder="Ej: 6 títulos o Año de retiro" />
          <BaseInput label="Orden de Aparición" type="number" v-model="form.order_index" />
        </div>

        <BaseInput label="Logro Resumido / Titular" v-model="form.highlight" placeholder="Ej: Pieza vital en los 6 campeonatos consecutivos" />

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Descripción / Semblanza</label>
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500 placeholder-slate-500"
            placeholder="Breve reseña sobre el legado del dorsal en Guaiqueríes..."
          ></textarea>
        </div>

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en el Salón de la Fama</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Dorsal</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
