<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import QueueHeader from '../components/queue/QueueHeader.vue'
import QueueTable from '../components/queue/QueueTable.vue'
import QueueRejectModal from '../components/queue/QueueRejectModal.vue'
import { supabase } from '../lib/supabase'

import type { RealtimeChannel } from '@supabase/supabase-js'

export interface QueueItem {
  id: string
  fan_display_name?: string
  product_name: string
  variant?: string | null
  cost_pearls: number
  status: string
  created_at: string
}

const items = ref<QueueItem[]>([])
const isLoading = ref(true)
const activeTab = ref('all')
const searchQuery = ref('')
const isRealtimeConnected = ref(false)

const selectedRejectItem = ref<QueueItem | null>(null)
const isRejectModalOpen = ref(false)

let realtimeChannel: RealtimeChannel | null = null

const fetchQueue = async () => {
  isLoading.value = true
  try {
    const statusParam = activeTab.value === 'all' ? null : activeTab.value
    const searchParam = searchQuery.value.trim() || null

    const { data, error } = await supabase.rpc('staff_redemption_queue', {
      p_status: statusParam,
      p_search: searchParam,
      p_cursor: null,
      p_limit: 50
    })

    if (error) {
      console.error('Error fetching queue:', error)
      items.value = []
    } else {
      items.value = (data as QueueItem[]) || []
    }
  } finally {
    isLoading.value = false
  }
}

const setupRealtime = () => {
  realtimeChannel = supabase
    .channel('staff_queue_realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'redemptions' }, () => {
      fetchQueue()
    })
    .subscribe((status) => {
      isRealtimeConnected.value = status === 'SUBSCRIBED'
    })
}

const handleApprove = async (item: QueueItem) => {
  try {
    const { error } = await supabase.rpc('approve_redemption', {
      p_redemption_id: item.id
    })
    if (error) {
      alert('Error al aprobar: ' + error.message)
    } else {
      await fetchQueue()
    }
  } catch (err: unknown) {
    alert('Error al aprobar el canje: ' + (err instanceof Error ? err.message : String(err)))
  }
}

const openRejectModal = (item: QueueItem) => {
  selectedRejectItem.value = item
  isRejectModalOpen.value = true
}

const handleConfirmReject = async ({ reason }: { reason: string; note: string }) => {
  if (!selectedRejectItem.value) return
  try {
    const { error } = await supabase.rpc('reject_redemption', {
      p_redemption_id: selectedRejectItem.value.id,
      p_reason: reason
    })

    if (error) {
      alert('Error al rechazar: ' + error.message)
    } else {
      isRejectModalOpen.value = false
      selectedRejectItem.value = null
      await fetchQueue()
    }
  } catch (err: unknown) {
    alert('Error al procesar rechazo: ' + (err instanceof Error ? err.message : String(err)))
  }
}

const handleDeliver = async (item: QueueItem) => {
  try {
    const { error } = await supabase.rpc('deliver_redemption', {
      p_redemption_id: item.id,
      p_idempotency_key: `idemp_queue_${Date.now()}`,
      p_note: 'Entrega desde cola de taquilla'
    })

    if (error) {
      alert('Error al entregar: ' + error.message)
    } else {
      await fetchQueue()
    }
  } catch (err: unknown) {
    alert('Error al procesar entrega: ' + (err instanceof Error ? err.message : String(err)))
  }
}

onMounted(() => {
  fetchQueue()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeChannel) {
    supabase.removeChannel(realtimeChannel)
  }
})
</script>

<template>
  <StaffLayout>
    <QueueHeader
      v-model:activeTab="activeTab"
      v-model:searchQuery="searchQuery"
      :is-realtime-connected="isRealtimeConnected"
      :is-loading="isLoading"
      @update:active-tab="fetchQueue"
      @update:search-query="fetchQueue"
      @refresh="fetchQueue"
    />

    <QueueTable
      :items="items"
      :is-loading="isLoading"
      @approve="handleApprove"
      @reject="openRejectModal"
      @deliver="handleDeliver"
    />

    <QueueRejectModal
      :is-open="isRejectModalOpen"
      :redemption="selectedRejectItem"
      @close="isRejectModalOpen = false"
      @confirm="handleConfirmReject"
    />
  </StaffLayout>
</template>
