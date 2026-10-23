<script setup lang="ts">
import { BaseModal, BaseButton, BaseInput, BaseSelect } from '@guaiqui/ui'
import CtaContainerFields from './CtaContainerFields.vue'
import CtaPhraseFields from './CtaPhraseFields.vue'
import CtaBackgroundControl from './CtaBackgroundControl.vue'
import CtaLivePreview from './CtaLivePreview.vue'
import { PLACEMENT_OPTIONS, type CtaFormData } from './ctaTypes'

defineProps<{
  show: boolean
  form: CtaFormData
  loading: boolean
  errorMessage: string | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save'): void
}>()
</script>

<template>
  <BaseModal
    :is-open="show"
    :title="form.id ? 'Editar Llamado a la Acción' : 'Nuevo Llamado a la Acción (CTA)'"
    size="xl"
    @close="emit('close')"
  >
    <div class="space-y-6">
      <!-- Error Alert -->
      <div v-if="errorMessage" class="p-3 bg-red-950/60 border border-red-800 text-red-200 text-sm rounded-lg flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- General Info: Name and Placement -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <BaseInput
          v-model="form.name"
          label="Nombre Descriptivo (Uso Interno)"
          placeholder="Ej: CTA Hero Registro, Frase Orgullo Tribu, etc."
          required
        />

        <BaseSelect
          v-model="form.placement"
          label="Ubicación en la Landing Page"
          :options="PLACEMENT_OPTIONS"
        />
      </div>

      <!-- Mode Selector -->
      <div>
        <label class="text-xs font-semibold text-slate-300 block mb-2">
          Modalidad del Llamado a la Acción
        </label>
        <div class="grid grid-cols-2 gap-3 p-1.5 bg-slate-900 border border-slate-800 rounded-xl">
          <button
            type="button"
            @click="form.type = 'container'"
            :class="[
              'py-2.5 px-4 rounded-lg text-sm font-semibold flex items-center justify-center gap-2 transition-all',
              form.type === 'container'
                ? 'bg-guaiqui-primary text-white shadow-md shadow-emerald-950/60'
                : 'text-slate-400 hover:text-white'
            ]"
          >
            <i class="bi bi-card-heading text-lg"></i>
            <span>Contenedor Completo</span>
          </button>

          <button
            type="button"
            @click="form.type = 'phrase'"
            :class="[
              'py-2.5 px-4 rounded-lg text-sm font-semibold flex items-center justify-center gap-2 transition-all',
              form.type === 'phrase'
                ? 'bg-guaiqui-primary text-white shadow-md shadow-emerald-950/60'
                : 'text-slate-400 hover:text-white'
            ]"
          >
            <i class="bi bi-chat-square-quote text-lg"></i>
            <span>Solo Frase</span>
          </button>
        </div>
      </div>

      <!-- Background Style Control (Solid color / Custom Hex / Gradient) -->
      <CtaBackgroundControl :model-value="form" />

      <!-- Mode Specific Fields -->
      <div class="p-4 bg-slate-900/60 border border-slate-800 rounded-xl">
        <CtaContainerFields
          v-if="form.type === 'container'"
          :model-value="form"
        />
        <CtaPhraseFields
          v-else
          :model-value="form"
        />
      </div>

      <!-- Live Preview -->
      <div class="space-y-2">
        <span class="text-xs font-semibold text-slate-300 block">
          Vista Previa en Tiempo Real:
        </span>
        <CtaLivePreview :cta="form" />
      </div>
    </div>

    <!-- Modal Footer Actions -->
    <template #footer>
      <div class="flex items-center justify-end gap-3 w-full">
        <BaseButton
          variant="secondary"
          size="md"
          :disabled="loading"
          @click="emit('close')"
        >
          Cancelar
        </BaseButton>

        <BaseButton
          variant="primary"
          size="md"
          :loading="loading"
          @click="emit('save')"
        >
          <i class="bi bi-check2-circle mr-1.5"></i>
          {{ form.id ? 'Guardar Cambios' : 'Crear CTA' }}
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
