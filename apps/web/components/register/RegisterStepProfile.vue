<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseSelect, BaseButton } from '@guaiqui/ui'
import { MUNICIPALITIES } from '@guaiqui/shared'

const props = defineProps<{
  initialDisplayName?: string
  initialMunicipality?: string
  loading?: boolean
  error?: string | null
}>()

const emit = defineEmits<{
  (e: 'submit', payload: { displayName: string; municipality: string }): void
  (e: 'back'): void
}>()

const displayName = ref(props.initialDisplayName || '')
const municipality = ref(props.initialMunicipality || 'Mariño')
const localError = ref<string | null>(null)

const municipalityOptions = MUNICIPALITIES.map((m) => ({ value: m, label: m }))

function handleSubmit() {
  localError.value = null

  if (!displayName.value.trim()) {
    localError.value = 'Ingresa tu nombre para mostrar.'
    return
  }

  if (displayName.value.trim().length < 3) {
    localError.value = 'El nombre debe tener al menos 3 caracteres.'
    return
  }

  if (!municipality.value) {
    localError.value = 'Selecciona tu municipio o ubicación.'
    return
  }

  emit('submit', {
    displayName: displayName.value.trim(),
    municipality: municipality.value,
  })
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="space-y-4">
    <div v-if="localError || error" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ localError || error }}</span>
    </div>

    <div>
      <h3 class="text-lg font-semibold text-guaiqui-text mb-1">Tu Identidad de Fanático</h3>
      <p class="text-sm text-guaiqui-text-muted">
        Este nombre se mostrará en el Ranking de Fanáticos y al canjear tus premios.
      </p>
    </div>

    <BaseInput
      v-model="displayName"
      label="Nombre para mostrar *"
      placeholder="Ej. Pedro Guaiquerí"
      required
    />

    <BaseSelect
      v-model="municipality"
      label="Municipio / Ubicación *"
      :options="municipalityOptions"
      required
    />

    <div class="flex gap-3 pt-2">
      <BaseButton type="button" variant="outline" class="w-1/3" @click="emit('back')">
        <i class="bi bi-arrow-left mr-1"></i>
        Volver
      </BaseButton>
      <BaseButton type="submit" variant="primary" class="w-2/3" :loading="loading">
        Continuar (Opcional)
        <i class="bi bi-arrow-right ml-1"></i>
      </BaseButton>
    </div>
  </form>
</template>
