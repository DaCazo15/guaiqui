<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'
import BulkImportModal from '../components/common/BulkImportModal.vue'

interface GameRow {
  id: string
  opponent: string
  opponent_logo_url?: string | null
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
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const showBulkImportModal = ref(false)
const gameForm = ref({
  id: '',
  opponent: '',
  opponent_logo_url: '',
  location: 'Gimnasio Ciudad de La Asunción',
  game_date: '',
  is_home: true,
  status: 'scheduled' as 'scheduled' | 'live' | 'finished' | 'cancelled',
  our_score: 0,
  opponent_score: 0,
})

const columns = [
  { key: 'opponent', label: 'Rival' },
  { key: 'game_date', label: 'Fecha del Partido' },
  { key: 'is_home', label: 'Sede' },
  { key: 'score', label: 'Marcador', align: 'center' as const },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadGames = async () => {
  loading.value = true
  errorMessage.value = null
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

const openNewGame = () => {
  gameForm.value = {
    id: '',
    opponent: '',
    opponent_logo_url: '',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: nowCaracasInput(),
    is_home: true,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0,
  }
  showEditorModal.value = true
}

const editGame = (g: GameRow) => {
  gameForm.value = {
    id: g.id,
    opponent: g.opponent,
    opponent_logo_url: g.opponent_logo_url || '',
    location: g.location,
    game_date: g.game_date ? isoToCaracasInput(g.game_date) : '',
    is_home: g.is_home,
    status: g.status,
    our_score: g.our_score || 0,
    opponent_score: g.opponent_score || 0,
  }
  showEditorModal.value = true
}

const saveGame = async () => {
  if (!gameForm.value.opponent.trim()) {
    errorMessage.value = 'El nombre del rival es obligatorio.'
    return
  }
  if (!gameForm.value.game_date) {
    errorMessage.value = 'La fecha y hora del partido es obligatoria.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      opponent: gameForm.value.opponent.trim(),
      opponent_logo_url: gameForm.value.opponent_logo_url.trim() || null,
      location: gameForm.value.location.trim() || 'Gimnasio Ciudad de La Asunción',
      game_date: caracasInputToISO(gameForm.value.game_date),
      is_home: Boolean(gameForm.value.is_home),
      status: gameForm.value.status,
      our_score: Number(gameForm.value.our_score) || 0,
      opponent_score: Number(gameForm.value.opponent_score) || 0,
    }

    if (gameForm.value.id) {
      const { error } = await supabase
        .from('games')
        .update(payload)
        .eq('id', gameForm.value.id)
      if (error) throw error
      successMessage.value = 'Partido actualizado correctamente.'
    } else {
      const { error } = await supabase
        .from('games')
        .insert(payload)
      if (error) throw error
      successMessage.value = 'Partido programado exitosamente en el calendario.'
    }

    showEditorModal.value = false
    await loadGames()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const cancelGame = async (id: string) => {
  if (!confirm('¿Desea marcar este partido como cancelado?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('games')
      .update({ status: 'cancelled' })
      .eq('id', id)
    if (error) throw error
    successMessage.value = 'Partido marcado como cancelado.'
    await loadGames()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteGame = async (g: GameRow) => {
  if (!confirm(`¿Desea eliminar permanentemente el partido contra ${g.opponent}? Esta acción no se puede deshacer.`)) {
    return
  }
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('games')
      .delete()
      .eq('id', g.id)
    if (error) throw error
    successMessage.value = 'Partido eliminado definitivamente de la base de datos.'
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
          <h1 class="text-2xl font-bold font-title text-white">Calendario Oficial de Partidos</h1>
          <p class="text-sm text-slate-400 mt-1">
            Programación de encuentros del club, asignación de sedes y carga de resultados oficiales.
          </p>
        </div>
        <div class="flex items-center gap-3 flex-wrap">
          <BaseButton variant="secondary" @click="showBulkImportModal = true">
            <i class="bi bi-file-earmark-spreadsheet text-emerald-400 mr-1.5"></i> Carga Masiva (Excel / CSV)
          </BaseButton>
          <BaseButton variant="primary" @click="openNewGame">
            <i class="bi bi-calendar-plus mr-1.5"></i> Programar Partido
          </BaseButton>
        </div>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <BaseTable
        :columns="columns"
        :data="(games as any[])"
        :loading="loading"
        empty-text="No hay partidos registrados en el calendario. Haz clic en 'Programar Partido' para registrar el primero."
      >
        <template #cell-opponent="{ row }">
          <div class="flex items-center gap-3 py-1">
            <div class="relative w-10 h-10 rounded-xl bg-slate-900 border border-slate-700/80 p-1 flex items-center justify-center shrink-0 overflow-hidden shadow-inner">
              <img
                v-if="(row as GameRow).opponent_logo_url"
                :src="(row as GameRow).opponent_logo_url!"
                :alt="(row as GameRow).opponent"
                class="w-full h-full object-contain"
                loading="lazy"
              />
              <div
                v-else
                class="w-full h-full rounded-lg bg-emerald-950/60 border border-emerald-800/40 flex items-center justify-center text-emerald-400 font-display font-black text-xs"
              >
                <i class="bi bi-shield-shaded text-sm"></i>
              </div>
            </div>
            <div class="flex flex-col min-w-0">
              <div class="flex items-center gap-1.5 flex-wrap">
                <span class="text-xs font-semibold text-emerald-400">Guaiqueríes</span>
                <span class="text-[11px] text-slate-500 font-bold">vs</span>
                <span class="font-bold text-white tracking-tight">{{ (row as GameRow).opponent }}</span>
              </div>
              <span class="text-[11px] text-slate-400 truncate flex items-center gap-1 mt-0.5">
                <i class="bi bi-geo-alt text-[10px] text-slate-500"></i>
                {{ (row as GameRow).location }}
              </span>
            </div>
          </div>
        </template>

        <template #cell-game_date="{ row }">
          <span class="text-xs text-slate-300">{{ (row as GameRow).game_date ? formatCaracas((row as GameRow).game_date) : '' }}</span>
        </template>

        <template #cell-is_home="{ row }">
          <span class="text-xs font-semibold px-2 py-0.5 rounded-full bg-slate-800 border border-slate-700 text-slate-300">
            {{ (row as GameRow).is_home ? 'Casa (La Asunción)' : 'Visitante' }}
          </span>
        </template>

        <template #cell-score="{ row }">
          <span v-if="(row as GameRow).status === 'scheduled'" class="text-xs text-slate-500 font-mono italic">
            Por disputar
          </span>
          <span v-else class="font-mono text-sm font-bold text-emerald-400">
            {{ (row as GameRow).our_score }} - {{ (row as GameRow).opponent_score }}
          </span>
        </template>

        <template #cell-status="{ row }">
          <BaseBadge :variant="(row as GameRow).status === 'finished' ? 'success' : (row as GameRow).status === 'live' ? 'danger' : (row as GameRow).status === 'scheduled' ? 'accent' : 'soft'">
            {{ (row as GameRow).status === 'finished' ? 'Finalizado' : (row as GameRow).status === 'live' ? 'EN VIVO' : (row as GameRow).status === 'scheduled' ? 'Programado' : 'Cancelado' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button
              @click="editGame(row as GameRow)"
              class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
              title="Editar / Actualizar Marcador"
            >
              <i class="bi bi-pencil"></i>
            </button>
            <button
              v-if="(row as GameRow).status !== 'cancelled'"
              @click="cancelGame((row as GameRow).id)"
              class="p-1.5 text-amber-400 hover:bg-amber-950/60 rounded-lg transition-colors"
              title="Cancelar Partido"
            >
              <i class="bi bi-calendar-x"></i>
            </button>
            <button
              @click="deleteGame(row as GameRow)"
              class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors"
              title="Eliminar permanentemente"
            >
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Game Editor -->
    <BaseModal
      v-if="showEditorModal"
      :is-open="showEditorModal"
      :title="gameForm.id ? 'Editar Partido / Cargar Marcador' : 'Programar Partido en Calendario'"
      @close="showEditorModal = false"
    >
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
          <div class="sm:col-span-2">
            <BaseInput label="Equipo Rival" v-model="gameForm.opponent" placeholder="Ej: Trotamundos de Carabobo" />
          </div>
          <div>
            <label class="block text-xs font-semibold text-slate-300 mb-1">Logo del Rival</label>
            <div class="h-10 px-3 rounded-xl bg-slate-950 border border-slate-800 flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-slate-900 border border-slate-700 p-0.5 flex items-center justify-center shrink-0 overflow-hidden">
                <img
                  v-if="gameForm.opponent_logo_url?.trim()"
                  :src="gameForm.opponent_logo_url.trim()"
                  :alt="gameForm.opponent || 'Logo Rival'"
                  class="w-full h-full object-contain"
                />
                <i v-else class="bi bi-shield-shaded text-slate-500 text-xs"></i>
              </div>
              <span class="text-[11px] text-slate-400 truncate">
                {{ gameForm.opponent_logo_url?.trim() ? 'Logo asignado' : 'Sin logo' }}
              </span>
            </div>
          </div>
        </div>

        <BaseInput
          label="URL del Logo del Rival (Opcional)"
          v-model="gameForm.opponent_logo_url"
          placeholder="https://ejemplo.com/logos/rival.png"
          hint="Enlace web directo en formato PNG, SVG o WEBP para mostrar el escudo del equipo rival."
        />

        <BaseInput label="Ubicación / Gimnasio" v-model="gameForm.location" placeholder="Ej: Gimnasio Ciudad de La Asunción" />
        <BaseInput label="Fecha y Hora — Hora de Caracas (GMT-4)" type="datetime-local" v-model="gameForm.game_date" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseSelect
            label="Estado del Partido"
            v-model="gameForm.status"
            :options="[
              { value: 'scheduled', label: 'Programado (Por disputar)' },
              { value: 'live', label: 'EN VIVO' },
              { value: 'finished', label: 'Finalizado' },
              { value: 'cancelled', label: 'Cancelado' }
            ]"
          />
          <div class="flex items-center pt-6">
            <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
              <input type="checkbox" v-model="gameForm.is_home" class="accent-emerald-600 rounded" />
              <span>Juego como Local (Casa)</span>
            </label>
          </div>
        </div>

        <!-- Marcador: solo visible al editar un partido o cuando está en vivo o finalizado -->
        <div
          v-if="gameForm.id || gameForm.status === 'live' || gameForm.status === 'finished'"
          class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-3"
        >
          <div class="flex items-center justify-between">
            <h4 class="text-xs font-bold uppercase text-slate-300">Marcador del Partido</h4>
            <span class="text-[11px] text-slate-400">Actualiza los puntos oficiales</span>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <BaseInput label="Puntos Guaiqueríes" type="number" v-model="gameForm.our_score" />
            <BaseInput label="Puntos Rival" type="number" v-model="gameForm.opponent_score" />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveGame">
            <i class="bi bi-check2 mr-1.5"></i>
            {{ gameForm.id ? 'Guardar Cambios' : 'Programar Partido' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      :is-open="showBulkImportModal"
      type="games"
      @close="showBulkImportModal = false"
      @success="loadGames"
    />
  </AdminLayout>
</template>
