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

interface WhoIsRow {
  id: string
  player_id: string
  challenge_type: 'silhouette' | 'dorsal'
  title: string
  clue?: string | null
  custom_image_url?: string | null
  dorsal_number?: number | null
  reward_pearls: number
  status: 'draft' | 'published' | 'archived'
  starts_at: string
  ends_at: string
  created_at: string
  player?: PlayerItem | null
}

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
const previewRevealed = ref(false)

// Form state
const challengeForm = ref({
  id: '',
  player_id: '',
  challenge_type: 'silhouette' as 'silhouette' | 'dorsal',
  title: '¿Quién es este jugador de la Tribu?',
  clue: '',
  custom_image_url: '',
  dorsal_number: null as number | null,
  reward_pearls: 50,
  status: 'published' as 'draft' | 'published' | 'archived',
  starts_at: '',
  ends_at: ''
})

const columns = [
  { key: 'challenge', label: 'Reto & Jugador' },
  { key: 'type', label: 'Modo', align: 'center' as const },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'dates', label: 'Vigencia' },
  { key: 'rewards', label: 'Recompensa', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const selectedPlayer = computed(() => {
  return rosterPlayers.value.find(p => p.id === challengeForm.value.player_id) || null
})

const previewImageUrl = computed(() => {
  if (challengeForm.value.custom_image_url?.trim()) {
    return challengeForm.value.custom_image_url.trim()
  }
  return selectedPlayer.value?.photo_url || ''
})

const effectiveDorsal = computed(() => {
  if (challengeForm.value.dorsal_number !== null && challengeForm.value.dorsal_number !== undefined) {
    return challengeForm.value.dorsal_number
  }
  return selectedPlayer.value?.jersey_number ?? 0
})

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    // 1. Cargar jugadores activos para el selector
    const { data: pData, error: pErr } = await supabase
      .from('players')
      .select('id, name, jersey_number, photo_url, position')
      .order('jersey_number', { ascending: true })

    if (pErr) throw pErr
    rosterPlayers.value = pData || []

    // 2. Cargar retos
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
  previewRevealed.value = false

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
  previewRevealed.value = false

  challengeForm.value = {
    id: c.id,
    player_id: c.player_id,
    challenge_type: c.challenge_type,
    title: c.title,
    clue: c.clue || '',
    custom_image_url: c.custom_image_url || '',
    dorsal_number: c.dorsal_number ?? null,
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
  if (!challengeForm.value.title.trim()) {
    errorMessage.value = 'El título del reto es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      id: challengeForm.value.id || undefined,
      player_id: challengeForm.value.player_id,
      challenge_type: challengeForm.value.challenge_type,
      title: challengeForm.value.title.trim(),
      clue: challengeForm.value.clue.trim() || null,
      custom_image_url: challengeForm.value.custom_image_url.trim() || null,
      dorsal_number: challengeForm.value.dorsal_number ?? selectedPlayer.value?.jersey_number ?? 0,
      reward_pearls: Number(challengeForm.value.reward_pearls) || 50,
      status: challengeForm.value.status,
      starts_at: caracasInputToISO(challengeForm.value.starts_at),
      ends_at: caracasInputToISO(challengeForm.value.ends_at)
    }

    const { error } = await supabase.rpc('admin_upsert_guess_player_challenge', { p_challenge: payload })
    if (error) throw error

    successMessage.value = challengeForm.value.id
      ? 'Reto "¿Quién es?" actualizado exitosamente.'
      : 'Nuevo reto "¿Quién es?" programado exitosamente.'

    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message
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
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_delete_guess_player_challenge', { p_id: selectedChallenge.value.id })
    if (error) throw error

    successMessage.value = 'Reto eliminado permanentemente.'
    showDeleteModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadData)
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-person-bounding-box text-emerald-400"></i>
          Retos Interactivos: «¿Quién es?»
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Mecánica de adivinanza por silueta o dorsal inspirada en Pokémon. Los fanáticos votan un jugador de la plantilla con conteo regresivo de 5s.
        </p>
      </div>
      <div class="flex items-center gap-2 flex-wrap">
        <BaseButton variant="secondary" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet text-emerald-400 mr-1.5"></i> Carga Masiva (Excel / CSV)
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openNewChallenge">
          <i class="bi bi-plus-lg mr-1.5"></i> Programar Reto
        </BaseButton>
      </div>
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

    <!-- Challenges Table -->
    <BaseTable :columns="columns" :data="(challenges as any[])" :loading="loading" empty-text="No hay retos de '¿Quién es?' programados. Haz clic en 'Programar Reto' para registrar el primero.">
      <template #cell-challenge="{ row }">
        <div class="flex items-center gap-3 py-1">
          <div class="relative w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border border-emerald-500/30 p-1 flex items-center justify-center shrink-0 overflow-hidden shadow-inner">
            <template v-if="(row as WhoIsRow).challenge_type === 'dorsal'">
              <div class="flex flex-col items-center justify-center font-display font-black text-emerald-400 text-base leading-none">
                <span class="text-[9px] text-emerald-200 font-bold uppercase">DORSAL</span>
                #{{ (row as WhoIsRow).dorsal_number ?? (row as WhoIsRow).player?.jersey_number }}
              </div>
            </template>
            <template v-else>
              <img
                v-if="(row as WhoIsRow).custom_image_url || (row as WhoIsRow).player?.photo_url"
                :src="(row as WhoIsRow).custom_image_url || (row as WhoIsRow).player?.photo_url!"
                :alt="(row as WhoIsRow).title"
                class="w-full h-full object-contain filter brightness-0 contrast-200"
              />
              <i v-else class="bi bi-person-fill text-emerald-400 text-2xl"></i>
            </template>
          </div>
          <div class="flex flex-col min-w-0">
            <span class="font-bold text-white tracking-tight truncate">{{ (row as WhoIsRow).title }}</span>
            <span class="text-xs text-slate-400 flex items-center gap-1.5 mt-0.5">
              <span class="text-emerald-400 font-semibold">Jugador Real:</span>
              {{ (row as WhoIsRow).player?.name || 'No asignado' }} (Dorsal #{{ (row as WhoIsRow).player?.jersey_number }})
            </span>
            <span v-if="(row as WhoIsRow).clue" class="text-[11px] text-slate-500 italic truncate mt-0.5">
              Pista: "{{ (row as WhoIsRow).clue }}"
            </span>
          </div>
        </div>
      </template>

      <template #cell-type="{ row }">
        <span
          class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider"
          :class="(row as WhoIsRow).challenge_type === 'silhouette'
            ? 'bg-purple-950/60 text-purple-300 border border-purple-800'
            : 'bg-emerald-950/60 text-emerald-300 border border-emerald-800'"
        >
          <i :class="['bi', (row as WhoIsRow).challenge_type === 'silhouette' ? 'bi-incognito' : 'bi-123']"></i>
          {{ (row as WhoIsRow).challenge_type === 'silhouette' ? 'Silueta' : 'Dorsal' }}
        </span>
      </template>

      <template #cell-status="{ row }">
        <BaseBadge :variant="(row as WhoIsRow).status === 'published' ? 'success' : (row as WhoIsRow).status === 'draft' ? 'warning' : 'soft'">
          {{ (row as WhoIsRow).status === 'published' ? 'Publicado' : (row as WhoIsRow).status === 'draft' ? 'Borrador' : 'Archivado' }}
        </BaseBadge>
      </template>

      <template #cell-dates="{ row }">
        <div class="flex flex-col text-xs text-slate-400">
          <span><span class="text-slate-500">Inicio:</span> {{ (row as WhoIsRow).starts_at ? formatCaracas((row as WhoIsRow).starts_at) : '' }}</span>
          <span><span class="text-slate-500">Cierre:</span> {{ (row as WhoIsRow).ends_at ? formatCaracas((row as WhoIsRow).ends_at) : '' }}</span>
        </div>
      </template>

      <template #cell-rewards="{ row }">
        <span class="text-xs font-mono font-bold text-emerald-400 bg-emerald-950/40 px-2 py-1 rounded-md border border-emerald-800/40">
          +{{ (row as WhoIsRow).reward_pearls }} perlitas
        </span>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editChallenge(row as WhoIsRow)" class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar Reto">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="confirmDeleteChallenge(row as WhoIsRow)" class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors" title="Eliminar Reto">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Editor Modal -->
    <BaseModal
      v-if="showEditorModal"
      :is-open="showEditorModal"
      :title="challengeForm.id ? 'Editar Reto «¿Quién es?»' : 'Programar Reto «¿Quién es?»'"
      @close="showEditorModal = false"
      size="xl"
    >
      <div class="space-y-6">
        <!-- Live Dark Green Gradient Preview as requested -->
        <div class="p-5 rounded-2xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border border-emerald-500/40 text-white relative shadow-2xl overflow-hidden">
          <div class="flex items-center justify-between border-b border-emerald-500/20 pb-3 mb-4">
            <div class="flex items-center gap-2">
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
              <span class="text-xs font-mono font-bold uppercase tracking-wider text-emerald-300">
                Vista Previa del Fanático (Fondo Verde Gradiente Oscuro)
              </span>
            </div>
            <BaseButton size="sm" variant="secondary" @click="previewRevealed = !previewRevealed">
              <i :class="['bi', previewRevealed ? 'bi-eye-slash' : 'bi-eye', 'mr-1 text-emerald-400']"></i>
              {{ previewRevealed ? 'Ocultar (Silueta)' : 'Revelar Solución' }}
            </BaseButton>
          </div>

          <div class="flex flex-col sm:flex-row items-center justify-center gap-6 py-2">
            <!-- Visual display box -->
            <div class="relative w-36 h-36 rounded-2xl bg-slate-950/80 border-2 border-emerald-400/40 p-2 shadow-2xl flex items-center justify-center overflow-hidden">
              <template v-if="challengeForm.challenge_type === 'dorsal'">
                <div class="flex flex-col items-center justify-center text-center">
                  <div class="w-14 h-14 rounded-full bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-400 mb-1">
                    <i class="bi bi-shield-shaded text-2xl"></i>
                  </div>
                  <span class="font-display font-black text-4xl text-emerald-400 tracking-wider">
                    #{{ effectiveDorsal }}
                  </span>
                  <span class="text-[10px] text-emerald-200 font-bold uppercase">Dorsal Tribu</span>
                </div>
              </template>
              <template v-else>
                <img
                  v-if="previewImageUrl"
                  :src="previewImageUrl"
                  :alt="challengeForm.title"
                  class="w-full h-full object-contain transition-all duration-300"
                  :class="previewRevealed ? 'filter-none scale-105' : 'filter brightness-0 contrast-200'"
                />
                <div v-else class="text-center text-xs text-slate-400">
                  <i class="bi bi-image text-3xl text-emerald-400 block mb-1"></i>
                  Sin foto asignada
                </div>
              </template>

              <!-- Secret reveal badge in admin preview -->
              <span v-if="previewRevealed" class="absolute top-1 right-1 px-1.5 py-0.5 rounded bg-emerald-500 text-slate-950 text-[9px] font-bold uppercase">
                Descubierto
              </span>
            </div>

            <!-- Preview Challenge Text Info -->
            <div class="space-y-2 text-center sm:text-left max-w-sm">
              <span class="px-2.5 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-400/30 text-[10px] font-bold uppercase tracking-wider text-emerald-300 inline-block">
                {{ challengeForm.challenge_type === 'silhouette' ? 'Adivina por Silueta' : 'Adivina por Dorsal' }}
              </span>
              <h4 class="font-display font-black text-xl text-white uppercase tracking-tight">
                {{ challengeForm.title || '¿Quién es este jugador de la Tribu?' }}
              </h4>
              <p v-if="challengeForm.clue" class="text-xs text-slate-300 italic">
                <i class="bi bi-lightbulb-fill text-amber-300 mr-1"></i>
                Pista: "{{ challengeForm.clue }}"
              </p>
              <div class="text-xs text-emerald-400 font-mono font-bold">
                Recompensa: +{{ challengeForm.reward_pearls }} perlitas
              </div>
              <div v-if="selectedPlayer" class="text-[11px] text-slate-400 pt-1 border-t border-emerald-500/20">
                Solución asignada: <strong class="text-white">{{ selectedPlayer.name }}</strong> (#{{ selectedPlayer.jersey_number }})
              </div>
            </div>
          </div>
        </div>

        <!-- Form Fields -->
        <div class="space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                Modo del Reto <span class="text-emerald-400">*</span>
              </label>
              <select
                v-model="challengeForm.challenge_type"
                class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-2.5 text-sm focus:outline-none focus:border-emerald-500"
              >
                <option value="silhouette">Adivinar por Silueta / Imagen del Jugador</option>
                <option value="dorsal">Adivinar por Dorsal / Número de Camiseta</option>
              </select>
            </div>

            <div>
              <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                Jugador Real de la Plantilla <span class="text-emerald-400">*</span>
              </label>
              <select
                v-model="challengeForm.player_id"
                class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-2.5 text-sm focus:outline-none focus:border-emerald-500"
              >
                <option value="" disabled>Seleccione un jugador</option>
                <option v-for="p in rosterPlayers" :key="p.id" :value="p.id">
                  #{{ p.jersey_number }} — {{ p.name }} ({{ p.position || 'Jugador' }})
                </option>
              </select>
            </div>
          </div>

          <BaseInput
            label="Título del Reto"
            v-model="challengeForm.title"
            placeholder="Ej: ¿Quién es este jugador de la Tribu?"
          />

          <BaseInput
            label="Pista Opcional para los Fanáticos"
            v-model="challengeForm.clue"
            placeholder="Ej: Posición: Alero, máximo anotador en la temporada 2026."
            hint="Aparecerá en pantalla para orientar a los fanáticos sin regalar la respuesta."
          />

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <BaseInput
              label="Perlitas de Recompensa"
              type="number"
              v-model="challengeForm.reward_pearls"
              placeholder="50"
            />

            <BaseInput
              v-if="challengeForm.challenge_type === 'dorsal'"
              label="Número Dorsal en Pantalla"
              type="number"
              v-model="challengeForm.dorsal_number"
              :placeholder="String(selectedPlayer?.jersey_number ?? 10)"
              hint="Por defecto toma el dorsal oficial del jugador."
            />

            <BaseInput
              v-else
              label="URL Imagen Personalizada (Opcional)"
              v-model="challengeForm.custom_image_url"
              placeholder="https://ejemplo.com/silueta.png"
              hint="Si se deja vacío, se usa la foto oficial del jugador."
            />

            <BaseSelect
              label="Estado del Reto"
              v-model="challengeForm.status"
              :options="[
                { value: 'published', label: 'Publicado (Activo para fanáticos)' },
                { value: 'draft', label: 'Borrador (Oculto)' },
                { value: 'archived', label: 'Archivado' }
              ]"
            />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <BaseInput
              label="Fecha y Hora de Inicio — Hora Caracas (GMT-4)"
              type="datetime-local"
              v-model="challengeForm.starts_at"
            />
            <BaseInput
              label="Fecha y Hora de Cierre — Hora Caracas (GMT-4)"
              type="datetime-local"
              v-model="challengeForm.ends_at"
            />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveChallenge">
            <i class="bi bi-check2 mr-1.5"></i>
            {{ challengeForm.id ? 'Guardar Cambios' : 'Programar Reto' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>

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
