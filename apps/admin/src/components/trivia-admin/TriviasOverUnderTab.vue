<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface PlayerItem {
  id: string
  name: string
  jersey_number: number
}

interface OverUnderRow {
  id: string
  title: string
  description?: string | null
  stat_type: string
  line_value: number
  reward_pearls: number
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  actual_value?: number | null
  winning_choice?: 'over' | 'under' | 'push' | null
  player_id?: string | null
  player?: PlayerItem | null
  total_votes?: number
  over_votes?: number
  under_votes?: number
}

const items = ref<OverUnderRow[]>([])
const rosterPlayers = ref<PlayerItem[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showResolveModal = ref(false)
const showBulkImportModal = ref(false)
const selectedItem = ref<OverUnderRow | null>(null)
const actualValueInput = ref<number | ''>('')

// Form state
const form = ref({
  id: '',
  title: '',
  description: '',
  stat_type: 'points',
  line_value: 84.5,
  player_id: '',
  reward_pearls: 40,
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: ''
})

const columns = [
  { key: 'title', label: 'Pronóstico' },
  { key: 'stat', label: 'Línea & Estadística' },
  { key: 'player', label: 'Jugador' },
  { key: 'votes', label: 'Votos (Over/Under)' },
  { key: 'closes_at', label: 'Cierre' },
  { key: 'reward', label: 'Premio', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const [playersRes, ouRes] = await Promise.all([
      supabase.from('players').select('id, name, jersey_number').order('jersey_number', { ascending: true }),
      supabase.from('over_under_predictions').select(`
        *,
        player:players(id, name, jersey_number)
      `).order('closes_at', { ascending: false })
    ])

    if (playersRes.data) rosterPlayers.value = playersRes.data
    if (ouRes.error) throw ouRes.error

    const rows = ouRes.data || []
    // Get votes counts
    const { data: votes } = await supabase.from('over_under_votes').select('prediction_id, choice')
    const voteMap = new Map<string, { over: number; under: number }>()
    votes?.forEach((v: any) => {
      if (!voteMap.has(v.prediction_id)) voteMap.set(v.prediction_id, { over: 0, under: 0 })
      const m = voteMap.get(v.prediction_id)!
      if (v.choice === 'over') m.over++
      else if (v.choice === 'under') m.under++
    })

    items.value = rows.map((r: any) => {
      const v = voteMap.get(r.id) || { over: 0, under: 0 }
      return {
        ...r,
        over_votes: v.over,
        under_votes: v.under,
        total_votes: v.over + v.under
      }
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar pronósticos Over/Under'
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  selectedItem.value = null
  const nowStr = nowCaracasInput()
  const defaultClose = nowCaracasInput(48)
  form.value = {
    id: '',
    title: '',
    description: '',
    stat_type: 'points',
    line_value: 84.5,
    player_id: '',
    reward_pearls: 40,
    status: 'published',
    starts_at: nowStr,
    closes_at: defaultClose
  }
  showEditorModal.value = true
}

const openEditModal = (item: OverUnderRow) => {
  selectedItem.value = item
  form.value = {
    id: item.id,
    title: item.title,
    description: item.description || '',
    stat_type: item.stat_type || 'points',
    line_value: item.line_value,
    player_id: item.player_id || '',
    reward_pearls: item.reward_pearls,
    status: item.status === 'draft' ? 'draft' : 'published',
    starts_at: isoToCaracasInput(item.starts_at),
    closes_at: isoToCaracasInput(item.closes_at)
  }
  showEditorModal.value = true
}

const saveItem = async () => {
  if (!form.value.title.trim()) {
    errorMessage.value = 'El título es obligatorio.'
    return
  }
  actionLoading.value = true
  errorMessage.value = null
  try {
    const startsAtISO = form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString()
    const closesAtISO = form.value.closes_at ? caracasInputToISO(form.value.closes_at) : new Date(Date.now() + 2 * 86400000).toISOString()

    const { error } = await supabase.rpc('admin_upsert_over_under', {
      p_id: form.value.id || null,
      p_game_id: null,
      p_player_id: form.value.player_id || null,
      p_title: form.value.title.trim(),
      p_description: form.value.description.trim() || null,
      p_stat_type: form.value.stat_type,
      p_line_value: Number(form.value.line_value),
      p_reward_pearls: Number(form.value.reward_pearls) || 40,
      p_status: form.value.status,
      p_starts_at: startsAtISO,
      p_closes_at: closesAtISO
    })

    if (error) throw error
    successMessage.value = form.value.id ? 'Pronóstico actualizado.' : 'Pronóstico creado exitosamente.'
    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar pronóstico'
  } finally {
    actionLoading.value = false
  }
}

const openResolveModal = (item: OverUnderRow) => {
  selectedItem.value = item
  actualValueInput.value = item.line_value ? Math.ceil(item.line_value) : ''
  showResolveModal.value = true
}

const resolvePrediction = async () => {
  if (!selectedItem.value || actualValueInput.value === '') return
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_resolve_over_under', {
      p_prediction_id: selectedItem.value.id,
      p_actual_value: Number(actualValueInput.value)
    })
    if (error) throw error
    successMessage.value = `Pronóstico resuelto. Ganó: ${data?.winning_choice?.toUpperCase()}. Ganadores premiados: ${data?.winners_count}`
    showResolveModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al resolver pronóstico'
  } finally {
    actionLoading.value = false
  }
}

const deleteItem = async (item: OverUnderRow) => {
  if (!confirm(`¿Eliminar pronóstico "${item.title}"?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('over_under_predictions').delete().eq('id', item.id)
    if (error) throw error
    successMessage.value = 'Pronóstico eliminado.'
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar'
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="space-y-4">
    <!-- Feedback alerts -->
    <div v-if="errorMessage" class="p-4 rounded-xl bg-red-950/40 border border-red-800/80 text-red-200 text-sm flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>
      <button @click="errorMessage = null" class="text-red-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>

    <div v-if="successMessage" class="p-4 rounded-xl bg-emerald-950/40 border border-emerald-800/80 text-emerald-200 text-sm flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-400"></i>
        <span>{{ successMessage }}</span>
      </div>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>

    <!-- Header Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
      <div>
        <h2 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-arrow-down-up text-emerald-400"></i>
          Mayor o Menor (Over / Under)
        </h2>
        <p class="text-xs text-slate-400">
          Líneas estadísticas rápidas (puntos, triples, rebotes) resueltas automáticamente al culminar el encuentro.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="outline" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openCreateModal">
          <i class="bi bi-plus-circle me-1"></i>
          Nuevo Over/Under
        </BaseButton>
      </div>
    </div>

    <!-- Table -->
    <BaseTable :columns="columns" :data="items" :loading="loading" empty-text="No hay pronósticos Over/Under creados aún.">
      <template #title="{ item }">
        <div class="font-bold text-white text-sm">{{ item.title }}</div>
        <div v-if="item.description" class="text-xs text-slate-400 line-clamp-1">{{ item.description }}</div>
      </template>

      <template #stat="{ item }">
        <div class="flex items-center gap-2">
          <span class="px-2 py-0.5 rounded text-xs font-bold bg-slate-800 text-emerald-400 border border-slate-700">
            {{ item.line_value }} pts/val
          </span>
          <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">{{ item.stat_type }}</span>
        </div>
      </template>

      <template #player="{ item }">
        <div v-if="item.player" class="flex items-center gap-1.5 text-xs text-slate-300">
          <span class="font-bold text-emerald-400">#{{ item.player.jersey_number }}</span>
          <span>{{ item.player.name }}</span>
        </div>
        <span v-else class="text-xs text-slate-500 italic">Equipo general</span>
      </template>

      <template #votes="{ item }">
        <div class="text-xs text-slate-300">
          <span class="text-emerald-400 font-bold">▲ {{ item.over_votes }}</span>
          <span class="text-slate-500 mx-1">|</span>
          <span class="text-amber-400 font-bold">▼ {{ item.under_votes }}</span>
          <span class="text-slate-500 text-[11px] ms-1">({{ item.total_votes }} tot)</span>
        </div>
      </template>

      <template #closes_at="{ item }">
        <span class="text-xs text-slate-300 font-mono">{{ formatCaracas(item.closes_at) }}</span>
      </template>

      <template #reward="{ item }">
        <span class="inline-flex items-center gap-1 text-xs font-bold text-amber-300">
          <i class="bi bi-gem"></i> {{ item.reward_pearls }}
        </span>
      </template>

      <template #status_badge="{ item }">
        <BaseBadge v-if="item.status === 'resolved'" variant="success">Resuelto ({{ item.winning_choice?.toUpperCase() }})</BaseBadge>
        <BaseBadge v-else-if="item.status === 'published'" variant="primary">Activo</BaseBadge>
        <BaseBadge v-else-if="item.status === 'closed'" variant="warning">Cerrado</BaseBadge>
        <BaseBadge v-else variant="soft">Borrador</BaseBadge>
      </template>

      <template #actions="{ item }">
        <div class="flex items-center justify-end gap-1.5">
          <button
            v-if="item.status !== 'resolved'"
            @click="openResolveModal(item)"
            class="px-2 py-1 text-xs font-bold text-emerald-400 hover:text-white bg-emerald-950/60 hover:bg-emerald-800 border border-emerald-800/80 rounded transition"
            title="Resolver y premiar ganadores"
          >
            <i class="bi bi-check2-circle me-1"></i> Resolver
          </button>
          <button
            @click="openEditModal(item)"
            class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded transition"
            title="Editar"
          >
            <i class="bi bi-pencil-square"></i>
          </button>
          <button
            @click="deleteItem(item)"
            class="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-950/40 rounded transition"
            title="Eliminar"
          >
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Create/Edit Modal -->
    <BaseModal v-model="showEditorModal" :title="form.id ? 'Editar Pronóstico Over/Under' : 'Nuevo Pronóstico Over/Under'">
      <div class="space-y-4 text-left">
        <BaseInput v-model="form.title" label="Título del Pronóstico *" placeholder="Ej: Puntos de Guaiqueríes vs Trotamundos" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseSelect
            v-model="form.stat_type"
            label="Tipo de Estadística"
            :options="[
              { value: 'points', label: 'Puntos Anotados' },
              { value: 'triples', label: 'Triples Convertidos' },
              { value: 'rebounds', label: 'Rebotes Totales' },
              { value: 'assists', label: 'Asistencias' },
              { value: 'custom', label: 'Otra Métrica' },
            ]"
          />
          <BaseInput v-model="form.line_value" type="number" step="0.5" label="Valor de la Línea (ej: 84.5) *" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseSelect
            v-model="form.player_id"
            label="Jugador Asociado (Opcional)"
            :options="[
              { value: '', label: 'Ninguno (Estadística de Equipo)' },
              ...rosterPlayers.map(p => ({ value: p.id, label: `#${p.jersey_number} - ${p.name}` }))
            ]"
          />
          <BaseInput v-model="form.reward_pearls" type="number" label="Perlitas de Premio" />
        </div>

        <BaseInput v-model="form.description" label="Descripción / Contexto (Opcional)" placeholder="Detalle adicional de la línea para los fanáticos" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.starts_at" type="datetime-local" label="Fecha Inicio (Caracas)" />
          <BaseInput v-model="form.closes_at" type="datetime-local" label="Fecha Cierre (Caracas)" />
        </div>

        <BaseSelect
          v-model="form.status"
          label="Estado de Publicación"
          :options="[
            { value: 'published', label: 'Publicado (Disponible)' },
            { value: 'draft', label: 'Borrador (Oculto)' },
          ]"
        />
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" size="sm" :loading="actionLoading" @click="saveItem">Guardar</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Resolve Modal -->
    <BaseModal v-model="showResolveModal" title="Resolver Pronóstico Over / Under">
      <div v-if="selectedItem" class="space-y-4 text-left">
        <p class="text-sm text-slate-300">
          Ingresa el valor numérico final alcanzado en el partido para <strong class="text-white">{{ selectedItem.title }}</strong>.
        </p>

        <div class="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-1">
          <div class="text-xs text-slate-400">Línea establecida: <strong class="text-emerald-400 text-sm">{{ selectedItem.line_value }}</strong></div>
          <div class="text-xs text-slate-400">Premio a entregar: <strong class="text-amber-300">{{ selectedItem.reward_pearls }} Perlitas</strong></div>
        </div>

        <BaseInput
          v-model="actualValueInput"
          type="number"
          step="0.1"
          label="Valor Real Final Alcanzado *"
          placeholder="Ej: 89"
        />

        <div v-if="actualValueInput !== ''" class="p-3 rounded-xl border text-sm font-bold flex items-center gap-2" :class="Number(actualValueInput) > selectedItem.line_value ? 'bg-emerald-950/50 border-emerald-700 text-emerald-300' : (Number(actualValueInput) < selectedItem.line_value ? 'bg-amber-950/50 border-amber-700 text-amber-300' : 'bg-slate-800 border-slate-700 text-slate-300')">
          <i class="bi bi-info-circle"></i>
          <span>
            Resultado: {{ Number(actualValueInput) > selectedItem.line_value ? 'GANA OVER (MÁS)' : (Number(actualValueInput) < selectedItem.line_value ? 'GANA UNDER (MENOS)' : 'PUSH (EMPATE)') }}
          </span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="showResolveModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" size="sm" :loading="actionLoading" @click="resolvePrediction">Confirmar y Premiar</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      v-model:is-open="showBulkImportModal"
      type="over_under"
      @imported="loadData"
    />
  </div>
</template>
