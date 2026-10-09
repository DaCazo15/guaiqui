<script setup lang="ts">
import { ref } from 'vue'
import { BaseModal, BaseInput, BaseButton } from '@guaiqui/ui'

const props = defineProps<{
  open: boolean
  loading?: boolean
  error?: string | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm'): void
}>()

const confirmWord = ref('')

function handleConfirm() {
  if (confirmWord.value.trim() !== 'ELIMINAR') return
  emit('confirm')
}
</script>

<template>
  <BaseModal
    :open="open"
    title="Eliminar Cuenta de Fanático"
    @close="emit('close')"
  >
    <div class="space-y-4 text-sm text-guaiqui-text">
      <div v-if="error" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill shrink-0"></i>
        <span>{{ error }}</span>
      </div>

      <div class="p-4 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/20 rounded-guaiqui-lg space-y-2 text-xs">
        <h4 class="font-bold text-guaiqui-status-danger uppercase tracking-wider text-sm flex items-center gap-1.5">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>¿Estás seguro de que deseas eliminar tu cuenta?</span>
        </h4>
        <p class="text-guaiqui-text-muted">Esta acción desactiva tu acceso e invalida tu cuenta.</p>

        <div class="pt-2 border-t border-guaiqui-status-danger/20 space-y-1">
          <p class="font-semibold text-guaiqui-text">Lo que se elimina y anonimiza:</p>
          <ul class="list-disc list-inside text-guaiqui-text-muted space-y-0.5">
            <li>Tu nombre, avatar, fecha de nacimiento y municipio.</li>
            <li>Tus preferencias de notificación y metadatos de perfil.</li>
            <li>Tus accesos de inicio de sesión.</li>
          </ul>
        </div>

        <div class="pt-2 border-t border-guaiqui-status-danger/20 space-y-1">
          <p class="font-semibold text-guaiqui-text">Lo que se conserva (Integridad Contable):</p>
          <p class="text-guaiqui-text-muted">
            Los registros históricos de perlitas ganadas y canjes entregados se conservan de forma anonimizada para auditoría inmutable del programa.
          </p>
        </div>
      </div>

      <div class="space-y-2">
        <label class="block text-xs font-semibold text-guaiqui-text">
          Para confirmar, escribe la palabra <span class="text-guaiqui-status-danger font-bold select-all">ELIMINAR</span> abajo:
        </label>
        <BaseInput
          v-model="confirmWord"
          placeholder="Escribe ELIMINAR"
        />
      </div>

      <div class="flex gap-3 pt-2 justify-end">
        <BaseButton variant="outline" size="sm" @click="emit('close')">
          Cancelar
        </BaseButton>
        <BaseButton
          variant="danger"
          size="sm"
          :disabled="confirmWord.trim() !== 'ELIMINAR' || loading"
          :loading="loading"
          @click="handleConfirm"
        >
          <i class="bi bi-trash3-fill mr-1.5"></i>
          Eliminar Mi Cuenta Permanentemente
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>
