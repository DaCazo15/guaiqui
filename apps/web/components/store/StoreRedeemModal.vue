<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { BaseModal, BaseButton, PearlAmount } from '@guaiqui/ui'
import type { Product } from '~/composables/useCatalog'
import { useRedemptions } from '~/composables/useRedemptions'

const props = defineProps<{
  isOpen: boolean
  product: Product | null
  variant: string | null
  userBalance: number
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'redeemed', redemptionId: string): void
}>()

const { redeemProduct, actionLoading, error } = useRedemptions()

// Generador de clave de idempotencia persistente por intento de modal
const currentIdempotencyKey = ref<string>('')

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      currentIdempotencyKey.value = crypto.randomUUID()
    }
  }
)

const remainingBalance = computed(() => {
  if (!props.product) return 0
  return Math.max(0, props.userBalance - props.product.cost_pearls)
})

const handleConfirmRedeem = async () => {
  if (!props.product || actionLoading.value) return

  const result = await redeemProduct(
    props.product.id,
    props.variant || 'Única',
    currentIdempotencyKey.value
  )

  if (result.success && result.data) {
    emit('redeemed', result.data.redemption_id)
  }
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    title="Confirmación de Canje"
    size="md"
    @close="!actionLoading && emit('close')"
  >
    <div v-if="product" class="space-y-5">
      <!-- Resumen del Producto -->
      <div class="p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-lg space-y-2">
        <div class="flex items-start justify-between gap-3">
          <div>
            <h4 class="font-display font-bold text-lg text-guaiqui-text uppercase">
              {{ product.name }}
            </h4>
            <p v-if="variant" class="text-xs font-semibold text-guaiqui-primary mt-0.5">
              Variante seleccionada: <span class="uppercase">{{ variant }}</span>
            </p>
          </div>
          <PearlAmount :amount="product.cost_pearls" size="md" />
        </div>
      </div>

      <!-- Resumen de Balance -->
      <div class="space-y-2 text-sm border-t border-b border-guaiqui-border py-3">
        <div class="flex justify-between text-guaiqui-text-muted">
          <span>Tu saldo actual:</span>
          <span class="font-semibold text-guaiqui-text">{{ userBalance.toLocaleString('es-VE') }} perlitas</span>
        </div>
        <div class="flex justify-between text-guaiqui-accent">
          <span>Costo a debitar:</span>
          <span class="font-semibold">-{{ product.cost_pearls.toLocaleString('es-VE') }} perlitas</span>
        </div>
        <div class="flex justify-between text-guaiqui-text font-bold pt-1 border-t border-guaiqui-border/60">
          <span>Saldo tras el canje:</span>
          <span class="text-guaiqui-primary">{{ remainingBalance.toLocaleString('es-VE') }} perlitas</span>
        </div>
      </div>

      <!-- Mensaje de Error si ocurre -->
      <div v-if="error" class="p-3 bg-red-50 border border-red-200 rounded-guaiqui-md text-xs text-guaiqui-status-danger flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-base shrink-0"></i>
        <span>{{ error }}</span>
      </div>

      <!-- Aviso de entrega presencial -->
      <p class="text-xs text-guaiqui-text-muted leading-relaxed">
        Al confirmar, se descontarán las perlitas de tu billetera y se generará tu canje pendiente. Podrás ver el código QR una vez sea aprobado para su retiro presencial.
      </p>

      <!-- Botones de Acción -->
      <div class="flex items-center justify-end gap-3 pt-2">
        <BaseButton
          variant="outline"
          size="md"
          :disabled="actionLoading"
          @click="emit('close')"
        >
          Cancelar
        </BaseButton>

        <BaseButton
          variant="primary"
          size="md"
          :loading="actionLoading"
          :disabled="actionLoading || userBalance < product.cost_pearls || product.stock <= 0"
          @click="handleConfirmRedeem"
        >
          <i class="bi bi-check-circle-fill mr-1.5"></i>
          Confirmar Canje
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>
