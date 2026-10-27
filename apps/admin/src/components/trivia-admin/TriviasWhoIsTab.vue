<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'
import type { PlayerItem, WhoIsRow, WhoIsFormData } from './who-is/types'
import WhoIsChallengeTable from './who-is/WhoIsChallengeTable.vue'
import WhoIsChallengeModal from './who-is/WhoIsChallengeModal.vue'

const challenges = ref<WhoIsRow[]>([])
const rosterPlayers = ref<PlayerItem[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showDeleteModal = ref(false)
const showBulkImportModal = ref(false)
const selectedChallenge = ref<WhoIsRow | null>(null)

const challengeForm = ref<WhoIsFormData>({
  id: '',
  player_id: '',
  challenge_type: 'silhouette',
  title: '¿Quién es este jugador de la Tribu?',
  clue: '',
  custom_image_url: '',
  dorsal_number: null,
  reward_pearls: 50,
  status: 'published',
  starts_at: '',
  ends_at: ''
})

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data: pData, error: pErr } = await supabase
      .from('players')
      .select('id, name, jersey_number, photo_url, position')
      .order('jersey_number', { ascending: true })

    if (pErr) throw pErr
    rosterPlayers.value = pData || []

    const { data: cData, error: cErr } = await supabase
      .from('guess_player_challenges')
      .select('*, player:players(id, name, jersey_number, photo_url, position)')
      .order('created_at', { ascending: false })

    if (cErr) throw cErr
    challenges.value = cData || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewChallenge = () => {
  selectedChallenge.value = null
  const defaultPlayer = rosterPlayers.value[0] || null

  challengeForm.value = {
    id: '',
    player_id: defaultPlayer ? defaultPlayer.id : '',
    challenge_type: 'silhouette',
    title: '¿Quién es este jugador de la Tribu?',
    clue: '',
    custom_image_url: '',
    dorsal_number: defaultPlayer ? defaultPlayer.jersey_number : 10,
    reward_pearls: 50,
    status: 'published',
    starts_at: nowCaracasInput(),
    ends_at: nowCaracasInput(7 * 24 * 60 * 60 * 1000)
  }
  showEditorModal.value = true
}

const editChallenge = (c: WhoIsRow) => {
  selectedChallenge.value = c
  challengeForm.value = {
    id: c.id,
    player_id: c.player_id,
    challenge_type: c.challenge_type,
    title: c.title,
    clue: c.clue || '',
    custom_image_url: c.custom_image_url || '',
    dorsal_number: (c.dorsal_number !== null && c.dorsal_number !== undefined) ? c.dorsal_number : null,
    reward_pearls: c.reward_pearls,
    status: c.status,
    starts_at: isoToCaracasInput(c.starts_at),
    ends_at: isoToCaracasInput(c.ends_at)
  }
  showEditorModal.value = true
}

const saveChallenge = async () => {
  if (!challengeForm.value.player_id) {
    errorMessage.value = 'Debe seleccionar un jugador de la plantilla.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const selPlayer = rosterPlayers.value.find(p => p.id === challengeForm.value.player_id)
    const dorsal = challengeForm.value.challenge_type === 'dorsal'
      ? (challengeForm.value.dorsal_number ?? selPlayer?.jersey_number ?? 0)
      : (selPlayer?.jersey_number ?? null)

    const payload = {
      player_id: challengeForm.value.player_id,
      challenge_type: challengeForm.value.challenge_type,
      title: challengeForm.value.title.trim() || '¿Quién es este jugador de la Tribu?',
      clue: challengeForm.value.clue.trim() || null,
      custom_image_url: challengeForm.value.challenge_type === 'silhouette'
        ? (challengeForm.value.custom_image_url.trim() || null)
        : null,
      dorsal_number: dorsal,
      reward_pearls: Number(challengeForm.value.reward_pearls) || 50,
      status: challengeForm.value.status,
      starts_at: caracasInputToISO(challengeForm.value.starts_at),
      ends_at: caracasInputToISO(challengeForm.value.ends_at)
    }

    if (challengeForm.value.id) {
      const { error } = await supabase
        .from('guess_player_challenges')
        .update(payload)
        .eq('id', challengeForm.value.id)
      if (error) throw error
      successMessage.value = 'Reto actualizado exitosamente.'
    } else {
      const { error } = await supabase
        .from('guess_player_challenges')
        .insert([payload])
      if (error) throw error
      successMessage.value = 'Reto programado exitosamente.'
    }

    showEditorModal.value = false
    await loadData()
    setTimeout(() => { successMessage.value = null }, 3000)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar el reto.'
  } finally {
    actionLoading.value = false
  }
}

