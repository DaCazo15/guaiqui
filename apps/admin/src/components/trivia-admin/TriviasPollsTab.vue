<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'
import type { PlayerItem, GameItem, PollRow, PollFormData } from './polls/types'
import PollsTable from './polls/PollsTable.vue'
import PollEditorModal from './polls/PollEditorModal.vue'
import PollResolveModal from './polls/PollResolveModal.vue'

const polls = ref<PollRow[]>([])
const games = ref<GameItem[]>([])
const rosterPlayers = ref<PlayerItem[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showResolveModal = ref(false)
const showDeleteModal = ref(false)
const showBulkImportModal = ref(false)
const selectedPoll = ref<PollRow | null>(null)
const selectedWinningOptionId = ref<string>('')

const pollForm = ref<PollFormData>({
  id: '',
  game_id: '',
  title: '',
  description: '',
  reward_pearls: 50,
  status: 'published',
  starts_at: '',
  closes_at: '',
  options: []
})

const loadPollsData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const [pRes, gRes, plRes] = await Promise.all([
      supabase
        .from('trivia_polls')
        .select(`
          *,
          game:games(id, opponent, game_date, is_home, location),
          options:trivia_poll_options(
            id, poll_id, label, player_id, order_index, votes_count,
            player:players(id, name, jersey_number, photo_url, position)
          )
        `)
        .order('created_at', { ascending: false }),
      supabase
        .from('games')
        .select('id, opponent, game_date, is_home, location')
        .order('game_date', { ascending: false })
        .limit(20),
      supabase
        .from('players')
        .select('id, name, jersey_number, photo_url, position')
        .eq('is_active', true)
        .order('jersey_number', { ascending: true })
    ])

    if (pRes.error) throw pRes.error
    if (gRes.error) throw gRes.error
    if (plRes.error) throw plRes.error

    polls.value = (pRes.data || []).map((p: any) => {
      const opts = p.options || []
      const total = opts.reduce((acc: number, curr: any) => acc + (curr.votes_count || 0), 0)
      return {
        ...p,
        total_votes: total
      }
    })
    games.value = gRes.data || []
    rosterPlayers.value = plRes.data || []
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar encuestas.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadPollsData()
})

const openNewPollModal = () => {
  const now = nowCaracasInput()
  pollForm.value = {
    id: '',
    game_id: games.value[0]?.id || '',
    title: '',
    description: '',
    reward_pearls: 50,
    status: 'published',
    starts_at: now,
    closes_at: now,
    options: [
      { label: '', player_id: '' },
      { label: '', player_id: '' }
    ]
  }
  showEditorModal.value = true
}

const editPoll = (p: PollRow) => {
  pollForm.value = {
    id: p.id,
    game_id: p.game_id || '',
    title: p.title,
    description: p.description || '',
    reward_pearls: p.reward_pearls,
    status: p.status === 'draft' ? 'draft' : 'published',
    starts_at: isoToCaracasInput(p.starts_at),
    closes_at: isoToCaracasInput(p.closes_at),
    options: (p.options || []).map(o => ({
      id: o.id,
      label: o.label,
      player_id: o.player_id || ''
    }))
  }
  if (pollForm.value.options.length < 2) {
    pollForm.value.options.push({ label: '', player_id: '' })
  }
  showEditorModal.value = true
}

const addOptionField = () => {
  pollForm.value.options.push({ label: '', player_id: '' })
}

const removeOptionField = (idx: number) => {
  if (pollForm.value.options.length <= 2) {
    errorMessage.value = 'Una encuesta debe tener un mínimo de 2 opciones.'
    return
  }
  pollForm.value.options.splice(idx, 1)
}

const onPlayerSelectChange = (idx: number, playerId: string) => {
  pollForm.value.options[idx].player_id = playerId
  if (playerId && !pollForm.value.options[idx].label) {
    const pl = rosterPlayers.value.find(p => p.id === playerId)
    if (pl) pollForm.value.options[idx].label = `#${pl.jersey_number} ${pl.name}`
  }
}

const savePoll = async () => {
  if (!pollForm.value.title.trim()) {
    errorMessage.value = 'El título de la encuesta es obligatorio.'
    return
  }
  const validOpts = pollForm.value.options.filter(o => o.label.trim())
  if (validOpts.length < 2) {
    errorMessage.value = 'Debes especificar al menos 2 opciones con texto válido.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const pollPayload = {
      title: pollForm.value.title.trim(),
      description: pollForm.value.description ? pollForm.value.description.trim() : null,
      game_id: pollForm.value.game_id || null,
      reward_pearls: Number(pollForm.value.reward_pearls) || 50,
      status: pollForm.value.status,
      starts_at: caracasInputToISO(pollForm.value.starts_at),
      closes_at: caracasInputToISO(pollForm.value.closes_at)
    }

    const optionsPayload = validOpts.map((o, idx) => ({
      id: o.id || undefined,
      label: o.label.trim(),
      player_id: o.player_id || null,
      order_index: idx + 1
    }))

    const { error } = await supabase.rpc('admin_upsert_trivia_poll', {
      p_poll: pollPayload,
      p_options: optionsPayload,
      p_poll_id: pollForm.value.id || null
    })

    if (error) throw error

    successMessage.value = pollForm.value.id ? 'Encuesta actualizada exitosamente.' : 'Encuesta creada exitosamente.'
    showEditorModal.value = false
    await loadPollsData()
    setTimeout(() => { successMessage.value = null }, 3500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar la encuesta.'
  } finally {
    actionLoading.value = false
  }
}

