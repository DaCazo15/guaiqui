<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

interface ChampionshipRow {
  id: string
  year: number
  tournament: string
  runner_up?: string | null
  highlight?: string | null
  is_hexa: boolean
  order_index: number
  is_published: boolean
}

const championships = ref<ChampionshipRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref({
  id: '',
  year: 1977,
  tournament: 'Liga Especial (Li-Es)',
  runner_up: '',
  highlight: '',
  is_hexa: false,
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'year', label: 'Año', align: 'center' as const, width: '90px' },
  { key: 'tournament', label: 'Torneo / Competencia' },
  { key: 'runner_up', label: 'Subcampeón' },
  { key: 'is_hexa', label: 'Hexacampeonato', align: 'center' as const },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadChampionships = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('hall_of_fame_championships')
      .select('*')
      .order('year', { ascending: true })

    if (error) throw error
    championships.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    year: new Date().getFullYear(),
    tournament: 'Superliga Profesional de Baloncesto (SPB)',
    runner_up: '',
    highlight: '',
    is_hexa: false,
    order_index: championships.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: ChampionshipRow) => {
  form.value = {
    id: row.id,
    year: row.year,
    tournament: row.tournament,
    runner_up: row.runner_up || '',
    highlight: row.highlight || '',
    is_hexa: row.is_hexa,
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const saveRow = async () => {
  if (!form.value.tournament.trim()) {
    errorMessage.value = 'El nombre del torneo es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      year: Number(form.value.year),
      tournament: form.value.tournament.trim(),
      runner_up: form.value.runner_up?.trim() || null,
      highlight: form.value.highlight?.trim() || null,
      is_hexa: Boolean(form.value.is_hexa),
      order_index: Number(form.value.order_index) || 0,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('hall_of_fame_championships').update(payload).eq('id', form.value.id)
      if (error) throw error
      successMessage.value = 'Título de campeonato actualizado correctamente.'
    } else {
      const { error } = await supabase.from('hall_of_fame_championships').insert(payload)
      if (error) throw error
      successMessage.value = 'Nuevo título de campeonato agregado al palmarés.'
    }

    showModal.value = false
    await loadChampionships()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string, year: number) => {
  if (!confirm(`¿Eliminar definitivamente el título de ${year}?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('hall_of_fame_championships').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Título eliminado del palmarés.'
    await loadChampionships()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadChampionships()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-trophy-fill text-amber-400"></i>
          Campeonatos y Palmarés Oficial
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Las 9 estrellas nacionales consagradas por Guaiqueríes de Margarita a lo largo de su historia.
        </p>
      </div>
      <BaseButton variant="primary" size="sm" @click="openNew">
        <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Campeonato
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

    <BaseTable :columns="columns" :data="championships" :loading="loading" empty-text="No hay campeonatos registrados">
      <template #cell-year="{ row }">
        <span class="font-display font-black text-lg text-amber-400 bg-slate-950 px-2.5 py-1 rounded-lg border border-slate-800">
          {{ (row as ChampionshipRow).year }}
        </span>
      </template>

      <template #cell-tournament="{ row }">
        <div>
          <span class="font-bold text-white block">{{ (row as ChampionshipRow).tournament }}</span>
          <span v-if="(row as ChampionshipRow).highlight" class="text-xs text-slate-400 truncate max-w-sm block">
            {{ (row as ChampionshipRow).highlight }}
          </span>
        </div>
      </template>

      <template #cell-runner_up="{ row }">
        <span class="text-xs text-slate-300">{{ (row as ChampionshipRow).runner_up || '-' }}</span>
      </template>

      <template #cell-is_hexa="{ row }">
        <span v-if="(row as ChampionshipRow).is_hexa" class="inline-flex items-center gap-1 text-[11px] font-bold text-amber-300 bg-amber-950 px-2 py-0.5 rounded border border-amber-800">
          <i class="bi bi-patch-check-fill text-amber-400"></i> Hexacampeón
        </span>
        <span v-else class="text-slate-500 text-xs">-</span>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="(row as ChampionshipRow).is_published ? 'success' : 'soft'">
          {{ (row as ChampionshipRow).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editRow(row as ChampionshipRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteRow((row as ChampionshipRow).id, (row as ChampionshipRow).year)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" :title="form.id ? 'Editar Campeonato' : 'Nuevo Campeonato'" @close="showModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Año del Campeonato" type="number" v-model="form.year" placeholder="Ej: 1977" />
          <BaseInput label="Torneo / Liga" v-model="form.tournament" placeholder="Ej: Liga Especial (Li-Es)" />
          <BaseInput label="Subcampeón de la Serie" v-model="form.runner_up" placeholder="Ej: Cocodrilos de Caracas" />
          <BaseInput label="Orden" type="number" v-model="form.order_index" />
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Detalle / Reseña del Título</label>
          <textarea
            v-model="form.highlight"
            rows="3"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500 placeholder-slate-500"
            placeholder="Ej: Regreso a la gloria tras 15 años de la mano de Julio Toro..."
          ></textarea>
        </div>

        <div class="flex items-center gap-6 border-t border-slate-800 pt-3">
          <label class="flex items-center gap-2 text-sm text-amber-400 cursor-pointer">
            <input type="checkbox" v-model="form.is_hexa" class="accent-amber-500 rounded" />
            <span>Forma parte del Hexacampeonato histórico (1977-1982)</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
            <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
            <span>Publicado</span>
          </label>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Campeonato</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
