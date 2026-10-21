<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from '#imports'
import QRCode from 'qrcode'
import { BaseCard, BaseBadge, BaseButton, BaseModal, PearlAmount } from '@guaiqui/ui'
import { useRedemptions } from '~/composables/useRedemptions'
import { useWallet } from '~/composables/useWallet'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const redemptionId = route.params.id as string

const {
  currentRedemption,
  redemptionHistory,
  qrData,
  loading,
  actionLoading,
  error,
  fetchRedemptionDetails,
  cancelRedemption,
} = useRedemptions()

const { fetchSummary } = useWallet()

const qrCanvas = ref<HTMLCanvasElement | null>(null)
const isCancelModalOpen = ref(false)
const copiedCode = ref(false)

const getStatusConfig = (status?: string) => {
  switch (status) {
    case 'pending':
      return {
        label: 'Pendiente de Aprobación',
        variant: 'warning' as const,
        icon: 'bi-hourglass-split',
        textClass: 'text-amber-800 bg-amber-50 border-amber-200',
      }
    case 'approved':
      return {
        label: 'Aprobado — Listo para Retiro',
        variant: 'success' as const,
        icon: 'bi-qr-code-scan',
        textClass: 'text-emerald-800 bg-emerald-50 border-emerald-200',
      }
    case 'scheduled':
      return {
        label: 'Agendado para Retiro',
        variant: 'info' as const,
        icon: 'bi-calendar-check-fill',
        textClass: 'text-blue-800 bg-blue-50 border-blue-200',
      }
    case 'delivered':
    case 'completed':
      return {
        label: 'Entregado Satisfactoriamente',
        variant: 'primary' as const,
        icon: 'bi-check-circle-fill',
        textClass: 'text-guaiqui-primary bg-guaiqui-primary-soft border-guaiqui-primary/30',
      }
    case 'cancelled':
      return {
        label: 'Cancelado & Reembolsado',
        variant: 'neutral' as const,
        icon: 'bi-x-circle',
        textClass: 'text-guaiqui-text-muted bg-guaiqui-surface border-guaiqui-border',
      }
    case 'rejected':
      return {
        label: 'Rechazado & Reembolsado',
        variant: 'danger' as const,
        icon: 'bi-slash-circle-fill',
        textClass: 'text-guaiqui-status-danger bg-red-50 border-red-200',
      }
    case 'issue':
      return {
        label: 'Con Incidencia',
        variant: 'danger' as const,
        icon: 'bi-exclamation-octagon-fill',
        textClass: 'text-guaiqui-status-danger bg-red-50 border-red-200',
      }
    case 'expired':
      return {
        label: 'Código Vencido',
        variant: 'neutral' as const,
        icon: 'bi-clock-history',
        textClass: 'text-guaiqui-text-subtle bg-guaiqui-surface border-guaiqui-border',
      }
    default:
      return {
        label: status || 'Desconocido',
        variant: 'neutral' as const,
        icon: 'bi-info-circle',
        textClass: 'text-guaiqui-text bg-guaiqui-surface border-guaiqui-border',
      }
  }
}