const openResolveModal = (p: PollRow) => {
  selectedPoll.value = p
  selectedWinningOptionId.value = p.correct_option_id || ''
  showResolveModal.value = true
}

const confirmResolution = async () => {
  if (!selectedPoll.value) return
  if (!selectedWinningOptionId.value) {
    errorMessage.value = 'Debes seleccionar la opción ganadora definitiva.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('admin_resolve_trivia_poll', {
      p_poll_id: selectedPoll.value.id,
      p_correct_option_id: selectedWinningOptionId.value
    })

    if (error) throw error

    successMessage.value = `¡Encuesta resuelta! Se premiaron a ${data?.winners_count || 0} fanáticos ganadores con un total de ${data?.total_pearls_distributed || 0} perlitas.`
    showResolveModal.value = false
    await loadPollsData()
    setTimeout(() => { successMessage.value = null }, 5000)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al resolver la encuesta.'
  } finally {
    actionLoading.value = false
  }
}

const openDeleteModal = (p: PollRow) => {
  selectedPoll.value = p
  showDeleteModal.value = true
}

const confirmDelete = async () => {
  if (!selectedPoll.value) return
  actionLoading.value = true
  try {
    const { error } = await supabase.rpc('admin_delete_trivia_poll', {
      p_id: selectedPoll.value.id
    })
    if (error) throw error
    successMessage.value = 'Encuesta eliminada exitosamente.'
    showDeleteModal.value = false
    await loadPollsData()
    setTimeout(() => { successMessage.value = null }, 3500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar la encuesta.'
  } finally {
    actionLoading.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header Controls -->
    <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-slate-900/60 p-4 rounded-xl border border-slate-800">
      <div>
        <h2 class="text-lg font-bold text-white flex items-center gap-2">
          <i class="bi bi-bar-chart-fill text-emerald-400"></i>
          Encuestas y Predicciones de Partido
        </h2>
        <p class="text-xs text-slate-400 mt-0.5">
          Crea preguntas dinámicas (MVP, triples, marcador). La respuesta es una incógnita y se resuelve al finalizar el partido para premiar a los acertados.
        </p>
      </div>

      <div class="flex items-center gap-2.5 w-full sm:w-auto">
        <BaseButton variant="secondary" size="sm" @click="showBulkImportModal = true" class="flex-1 sm:flex-initial">
          <i class="bi bi-file-earmark-spreadsheet mr-1.5 text-emerald-400"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openNewPollModal" class="flex-1 sm:flex-initial">
          <i class="bi bi-plus-circle-fill mr-1.5"></i>
          Nueva Encuesta
        </BaseButton>
      </div>
    </div>

    <!-- Alert Messages -->
    <div v-if="errorMessage" class="p-3 bg-red-950/60 border border-red-800/80 rounded-lg text-red-200 text-xs flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>
      <button @click="errorMessage = null" class="text-red-400 hover:text-white">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <div v-if="successMessage" class="p-3 bg-emerald-950/60 border border-emerald-800/80 rounded-lg text-emerald-200 text-xs flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-400"></i>
        <span>{{ successMessage }}</span>
      </div>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-white">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- Subcomponent: Table of Polls -->
    <PollsTable
      :polls="polls"
      :loading="loading"
      @resolve="openResolveModal"
      @edit="editPoll"
      @delete="openDeleteModal"
    />

    <!-- Subcomponent: Modal Create / Edit Poll -->
    <PollEditorModal
      :is-open="showEditorModal"
      :form="pollForm"
      :games="games"
      :roster-players="rosterPlayers"
      :action-loading="actionLoading"
      @close="showEditorModal = false"
      @save="savePoll"
      @add-option="addOptionField"
      @remove-option="removeOptionField"
      @player-select="onPlayerSelectChange"
    />

    <!-- Subcomponent: Modal Resolve Poll -->
    <PollResolveModal
      :is-open="showResolveModal"
      :poll="selectedPoll"
      :winning-option-id="selectedWinningOptionId"
      :action-loading="actionLoading"
      @close="showResolveModal = false"
      @update:winning-option-id="selectedWinningOptionId = $event"
      @confirm="confirmResolution"
    />

    <!-- Modal: Delete Confirmation -->
    <BaseModal
      v-if="showDeleteModal"
      :is-open="showDeleteModal"
      title="Eliminar Encuesta"
      @close="showDeleteModal = false"
    >
      <div class="space-y-3">
        <p class="text-sm text-slate-300">
          ¿Estás seguro de que deseas eliminar permanentemente la encuesta <strong>"{{ selectedPoll?.title }}"</strong>?
        </p>
        <p class="text-xs text-red-400">
          Se borrarán también las opciones asociadas y los votos registrados para esta encuesta.
        </p>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showDeleteModal = false">Cancelar</BaseButton>
          <BaseButton variant="danger" :loading="actionLoading" @click="confirmDelete">Eliminar</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Modal: Bulk Import -->
    <BulkImportModal
      :is-open="showBulkImportModal"
      type="polls"
      @close="showBulkImportModal = false"
      @success="loadPollsData"
    />
  </div>
</template>
