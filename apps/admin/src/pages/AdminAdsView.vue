<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { supabase } from '../lib/supabase'

const loading = ref(true)
const savingSettings = ref(false)
const importingReport = ref(false)
const message = ref<{ text: string; type: 'success' | 'error' } | null>(null)

// Form settings
const settings = ref({
  ads_enabled: true,
  daily_ad_views: 50,
  block_size: 10,
  ad_min_seconds: 6,
  ad_min_account_age_days: 3,
  ad_min_trivias_completed: 1,
  reward_tiers: [
    { block_number: 1, pearls: 5 },
    { block_number: 2, pearls: 10 },
    { block_number: 3, pearls: 15 },
    { block_number: 4, pearls: 20 },
    { block_number: 5, pearls: 25 },
  ],
})

// Reconciliation import form
const importForm = ref({
  day: new Date().toISOString().split('T')[0],
  google_impressions: 0,
  notes: '',
})

// Analytics state
const analyticsData = ref<any>(null)

const fetchData = async () => {
  loading.value = true
  message.value = null
  try {
    // 1. Fetch current settings safely without coercing error
    const { data: ecoData, error: ecoErr } = await supabase
      .from('economy_settings')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (!ecoErr && ecoData) {
      settings.value.ads_enabled = ecoData.ads_enabled ?? true
      settings.value.daily_ad_views = ecoData.daily_ad_views ?? 50
      settings.value.block_size = ecoData.block_size ?? 10
      settings.value.ad_min_seconds = ecoData.ad_min_seconds ?? 6
      settings.value.ad_min_account_age_days = ecoData.ad_min_account_age_days ?? 3
      settings.value.ad_min_trivias_completed = ecoData.ad_min_trivias_completed ?? 1
    }

    // 2. Fetch reward tiers
    const { data: tierData } = await supabase
      .from('ad_reward_tiers')
      .select('*')
      .order('block_number', { ascending: true })

    if (tierData && tierData.length > 0) {
      settings.value.reward_tiers = tierData.map((t) => ({
        block_number: t.block_number,
        pearls: t.pearls,
      }))
    }

    // 3. Fetch analytics (graceful fallback)
    try {
      const { data: analyticsRes, error: analyticsErr } = await supabase.rpc('analytics_ads')
      if (!analyticsErr) {
        analyticsData.value = analyticsRes
      }
    } catch {
      analyticsData.value = null
    }
  } catch (err: any) {
    message.value = { text: err.message || 'Error al cargar datos de anuncios.', type: 'error' }
  } finally {
    loading.value = false
  }
}

const handleSaveSettings = async () => {
  savingSettings.value = true
  message.value = null
  try {
    const { error } = await supabase.rpc('admin_update_ads_settings', {
      p_settings: settings.value,
    })
    if (error) throw error
    message.value = { text: 'Configuración de anuncios guardada exitosamente.', type: 'success' }
    await fetchData()
  } catch (err: any) {
    message.value = { text: err.message || 'Error al guardar la configuración.', type: 'error' }
  } finally {
    savingSettings.value = false
  }
}

const handleImportReport = async () => {
  if (!importForm.value.day || importForm.value.google_impressions < 0) {
    message.value = { text: 'Ingresa una fecha e impresiones válidas.', type: 'error' }
    return
  }

  importingReport.value = true
  message.value = null
  try {
    const { data, error } = await supabase.rpc('import_ad_report', {
      p_day: importForm.value.day,
      p_impressions: importForm.value.google_impressions,
      p_notes: importForm.value.notes || null,
    })
    if (error) throw error

    if (data.alert_flagged) {
      message.value = {
        text: `Informe importado. ¡ALERTA DE DISCREPANCIA! La proporción DB/Google (${data.discrepancy_ratio}) supera el umbral de 1.2.`,
        type: 'error',
      }
    } else {
      message.value = {
        text: `Informe importado exitosamente. Proporción de coincidencia: ${data.discrepancy_ratio}.`,
        type: 'success',
      }
    }
    await fetchData()
  } catch (err: any) {
    message.value = { text: err.message || 'Error al importar informe.', type: 'error' }
  } finally {
    importingReport.value = false
  }
}

