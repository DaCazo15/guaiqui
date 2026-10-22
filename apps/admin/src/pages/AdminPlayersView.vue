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
  height?: string | null
  age?: number | null
  nationality: string
  bio?: string | null
  is_active: boolean
  is_star: boolean
  instagram_url?: string | null
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
  jersey_number: 1,
  position: 'Base',
  height: '1.85m',
  age: 24,
  nationality: 'Venezuela',
  bio: '',
  is_active: true,
  is_star: false,
  instagram_url: '',
})

const columns = [
  { key: 'jersey_number', label: '#', align: 'center' as const, width: '60px' },
  { key: 'name', label: 'Jugador' },
  { key: 'position', label: 'Posición' },
  { key: 'is_star', label: 'Estrella', align: 'center' as const },
  { key: 'is_active', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadPlayers = async () => {
  loading.value = true
  errorMessage.value = null
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
    is_star: false,
    instagram_url: '',
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
    is_star: p.is_star,
    instagram_url: p.instagram_url || '',
  }
  showEditorModal.value = true
}

const savePlayer = async () => {
  if (!playerForm.value.name.trim()) {
    errorMessage.value = 'El nombre del jugador es obligatorio.'
    return
  }
  if (!playerForm.value.jersey_number && playerForm.value.jersey_number !== 0) {
    errorMessage.value = 'El número de camiseta es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const rawIg = playerForm.value.instagram_url?.trim() || null
    const formattedIg = rawIg && !rawIg.startsWith('http') && !rawIg.includes('/')
      ? `https://instagram.com/${rawIg.replace(/^@/, '')}`
      : rawIg

    const payload = {
      name: playerForm.value.name.trim(),
      jersey_number: Number(playerForm.value.jersey_number),
      position: playerForm.value.position.trim(),
      height: playerForm.value.height?.trim() || null,
      age: playerForm.value.age ? Number(playerForm.value.age) : null,
      nationality: playerForm.value.nationality?.trim() || 'Venezuela',
      bio: playerForm.value.bio?.trim() || null,
      is_active: Boolean(playerForm.value.is_active),
      is_star: Boolean(playerForm.value.is_star),
      instagram_url: formattedIg,
    }

    if (playerForm.value.id) {
      const { error } = await supabase
        .from('players')
        .update(payload)
        .eq('id', playerForm.value.id)
      if (error) throw error
      successMessage.value = 'Jugador actualizado correctamente.'
    } else {
      const { error } = await supabase
        .from('players')
        .insert(payload)
      if (error) throw error
      successMessage.value = 'Jugador agregado exitosamente a la plantilla.'
    }

    showEditorModal.value = false
    await loadPlayers()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const togglePlayerStatus = async (p: PlayerRow) => {
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('players')
      .update({ is_active: !p.is_active })
      .eq('id', p.id)
    if (error) throw error
    successMessage.value = p.is_active ? 'Jugador marcado como inactivo.' : 'Jugador activado en la plantilla.'
    await loadPlayers()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deletePlayer = async (p: PlayerRow) => {
  if (!confirm(`¿Desea eliminar de forma permanente al jugador ${p.name} (#${p.jersey_number})? Esta acción no se puede deshacer.`)) {
    return
  }
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('players')
      .delete()
      .eq('id', p.id)
    if (error) throw error
    successMessage.value = 'Jugador eliminado definitivamente de la base de datos.'
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
          <h1 class="text-2xl font-bold font-title text-slate-900">Plantilla de Jugadores</h1>
          <p class="text-sm text-slate-600 mt-1">
            Gestión exclusiva y manual de los jugadores oficiales de Guaiqueríes de Margarita.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <BaseButton variant="primary" @click="openNewPlayer">
            <i class="bi bi-person-plus mr-1.5"></i> Agregar Jugador
          </BaseButton>
        </div>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-50 border border-red-200 text-red-700 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-500 hover:text-red-700">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-600 hover:text-emerald-800">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <BaseTable
        :columns="columns"
        :data="(players as any[])"
        :loading="loading"
        empty-text="No hay jugadores registrados. Haz clic en 'Agregar Jugador' para registrar al primero."
      >
        <template #cell-jersey_number="{ row }">
          <span class="font-bold font-mono text-guaiqui-primary">#{{ (row as PlayerRow).jersey_number }}</span>
        </template>

        <template #cell-name="{ row }">
          <div class="flex items-center gap-2">
            <span class="font-bold text-slate-900">{{ (row as PlayerRow).name }}</span>
            <a
              v-if="(row as PlayerRow).instagram_url"
              :href="(row as PlayerRow).instagram_url!"
              target="_blank"
              rel="noopener noreferrer"
              class="text-pink-600 hover:text-pink-700 text-sm"
              title="Ver Instagram"
            >
              <i class="bi bi-instagram"></i>
            </a>
          </div>
        </template>

        <template #cell-is_star="{ row }">
          <span v-if="(row as PlayerRow).is_star" class="text-amber-500 font-semibold text-xs flex items-center justify-center gap-1">
            <i class="bi bi-star-fill text-xs"></i> Estrella
          </span>
          <span v-else class="text-slate-400 text-xs">-</span>
        </template>

        <template #cell-is_active="{ row }">
          <BaseBadge :variant="(row as PlayerRow).is_active ? 'success' : 'soft'">
            {{ (row as PlayerRow).is_active ? 'Activo' : 'Inactivo' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button
              @click="editPlayer(row as PlayerRow)"
              class="p-1.5 text-slate-600 hover:bg-slate-100 rounded-lg transition-colors"
              title="Editar"
            >
              <i class="bi bi-pencil"></i>
            </button>
            <button
              @click="togglePlayerStatus(row as PlayerRow)"
              class="p-1.5 rounded-lg transition-colors"
              :class="(row as PlayerRow).is_active ? 'text-amber-600 hover:bg-amber-50' : 'text-emerald-600 hover:bg-emerald-50'"
              :title="(row as PlayerRow).is_active ? 'Desactivar de la plantilla' : 'Activar en la plantilla'"
            >
              <i :class="(row as PlayerRow).is_active ? 'bi bi-person-dash' : 'bi bi-person-check'"></i>
            </button>
            <button
              @click="deletePlayer(row as PlayerRow)"
              class="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
              title="Eliminar permanentemente"
            >
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Player Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" :title="playerForm.id ? 'Editar Jugador' : 'Nuevo Jugador'" @close="showEditorModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Nombre del Jugador" v-model="playerForm.name" placeholder="Ej: Heissler Guillent" />
          <BaseInput label="Número de Camiseta (#)" type="number" v-model="playerForm.jersey_number" placeholder="Ej: 10" />
          <BaseInput label="Posición" v-model="playerForm.position" placeholder="Ej: Base (PG), Escolta (SG)" />
          <BaseInput label="Estatura" v-model="playerForm.height" placeholder="Ej: 1.86 m" />
          <BaseInput label="Edad" type="number" v-model="playerForm.age" placeholder="Ej: 28" />
          <BaseInput label="Nacionalidad" v-model="playerForm.nationality" placeholder="Ej: Venezuela" />
        </div>
        <BaseInput label="Biografía / Notas" v-model="playerForm.bio" placeholder="Trayectoria o méritos del jugador" />
        <BaseInput label="Perfil de Instagram (URL o @usuario)" v-model="playerForm.instagram_url" placeholder="https://instagram.com/nombre o @nombre" />

        <div class="flex items-center gap-6 border-t border-slate-200 pt-3">
          <label class="flex items-center gap-2 text-sm text-slate-700 cursor-pointer">
            <input type="checkbox" v-model="playerForm.is_active" class="accent-emerald-600 rounded" />
            <span>Activo en Plantilla</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-amber-700 cursor-pointer">
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
