<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { supabase } from '../lib/supabase'
import PlatformTeamsHeader from '../components/platform/PlatformTeamsHeader.vue'
import PlatformTeamsTable, { type TeamRow } from '../components/platform/PlatformTeamsTable.vue'
import CreateTeamModal from '../components/platform/CreateTeamModal.vue'
import EditTeamModal from '../components/platform/EditTeamModal.vue'
import RecordPaymentModal from '../components/platform/RecordPaymentModal.vue'
import TeamBillingHistoryModal from '../components/platform/TeamBillingHistoryModal.vue'
import ToggleTeamStatusModal from '../components/platform/ToggleTeamStatusModal.vue'

const teams = ref<TeamRow[]>([])
const loading = ref(true)
const search = ref('')
const statusFilter = ref('all')
const billingFilter = ref('all')

const isCreateModalOpen = ref(false)
const isEditModalOpen = ref(false)
const isPaymentModalOpen = ref(false)
const isHistoryModalOpen = ref(false)
const isToggleStatusModalOpen = ref(false)

const selectedTeam = ref<TeamRow | null>(null)

// Computed KPI counters
const totalCount = computed(() => teams.value.length)
const activeCount = computed(() => teams.value.filter(t => t.status === 'active').length)
const currentBillingCount = computed(() => teams.value.filter(t => t.billing_status === 'current').length)
const expiringOrExpiredCount = computed(() => 
  teams.value.filter(t => t.billing_status === 'expiring_soon' || t.billing_status === 'expired').length
)

const fetchTeams = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('admin_list_teams', {
      p_search: search.value.trim() || null,
      p_status: statusFilter.value !== 'all' ? statusFilter.value : null,
      p_billing_status: billingFilter.value !== 'all' ? billingFilter.value : null,
      p_limit: 100,
      p_offset: 0
    })

    if (error) throw error

    if (data?.teams) {
      teams.value = data.teams as TeamRow[]
    } else {
      teams.value = []
    }
  } catch (err) {
    console.error('Error al listar equipos de plataforma:', err)
  } finally {
    loading.value = false
  }
}

// Debounced search / filter watcher
let debounceTimeout: any = null
watch([search, statusFilter, billingFilter], () => {
  clearTimeout(debounceTimeout)
  debounceTimeout = setTimeout(() => {
    fetchTeams()
  }, 250)
})

onMounted(() => {
  fetchTeams()
})

const handleEdit = (team: TeamRow) => {
  selectedTeam.value = team
  isEditModalOpen.value = true
}

const handleRecordPayment = (team: TeamRow) => {
  selectedTeam.value = team
  isPaymentModalOpen.value = true
}

const handleViewHistory = (team: TeamRow) => {
  selectedTeam.value = team
  isHistoryModalOpen.value = true
}

const handleToggleStatus = (team: TeamRow) => {
  selectedTeam.value = team
  isToggleStatusModalOpen.value = true
}
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <PlatformTeamsHeader
        :total-count="totalCount"
        :active-count="activeCount"
        :current-billing-count="currentBillingCount"
        :expiring-or-expired-count="expiringOrExpiredCount"
        :search="search"
        :status-filter="statusFilter"
        :billing-filter="billingFilter"
        @update:search="val => search = val"
        @update:status-filter="val => statusFilter = val"
        @update:billing-filter="val => billingFilter = val"
        @open-create-modal="isCreateModalOpen = true"
        @refresh="fetchTeams"
      />

      <PlatformTeamsTable
        :teams="teams"
        :loading="loading"
        @edit="handleEdit"
        @record-payment="handleRecordPayment"
        @view-history="handleViewHistory"
        @toggle-status="handleToggleStatus"
      />

      <!-- Modals -->
      <CreateTeamModal
        :is-open="isCreateModalOpen"
        @close="isCreateModalOpen = false"
        @created="fetchTeams"
      />

      <EditTeamModal
        :is-open="isEditModalOpen"
        :team="selectedTeam"
        @close="isEditModalOpen = false"
        @updated="fetchTeams"
      />

      <RecordPaymentModal
        :is-open="isPaymentModalOpen"
        :team="selectedTeam"
        @close="isPaymentModalOpen = false"
        @payment-recorded="fetchTeams"
      />

      <TeamBillingHistoryModal
        :is-open="isHistoryModalOpen"
        :team="selectedTeam"
        @close="isHistoryModalOpen = false"
      />

      <ToggleTeamStatusModal
        :is-open="isToggleStatusModalOpen"
        :team="selectedTeam"
        @close="isToggleStatusModalOpen = false"
        @status-changed="fetchTeams"
      />
    </div>
  </AdminLayout>
</template>