onMounted(() => {
  fetchData()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-8">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900 uppercase tracking-wide">
          Anuncios Recompensados (Google Ad Manager)
        </h1>
        <p class="text-sm text-gray-500">
          Gestión de límites, recompensas por bloques, conciliación diaria y analítica de fraude.
        </p>
      </div>

      <div class="flex items-center gap-3">
        <span class="text-xs font-semibold text-gray-500">Estado General:</span>
        <button
          type="button"
          :class="[
            'px-4 py-2 text-xs font-bold uppercase rounded-lg transition-colors cursor-pointer',
            settings.ads_enabled ? 'bg-emerald-600 text-white hover:bg-emerald-700' : 'bg-red-600 text-white hover:bg-red-700',
          ]"
          @click="settings.ads_enabled = !settings.ads_enabled; handleSaveSettings()"
        >
          {{ settings.ads_enabled ? 'ANUNCIOS ACTIVOS' : 'ANUNCIOS DESACTIVADOS' }}
        </button>
      </div>
    </div>

    <!-- Alert message -->
    <div
      v-if="message"
      :class="[
        'p-4 rounded-xl text-sm font-semibold flex items-center justify-between',
        message.type === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-red-50 text-red-800 border border-red-200',
      ]"
    >
      <span>{{ message.text }}</span>
      <button @click="message = null" class="text-xs underline ml-4">Cerrar</button>
    </div>

    <div v-if="loading" class="p-12 text-center text-gray-500 font-medium">
      Cargando panel de anuncios...
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Left Column: Settings & Reward Tiers -->
      <div class="lg:col-span-2 space-y-6">
        <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-xs space-y-6">
          <h2 class="text-lg font-bold text-gray-900 border-b pb-3 uppercase">
            Configuración y Reglas de la Economía de Anuncios
          </h2>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div>
              <label class="block font-semibold text-gray-700 mb-1">Límite Diario por Fanático (Anuncios)</label>
              <input
                v-model.number="settings.daily_ad_views"
                type="number"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Tamaño del Bloque (Anuncios por Bloque)</label>
              <input
                v-model.number="settings.block_size"
                type="number"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Segundos Mínimos del Servidor (Reloj)</label>
              <input
                v-model.number="settings.ad_min_seconds"
                type="number"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Antigüedad Mínima de Cuenta (Días)</label>
              <input
                v-model.number="settings.ad_min_account_age_days"
                type="number"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Trivias Completadas Mínimas</label>
              <input
                v-model.number="settings.ad_min_trivias_completed"
                type="number"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>
          </div>

          <!-- Reward Tiers Config -->
          <div class="pt-4 border-t border-gray-200 space-y-3">
            <h3 class="text-sm font-bold text-gray-800 uppercase">
              Recompensas en Perlitas por Bloque de {{ settings.block_size }} Anuncios
            </h3>

            <div class="grid grid-cols-1 sm:grid-cols-5 gap-3">
              <div
                v-for="(tier, idx) in settings.reward_tiers"
                :key="tier.block_number"
                class="p-3 bg-gray-50 border border-gray-200 rounded-lg text-xs text-center space-y-1"
              >
                <span class="font-bold text-gray-700 block uppercase">Bloque {{ tier.block_number }}</span>
                <span class="text-[10px] text-gray-500 block">Anuncios {{ (tier.block_number - 1) * settings.block_size + 1 }} a {{ tier.block_number * settings.block_size }}</span>
                <input
                  v-model.number="settings.reward_tiers[idx].pearls"
                  type="number"
                  class="w-full px-2 py-1 border border-gray-300 rounded text-center font-bold text-emerald-700"
                />
              </div>
            </div>
          </div>

          <div class="pt-2 flex justify-end">
            <button
              type="button"
              :disabled="savingSettings"
              class="px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs uppercase rounded-lg hover:bg-emerald-700 transition-colors disabled:opacity-50 cursor-pointer"
              @click="handleSaveSettings"
            >
              {{ savingSettings ? 'Guardando...' : 'Guardar Cambios' }}
            </button>
          </div>
        </div>

        <!-- Analytics Overview Cards -->
        <div v-if="analyticsData" class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div class="bg-white border border-gray-200 p-4 rounded-xl text-center">
            <span class="text-xs text-gray-500 font-semibold block uppercase">Iniciadas (30d)</span>
            <span class="text-2xl font-extrabold text-gray-900">{{ analyticsData.sessions_started }}</span>
          </div>

          <div class="bg-white border border-gray-200 p-4 rounded-xl text-center">
            <span class="text-xs text-gray-500 font-semibold block uppercase">Completadas (30d)</span>
            <span class="text-2xl font-extrabold text-emerald-600">{{ analyticsData.sessions_completed }}</span>
          </div>

          <div class="bg-white border border-gray-200 p-4 rounded-xl text-center">
            <span class="text-xs text-gray-500 font-semibold block uppercase">Fans Únicos</span>
            <span class="text-2xl font-extrabold text-blue-600">{{ analyticsData.unique_fans }}</span>
          </div>

          <div class="bg-white border border-gray-200 p-4 rounded-xl text-center">
            <span class="text-xs text-gray-500 font-semibold block uppercase">Perlitas Pagadas</span>
            <span class="text-2xl font-extrabold text-amber-600">+{{ analyticsData.pearls_paid }}</span>
          </div>
        </div>

        <!-- Reconciliation Table -->
        <div v-if="analyticsData" class="bg-white border border-gray-200 rounded-xl p-6 shadow-xs space-y-4">
          <h2 class="text-lg font-bold text-gray-900 uppercase border-b pb-3">
            Historial de Conciliación con Google Ad Manager
          </h2>

          <div v-if="analyticsData.reconciliation_history.length === 0" class="text-xs text-gray-500 italic py-4">
            No hay datos de conciliación importados aún.
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full text-xs text-left">
              <thead class="bg-gray-50 text-gray-600 uppercase font-semibold border-b">
                <tr>
                  <th class="p-3">Fecha</th>
                  <th class="p-3">Impresiones Google</th>
                  <th class="p-3">Completadas DB</th>
                  <th class="p-3">Proporción</th>
                  <th class="p-3">Estado</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr v-for="rec in analyticsData.reconciliation_history" :key="rec.day">
                  <td class="p-3 font-semibold text-gray-900">{{ rec.day }}</td>
                  <td class="p-3 font-mono">{{ rec.google_impressions }}</td>
                  <td class="p-3 font-mono">{{ rec.db_completed }}</td>
                  <td class="p-3 font-bold">
                    {{ rec.google_impressions > 0 ? (rec.db_completed / rec.google_impressions).toFixed(2) : 'N/A' }}
                  </td>
                  <td class="p-3">
                    <span
                      v-if="rec.google_impressions > 0 && rec.db_completed / rec.google_impressions > 1.2"
                      class="px-2 py-0.5 bg-red-100 text-red-800 font-bold rounded text-[10px]"
                    >
                      ALERTA (> 1.2)
                    </span>
                    <span v-else class="px-2 py-0.5 bg-emerald-100 text-emerald-800 font-bold rounded text-[10px]">
                      CONCILIADO
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Right Column: Import Ad Report -->
      <div class="space-y-6">
        <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-xs space-y-4">
          <h2 class="text-base font-bold text-gray-900 uppercase border-b pb-2">
            Importar Informe de Ad Manager
          </h2>
          <p class="text-xs text-gray-500 leading-relaxed">
            Ingresa diariamente las impresiones de anuncios recompensados del informe de Google GAM para detectar discrepancias y fraude en cliente.
          </p>

          <form @submit.prevent="handleImportReport" class="space-y-3 text-xs">
            <div>
              <label class="block font-semibold text-gray-700 mb-1">Fecha del Informe</label>
              <input
                v-model="importForm.day"
                type="date"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Impresiones Recompensadas (Google GAM)</label>
              <input
                v-model.number="importForm.google_impressions"
                type="number"
                min="0"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              />
            </div>

            <div>
              <label class="block font-semibold text-gray-700 mb-1">Notas / Observaciones</label>
              <textarea
                v-model="importForm.notes"
                rows="2"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                placeholder="Ej. Informe oficial descargado de Ad Manager"
              ></textarea>
            </div>

            <button
              type="submit"
              :disabled="importingReport"
              class="w-full py-2.5 bg-blue-600 text-white font-bold text-xs uppercase rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 cursor-pointer"
            >
              {{ importingReport ? 'Importando...' : 'Importar y Verificar' }}
            </button>
          </form>
        </div>

        <!-- Cancellations breakdown card -->
        <div v-if="analyticsData" class="bg-white border border-gray-200 rounded-xl p-6 shadow-xs space-y-3">
          <h3 class="text-xs font-bold text-gray-700 uppercase">Cancelaciones por Motivo</h3>

          <div class="space-y-2 text-xs">
            <div
              v-for="(count, reason) in analyticsData.cancellations_by_reason"
              :key="reason"
              class="flex items-center justify-between p-2 bg-gray-50 rounded border border-gray-100"
            >
              <span class="font-medium text-gray-700 uppercase">{{ reason }}</span>
              <span class="font-bold text-gray-900">{{ count }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</AdminLayout>
</template>
