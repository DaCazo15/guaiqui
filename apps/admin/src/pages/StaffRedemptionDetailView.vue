<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import StaffLayout from '../components/layout/StaffLayout.vue'
import QueueRejectModal from '../components/queue/QueueRejectModal.vue'
import ScannerIssueModal from '../components/scanner/ScannerIssueModal.vue'
import { formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

const route = useRoute()
const router = useRouter()
const redemptionId = route.params.id as string

const item = ref<any | null>(null)
const history = ref<any[]>([])
const scans = ref<any[]>([])
const isLoading = ref(true)

const isRejectModalOpen = ref(false)
const isIssueModalOpen = ref(false)

const fetchDetails = async () => {
  isLoading.value = true
  try {
    // 1. Fetch redemption details (joining profile & product without sensitive data)
    const { data: redData, error: redErr } = await supabase
      .from('redemptions')
      .select(`
        id, fan_id, product_id, variant, cost_pearls, status, code_hash, created_at, expires_at, delivered_at, delivered_by, note,
        profiles ( display_name, avatar_url ),
        products ( name, category, image_url )
      `)
      .eq('id', redemptionId)
      .single()

    if (redErr || !redData) {
      alert('Canje no encontrado')
      router.push('/staff/cola')
      return
    }

    const rd = redData as any
    const profileObj = Array.isArray(rd.profiles) ? rd.profiles[0] : rd.profiles
    const productObj = Array.isArray(rd.products) ? rd.products[0] : rd.products

    item.value = {
      ...rd,
      fan_display_name: profileObj?.display_name,
      fan_avatar_url: profileObj?.avatar_url,
      product_name: productObj?.name,
      product_category: productObj?.category
    }

    // 2. Fetch history timeline
    const { data: histData } = await supabase
      .from('redemption_history')
      .select('*')
      .eq('redemption_id', redemptionId)
      .order('created_at', { ascending: false })

    history.value = histData || []

    // 3. Fetch scan events
    const { data: scanData } = await supabase
      .from('scan_events')
      .select('*')
      .eq('code_hash', redData.code_hash)
      .order('created_at', { ascending: false })

    scans.value = scanData || []
  } finally {
    isLoading.value = false
  }
}

const handleDeliver = async () => {
  if (!item.value) return
  try {
    const isExperience = item.value.product_category === 'experience'
    const functionName = isExperience ? 'check_in_redemption' : 'deliver_redemption'

    const { error } = await supabase.rpc(functionName, {
      p_redemption_id: item.value.id,
      p_idempotency_key: `idemp_detail_${item.value.id}_${Date.now()}`,
      p_note: 'Entrega desde vista detallada de taquilla'
    })

    if (error) alert('Error al entregar: ' + error.message)
    else await fetchDetails()
  } catch (err: any) {
    alert('Error al realizar entrega: ' + err.message)
  }
}

const handleConfirmReject = async ({ reason }: { reason: string }) => {
  if (!item.value) return
  try {
    const { error } = await supabase.rpc('reject_redemption', {
      p_redemption_id: item.value.id,
      p_reason: reason
    })

    if (error) alert('Error al rechazar: ' + error.message)
    else {
      isRejectModalOpen.value = false
      await fetchDetails()
    }
  } catch (err: any) {
    alert('Error al rechazar: ' + err.message)
  }
}

const handleReportIssue = async ({ reason, note }: { reason: string; note: string }) => {
  if (!item.value) return
  try {
    const { error } = await supabase.rpc('report_redemption_issue', {
      p_redemption_id: item.value.id,
      p_reason: reason,
      p_note: note
    })

    if (error) alert('Error al reportar incidencia: ' + error.message)
    else {
      isIssueModalOpen.value = false
      await fetchDetails()
    }
  } catch (err: any) {
    alert('Error al registrar incidencia: ' + err.message)
  }
}

onMounted(() => {
  fetchDetails()
})
</script>

<template>
  <StaffLayout>
    <div class="space-y-6 max-w-4xl mx-auto">
      <!-- Top Nav Back button -->
      <div class="flex items-center gap-3">
        <button
          @click="router.back()"
          class="p-2 bg-slate-900 hover:bg-slate-800 text-slate-300 rounded-xl border border-slate-800 transition-colors shadow-xs"
        >
          <i class="bi bi-arrow-left text-lg"></i>
        </button>
        <div>
          <h1 class="text-xl sm:text-2xl font-bold font-title text-white">Detalle de Canje #{{ redemptionId.slice(0, 8) }}</h1>
          <p class="text-xs text-slate-400">Historial completo, escaneos y trazabilidad del canje</p>
        </div>
      </div>

      <div v-if="isLoading" class="p-12 text-center bg-slate-900 rounded-2xl border border-slate-800 shadow-xs">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-400 block mb-2"></i>
        <span class="text-xs text-slate-400">Cargando detalles...</span>
      </div>

      <div v-else-if="item" class="space-y-6">
        <!-- Main Card Info -->
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xs space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-800 pb-4">
            <div class="flex items-center gap-3">
              <div class="w-12 h-12 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-bold text-lg">
                {{ (item.fan_display_name || 'F')[0] }}
              </div>
              <div>
                <div class="text-xs text-slate-400 uppercase font-semibold">Fanático</div>
                <div class="font-bold text-base text-white">{{ item.fan_display_name }}</div>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <span class="px-3 py-1 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-full text-xs font-bold uppercase">
                {{ item.status }}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
            <div>
              <span class="text-slate-400 uppercase font-semibold block mb-0.5">Premio</span>
              <span class="font-bold text-white text-sm">{{ item.product_name }}</span>
            </div>

            <div>
              <span class="text-slate-400 uppercase font-semibold block mb-0.5">Variante</span>
              <span class="font-mono text-slate-300">{{ item.variant || '-' }}</span>
            </div>

            <div>
              <span class="text-slate-400 uppercase font-semibold block mb-0.5">Perlitas Canjeadas</span>
              <span class="font-bold text-emerald-400 text-sm">{{ item.cost_pearls }} perlitas</span>
            </div>
          </div>

          <!-- Actions if allowed -->
          <div class="pt-4 border-t border-slate-800 flex items-center justify-end gap-2">
            <button
              v-if="item.status === 'pending'"
              @click="isRejectModalOpen = true"
              class="px-4 py-2 bg-red-950/60 hover:bg-red-900/60 border border-red-800 text-red-300 text-xs font-semibold rounded-xl transition-colors"
            >
              Rechazar
            </button>

            <button
              v-if="item.status === 'approved' || item.status === 'scheduled'"
              @click="isIssueModalOpen = true"
              class="px-4 py-2 bg-amber-950/60 hover:bg-amber-900/60 border border-amber-800 text-amber-300 text-xs font-semibold rounded-xl transition-colors"
            >
              Reportar Incidencia
            </button>

            <button
              v-if="item.status === 'approved' || item.status === 'scheduled'"
              @click="handleDeliver"
              class="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-xl transition-colors"
            >
              Entregar / Marcar Asistencia
            </button>
          </div>
        </div>

        <!-- History Timeline -->
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xs space-y-4">
          <h3 class="font-bold text-sm text-white flex items-center gap-2">
            <i class="bi bi-clock-history text-emerald-400"></i>
            Historial de Cambios de Estado
          </h3>

          <div v-if="history.length === 0" class="text-xs text-slate-400 italic">No hay eventos registrados en el historial.</div>

          <div v-else class="space-y-3">
            <div
              v-for="h in history"
              :key="h.id"
              class="p-3 bg-slate-950/60 rounded-xl border border-slate-800 text-xs flex items-center justify-between"
            >
              <div>
                <span class="font-semibold text-slate-200 uppercase mr-2">{{ h.to_status }}</span>
                <span v-if="h.note" class="text-slate-400">({{ h.note }})</span>
              </div>

              <span class="font-mono text-[11px] text-slate-400">
                {{ formatCaracas(h.created_at) }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <QueueRejectModal
      :is-open="isRejectModalOpen"
      :redemption="item"
      @close="isRejectModalOpen = false"
      @confirm="handleConfirmReject"
    />

    <ScannerIssueModal
      :is-open="isIssueModalOpen"
      :redemption-id="item?.id || null"
      @close="isIssueModalOpen = false"
      @submit="handleReportIssue"
    />
  </StaffLayout>
</template>
