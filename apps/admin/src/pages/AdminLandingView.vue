<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseInput, BaseCard, BaseBadge, BaseTable, BaseModal } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface LandingSettings {
  id: number
  hero_title: string
  hero_subtitle: string
  cta_primary_text: string
  cta_primary_url: string
  cta_secondary_text: string
  cta_secondary_url: string
  dark_mode_enabled: boolean
  theme_color: string
}

interface StandingRow {
  id: string
  team_name: string
  games_played: number
  wins: number
  losses: number
  points: number
  order_index: number
}

const activeTab = ref<'hero' | 'standings' | 'instagram'>('hero')

const settings = ref<LandingSettings>({
  id: 1,
  hero_title: 'La Tribu Insular Vive en la Fan Zone Oficial',
  hero_subtitle: 'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.',
  cta_primary_text: 'Únete a la Tribu Gratis',
  cta_primary_url: '/register',
  cta_secondary_text: 'Explorar Premios',
  cta_secondary_url: '#premios',
  dark_mode_enabled: true,
  theme_color: '#059669'
})

const standings = ref<StandingRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Standings modal
const showStandingModal = ref(false)
const standingForm = ref({
  id: '',
  team_name: '',
  games_played: 0,
  wins: 0,
  losses: 0,
  points: 0,
  order_index: 1
})

