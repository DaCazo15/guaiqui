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
  photo_url?: string | null
}

interface ProgressiveClueRow {
  id: string
  title: string
  description?: string | null
  player_id?: string | null
  target_player_name: string
  clue_1: string
  clue_2: string
  clue_3: string
  pearls_clue_1: number
  pearls_clue_2: number
  pearls_clue_3: number
  reveal_photo_url?: string | null
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  player?: PlayerItem | null
  total_votes?: number
  correct_votes?: number
}

const items = ref<ProgressiveClueRow[]>([])
const rosterPlayers = ref<PlayerItem[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showBulkImportModal = ref(false)
const selectedItem = ref<ProgressiveClueRow | null>(null)

// Form
const form = ref({
  id: '',
  title: '',
  player_id: '',
  target_player_name: '',
  clue_1: '',
  clue_2: '',
  clue_3: '',
  pearls_clue_1: 60,
  pearls_clue_2: 35,
  pearls_clue_3: 15,
  reveal_photo_url: '',
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: ''
})

const columns = [
  { key: 'title', label: 'Desafío / Jugador Objetivo' },
  { key: 'clues', label: 'Pistas Escalonadas' },
  { key: 'votes', label: 'Participantes', align: 'center' as const },
  { key: 'closes_at', label: 'Cierre' },
  { key: 'rewards', label: 'Escala Perlitas', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const [playersRes, pcRes] = await Promise.all([
      supabase.from('players').select('id, name, jersey_number, photo_url').order('jersey_number', { ascending: true }),
      supabase.from('progressive_clue_challenges').select(`
        *,
        player:players(id, name, jersey_number, photo_url)
      `).order('closes_at', { ascending: false })
    ])

    if (playersRes.data) rosterPlayers.value = playersRes.data
    if (pcRes.error) throw pcRes.error

    const rows = pcRes.data || []
    const { data: votes } = await supabase.from('progressive_clue_votes').select('challenge_id, is_correct')
    const voteMap = new Map<string, { total: number; correct: number }>()
    votes?.forEach((v: any) => {
      if (!voteMap.has(v.challenge_id)) voteMap.set(v.challenge_id, { total: 0, correct: 0 })
      const m = voteMap.get(v.challenge_id)!
      m.total++
      if (v.is_correct) m.correct++
    })

    items.value = rows.map((r: any) => {
      const v = voteMap.get(r.id) || { total: 0, correct: 0 }
      return {
        ...r,
        total_votes: v.total,
        correct_votes: v.correct
      }
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar pistas progresivas'
  } finally {
    loading.value = false
  }
}

const onPlayerSelected = (playerId: string) => {
  const p = rosterPlayers.value.find(pl => pl.id === playerId)
  if (p) {
    form.value.target_player_name = p.name
    if (p.photo_url) form.value.reveal_photo_url = p.photo_url
  }
}

const openCreateModal = () => {
  selectedItem.value = null
  const nowStr = nowCaracasInput()
  const defaultClose = nowCaracasInput(72)
  form.value = {
    id: '',
    title: 'Jugador Misterioso',
    player_id: rosterPlayers.value[0]?.id || '',
    target_player_name: rosterPlayers.value[0]?.name || '',
    clue_1: '',
    clue_2: '',
    clue_3: '',
    pearls_clue_1: 60,
    pearls_clue_2: 35,
    pearls_clue_3: 15,
    reveal_photo_url: rosterPlayers.value[0]?.photo_url || '',
    status: 'published',
    starts_at: nowStr,
    closes_at: defaultClose
  }
  showEditorModal.value = true
}

const openEditModal = (item: ProgressiveClueRow) => {
  selectedItem.value = item
  form.value = {
    id: item.id,
    title: item.title,
    player_id: item.player_id || '',
    target_player_name: item.target_player_name,
    clue_1: item.clue_1,
    clue_2: item.clue_2,
    clue_3: item.clue_3,
    pearls_clue_1: item.pearls_clue_1,
    pearls_clue_2: item.pearls_clue_2,
    pearls_clue_3: item.pearls_clue_3,
    reveal_photo_url: item.reveal_photo_url || '',
    status: item.status === 'draft' ? 'draft' : 'published',
    starts_at: isoToCaracasInput(item.starts_at),
    closes_at: isoToCaracasInput(item.closes_at)
  }
  showEditorModal.value = true
}

const saveItem = async () => {
  if (!form.value.title.trim() || !form.value.target_player_name.trim()) {
    errorMessage.value = 'El título y el nombre del jugador son obligatorios.'
    return
  }
  if (!form.value.clue_1.trim() || !form.value.clue_2.trim() || !form.value.clue_3.trim()) {
    errorMessage.value = 'Debes redactar las 3 pistas escalonadas.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const startsAtISO = form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString()
    const closesAtISO = form.value.closes_at ? caracasInputToISO(form.value.closes_at) : new Date(Date.now() + 3 * 86400000).toISOString()

    const { error } = await supabase.rpc('admin_upsert_progressive_clue', {
      p_id: form.value.id || null,
      p_player_id: form.value.player_id || null,
      p_target_player_name: form.value.target_player_name.trim(),
      p_title: form.value.title.trim(),
      p_description: 'Desafío de pistas progresivas',
      p_clue_1: form.value.clue_1.trim(),
      p_clue_2: form.value.clue_2.trim(),
      p_clue_3: form.value.clue_3.trim(),
      p_pearls_clue_1: Number(form.value.pearls_clue_1) || 60,
      p_pearls_clue_2: Number(form.value.pearls_clue_2) || 35,
      p_pearls_clue_3: Number(form.value.pearls_clue_3) || 15,
      p_reveal_photo_url: form.value.reveal_photo_url.trim() || null,
      p_status: form.value.status,
      p_starts_at: startsAtISO,
      p_closes_at: closesAtISO
    })

    if (error) throw error
    successMessage.value = form.value.id ? 'Desafío actualizado.' : 'Desafío de pistas progresivas creado exitosamente.'
    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar desafío'
  } finally {
    actionLoading.value = false
  }
}

const deleteItem = async (item: ProgressiveClueRow) => {
  if (!confirm(`¿Eliminar desafío "${item.title}"?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('progressive_clue_challenges').delete().eq('id', item.id)
    if (error) throw error
    successMessage.value = 'Desafío eliminado.'
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
          <i class="bi bi-puzzle-fill text-emerald-400"></i>
          Pistas Progresivas (El Jugador Misterioso)
        </h2>
        <p class="text-xs text-slate-400">
          Adivina con el menor número de pistas posible: mientras menos pistas uses para acertar, más perlitas ganas.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="outline" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openCreateModal">
          <i class="bi bi-plus-circle me-1"></i>
          Nuevo Desafío de Pistas
        </BaseButton>
      </div>
    </div>

    <!-- Table -->
    <BaseTable :columns="columns" :data="items" :loading="loading" empty-text="No hay desafíos de pistas progresivas creados.">
      <template #title="{ item }">
        <div class="font-bold text-white text-sm">{{ item.title }}</div>
        <div class="text-xs text-emerald-400 flex items-center gap-1.5 mt-0.5">
          <i class="bi bi-person-badge"></i>
          <span class="font-bold">{{ item.target_player_name }}</span>
          <span v-if="item.player" class="text-slate-400">(#{{ item.player.jersey_number }})</span>
        </div>
      </template>

      <template #clues="{ item }">
        <div class="space-y-0.5 text-[11px] max-w-sm">
          <div class="truncate text-slate-300"><span class="font-bold text-red-400">P1:</span> {{ item.clue_1 }}</div>
          <div class="truncate text-slate-300"><span class="font-bold text-amber-400">P2:</span> {{ item.clue_2 }}</div>
          <div class="truncate text-slate-300"><span class="font-bold text-emerald-400">P3:</span> {{ item.clue_3 }}</div>
        </div>
      </template>

      <template #votes="{ item }">
        <div class="text-xs text-slate-300">
          <span class="font-bold text-white">{{ item.total_votes }}</span>
          <span class="text-emerald-400 text-[11px] ms-1">({{ item.correct_votes }} aciertos)</span>
        </div>
      </template>

      <template #closes_at="{ item }">
        <span class="text-xs text-slate-300 font-mono">{{ formatCaracas(item.closes_at) }}</span>
      </template>

      <template #rewards="{ item }">
        <div class="text-xs text-slate-300 font-mono">
          <span class="text-amber-300 font-bold">{{ item.pearls_clue_1 }}</span> /
          <span class="text-amber-300 font-bold">{{ item.pearls_clue_2 }}</span> /
          <span class="text-amber-300 font-bold">{{ item.pearls_clue_3 }}</span>
        </div>
      </template>

      <template #status_badge="{ item }">
        <BaseBadge v-if="item.status === 'published'" variant="primary">Activo</BaseBadge>
        <BaseBadge v-else-if="item.status === 'closed'" variant="warning">Cerrado</BaseBadge>
        <BaseBadge v-else variant="soft">Borrador</BaseBadge>
      </template>

      <template #actions="{ item }">
        <div class="flex items-center justify-end gap-1.5">
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
    <BaseModal v-model="showEditorModal" :title="form.id ? 'Editar Desafío de Pistas' : 'Nuevo Desafío de Pistas'">
      <div class="space-y-4 text-left">
        <BaseInput v-model="form.title" label="Título del Desafío *" placeholder="Ej: Jugador Legendario #1" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseSelect
            v-model="form.player_id"
            label="Jugador Objetivo (Plantilla)"
            :options="rosterPlayers.map(p => ({ value: p.id, label: `#${p.jersey_number} - ${p.name}` }))"
            @change="onPlayerSelected(form.player_id)"
          />
          <BaseInput v-model="form.target_player_name" label="Nombre a Mostrar / Histórico *" placeholder="Nombre completo" />
        </div>

        <div class="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-3">
          <div class="text-xs font-bold text-slate-300 uppercase tracking-wider">Pistas y Escala de Perlitas</div>

          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs text-red-400 font-bold">
              <span>Pista 1 (Difícil)</span>
              <span>+{{ form.pearls_clue_1 }} Perlitas</span>
            </div>
            <BaseInput v-model="form.clue_1" placeholder="Ej: Fue Novato del Año en 2011" />
          </div>

          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs text-amber-400 font-bold">
              <span>Pista 2 (Media)</span>
              <span>+{{ form.pearls_clue_2 }} Perlitas</span>
            </div>
            <BaseInput v-model="form.clue_2" placeholder="Ej: Jugó en la posición Base con la Selección Nacional" />
          </div>

          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs text-emerald-400 font-bold">
              <span>Pista 3 (Fácil)</span>
              <span>+{{ form.pearls_clue_3 }} Perlitas</span>
            </div>
            <BaseInput v-model="form.clue_3" placeholder="Ej: Viste el dorsal #8 en la isla" />
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.starts_at" type="datetime-local" label="Fecha Inicio (Caracas)" />
          <BaseInput v-model="form.closes_at" type="datetime-local" label="Fecha Cierre (Caracas)" />
        </div>

        <BaseSelect
          v-model="form.status"
          label="Estado de Publicación"
          :options="[
            { value: 'published', label: 'Publicado (Activo)' },
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

    <!-- Bulk Import Modal -->
    <BulkImportModal
      v-model:is-open="showBulkImportModal"
      type="progressive_clues"
      @imported="loadData"
    />
  </div>
</template>
