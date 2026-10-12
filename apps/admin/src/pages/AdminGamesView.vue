<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { SOFASCORE_OFFICIAL_GAMES, SOFASCORE_TEAM_INFO, caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface GameRow {
  id: string
  opponent: string
  location: string
  game_date: string
  is_home: boolean
  status: 'scheduled' | 'live' | 'finished' | 'cancelled'
  our_score: number
  opponent_score: number
}

const games = ref<GameRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const syncLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const gameForm = ref({
  id: '',
  opponent: '',
  location: 'Gimnasio Ciudad de La Asunción',
  game_date: '',
  is_home: true,
  status: 'scheduled' as 'scheduled' | 'live' | 'finished' | 'cancelled',
  our_score: 0,
  opponent_score: 0
})

const columns = [
  { key: 'opponent', label: 'Rival' },
  { key: 'game_date', label: 'Fecha del Partido' },
  { key: 'is_home', label: 'Sede' },
  { key: 'score', label: 'Marcador', align: 'center' as const },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadGames = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('games')
      .select('*')
      .order('game_date', { ascending: false })

    if (error) throw error
    games.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const syncWithSofascore = async () => {
  if (!confirm(`¿Deseas sincronizar el calendario y resultados desde Sofascore (ID: ${SOFASCORE_TEAM_INFO.sofascore_id})?\nEsto actualizará los marcadores de la Gran Final SPB y los próximos encuentros programados.`)) {
    return
  }

  syncLoading.value = true
  errorMessage.value = null
  successMessage.value = null

  try {
    let syncedCount = 0
    for (const g of SOFASCORE_OFFICIAL_GAMES) {
      // Buscar si el partido ya existe con este rival y fecha similar
      const gDateDay = new Date(g.game_date).toISOString().slice(0, 10)
      const existing = games.value.find(eg => {
        const egDay = eg.game_date ? new Date(eg.game_date).toISOString().slice(0, 10) : ''
        return eg.opponent.toLowerCase() === g.opponent.toLowerCase() && egDay === gDateDay
      })

      const payload = {
        id: existing ? existing.id : undefined,
        opponent: g.opponent,
        location: g.location,
        game_date: new Date(g.game_date).toISOString(),
        is_home: g.is_home,
        status: g.status,
        our_score: g.our_score,
        opponent_score: g.opponent_score
      }

      const { error } = await supabase.rpc('admin_upsert_game', { p_game: payload })
      if (!error) {
        syncedCount++
      }
    }

    successMessage.value = `¡Sincronización completada! ${syncedCount} partidos oficiales de Sofascore actualizados.`
    await loadGames()
  } catch (err: any) {
    errorMessage.value = `Error al sincronizar partidos: ${err.message}`
  } finally {
    syncLoading.value = false
  }
}

const openNewGame = () => {
  gameForm.value = {
    id: '',
    opponent: '',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: nowCaracasInput(),
    is_home: true,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0
  }
  showEditorModal.value = true
}

const editGame = (g: GameRow) => {
  gameForm.value = {
    id: g.id,
    opponent: g.opponent,
    location: g.location,
    game_date: g.game_date ? isoToCaracasInput(g.game_date) : '',
    is_home: g.is_home,
    status: g.status,
    our_score: g.our_score || 0,
    opponent_score: g.opponent_score || 0
  }
  showEditorModal.value = true
}

const saveGame = async () => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      id: gameForm.value.id || undefined,
      opponent: gameForm.value.opponent,
      location: gameForm.value.location,
      game_date: caracasInputToISO(gameForm.value.game_date),
      is_home: gameForm.value.is_home,
      status: gameForm.value.status,
      our_score: Number(gameForm.value.our_score),
      opponent_score: Number(gameForm.value.opponent_score)
    }

    const { error } = await supabase.rpc('admin_upsert_game', { p_game: payload })
    if (error) throw error

    successMessage.value = 'Partido guardado correctamente.'
    showEditorModal.value = false
    await loadGames()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const cancelGame = async (id: string) => {
  if (!confirm('¿Desea cancelar este partido?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.rpc('admin_delete_game', { p_game_id: id })
    if (error) throw error
    successMessage.value = 'Partido cancelado.'
    await loadGames()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadGames)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold font-title text-white">Calendario y Resultados de Partidos</h1>
            <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-950/80 text-emerald-400 border border-emerald-800">
              <i class="bi bi-link-45deg"></i> Sofascore ID: 248672
            </span>
          </div>
          <p class="text-sm text-slate-400 mt-1">Programación oficial, resultados de la Gran Final SPB y marcadores sincronizados desde Sofascore.</p>
        </div>
        <div class="flex items-center gap-3">
          <BaseButton variant="outline" :loading="syncLoading" @click="syncWithSofascore">
            <i class="bi bi-arrow-repeat mr-1.5" :class="{ 'animate-spin': syncLoading }"></i> Sincronizar con Sofascore
          </BaseButton>
          <BaseButton variant="primary" @click="openNewGame">
            <i class="bi bi-calendar-plus mr-1.5"></i> Programar Partido
          </BaseButton>
        </div>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(games as any[])" :loading="loading" empty-text="No hay partidos registrados">
        <template #cell-opponent="{ row }">
          <span class="font-bold text-slate-100">Guaiqueríes vs {{ (row as GameRow).opponent }}</span>
        </template>

        <template #cell-game_date="{ row }">
          <span class="text-xs text-slate-300">{{ (row as GameRow).game_date ? formatCaracas((row as GameRow).game_date) : '' }}</span>
        </template>

        <template #cell-is_home="{ row }">
          <span class="text-xs font-semibold px-2 py-0.5 rounded-full bg-slate-900 border border-slate-800 text-slate-300">
            {{ (row as GameRow).is_home ? 'Casa (La Asunción)' : 'Visitante' }}
          </span>
        </template>

        <template #cell-score="{ row }">
          <span class="font-mono text-sm font-bold text-emerald-400">
            {{ (row as GameRow).our_score }} - {{ (row as GameRow).opponent_score }}
          </span>
        </template>

        <template #cell-status="{ row }">
          <BaseBadge :variant="(row as GameRow).status === 'finished' ? 'success' : (row as GameRow).status === 'live' ? 'danger' : 'soft'">
            {{ (row as GameRow).status === 'finished' ? 'Finalizado' : (row as GameRow).status === 'live' ? 'EN VIVO' : (row as GameRow).status === 'scheduled' ? 'Programado' : 'Cancelado' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editGame(row as GameRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg" title="Editar / Marcador">
              <i class="bi bi-pencil"></i>
            </button>
            <button v-if="(row as GameRow).status !== 'cancelled'" @click="cancelGame((row as GameRow).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg" title="Cancelar Partido">
              <i class="bi bi-calendar-x"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Game Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Programación de Partido" @close="showEditorModal = false">
      <div class="space-y-4">
        <BaseInput label="Equipo Rival" v-model="gameForm.opponent" placeholder="Ej: Trotamundos de Carabobo" />
        <BaseInput label="Ubicación / Gimnasio" v-model="gameForm.location" />
        <BaseInput label="Fecha y Hora — Hora de Caracas (GMT-4)" type="datetime-local" v-model="gameForm.game_date" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseSelect
            label="Estado del Partido"
            v-model="gameForm.status"
            :options="[
              { value: 'scheduled', label: 'Programado' },
              { value: 'live', label: 'EN VIVO' },
              { value: 'finished', label: 'Finalizado' },
              { value: 'cancelled', label: 'Cancelado' }
            ]"
          />
          <div class="flex items-center pt-6">
            <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
              <input type="checkbox" v-model="gameForm.is_home" class="accent-emerald-500 rounded" />
              <span>Juego como Local (Casa)</span>
            </label>
          </div>
        </div>

        <div class="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
          <h4 class="text-xs font-bold uppercase text-slate-400">Marcador del Partido</h4>
          <div class="grid grid-cols-2 gap-4">
            <BaseInput label="Guaiqueríes Score" type="number" v-model="gameForm.our_score" />
            <BaseInput label="Rival Score" type="number" v-model="gameForm.opponent_score" />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveGame">Guardar Partido</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