const standingsColumns = [
  { key: 'order_index', label: 'Pos' },
  { key: 'team_name', label: 'Equipo' },
  { key: 'games_played', label: 'JJ', align: 'center' as const },
  { key: 'wins', label: 'JG', align: 'center' as const },
  { key: 'losses', label: 'JP', align: 'center' as const },
  { key: 'points', label: 'PTS', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadData = async () => {
  loading.value = true
  try {
    const { data: setts } = await supabase.from('landing_settings').select('*').eq('id', 1).maybeSingle()
    if (setts) {
      settings.value = setts
    }

    const { data: stData } = await supabase.from('standings').select('*').order('order_index', { ascending: true })
    standings.value = stData || []
  } catch (err: any) {
    console.error('Error loading landing data:', err)
  } finally {
    loading.value = false
  }
}

const saveSettings = async () => {
  actionLoading.value = true
  errorMessage.value = null
  successMessage.value = null
  try {
    const { error } = await supabase.from('landing_settings').upsert({
      ...settings.value,
      id: 1,
      updated_at: new Date().toISOString()
    })
    if (error) throw error
    successMessage.value = 'Configuración del Hero y Tema guardados correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const openNewStanding = () => {
  standingForm.value = {
    id: '',
    team_name: '',
    games_played: 0,
    wins: 0,
    losses: 0,
    points: 0,
    order_index: standings.value.length + 1
  }
  showStandingModal.value = true
}

const editStanding = (row: StandingRow) => {
  standingForm.value = { ...row }
  showStandingModal.value = true
}

const saveStanding = async () => {
  if (!standingForm.value.team_name) return
  actionLoading.value = true
  try {
    const payload = {
      team_name: standingForm.value.team_name,
      games_played: Number(standingForm.value.games_played),
      wins: Number(standingForm.value.wins),
      losses: Number(standingForm.value.losses),
      points: Number(standingForm.value.wins * 2 + standingForm.value.losses),
      order_index: Number(standingForm.value.order_index)
    }

    if (standingForm.value.id) {
      await supabase.from('standings').update(payload).eq('id', standingForm.value.id)
    } else {
      await supabase.from('standings').insert(payload)
    }

    successMessage.value = 'Equipo guardado en la tabla de clasificación.'
    showStandingModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteStanding = async (id: string) => {
  if (!confirm('¿Desea eliminar este equipo de la tabla de clasificación?')) return
  try {
    await supabase.from('standings').delete().eq('id', id)
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message
  }
}

onMounted(loadData)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Configuración General de Landing Page</h1>
          <p class="text-sm text-slate-400">Edita el Hero principal, modo oscuro, tabla de clasificación y accesos a secciones.</p>
        </div>

        <div class="flex items-center gap-2">
          <RouterLink to="/admin/carrusel" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 flex items-center gap-1.5">
            <i class="bi bi-images text-emerald-400"></i> Carrusel
          </RouterLink>
          <RouterLink to="/admin/jugadores" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 flex items-center gap-1.5">
            <i class="bi bi-person-bounding-box text-emerald-400"></i> Plantilla
          </RouterLink>
          <RouterLink to="/admin/equipo" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 flex items-center gap-1.5">
            <i class="bi bi-person-lines-fill text-emerald-400"></i> C. Técnico
          </RouterLink>
          <RouterLink to="/admin/instagram" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 flex items-center gap-1.5">
            <i class="bi bi-instagram text-emerald-400"></i> Instagram
          </RouterLink>
        </div>
      </div>

      <!-- Alert Messages -->
      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- Navigation Tabs -->
      <div class="flex items-center gap-2 border-b border-slate-800 pb-2">
        <button
          @click="activeTab = 'hero'"
          :class="[
            'px-4 py-2 rounded-xl text-sm font-semibold transition-all',
            activeTab === 'hero' ? 'bg-emerald-600 text-white shadow-md' : 'text-slate-400 hover:text-white hover:bg-slate-800'
          ]"
        >
          <i class="bi bi-layout-text-window-reverse mr-1.5"></i> Hero Section & Tema
        </button>
        <button
          @click="activeTab = 'standings'"
          :class="[
            'px-4 py-2 rounded-xl text-sm font-semibold transition-all',
            activeTab === 'standings' ? 'bg-emerald-600 text-white shadow-md' : 'text-slate-400 hover:text-white hover:bg-slate-800'
          ]"
        >
          <i class="bi bi-trophy mr-1.5"></i> Tabla de Clasificación
        </button>
      </div>

      <!-- TAB 1: Hero Section & Theme -->
      <div v-if="activeTab === 'hero'" class="space-y-6">
        <BaseCard class="bg-slate-900 border-slate-800 p-6 space-y-6">
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-pen text-emerald-400"></i> Contenido Principal del Hero
          </h3>

          <div class="grid grid-cols-1 gap-4">
            <BaseInput label="Título Principal de la Landing" v-model="settings.hero_title" />
            <div>
              <label class="block text-xs font-semibold text-slate-300 mb-1">Subtítulo / Descripción Hero</label>
              <textarea
                v-model="settings.hero_subtitle"
                rows="3"
                class="w-full bg-slate-950 border border-slate-800 text-slate-100 rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500"
              ></textarea>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4 border-t border-slate-800">
            <BaseInput label="Texto Botón Principal (CTA)" v-model="settings.cta_primary_text" />
            <BaseInput label="Enlace Botón Principal" v-model="settings.cta_primary_url" />
            <BaseInput label="Texto Botón Secundario" v-model="settings.cta_secondary_text" />
            <BaseInput label="Enlace Botón Secundario" v-model="settings.cta_secondary_url" />
          </div>

          <div class="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-3 pt-4">
            <h4 class="text-xs font-bold uppercase text-slate-400">Personalización de Apariencia</h4>
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <label class="flex items-center gap-3 text-sm text-slate-200 cursor-pointer">
                <input type="checkbox" v-model="settings.dark_mode_enabled" class="w-5 h-5 accent-emerald-500 rounded" />
                <span>Modo Oscuro Predeterminado para Nuevos Visitantes</span>
              </label>

              <div class="flex items-center gap-3">
                <label class="text-xs text-slate-400">Color Primario de Énfasis:</label>
                <input type="color" v-model="settings.theme_color" class="w-8 h-8 rounded-lg cursor-pointer bg-slate-900 border border-slate-700" />
              </div>
            </div>
          </div>

          <div class="flex justify-end pt-4">
            <BaseButton variant="primary" :loading="actionLoading" @click="saveSettings">
              <i class="bi bi-check-lg mr-1.5"></i> Guardar Cambios del Hero
            </BaseButton>
          </div>
        </BaseCard>
      </div>

      <!-- TAB 2: Standings / Tabla de Clasificación -->
      <div v-if="activeTab === 'standings'" class="space-y-6">
        <div class="flex items-center justify-between">
          <p class="text-sm text-slate-400">Tabla de Posiciones de la Temporada SPB.</p>
          <BaseButton variant="primary" size="sm" @click="openNewStanding">
            <i class="bi bi-plus-lg mr-1.5"></i> Agregar Equipo
          </BaseButton>
        </div>

        <BaseTable :columns="standingsColumns" :data="standings" :loading="loading" empty-text="No hay equipos en la clasificación">
          <template #cell-order_index="{ row }">
            <span class="font-bold text-emerald-400 font-mono">#{{ (row as StandingRow).order_index }}</span>
          </template>

          <template #cell-team_name="{ row }">
            <span class="font-semibold text-slate-100">{{ (row as StandingRow).team_name }}</span>
          </template>

          <template #cell-actions="{ row }">
            <div class="flex items-center justify-end gap-1.5">
              <button @click="editStanding(row as StandingRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg">
                <i class="bi bi-pencil"></i>
              </button>
              <button @click="deleteStanding((row as StandingRow).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </template>
        </BaseTable>
      </div>
    </div>

    <!-- Modal Standing Editor -->
    <BaseModal v-if="showStandingModal" :is-open="showStandingModal" title="Equipo en Clasificación" @close="showStandingModal = false">
      <div class="space-y-4">
        <BaseInput label="Nombre del Equipo" v-model="standingForm.team_name" placeholder="Ej: Guaiqueríes de Margarita" />

        <div class="grid grid-cols-2 gap-4">
          <BaseInput label="Juegos Jugados (JJ)" type="number" v-model.number="standingForm.games_played" />
          <BaseInput label="Juegos Ganados (JG)" type="number" v-model.number="standingForm.wins" />
          <BaseInput label="Juegos Perdidos (JP)" type="number" v-model.number="standingForm.losses" />
          <BaseInput label="Orden de Posición (#)" type="number" v-model.number="standingForm.order_index" />
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showStandingModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveStanding">Guardar Equipo</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
