<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface StaffMemberRow {
  user_id: string
  role: 'staff' | 'admin'
  active: boolean
  created_at: string
  display_name?: string
  email?: string
}

const staffList = ref<StaffMemberRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showInviteModal = ref(false)
const inviteEmail = ref('')
const inviteRole = ref<'staff' | 'admin'>('staff')

const columns = [
  { key: 'user_id', label: 'ID / Nombre' },
  { key: 'role', label: 'Rol Asignado' },
  { key: 'active', label: 'Estado', align: 'center' as const },
  { key: 'created_at', label: 'Fecha de Alta' },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadStaffMembers = async () => {
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

    staffList.value = (staffData || []).map(s => ({
      ...s,
      display_name: profileMap.get(s.user_id) || 'Personal'
    }))
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
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
    await loadStaffMembers()
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
    await loadStaffMembers()
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
    await loadStaffMembers()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadStaffMembers)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Gestión de Personal y Roles</h1>
          <p class="text-sm text-slate-400">Invitar miembros del equipo de taquilla y administradores con privilegios elevados.</p>
        </div>
        <BaseButton variant="primary" @click="showInviteModal = true">
          <i class="bi bi-person-plus-fill mr-1.5"></i> Invitar Miembro
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

      <BaseTable :columns="columns" :data="(staffList as any[])" :loading="loading" empty-text="No hay personal registrado">
        <template #cell-user_id="{ row }">
          <div>
            <div class="font-semibold text-slate-100">{{ (row as StaffMemberRow).display_name }}</div>
            <div class="text-xs font-mono text-slate-500">{{ (row as StaffMemberRow).user_id }}</div>
          </div>
        </template>

        <template #cell-role="{ row }">
          <BaseBadge :variant="(row as StaffMemberRow).role === 'admin' ? 'info' : 'soft'">
            {{ (row as StaffMemberRow).role === 'admin' ? 'Administrador' : 'Personal de Taquilla' }}
          </BaseBadge>
        </template>

        <template #cell-active="{ row }">
          <BaseBadge :variant="(row as StaffMemberRow).active ? 'success' : 'danger'">
            {{ (row as StaffMemberRow).active ? 'Activo' : 'Inactivo' }}
          </BaseBadge>
        </template>

        <template #cell-created_at="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ (row as StaffMemberRow).created_at ? new Date((row as StaffMemberRow).created_at).toLocaleDateString() : '' }}</span>
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
