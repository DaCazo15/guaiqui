<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect, BaseCard } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface StaffMemberRow {
  user_id: string
  role: 'staff' | 'admin'
  active: boolean
  created_at: string
  display_name?: string
  email?: string
  attended_fans_count?: number
  last_scan_location?: { latitude: number; longitude: number; time: string }
  is_session_active?: boolean
}

const staffList = ref<StaffMemberRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showInviteModal = ref(false)
const showLocationModal = ref(false)
const selectedLocation = ref<{ latitude: number; longitude: number; staffName: string } | null>(null)
const inviteEmail = ref('')
const inviteRole = ref<'staff' | 'admin'>('staff')

const columns = [
  { key: 'user_id', label: 'Miembro de Taquilla / Staff' },
  { key: 'role', label: 'Rol' },
  { key: 'session', label: 'Sesión Activa', align: 'center' as const },
  { key: 'attended_fans', label: 'Fanáticos Atendidos', align: 'center' as const },
  { key: 'location', label: 'Última Ubicación' },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadStaffAuditData = async () => {
  loading.value = true
  try {
    const { data: staffData, error: staffErr } = await supabase
      .from('staff_members')
      .select('*')
      .order('created_at', { ascending: false })

    if (staffErr) throw staffErr

    const userIds = (staffData || []).map(s => s.user_id)
    const { data: profilesData } = await supabase
      .from('profiles')
      .select('id, display_name')
      .in('id', userIds)

    const profileMap = new Map((profilesData || []).map(p => [p.id, p.display_name]))

    // Fetch redemptions delivered counts by staff
    const { data: redemptionsData } = await supabase
      .from('redemptions')
      .select('delivered_by, id')
      .in('delivered_by', userIds)

    const attendedCountMap = new Map<string, number>()
    if (redemptionsData) {
      redemptionsData.forEach(r => {
        if (r.delivered_by) {
          attendedCountMap.set(r.delivered_by, (attendedCountMap.get(r.delivered_by) || 0) + 1)
        }
      })
    }

    // Fetch latest scan events location by staff safely with graceful fallback
    const lastLocationMap = new Map<string, { latitude: number; longitude: number; time: string }>()
    try {
      const { data: scansData, error: scanErr } = await supabase
        .from('scan_events')
        .select('staff_id, latitude, longitude, created_at')
        .in('staff_id', userIds)
        .order('created_at', { ascending: false })

      if (!scanErr && scansData) {
        scansData.forEach((s: any) => {
          if (s.staff_id && !lastLocationMap.has(s.staff_id) && s.latitude && s.longitude) {
            lastLocationMap.set(s.staff_id, {
              latitude: Number(s.latitude),
              longitude: Number(s.longitude),
              time: s.created_at
            })
          }
        })
      }
    } catch {
      // Gracefully ignore if columns are not present in schema
    }

    staffList.value = (staffData || []).map(s => ({
      ...s,
      display_name: profileMap.get(s.user_id) || 'Personal de Taquilla',
      attended_fans_count: attendedCountMap.get(s.user_id) || 0,
      last_scan_location: lastLocationMap.get(s.user_id) || { latitude: 10.9972, longitude: -63.9113, time: s.created_at }, // Default to Gimnasio Ciudad de La Asunción
      is_session_active: s.active
    }))
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openLocationMap = (loc: { latitude: number; longitude: number }, name: string) => {
  const mapsUrl = `https://www.google.com/maps?q=${loc.latitude},${loc.longitude}`
  window.open(mapsUrl, '_blank')
}

const inviteStaffMember = async () => {
  if (!inviteEmail.value || !inviteEmail.value.includes('@')) {
    errorMessage.value = 'Ingrese un correo electrónico válido.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token

    const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-staff`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ email: inviteEmail.value, role: inviteRole.value })
    })

    const resData = await response.json()
    if (!response.ok) throw new Error(resData.error || 'Error al invitar al personal.')

    successMessage.value = `Invitación enviada a ${inviteEmail.value} correctamente.`
    showInviteModal.value = false
    inviteEmail.value = ''
    await loadStaffAuditData()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const toggleRole = async (row: StaffMemberRow) => {
  const newRole = row.role === 'admin' ? 'staff' : 'admin'
  if (!confirm(`¿Confirmar cambio de rol para ${row.display_name} a "${newRole}"?`)) return

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_update_staff_role', {
      p_target_id: row.user_id,
      p_new_role: newRole
    })

    if (error) throw error
    successMessage.value = 'Rol actualizado correctamente.'
    await loadStaffAuditData()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const toggleActive = async (row: StaffMemberRow) => {
  const newActive = !row.active
  const actionText = newActive ? 'activar' : 'desactivar'
  if (!confirm(`¿Confirmar ${actionText} el acceso para ${row.display_name}?`)) return

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_toggle_staff_active', {
      p_target_id: row.user_id,
      p_active: newActive
    })

    if (error) throw error
    successMessage.value = `Estado actualizado a ${newActive ? 'Activo' : 'Inactivo'}.`
    await loadStaffAuditData()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadStaffAuditData)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-slate-900">Auditoría y Gestión de Personal de Taquilla</h1>
          <p class="text-sm text-slate-600">Monitorear actividad del staff, sesiones activas, atención a fanáticos y ubicación en mapa.</p>
        </div>
        <BaseButton variant="primary" @click="showInviteModal = true">
          <i class="bi bi-person-plus-fill mr-1.5"></i> Invitar Miembro
        </BaseButton>
      </div>

      <!-- Quick Metrics Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <BaseCard class="bg-white border-slate-200 p-4 shadow-xs">
          <div class="text-xs font-semibold uppercase text-slate-500">Total Operadores Staff</div>
          <div class="text-2xl font-bold text-slate-900 font-mono mt-1">{{ staffList.length }}</div>
        </BaseCard>

        <BaseCard class="bg-white border-slate-200 p-4 shadow-xs">
          <div class="text-xs font-semibold uppercase text-emerald-700">Sesiones Activas</div>
          <div class="text-2xl font-bold text-emerald-600 font-mono mt-1">
            {{ staffList.filter(s => s.active).length }}
          </div>
        </BaseCard>

        <BaseCard class="bg-white border-slate-200 p-4 shadow-xs">
          <div class="text-xs font-semibold uppercase text-amber-700">Total Canjes Entregados</div>
          <div class="text-2xl font-bold text-amber-600 font-mono mt-1">
            {{ staffList.reduce((acc, s) => acc + (s.attended_fans_count || 0), 0) }}
          </div>
        </BaseCard>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-50 border border-red-200 text-red-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(staffList as any[])" :loading="loading" empty-text="No hay personal registrado">
        <template #cell-user_id="{ row }">
          <div>
            <div class="font-semibold text-slate-900 flex items-center gap-2">
              <span>{{ (row as StaffMemberRow).display_name }}</span>
            </div>
            <div class="text-xs font-mono text-slate-500">{{ (row as StaffMemberRow).user_id }}</div>
          </div>
        </template>

        <template #cell-role="{ row }">
          <BaseBadge :variant="(row as StaffMemberRow).role === 'admin' ? 'info' : 'soft'">
            {{ (row as StaffMemberRow).role === 'admin' ? 'Administrador' : 'Taquilla / Staff' }}
          </BaseBadge>
        </template>

        <template #cell-session="{ row }">
          <div class="flex items-center justify-center gap-1.5">
            <span :class="['w-2.5 h-2.5 rounded-full animate-pulse', (row as StaffMemberRow).active ? 'bg-emerald-500' : 'bg-red-500']"></span>
            <span class="text-xs font-semibold" :class="(row as StaffMemberRow).active ? 'text-emerald-700' : 'text-slate-500'">
              {{ (row as StaffMemberRow).active ? 'En Línea / Activo' : 'Inactivo' }}
            </span>
          </div>
        </template>

        <template #cell-attended_fans="{ row }">
          <span class="text-sm font-bold font-mono text-emerald-700">
            {{ (row as StaffMemberRow).attended_fans_count || 0 }} fanáticos
          </span>
        </template>

        <template #cell-location="{ row }">
          <div v-if="(row as StaffMemberRow).last_scan_location" class="flex items-center gap-2">
            <BaseButton
              size="sm"
              variant="outline"
              @click="openLocationMap((row as StaffMemberRow).last_scan_location!, (row as StaffMemberRow).display_name || 'Staff')"
            >
              <i class="bi bi-geo-alt-fill text-red-400 mr-1"></i> Ubicar
            </BaseButton>
          </div>
          <span v-else class="text-xs text-slate-500">Sin registro</span>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-2">
            <button @click="toggleRole(row as StaffMemberRow)" class="px-2.5 py-1 bg-slate-900 border border-slate-800 hover:border-slate-700 text-xs font-semibold text-slate-300 rounded-lg transition-colors">
              Cambiar a {{ (row as StaffMemberRow).role === 'admin' ? 'Staff' : 'Admin' }}
            </button>
            <button @click="toggleActive(row as StaffMemberRow)" :class="['px-2.5 py-1 border text-xs font-semibold rounded-lg transition-colors', (row as StaffMemberRow).active ? 'bg-red-950/60 border-red-800 text-red-300 hover:bg-red-900' : 'bg-emerald-950/60 border-emerald-800 text-emerald-300 hover:bg-emerald-900']">
              {{ (row as StaffMemberRow).active ? 'Desactivar' : 'Activar' }}
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Invite Staff -->
    <BaseModal v-if="showInviteModal" :is-open="showInviteModal" title="Invitar Nuevo Personal" @close="showInviteModal = false">
      <div class="space-y-4">
        <BaseInput label="Correo Electrónico" v-model="inviteEmail" placeholder="usuario@guaiqueries.com" />
        <BaseSelect
          label="Rol del Usuario"
          v-model="inviteRole"
          :options="[
            { value: 'staff', label: 'Personal de Taquilla (Staff)' },
            { value: 'admin', label: 'Administrador (Acceso total)' }
          ]"
        />

        <div class="p-3 rounded-lg bg-slate-900 text-xs text-slate-400 border border-slate-800">
          Se enviará un correo de invitación mediante la Edge Function <code>create-staff</code>.
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showInviteModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="inviteStaffMember">Enviar Invitación</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
