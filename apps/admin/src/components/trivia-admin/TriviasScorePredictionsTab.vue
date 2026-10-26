<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface GameItem {
  id: string
  opponent_name: string
  game_date: string
  is_home: boolean
}

interface ScorePredictionRow {
  id: string
  game_id: string
  title: string
  description?: string | null
  exact_reward_pearls: number
  closest_reward_pearls: number
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  final_guaiqueries_score?: number | null
  final_rival_score?: number | null
  resolved_at?: string | null
  game?: GameItem | null
  total_votes?: number
  exact_winners?: number
  closest_winners?: number
}

const items = ref<ScorePredictionRow[]>([])
const scheduledGames = ref<GameItem[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showResolveModal = ref(false)
const showBulkImportModal = ref(false)
const selectedItem = ref<ScorePredictionRow | null>(null)

const finalGuaiquiScore = ref<number | ''>('')
const finalRivalScore = ref<number | ''>('')

// Form
const form = ref({
  id: '',
  game_id: '',
  title: '',
  description: '',
  exact_reward_pearls: 200,
  closest_reward_pearls: 50,
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: ''
})

const columns = [
  { key: 'title', label: 'Predicción / Partido' },
  { key: 'game', label: 'Partido Calendario' },
  { key: 'votes', label: 'Participantes', align: 'center' as const },
  { key: 'result', label: 'Marcador Final', align: 'center' as const },
  { key: 'closes_at', label: 'Cierre' },
  { key: 'rewards', label: 'Bote Perlitas', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const [gamesRes, spRes] = await Promise.all([
      supabase.from('games').select('id, opponent_name, game_date, is_home').order('game_date', { ascending: true }),
      supabase.from('score_predictions').select(`
        *,
        game:games(id, opponent_name, game_date, is_home)
      `).order('closes_at', { ascending: false })
    ])

    if (gamesRes.data) scheduledGames.value = gamesRes.data
    if (spRes.error) throw spRes.error

    const rows = spRes.data || []
    const { data: votes } = await supabase.from('score_prediction_votes').select('prediction_id, is_exact_match, is_closest_match')
    const voteMap = new Map<string, { total: number; exact: number; closest: number }>()

    votes?.forEach((v: any) => {
      if (!voteMap.has(v.prediction_id)) voteMap.set(v.prediction_id, { total: 0, exact: 0, closest: 0 })
      const m = voteMap.get(v.prediction_id)!
      m.total++
      if (v.is_exact_match) m.exact++
      if (v.is_closest_match) m.closest++
    })

    items.value = rows.map((r: any) => {
      const v = voteMap.get(r.id) || { total: 0, exact: 0, closest: 0 }
      return {
        ...r,
        total_votes: v.total,
        exact_winners: v.exact,
        closest_winners: v.closest
      }
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar predicciones de marcador'
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
    game_id: scheduledGames.value[0]?.id || '',
    title: '',
    description: '',
    exact_reward_pearls: 200,
    closest_reward_pearls: 50,
    status: 'published',
    starts_at: nowStr,
    closes_at: defaultClose
  }
  showEditorModal.value = true
}

const openEditModal = (item: ScorePredictionRow) => {
  selectedItem.value = item
  form.value = {
    id: item.id,
    game_id: item.game_id,
    title: item.title,
    description: item.description || '',
    exact_reward_pearls: item.exact_reward_pearls,
    closest_reward_pearls: item.closest_reward_pearls,
    status: item.status === 'draft' ? 'draft' : 'published',
    starts_at: isoToCaracasInput(item.starts_at),
    closes_at: isoToCaracasInput(item.closes_at)
  }
  showEditorModal.value = true
}

const saveItem = async () => {
  if (!form.value.title.trim() || !form.value.game_id) {
    errorMessage.value = 'El título y el partido asociado son obligatorios.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const startsAtISO = form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString()
    const closesAtISO = form.value.closes_at ? caracasInputToISO(form.value.closes_at) : new Date(Date.now() + 2 * 86400000).toISOString()

    const { error } = await supabase.rpc('admin_upsert_score_prediction', {
      p_id: form.value.id || null,
      p_game_id: form.value.game_id,
      p_title: form.value.title.trim(),
      p_description: form.value.description.trim() || null,
      p_exact_reward_pearls: Number(form.value.exact_reward_pearls) || 200,
      p_closest_reward_pearls: Number(form.value.closest_reward_pearls) || 50,
      p_status: form.value.status,
      p_starts_at: startsAtISO,
      p_closes_at: closesAtISO
    })

    if (error) throw error
    successMessage.value = form.value.id ? 'Predicción actualizada.' : 'Predicción de marcador creada exitosamente.'
    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar predicción'
  } finally {
    actionLoading.value = false
  }
}

const openResolveModal = (item: ScorePredictionRow) => {
  selectedItem.value = item
  finalGuaiquiScore.value = item.final_guaiqueries_score ?? ''
  finalRivalScore.value = item.final_rival_score ?? ''
  showResolveModal.value = true
}

const resolveScore = async () => {
  if (!selectedItem.value || finalGuaiquiScore.value === '' || finalRivalScore.value === '') {
    errorMessage.value = 'Debes ingresar el marcador de ambos equipos.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_resolve_score_prediction', {
      p_prediction_id: selectedItem.value.id,
      p_final_guaiqueries_score: Number(finalGuaiquiScore.value),
      p_final_rival_score: Number(finalRivalScore.value)
    })
    if (error) throw error
    successMessage.value = `Marcador resuelto: Guaiqueríes ${finalGuaiquiScore.value} - ${finalRivalScore.value} Rival. Aciertos exactos: ${data?.exact_winners}, Marcadores cercanos: ${data?.closest_winners}`
    showResolveModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al resolver marcador'
  } finally {
    actionLoading.value = false
  }
}

const deleteItem = async (item: ScorePredictionRow) => {
  if (!confirm(`¿Eliminar predicción de marcador "${item.title}"?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('score_predictions').delete().eq('id', item.id)
    if (error) throw error
    successMessage.value = 'Predicción eliminada.'
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
          <i class="bi bi-bullseye text-emerald-400"></i>
          Adivina el Marcador Exacto (El Gran Bote)
        </h2>
        <p class="text-xs text-slate-400">
          Predicciones de pizarra final con recompensa estelar al marcador exacto y premio consuelo a los más cercanos.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="outline" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openCreateModal">
          <i class="bi bi-plus-circle me-1"></i>
          Nueva Predicción de Marcador
        </BaseButton>
      </div>
    </div>

    <!-- Table -->
    <BaseTable :columns="columns" :data="items" :loading="loading" empty-text="No hay predicciones de marcador registradas.">
      <template #title="{ item }">
        <div class="font-bold text-white text-sm">{{ item.title }}</div>
        <div v-if="item.description" class="text-xs text-slate-400">{{ item.description }}</div>
      </template>

      <template #game="{ item }">
        <div v-if="item.game" class="text-xs text-slate-300">
          <span class="font-bold text-emerald-400">vs {{ item.game.opponent_name }}</span>
          <div class="text-[11px] text-slate-500 font-mono">{{ formatCaracas(item.game.game_date) }}</div>
        </div>
        <span v-else class="text-xs text-slate-500 italic">Sin partido</span>
      </template>

      <template #votes="{ item }">
        <span class="text-xs font-bold text-slate-300">
          <i class="bi bi-people-fill text-slate-400 me-1"></i> {{ item.total_votes }}
        </span>
      </template>

      <template #result="{ item }">
        <div v-if="item.status === 'resolved'" class="text-xs font-mono font-bold text-emerald-400 bg-slate-800/80 px-2 py-0.5 rounded border border-slate-700 inline-block">
          {{ item.final_guaiqueries_score }} - {{ item.final_rival_score }}
        </div>
        <span v-else class="text-xs text-slate-500 italic">Por disputar</span>
      </template>

      <template #closes_at="{ item }">
        <span class="text-xs text-slate-300 font-mono">{{ formatCaracas(item.closes_at) }}</span>
      </template>

      <template #rewards="{ item }">
        <div class="text-xs">
          <span class="text-amber-300 font-bold"><i class="bi bi-gem"></i> {{ item.exact_reward_pearls }}</span>
          <span class="text-slate-500 text-[11px] block">Cercano: +{{ item.closest_reward_pearls }}</span>
        </div>
      </template>

      <template #status_badge="{ item }">
        <BaseBadge v-if="item.status === 'resolved'" variant="success">Finalizado</BaseBadge>
        <BaseBadge v-else-if="item.status === 'published'" variant="primary">Abierto</BaseBadge>
        <BaseBadge v-else-if="item.status === 'closed'" variant="warning">Cerrado</BaseBadge>
        <BaseBadge v-else variant="soft">Borrador</BaseBadge>
      </template>

      <template #actions="{ item }">
        <div class="flex items-center justify-end gap-1.5">
          <button
            v-if="item.status !== 'resolved'"
            @click="openResolveModal(item)"
            class="px-2 py-1 text-xs font-bold text-emerald-400 hover:text-white bg-emerald-950/60 hover:bg-emerald-800 border border-emerald-800/80 rounded transition"
            title="Ingresar marcador oficial y premiar"
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
    <BaseModal v-model="showEditorModal" :title="form.id ? 'Editar Predicción de Marcador' : 'Nueva Predicción de Marcador'">
      <div class="space-y-4 text-left">
        <BaseInput v-model="form.title" label="Título del Pronóstico *" placeholder="Ej: Adivina el Marcador: Guaiqueríes vs Marinos" />

        <BaseSelect
          v-model="form.game_id"
          label="Partido Oficial del Calendario *"
          :options="scheduledGames.map(g => ({ value: g.id, label: `vs ${g.opponent_name} (${formatCaracas(g.game_date)})` }))"
        />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.exact_reward_pearls" type="number" label="Perlitas por Marcador Exacto *" />
          <BaseInput v-model="form.closest_reward_pearls" type="number" label="Perlitas por Marcador Cercano (<=4 pts) *" />
        </div>

        <BaseInput v-model="form.description" label="Descripción / Reglamento (Opcional)" placeholder="Detalle adicional sobre el pozo de perlitas" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.starts_at" type="datetime-local" label="Fecha Inicio (Caracas)" />
          <BaseInput v-model="form.closes_at" type="datetime-local" label="Fecha Cierre (Caracas)" />
        </div>

        <BaseSelect
          v-model="form.status"
          label="Estado de Publicación"
          :options="[
            { value: 'published', label: 'Publicado (Abierto a votos)' },
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
    <BaseModal v-model="showResolveModal" title="Registrar Marcador Final Oficial">
      <div v-if="selectedItem" class="space-y-4 text-left">
        <p class="text-sm text-slate-300">
          Ingresa el resultado final oficial del encuentro. El sistema calculará automáticamente a los ganadores exactos y cercanos.
        </p>

        <div class="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-1">
          <div class="text-xs text-slate-400">Predicción: <strong class="text-white">{{ selectedItem.title }}</strong></div>
          <div class="text-xs text-slate-400">Participantes totales: <strong class="text-emerald-400">{{ selectedItem.total_votes }}</strong></div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <BaseInput
            v-model="finalGuaiquiScore"
            type="number"
            label="Puntos Guaiqueríes *"
            placeholder="Ej: 85"
          />
          <BaseInput
            v-model="finalRivalScore"
            type="number"
            label="Puntos Rival *"
            placeholder="Ej: 79"
          />
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="showResolveModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" size="sm" :loading="actionLoading" @click="resolveScore">Resolver y Premiar Ganadores</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      v-model:is-open="showBulkImportModal"
      type="score_predictions"
      @imported="loadData"
    />
  </div>
</template>
