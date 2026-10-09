<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface PlayerRow {
  id: string
  name: string
  jersey_number: number
  position: string
  height?: string
  age?: number
  nationality: string
  bio?: string
  is_active: boolean
  is_star: boolean
}

const players = ref<PlayerRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const playerForm = ref({
  id: '',
  name: '',
  jersey_number: 10,
  position: 'Base',
  height: '1.85m',
  age: 25,
  nationality: 'Venezuela',
  bio: '',
  is_active: true,
  is_star: false
})

const columns = [
  { key: 'jersey_number', label: '#', align: 'center' as const, width: '60px' },
  { key: 'name', label: 'Jugador' },
  { key: 'position', label: 'Posición' },
  { key: 'is_star', label: 'Estrella', align: 'center' as const },
  { key: 'is_active', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadPlayers = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('players')
      .select('*')
      .order('jersey_number', { ascending: true })

    if (error) throw error
    players.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewPlayer = () => {
  playerForm.value = {
    id: '',
    name: '',
    jersey_number: 1,
    position: 'Base',
    height: '1.90m',
    age: 24,
    nationality: 'Venezuela',
    bio: '',
    is_active: true,
    is_star: false
  }
  showEditorModal.value = true
}

const editPlayer = (p: PlayerRow) => {
  playerForm.value = {
    id: p.id,
    name: p.name,
    jersey_number: p.jersey_number,
    position: p.position,
    height: p.height || '',
    age: p.age || 20,
    nationality: p.nationality || 'Venezuela',
    bio: p.bio || '',
    is_active: p.is_active,
    is_star: p.is_star
  }
  showEditorModal.value = true
}

const savePlayer = async () => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      id: playerForm.value.id || undefined,
      name: playerForm.value.name,
      jersey_number: Number(playerForm.value.jersey_number),
      position: playerForm.value.position,
      height: playerForm.value.height,
      age: Number(playerForm.value.age),
      nationality: playerForm.value.nationality,
      bio: playerForm.value.bio,
      is_active: playerForm.value.is_active,
      is_star: playerForm.value.is_star
    }

    const { error } = await supabase.rpc('admin_upsert_player', { p_player: payload })
    if (error) throw error

    successMessage.value = 'Jugador guardado correctamente.'
    showEditorModal.value = false
    await loadPlayers()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deactivatePlayer = async (id: string) => {
  if (!confirm('¿Desea desactivar a este jugador de la plantilla activa?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.rpc('admin_delete_player', { p_player_id: id })
    if (error) throw error
    successMessage.value = 'Jugador desactivado.'
    await loadPlayers()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadPlayers)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Plantilla de Jugadores</h1>
          <p class="text-sm text-slate-400">Gestión de la plantilla oficial de Guaiqueríes de Margarita.</p>
        </div>
        <BaseButton variant="primary" @click="openNewPlayer">
          <i class="bi bi-person-plus mr-1.5"></i> Agregar Jugador
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(players as any[])" :loading="loading" empty-text="No hay jugadores registrados">
        <template #cell-jersey_number="{ row }">
          <span class="font-bold font-mono text-emerald-400">#{{ (row as PlayerRow).jersey_number }}</span>
        </template>

        <template #cell-is_star="{ row }">
          <span v-if="(row as PlayerRow).is_star" class="text-amber-400 font-semibold text-xs flex items-center justify-center gap-1">
            <i class="bi bi-star-fill text-xs"></i> Estrella
          </span>
          <span v-else class="text-slate-500 text-xs">-</span>
        </template>

        <template #cell-is_active="{ row }">
          <BaseBadge :variant="(row as PlayerRow).is_active ? 'success' : 'soft'">
            {{ (row as PlayerRow).is_active ? 'Activo' : 'Inactivo' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editPlayer(row as PlayerRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button v-if="(row as PlayerRow).is_active" @click="deactivatePlayer((row as PlayerRow).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg" title="Desactivar">
              <i class="bi bi-person-x"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Player Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Ficha de Jugador" @close="showEditorModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Nombre del Jugador" v-model="playerForm.name" />
          <BaseInput label="Número de Camiseta (#)" type="number" v-model="playerForm.jersey_number" />
          <BaseInput label="Posición" v-model="playerForm.position" placeholder="Base, Escolta, Alero, Ala-Pívot, Pívot" />
          <BaseInput label="Estatura" v-model="playerForm.height" placeholder="1.95m" />
          <BaseInput label="Edad" type="number" v-model="playerForm.age" />
          <BaseInput label="Nacionalidad" v-model="playerForm.nationality" />
        </div>
        <BaseInput label="Biografía / Notas" v-model="playerForm.bio" placeholder="Trayectoria o méritos" />
        
        <div class="flex items-center gap-6 border-t border-slate-800 pt-3">
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
            <input type="checkbox" v-model="playerForm.is_active" class="accent-emerald-500 rounded" />
            <span>Activo en Plantilla</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-amber-300 cursor-pointer">
            <input type="checkbox" v-model="playerForm.is_star" class="accent-amber-500 rounded" />
            <span>Jugador Estrella</span>
          </label>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="savePlayer">Guardar Jugador</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