const confirmDeleteChallenge = (c: WhoIsRow) => {
  selectedChallenge.value = c
  showDeleteModal.value = true
}

const deleteChallenge = async () => {
  if (!selectedChallenge.value) return
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('guess_player_challenges')
      .delete()
      .eq('id', selectedChallenge.value.id)

    if (error) throw error
    successMessage.value = 'Reto eliminado exitosamente.'
    showDeleteModal.value = false
    await loadData()
    setTimeout(() => { successMessage.value = null }, 3000)
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header Actions -->
    <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-slate-900/60 p-4 rounded-xl border border-slate-800">
      <div>
        <h2 class="text-lg font-bold text-white flex items-center gap-2">
          <i class="bi bi-person-bounding-box text-emerald-400"></i>
          Retos «¿Quién es?» (Siluetas y Dorsales)
        </h2>
        <p class="text-xs text-slate-400 mt-0.5">
          Configura desafíos interactivos donde los fanáticos identifican a jugadores por su silueta o dorsal.
        </p>
      </div>

      <div class="flex items-center gap-2.5 w-full sm:w-auto">
        <BaseButton variant="secondary" size="sm" @click="showBulkImportModal = true" class="flex-1 sm:flex-initial">
          <i class="bi bi-file-earmark-spreadsheet mr-1.5 text-emerald-400"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openNewChallenge" class="flex-1 sm:flex-initial">
          <i class="bi bi-plus-circle-fill mr-1.5"></i>
          Nuevo Reto
        </BaseButton>
      </div>
    </div>

    <!-- Feedback alerts -->
    <div v-if="errorMessage" class="p-3 bg-red-950/60 border border-red-800 text-red-200 text-xs rounded-xl flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="successMessage" class="p-3 bg-emerald-950/60 border border-emerald-800 text-emerald-200 text-xs rounded-xl flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>

    <!-- Subcomponent: Challenge Table -->
    <WhoIsChallengeTable
      :challenges="challenges"
      :loading="loading"
      @edit="editChallenge"
      @delete="confirmDeleteChallenge"
    />

    <!-- Subcomponent: Editor Modal -->
    <WhoIsChallengeModal
      :is-open="showEditorModal"
      :form="challengeForm"
      :roster-players="rosterPlayers"
      :action-loading="actionLoading"
      @close="showEditorModal = false"
      @save="saveChallenge"
    />

    <!-- Delete Modal -->
    <BaseModal v-if="showDeleteModal" :is-open="showDeleteModal" title="Eliminar Reto" @close="showDeleteModal = false">
      <div class="space-y-4">
        <p class="text-sm text-slate-300">
          ¿Desea eliminar permanentemente el reto <strong class="text-white">{{ selectedChallenge?.title }}</strong>?
        </p>
        <div class="p-3 bg-red-950/60 border border-red-800 text-xs text-red-200 rounded-lg">
          Esta acción no se puede deshacer y borrará también el historial de votos asociados a este reto.
        </div>
      </div>
      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showDeleteModal = false">Cancelar</BaseButton>
          <BaseButton variant="danger" :loading="actionLoading" @click="deleteChallenge">Confirmar Eliminación</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      :is-open="showBulkImportModal"
      type="who_is"
      @close="showBulkImportModal = false"
      @success="loadData"
    />
  </div>
</template>
