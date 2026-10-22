<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import ScannerCamera from '../components/scanner/ScannerCamera.vue'
import ScannerManualInput from '../components/scanner/ScannerManualInput.vue'
import ScannerResultCard from '../components/scanner/ScannerResultCard.vue'
import ScannerIssueModal from '../components/scanner/ScannerIssueModal.vue'
import { supabase } from '../lib/supabase'

const scanData = ref<any | null>(null)
const isVerifying = ref(false)
const isDelivering = ref(false)
const isOffline = ref(!navigator.onLine)

const isIssueModalOpen = ref(false)

const updateOnlineStatus = () => {
  isOffline.value = !navigator.onLine
}

onMounted(() => {
  window.addEventListener('online', updateOnlineStatus)
  window.addEventListener('offline', updateOnlineStatus)
})

onUnmounted(() => {
  window.removeEventListener('online', updateOnlineStatus)
  window.removeEventListener('offline', updateOnlineStatus)
})

// SECURITY DIRECTIVE: Never log p_code to console.log or persist in localStorage/URL!
const handleCodeScanned = async (code: string) => {
  if (isOffline.value) {
    alert('Dispositivo sin conexión a internet. Conéctese a una red para verificar el código.')
    return
  }

  isVerifying.value = true
  try {
    const { data, error } = await supabase.rpc('verify_redemption_code', {
      p_code: code,
      p_device: 'Taquilla Web Terminal'
    })

    if (error) {
      if (error.code === '42501' && error.message.includes('SCANNER_LOCKED')) {
        scanData.value = {
          result: 'ERROR',
          message: 'ESCÁNER BLOQUEADO: Se acumularon 10 intentos fallidos. Intente en 15 minutos.'
        }
      } else {
        scanData.value = {
          result: 'ERROR',
          message: error.message || 'Error al verificar el código.'
        }
      }
    } else {
      scanData.value = data
    }
  } catch (err: any) {
    scanData.value = {
      result: 'ERROR',
      message: err.message || 'Error inesperado de comunicación con la base de datos.'
    }
  } finally {
    isVerifying.value = false
  }
}

const handleDeliver = async () => {
  const redemptionId = scanData.value?.redemption_id || scanData.value?.id
  if (!scanData.value || !redemptionId) return
  isDelivering.value = true

  try {
    const idempotencyKey = `idemp_scan_${redemptionId}_${Date.now()}`
    const isExperience = scanData.value.is_experience ?? (scanData.value.product_category === 'experience')

    const functionName = isExperience ? 'check_in_redemption' : 'deliver_redemption'

    const { data, error } = await supabase.rpc(functionName, {
      p_redemption_id: redemptionId,
      p_idempotency_key: idempotencyKey,
      p_note: isExperience ? 'Asistencia registrada en escáner' : 'Entrega realizada en escáner de taquilla'
    })

    if (error) {
      alert('Error al procesar: ' + error.message)
    } else {
      scanData.value = {
        ...scanData.value,
        status: data.status,
        result: data.result,
        message: data.result === 'ALREADY_DELIVERED' ? 'Este premio ya había sido entregado anteriormente.' : 'Premio entregado exitosamente.'
      }
    }
  } catch (err: any) {
    alert('Error al realizar entrega: ' + err.message)
  } finally {
    isDelivering.value = false
  }
}

const handleReportIssue = async ({ reason, note }: { reason: string; note: string }) => {
  const redemptionId = scanData.value?.redemption_id || scanData.value?.id
  if (!scanData.value || !redemptionId) return

  try {
    const { error } = await supabase.rpc('report_redemption_issue', {
      p_redemption_id: redemptionId,
      p_reason: reason,
      p_note: note
    })

    if (error) {
      alert('Error al registrar incidencia: ' + error.message)
    } else {
      isIssueModalOpen.value = false
      scanData.value = {
        ...scanData.value,
        status: 'issue',
        result: 'ISSUE',
        message: 'Incidencia registrada en taquilla. El canje fue derivado al panel de incidencias.'
      }
    }
  } catch (err: any) {
    alert('Error al reportar incidencia: ' + err.message)
  }
}

const clearScan = () => {
  scanData.value = null
}
</script>

<template>
  <StaffLayout>
    <div class="space-y-6 max-w-4xl mx-auto">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 tracking-wide font-title">Escáner de Canjes QR</h1>
          <p class="text-xs text-slate-600">Verificación e inspección rápida de boletos y premios en taquilla</p>
        </div>

        <!-- Offline indicator -->
        <div v-if="isOffline" class="px-3 py-1 bg-red-100 border border-red-300 text-red-800 rounded-full text-xs font-semibold flex items-center gap-1.5 animate-pulse">
          <span class="w-2 h-2 rounded-full bg-red-600"></span>
          <span>Sin Conexión</span>
        </div>
      </div>

      <!-- Result Card (shown when scan result is available) -->
      <div v-if="isVerifying" class="p-12 text-center bg-white border border-slate-200 rounded-2xl shadow-xs">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-600 block mb-2"></i>
        <span class="text-xs text-slate-700 font-semibold">Validando código con Supabase...</span>
      </div>

      <ScannerResultCard
        v-else-if="scanData"
        :scan-data="scanData"
        :is-loading-action="isDelivering"
        @deliver="handleDeliver"
        @report-issue="isIssueModalOpen = true"
        @clear="clearScan"
      />

      <!-- Scanner controls (Camera + Manual) -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <ScannerCamera @scan="handleCodeScanned" />
        <ScannerManualInput @submit="handleCodeScanned" />
      </div>

      <!-- Issue Modal -->
      <ScannerIssueModal
        :is-open="isIssueModalOpen"
        :redemption-id="scanData?.redemption_id || scanData?.id || null"
        @close="isIssueModalOpen = false"
        @submit="handleReportIssue"
      />
    </div>
  </StaffLayout>
</template>