const formatDate = (dateStr?: string | null) => {
  if (!dateStr) return '—'
  try {
    const d = new Date(dateStr)
    return d.toLocaleDateString('es-VE', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return dateStr
  }
}

const renderQRCode = async () => {
  if (!qrData.value?.code || !qrCanvas.value) return
  try {
    await QRCode.toCanvas(qrCanvas.value, qrData.value.code, {
      width: 220,
      margin: 1.5,
      color: {
        dark: '#0B7A3B',
        light: '#FFFFFF',
      },
    })
  } catch (err) {
    console.error('Error al generar QR:', err)
  }
}

const handleCopyCode = async () => {
  if (!qrData.value?.code) return
  try {
    await navigator.clipboard.writeText(qrData.value.code)
    copiedCode.value = true
    setTimeout(() => {
      copiedCode.value = false
    }, 2000)
  } catch (err) {
    console.error('Error al copiar:', err)
  }
}

const handleConfirmCancel = async () => {
  if (!currentRedemption.value || actionLoading.value) return
  const res = await cancelRedemption(currentRedemption.value.id)
  if (res.success) {
    isCancelModalOpen.value = false
    await fetchSummary()
  }
}

onMounted(async () => {
  await fetchRedemptionDetails(redemptionId)
  if (['approved', 'scheduled'].includes(currentRedemption.value?.status || '')) {
    await nextTick()
    await renderQRCode()
  }
})

useSeoMeta({
  title: computed(() => currentRedemption.value ? `Canje: ${currentRedemption.value.products?.name} — Guaiqueríes` : 'Detalle de Canje'),
})
</script>

<template>
  <div class="space-y-6 max-w-4xl mx-auto">
    <!-- Breadcrumb / Back Link -->
    <NuxtLink
      to="/app/canjes"
      class="inline-flex items-center text-xs font-semibold text-guaiqui-text-muted hover:text-guaiqui-primary transition-colors"
    >
      <i class="bi bi-arrow-left mr-1.5"></i>
      Volver a Mis Canjes
    </NuxtLink>

    <!-- Loading State -->
    <div v-if="loading" class="py-20 text-center text-guaiqui-text-muted space-y-3">
      <div class="inline-block animate-spin text-3xl text-guaiqui-primary">
        <i class="bi bi-arrow-repeat"></i>
      </div>
      <p class="text-sm font-medium">Cargando información del canje...</p>
    </div>

    <!-- Not Found -->
    <div v-else-if="!currentRedemption" class="py-20 text-center space-y-4">
      <div class="w-16 h-16 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-gift"></i>
      </div>
      <h2 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
        Canje no encontrado
      </h2>
      <NuxtLink to="/app/canjes">
        <BaseButton variant="primary" size="sm">Regresar al Listado</BaseButton>
      </NuxtLink>
    </div>

    <!-- Main Content -->
    <div v-else class="space-y-8">
      <!-- Header Card -->
      <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
        <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
          <div class="space-y-2">
            <span :class="['inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider border', getStatusConfig(currentRedemption.status).textClass]">
              <i :class="['bi', getStatusConfig(currentRedemption.status).icon]"></i>
              {{ getStatusConfig(currentRedemption.status).label }}
            </span>

            <h1 class="font-display font-bold text-3xl text-guaiqui-text uppercase">
              {{ currentRedemption.products?.name || 'Premio Oficial' }}
            </h1>

            <div class="flex flex-wrap items-center gap-3 text-xs text-guaiqui-text-muted">
              <span v-if="currentRedemption.variant" class="bg-guaiqui-surface px-2.5 py-1 rounded-guaiqui-md border border-guaiqui-border font-semibold text-guaiqui-text">
                Talla / Variante: <strong class="uppercase text-guaiqui-primary">{{ currentRedemption.variant }}</strong>
              </span>
              <span>Solicitado: <strong>{{ formatDate(currentRedemption.created_at) }}</strong></span>
            </div>
          </div>

          <!-- Cost & Action -->
          <div class="flex flex-col sm:items-end gap-3 shrink-0">
            <PearlAmount :amount="currentRedemption.cost_pearls" size="lg" show-label />

            <!-- Cancel Button (Only if pending) -->
            <BaseButton
              v-if="currentRedemption.status === 'pending'"
              variant="outline"
              size="sm"
              class="text-guaiqui-status-danger hover:border-guaiqui-status-danger"
              @click="isCancelModalOpen = true"
            >
              <i class="bi bi-x-circle mr-1.5"></i>
              Cancelar Solicitud
            </BaseButton>
          </div>
        </div>
      </BaseCard>

      <!-- QR Code or Pending Notice Section -->
      <div class="grid grid-cols-1 md:grid-cols-12 gap-6 items-start">
        <!-- QR / Status Panel -->
        <div class="md:col-span-6">
          <!-- State: Approved / Scheduled -> QR Available -->
          <BaseCard
            v-if="['approved', 'scheduled'].includes(currentRedemption.status) && qrData"
            class="p-6 bg-white border-guaiqui-primary/30 rounded-guaiqui-xl shadow-guaiqui-md text-center space-y-4 relative overflow-hidden"
          >
            <div class="space-y-1">
              <span class="text-xs font-bold text-guaiqui-primary uppercase tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
                Pase de Retiro Digital
              </span>
              <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase pt-2">
                Código QR de Retiro
              </h3>
              <p class="text-xs text-guaiqui-text-muted">
                Presenta este código al personal autorizado en el estadio.
              </p>
            </div>

            <!-- Canvas Container -->
            <div class="p-4 bg-white border-2 border-dashed border-guaiqui-border rounded-guaiqui-xl inline-block shadow-inner mx-auto">
              <canvas ref="qrCanvas" class="mx-auto rounded-guaiqui-lg"></canvas>
            </div>

            <!-- Alphanumeric Code Manual Fallback -->
            <div class="space-y-1.5 pt-1">
              <p class="text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted">
                Código para validación manual
              </p>
              <div class="flex items-center justify-center gap-2">
                <code class="px-3.5 py-1.5 bg-guaiqui-surface font-mono font-bold text-base text-guaiqui-primary rounded-guaiqui-md border border-guaiqui-border tracking-wider">
                  {{ qrData.code }}
                </code>
                <button
                  type="button"
                  class="p-2 rounded-guaiqui-md bg-white border border-guaiqui-border text-guaiqui-text hover:text-guaiqui-primary hover:border-guaiqui-primary transition-colors cursor-pointer shadow-xs"
                  title="Copiar código"
                  @click="handleCopyCode"
                >
                  <i :class="['bi', copiedCode ? 'bi-check-lg text-emerald-600' : 'bi-clipboard']"></i>
                </button>
              </div>
              <p v-if="copiedCode" class="text-[11px] font-semibold text-emerald-600">
                ¡Código copiado al portapapeles!
              </p>
            </div>

            <div v-if="qrData.expires_at" class="text-[11px] text-guaiqui-text-muted border-t border-guaiqui-border pt-3">
              Válido hasta: <strong class="text-guaiqui-text">{{ formatDate(qrData.expires_at) }}</strong>
            </div>
          </BaseCard>

          <!-- State: Pending -> Informational card -->
          <BaseCard
            v-else-if="currentRedemption.status === 'pending'"
            class="p-6 bg-gradient-to-br from-amber-50/50 via-white to-white border-amber-200 rounded-guaiqui-xl shadow-guaiqui-sm space-y-4"
          >
            <div class="w-12 h-12 rounded-full bg-amber-100 text-amber-600 flex items-center justify-center text-2xl mx-auto">
              <i class="bi bi-hourglass-split"></i>
            </div>
            <div class="text-center space-y-2">
              <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
                Canje en Revisión
              </h3>
              <p class="text-xs text-guaiqui-text-muted leading-relaxed">
                Tu solicitud está siendo procesada por el personal del equipo. Tan pronto como sea aprobada, se habilitará tu <strong>Código QR</strong> para el retiro presencial.
              </p>
            </div>

            <div class="p-3 bg-amber-50 rounded-guaiqui-md border border-amber-200 text-xs text-amber-900 flex items-center gap-2">
              <i class="bi bi-info-circle-fill text-amber-600 shrink-0"></i>
              <span>Puedes cancelar esta solicitud en cualquier momento antes de ser aprobada y tus puntos serán reembolsados inmediatamente.</span>
            </div>
          </BaseCard>

          <!-- State: Delivered / Completed -->
          <BaseCard
            v-else-if="['delivered', 'completed'].includes(currentRedemption.status)"
            class="p-6 bg-white border-guaiqui-primary/30 rounded-guaiqui-xl shadow-guaiqui-sm text-center space-y-3"
          >
            <div class="w-14 h-14 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
              <i class="bi bi-bag-check-fill"></i>
            </div>
            <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
              ¡Premio Entregado!
            </h3>
            <p class="text-xs text-guaiqui-text-muted leading-relaxed">
              Este premio fue entregado el {{ formatDate(currentRedemption.delivered_at) }}. ¡Esperamos que lo disfrutes y sigas apoyando a la Tribu!
            </p>
          </BaseCard>

          <!-- State: Cancelled / Rejected -->
          <BaseCard
            v-else
            class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm text-center space-y-3"
          >
            <div class="w-12 h-12 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-2xl mx-auto">
              <i class="bi bi-x-circle"></i>
            </div>
            <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
              Canje {{ currentRedemption.status === 'cancelled' ? 'Cancelado' : 'Rechazado' }}
            </h3>
            <p class="text-xs text-guaiqui-text-muted leading-relaxed">
              Los <strong>{{ currentRedemption.cost_pearls.toLocaleString('es-VE') }} puntos</strong> fueron devueltos íntegramente a tu saldo disponible en la billetera.
            </p>
          </BaseCard>
        </div>

        <!-- Timeline / History Panel -->
        <div class="md:col-span-6 space-y-4">
          <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
            <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase flex items-center gap-2">
              <i class="bi bi-clock-history text-guaiqui-primary"></i>
              Línea de Tiempo del Canje
            </h3>

            <!-- Timeline items -->
            <div class="space-y-4 relative before:absolute before:inset-0 before:left-3.5 before:w-0.5 before:bg-guaiqui-border">
              <div
                v-for="(h, idx) in redemptionHistory"
                :key="h.id"
                class="relative flex items-start gap-3 pl-8"
              >
                <!-- Dot indicator -->
                <div :class="['absolute left-2 top-1.5 w-3.5 h-3.5 rounded-full border-2 border-white -translate-x-1/2', idx === redemptionHistory.length - 1 ? 'bg-guaiqui-primary ring-2 ring-guaiqui-primary/30' : 'bg-guaiqui-border']"></div>

                <div class="space-y-0.5 flex-1">
                  <div class="flex items-center justify-between gap-2">
                    <p class="text-xs font-bold uppercase text-guaiqui-text">
                      {{ getStatusConfig(h.new_status).label }}
                    </p>
                    <span class="text-[11px] text-guaiqui-text-muted">
                      {{ formatDate(h.created_at) }}
                    </span>
                  </div>
                  <p v-if="h.note" class="text-xs text-guaiqui-text-muted">
                    {{ h.note }}
                  </p>
                </div>
              </div>
            </div>
          </BaseCard>

          <!-- Info Box: Ubicación de retiro -->
          <BaseCard class="p-4 bg-guaiqui-surface border-guaiqui-border rounded-guaiqui-lg text-xs space-y-1.5 text-guaiqui-text-muted">
            <p class="font-bold text-guaiqui-text flex items-center gap-1.5">
              <i class="bi bi-geo-alt-fill text-guaiqui-primary"></i>
              Lugar de Entrega
            </p>
            <p>
              Gimnasio Ciudad de La Asunción, Stand de Atención al Fanático Guaiquerí.
            </p>
          </BaseCard>
        </div>
      </div>
    </div>

    <!-- Modal Cancelar Canje -->
    <BaseModal
      :is-open="isCancelModalOpen"
      title="Cancelar Solicitud de Canje"
      @close="!actionLoading && (isCancelModalOpen = false)"
    >
      <div v-if="currentRedemption" class="space-y-4">
        <p class="text-xs text-guaiqui-text-muted leading-relaxed">
          ¿Estás seguro de que deseas cancelar tu solicitud de canje para <strong class="text-guaiqui-text">{{ currentRedemption.products?.name }}</strong>?
        </p>

        <div class="p-3.5 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-md space-y-1 text-xs">
          <div class="flex justify-between text-guaiqui-text-muted">
            <span>Puntos a reembolsar:</span>
            <span class="font-bold text-guaiqui-primary">+{{ currentRedemption.cost_pearls.toLocaleString('es-VE') }} puntos</span>
          </div>
          <p class="text-[11px] text-guaiqui-text-muted">
            El reembolso se reflejará inmediatamente en tu saldo disponible.
          </p>
        </div>

        <div v-if="error" class="p-3 bg-red-50 text-xs text-guaiqui-status-danger rounded-guaiqui-md">
          {{ error }}
        </div>

        <div class="flex items-center justify-end gap-3 pt-2">
          <BaseButton
            variant="outline"
            size="sm"
            :disabled="actionLoading"
            @click="isCancelModalOpen = false"
          >
            No cancelar
          </BaseButton>

          <BaseButton
            variant="danger"
            size="sm"
            :loading="actionLoading"
            :disabled="actionLoading"
            @click="handleConfirmCancel"
          >
            Confirmar Cancelación
          </BaseButton>
        </div>
      </div>
    </BaseModal>
  </div>
</template>
