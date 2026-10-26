<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface PlayerItem {
  id: string
  name: string
  jersey_number: number
  photo_url?: string | null
  position?: string | null
}

interface GameItem {
  id: string
  opponent: string
  game_date: string
  is_home: boolean
  location: string
}

interface PollOptionItem {
  id?: string
  poll_id?: string
  label: string
  player_id?: string | null
  order_index: number
  votes_count?: number
  player?: PlayerItem | null
}

interface PollRow {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  reward_pearls: number
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  correct_option_id?: string | null
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
  game?: GameItem | null
  options?: PollOptionItem[]
  total_votes?: number
}

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

// Form state
interface OptionFormItem {
  id?: string
  label: string
  player_id: string
}

const pollForm = ref({
  id: '',
  game_id: '',
  title: '',
  description: '',
  reward_pearls: 50,
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: '',
  options: [] as OptionFormItem[]
})

const columns = [
  { key: 'title', label: 'Encuesta / Pregunta' },
  { key: 'game', label: 'Partido Asociado' },
  { key: 'options_preview', label: 'Opciones' },
  { key: 'closes_at', label: 'Cierre de Votación' },
  { key: 'reward_pearls', label: 'Premio', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

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

const getPollStatusDisplay = (poll: PollRow) => {
  if (poll.status === 'resolved') {
    return { label: 'Resuelta', variant: 'success' as const, icon: 'bi-check2-all' }
  }
  if (poll.status === 'draft') {
    return { label: 'Borrador', variant: 'soft' as const, icon: 'bi-pencil-square' }
  }
  const isExpired = new Date(poll.closes_at).getTime() < Date.now()
  if (isExpired || poll.status === 'closed') {
    return { label: 'Cerrada (Pendiente)', variant: 'warning' as const, icon: 'bi-clock-history' }
  }
  return { label: 'Abierta para Votar', variant: 'success' as const, icon: 'bi-broadcast' }
}

const openNewPollModal = () => {
  const now = nowCaracasInput()
  // Default closes 4 hours from now
  const closesDate = new Date(Date.now() + 4 * 3600000)
  const defaultCloses = isoToCaracasInput(closesDate.toISOString())

  pollForm.value = {
    id: '',
    game_id: games.value[0]?.id || '',
    title: '',
    description: '',
    reward_pearls: 50,
    status: 'published',
    starts_at: now,
    closes_at: defaultCloses,
    options: [
      { label: '', player_id: '' },
      { label: '', player_id: '' }
    ]
  }
  errorMessage.value = null
  showEditorModal.value = true
}

const editPoll = (p: PollRow) => {
  pollForm.value = {
    id: p.id,
    game_id: p.game_id || '',
    title: p.title,
    description: p.description || '',
    reward_pearls: p.reward_pearls,
    status: (p.status === 'draft' ? 'draft' : 'published'),
    starts_at: isoToCaracasInput(p.starts_at),
    closes_at: isoToCaracasInput(p.closes_at),
    options: (p.options && p.options.length > 0)
      ? p.options.map(o => ({
          id: o.id,
          label: o.label,
          player_id: o.player_id || ''
        }))
      : [
          { label: '', player_id: '' },
          { label: '', player_id: '' }
        ]
  }
  errorMessage.value = null
  showEditorModal.value = true
}

const addOptionField = () => {
  pollForm.value.options.push({ label: '', player_id: '' })
}

const removeOptionField = (idx: number) => {
  if (pollForm.value.options.length <= 2) {
    errorMessage.value = 'La encuesta debe tener al menos dos opciones.'
    return
  }
  pollForm.value.options.splice(idx, 1)
}

const onPlayerSelectChange = (idx: number, playerId: string) => {
  pollForm.value.options[idx].player_id = playerId
  if (playerId) {
    const pl = rosterPlayers.value.find(p => p.id === playerId)
    if (pl && !pollForm.value.options[idx].label) {
      pollForm.value.options[idx].label = `${pl.name} (#${pl.jersey_number})`
    }
  }
}

const savePoll = async () => {
  if (!pollForm.value.title.trim()) {
    errorMessage.value = 'El título de la encuesta es obligatorio.'
    return
  }
  if (!pollForm.value.closes_at) {
    errorMessage.value = 'Debes especificar la fecha y hora de cierre de la votación.'
    return
  }
  const filledOptions = pollForm.value.options.filter(o => o.label.trim())
  if (filledOptions.length < 2) {
    errorMessage.value = 'Debes ingresar al menos 2 opciones válidas.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const pollPayload = {
      id: pollForm.value.id || undefined,
      game_id: pollForm.value.game_id || null,
      title: pollForm.value.title.trim(),
      description: pollForm.value.description.trim() || null,
      reward_pearls: Number(pollForm.value.reward_pearls) || 50,
      status: pollForm.value.status,
      starts_at: caracasInputToISO(pollForm.value.starts_at),
      closes_at: caracasInputToISO(pollForm.value.closes_at)
    }

    const optionsPayload = filledOptions.map((o, index) => ({
      id: o.id || undefined,
      label: o.label.trim(),
      player_id: o.player_id || null,
      order_index: index + 1
    }))

    const { error } = await supabase.rpc('admin_upsert_trivia_poll', {
      p_poll: pollPayload,
      p_options: optionsPayload
    })

    if (error) throw error

    successMessage.value = pollForm.value.id ? 'Encuesta actualizada correctamente.' : 'Encuesta creada y publicada exitosamente.'
    showEditorModal.value = false
    await loadPollsData()
    setTimeout(() => { successMessage.value = null }, 3500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar encuesta.'
  } finally {
    actionLoading.value = false
  }
}

// Resolution
const openResolveModal = (p: PollRow) => {
  selectedPoll.value = p
  selectedWinningOptionId.value = p.correct_option_id || ''
  errorMessage.value = null
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

// Delete
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

    <!-- Table of Polls -->
    <BaseTable
      :columns="columns"
      :data="(polls as any[])"
      :loading="loading"
      empty-text="No hay encuestas ni predicciones creadas. Haz clic en 'Nueva Encuesta' para crear la primera."
    >
      <!-- Title Cell -->
      <template #cell-title="{ row }">
        <div class="space-y-1 py-1">
          <div class="font-bold text-white text-sm flex items-center gap-2">
            <span>{{ (row as PollRow).title }}</span>
            <span v-if="(row as PollRow).status === 'resolved'" class="text-[10px] bg-emerald-500/20 text-emerald-300 px-1.5 py-0.5 rounded border border-emerald-500/30">
              <i class="bi bi-trophy-fill mr-1 text-amber-400"></i>Resuelta
            </span>
          </div>
          <p v-if="(row as PollRow).description" class="text-xs text-slate-400 line-clamp-1">
            {{ (row as PollRow).description }}
          </p>
        </div>
      </template>

      <!-- Game Cell -->
      <template #cell-game="{ row }">
        <div v-if="(row as PollRow).game" class="text-xs">
          <span class="font-medium text-slate-200">vs {{ (row as PollRow).game?.opponent }}</span>
          <div class="text-[11px] text-slate-400 font-mono">
            {{ formatCaracas((row as PollRow).game!.game_date) }}
          </div>
        </div>
        <span v-else class="text-xs text-slate-500 italic">General / Sin partido</span>
      </template>

      <!-- Options Preview Cell -->
      <template #cell-options_preview="{ row }">
        <div class="space-y-1">
          <div class="flex flex-wrap gap-1 max-w-xs">
            <span
              v-for="opt in (row as PollRow).options?.slice(0, 3)"
              :key="opt.id || opt.label"
              class="text-[11px] px-2 py-0.5 rounded-full border"
              :class="opt.id === (row as PollRow).correct_option_id
                ? 'bg-emerald-950/80 text-emerald-300 border-emerald-500 font-bold'
                : 'bg-slate-800 text-slate-300 border-slate-700'"
            >
              <i v-if="opt.id === (row as PollRow).correct_option_id" class="bi bi-check-circle-fill text-emerald-400 mr-1"></i>
              {{ opt.label }} ({{ opt.votes_count || 0 }})
            </span>
            <span v-if="((row as PollRow).options?.length || 0) > 3" class="text-[10px] text-slate-400 self-center">
              +{{ ((row as PollRow).options?.length || 0) - 3 }} más
            </span>
          </div>
          <div class="text-[10px] text-slate-400">
            Total votos: <span class="font-semibold text-white">{{ (row as PollRow).total_votes || 0 }}</span>
          </div>
        </div>
      </template>

      <!-- Closes At Cell -->
      <template #cell-closes_at="{ row }">
        <div class="text-xs font-mono text-slate-300">
          {{ formatCaracas((row as PollRow).closes_at) }}
        </div>
      </template>

      <!-- Reward Cell -->
      <template #cell-reward_pearls="{ row }">
        <div class="flex items-center justify-center gap-1 font-bold font-mono text-emerald-400 text-xs">
          <i class="bi bi-circle-fill text-[8px] text-emerald-400"></i>
          <span>+{{ (row as PollRow).reward_pearls }}</span>
        </div>
      </template>

      <!-- Status Badge Cell -->
      <template #cell-status_badge="{ row }">
        <BaseBadge :variant="getPollStatusDisplay(row as PollRow).variant" size="sm" class="flex items-center gap-1 whitespace-nowrap">
          <i :class="['bi', getPollStatusDisplay(row as PollRow).icon]"></i>
          <span>{{ getPollStatusDisplay(row as PollRow).label }}</span>
        </BaseBadge>
      </template>

      <!-- Actions Cell -->
      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button
            v-if="(row as PollRow).status !== 'resolved'"
            @click="openResolveModal(row as PollRow)"
            class="px-2.5 py-1 text-xs font-semibold rounded-lg bg-emerald-950/70 border border-emerald-600/60 text-emerald-300 hover:bg-emerald-900 transition-colors flex items-center gap-1"
            title="Resolver encuesta y entregar premios"
          >
            <i class="bi bi-trophy"></i>
            <span>Resolver</span>
          </button>
          <button
            @click="editPoll(row as PollRow)"
            class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
            title="Editar encuesta"
          >
            <i class="bi bi-pencil"></i>
          </button>
          <button
            @click="openDeleteModal(row as PollRow)"
            class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors"
            title="Eliminar encuesta"
          >
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal: Create / Edit Poll -->
    <BaseModal
      v-if="showEditorModal"
      :is-open="showEditorModal"
      :title="pollForm.id ? 'Editar Encuesta' : 'Nueva Encuesta de Predicción'"
      @close="showEditorModal = false"
    >
      <div class="space-y-4">
        <BaseInput
          label="Título / Pregunta de la Encuesta"
          v-model="pollForm.title"
          placeholder="Ej: ¿Quién será el MVP del partido vs Marinos?"
        />

        <BaseInput
          label="Descripción o Instrucción (Opcional)"
          v-model="pollForm.description"
          placeholder="Ej: Elige tu favorito antes del entretiempo."
        />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <!-- Game Select -->
          <div>
            <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Partido Asociado (Opcional)</label>
            <select
              v-model="pollForm.game_id"
              class="w-full bg-slate-900 border border-slate-700 text-white rounded-lg px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
            >
              <option value="">-- Sin vincular a partido --</option>
              <option v-for="g in games" :key="g.id" :value="g.id">
                vs {{ g.opponent }} ({{ formatCaracas(g.game_date) }})
              </option>
            </select>
          </div>

          <!-- Reward Pearls -->
          <BaseInput
            label="Premio por Acertar (Perlitas)"
            type="number"
            v-model="pollForm.reward_pearls"
            placeholder="50"
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput
            label="Fecha y Hora de Inicio"
            type="datetime-local"
            v-model="pollForm.starts_at"
          />
          <BaseInput
            label="Fecha y Hora de Cierre (Límite de Votación)"
            type="datetime-local"
            v-model="pollForm.closes_at"
          />
        </div>

        <!-- Dynamic Options Section -->
        <div class="border-t border-slate-800 pt-3 space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-slate-300 uppercase flex items-center gap-1.5">
              <i class="bi bi-list-check text-emerald-400"></i>
              Opciones de Respuesta (Mínimo 2)
            </label>
            <button
              type="button"
              @click="addOptionField"
              class="text-xs text-emerald-400 hover:text-emerald-300 flex items-center gap-1 font-semibold"
            >
              <i class="bi bi-plus-circle"></i> Agregar Opción
            </button>
          </div>

          <div class="space-y-2.5 max-h-60 overflow-y-auto pr-1">
            <div
              v-for="(opt, idx) in pollForm.options"
              :key="idx"
              class="flex items-center gap-2 p-2.5 bg-slate-900/80 border border-slate-800 rounded-lg"
            >
              <span class="w-6 text-center text-xs font-bold text-slate-500 font-mono">
                #{{ idx + 1 }}
              </span>

              <div class="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-2">
                <input
                  v-model="opt.label"
                  placeholder="Texto de opción (Ej: Pedro Chourio)"
                  class="bg-slate-950 border border-slate-700 text-white rounded px-2.5 py-1.5 text-xs focus:border-emerald-500 focus:outline-none"
                />

                <select
                  :value="opt.player_id"
                  @change="onPlayerSelectChange(idx, ($event.target as HTMLSelectElement).value)"
                  class="bg-slate-950 border border-slate-700 text-slate-300 rounded px-2.5 py-1.5 text-xs focus:border-emerald-500 focus:outline-none"
                >
                  <option value="">-- Vincular Jugador (Opcional) --</option>
                  <option v-for="p in rosterPlayers" :key="p.id" :value="p.id">
                    #{{ p.jersey_number }} - {{ p.name }}
                  </option>
                </select>
              </div>

              <button
                type="button"
                @click="removeOptionField(idx)"
                class="p-1.5 text-slate-500 hover:text-red-400 transition-colors"
                title="Eliminar opción"
              >
                <i class="bi bi-x-circle"></i>
              </button>
            </div>
          </div>
        </div>

        <!-- Status -->
        <div class="flex items-center gap-4 border-t border-slate-800 pt-3">
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
            <input type="radio" value="published" v-model="pollForm.status" class="accent-emerald-600" />
            <span>Publicado (Visible a fanáticos)</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-slate-400 cursor-pointer">
            <input type="radio" value="draft" v-model="pollForm.status" class="accent-emerald-600" />
            <span>Borrador (Oculto)</span>
          </label>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="savePoll">Guardar Encuesta</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Modal: Resolve Poll & Reward -->
    <BaseModal
      v-if="showResolveModal"
      :is-open="showResolveModal"
      title="Resolver Encuesta y Entregar Perlitas"
      @close="showResolveModal = false"
    >
      <div v-if="selectedPoll" class="space-y-4">
        <div class="p-3 bg-slate-900 border border-slate-800 rounded-lg space-y-1">
          <div class="text-xs text-slate-400 font-semibold uppercase">Encuesta a resolver</div>
          <div class="font-bold text-white text-base">{{ selectedPoll.title }}</div>
          <div v-if="selectedPoll.game" class="text-xs text-emerald-400 flex items-center gap-1.5">
            <i class="bi bi-geo-alt-fill"></i>
            <span>Partido: vs {{ selectedPoll.game.opponent }}</span>
          </div>
        </div>

        <p class="text-xs text-slate-300">
          Selecciona cuál fue la <strong>opción ganadora real</strong> del partido. Todos los fanáticos que hayan votado por ella recibirán automáticamente <strong>+{{ selectedPoll.reward_pearls }} perlitas</strong> en su billetera.
        </p>

        <div class="space-y-2">
          <label
            v-for="opt in selectedPoll.options"
            :key="opt.id"
            class="flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-all duration-200"
            :class="selectedWinningOptionId === opt.id
              ? 'bg-emerald-950/80 border-emerald-500 shadow-sm'
              : 'bg-slate-900/60 border-slate-800 hover:border-slate-700'"
          >
            <div class="flex items-center gap-3">
              <input
                type="radio"
                :value="opt.id"
                v-model="selectedWinningOptionId"
                class="accent-emerald-500 w-4 h-4"
              />
              <div class="flex items-center gap-2">
                <img
                  v-if="opt.player?.photo_url"
                  :src="opt.player.photo_url"
                  class="w-6 h-6 rounded-full object-cover border border-emerald-500/50"
                />
                <span class="font-medium text-sm" :class="selectedWinningOptionId === opt.id ? 'text-emerald-200 font-bold' : 'text-slate-200'">
                  {{ opt.label }}
                </span>
              </div>
            </div>

            <div class="text-xs font-mono text-slate-400">
              <span class="font-bold text-white">{{ opt.votes_count || 0 }}</span> votos
              <span v-if="selectedPoll.total_votes" class="text-[10px] text-slate-500 ml-1">
                ({{ Math.round(((opt.votes_count || 0) / selectedPoll.total_votes) * 100) }}%)
              </span>
            </div>
          </label>
        </div>

        <div class="p-3 bg-amber-950/40 border border-amber-800/60 rounded-lg text-amber-200 text-xs flex items-start gap-2">
          <i class="bi bi-shield-exclamation text-amber-400 text-sm shrink-0 mt-0.5"></i>
          <span>Esta acción es irreversible y ejecutará transacciones atómicas de ledger para todos los ganadores.</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showResolveModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="confirmResolution">
            <i class="bi bi-trophy-fill mr-1.5 text-amber-300"></i>
            Confirmar y Premiar Ganadores
          </BaseButton>
        </div>
      </template>
    </BaseModal>

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
