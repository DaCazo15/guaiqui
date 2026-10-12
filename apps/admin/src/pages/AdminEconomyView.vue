<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseCard, BaseButton, BaseInput, BaseTable } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

const dailyCap = ref(1000)
const weeklyCap = ref(5000)
const streak3DaysBonus = ref(100)
const streak7DaysBonus = ref(300)

const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const historyLogs = ref<any[]>([])

const loadEconomySettings = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('economy_settings')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error

    if (data && data.length > 0) {
      const current = data[0]
      dailyCap.value = current.daily_pearl_cap || 1000
      weeklyCap.value = current.weekly_pearl_cap || 5000
      streak3DaysBonus.value = current.streak_bonus_config?.streak_3_days ?? 100
      streak7DaysBonus.value = current.streak_bonus_config?.streak_7_days ?? 300
    }

    // Load economy change history from audit_log safely
    const { data: auditData } = await supabase
      .from('audit_log')
      .select('*')
      .eq('action', 'update_economy_settings')
      .order('created_at', { ascending: false })
      .limit(10)

    if (auditData && auditData.length > 0) {
      const actorIds = [...new Set(auditData.map((l: any) => l.actor_id).filter(Boolean))]
      let profilesMap: Record<string, string> = {}
      if (actorIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, display_name')
          .in('id', actorIds)
        if (profiles) {
          profilesMap = Object.fromEntries(profiles.map((p: any) => [p.id, p.display_name]))
        }
      }
      historyLogs.value = auditData.map((log: any) => ({
        ...log,
        actor: { display_name: profilesMap[log.actor_id] || 'Administrador' }
      }))
    } else {
      historyLogs.value = []
    }
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const saveEconomySettings = async () => {
  if (dailyCap.value <= 0) {
    errorMessage.value = 'El cap diario debe ser mayor a 0.'
    return
  }

  if (weeklyCap.value < dailyCap.value) {
    errorMessage.value = 'El cap semanal no puede ser inferior al cap diario.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      daily_pearl_cap: Number(dailyCap.value),
      weekly_pearl_cap: Number(weeklyCap.value),
      streak_bonus_config: {
        streak_3_days: Number(streak3DaysBonus.value),
        streak_7_days: Number(streak7DaysBonus.value)
      }
    }

    const { error } = await supabase.rpc('admin_update_economy_settings', { p_settings: payload })
    if (error) throw error

    successMessage.value = 'Configuración de la economía actualizada correctamente.'
    await loadEconomySettings()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadEconomySettings)
</script>

<template>
  <AdminLayout>
    <div class="max-w-5xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold font-title text-gray-900 tracking-tight">Reglas Económicas de la Plataforma</h1>
        <p class="text-sm text-gray-600 mt-1">Configurar límites máximos de emisión de perlitas y bonos de racha. Los cambios aplican hacia adelante.</p>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-50 border border-red-200 text-red-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-gray-400 hover:text-gray-700"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-gray-400 hover:text-gray-700"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseCard class="bg-white border border-gray-200 p-6 rounded-2xl shadow-xs space-y-6">
        <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2">
          <i class="bi bi-shield-lock text-emerald-700"></i> Caps Máximos de Ganancia de Perlitas
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <BaseInput label="Cap Diario de Perlitas por Fanático" type="number" v-model="dailyCap" />
          <BaseInput label="Cap Semanal de Perlitas por Fanático" type="number" v-model="weeklyCap" />
        </div>

        <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2 border-t border-gray-100 pt-6">
          <i class="bi bi-fire text-amber-600"></i> Configuración de Bonos por Racha de Participación
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <BaseInput label="Bono por 3 Días Consecutivos (Perlitas)" type="number" v-model="streak3DaysBonus" />
          <BaseInput label="Bono por 7 Días Consecutivos (Perlitas)" type="number" v-model="streak7DaysBonus" />
        </div>

        <div class="flex items-center justify-end border-t border-gray-100 pt-6">
          <BaseButton variant="primary" :loading="actionLoading" @click="saveEconomySettings">
            <i class="bi bi-check-lg mr-1.5"></i> Actualizar Reglas Económicas
          </BaseButton>
        </div>
      </BaseCard>

      <!-- History of updates -->
      <BaseCard class="bg-white border border-gray-200 p-6 rounded-2xl shadow-xs space-y-4">
        <h3 class="text-md font-bold text-gray-900 flex items-center gap-2">
          <i class="bi bi-clock-history text-gray-500"></i> Historial de Modificaciones
        </h3>

        <div class="space-y-3">
          <div v-for="log in historyLogs" :key="log.id" class="p-3.5 rounded-xl bg-gray-50 border border-gray-200 text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <span class="font-semibold text-gray-900">{{ log.actor?.display_name || 'Administrador' }}</span>
              <span class="text-gray-600 font-mono ml-2">Cap Diario: {{ log.after?.daily_pearl_cap }} | Cap Semanal: {{ log.after?.weekly_pearl_cap }}</span>
            </div>
            <span class="text-gray-500 font-mono">{{ formatCaracas(log.created_at) }}</span>
          </div>

          <div v-if="historyLogs.length === 0" class="text-xs text-gray-500 text-center py-4">
            No se han registrado modificaciones en la economía aún.
          </div>
        </div>
      </BaseCard>
    </div>
  </AdminLayout>
</template>
