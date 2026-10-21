<script setup lang="ts">
import { BaseModal, BaseButton } from '@guaiqui/ui'

defineProps<{
  isOpen: boolean
  heldAmount: number
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()
</script>

<template>
  <BaseModal :is-open="isOpen" title="Puntos en Revisión" @close="emit('close')">
    <div class="space-y-4">
      <div class="flex items-center gap-3 p-4 bg-amber-50 border border-amber-200 rounded-guaiqui-lg text-amber-900">
        <i class="bi bi-info-circle-fill text-2xl text-amber-600 shrink-0"></i>
        <div class="text-xs space-y-1">
          <p class="font-bold text-sm">
            Tienes {{ heldAmount.toLocaleString('es-VE') }} puntos en proceso de verificación
          </p>
          <p class="text-amber-800">
            Estos puntos corresponden a participaciones recientes en actividades especiales o trivias que están pasando por la validación automática de auditoría.
          </p>
        </div>
      </div>

      <p class="text-xs text-guaiqui-text-muted leading-relaxed">
        Una vez aprobadas por el sistema, se acreditarán automáticamente a tu saldo disponible para ser canjeadas por premios en la tienda.
      </p>

      <div class="pt-2 flex justify-end">
        <BaseButton variant="primary" size="sm" @click="emit('close')">
          Entendido
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>
