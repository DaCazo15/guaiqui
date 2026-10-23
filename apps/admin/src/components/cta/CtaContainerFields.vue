<script setup lang="ts">
import { BaseInput } from '@guaiqui/ui'
import type { CtaFormData } from './ctaTypes'

defineProps<{
  modelValue: CtaFormData
}>()
</script>

<template>
  <div class="space-y-4">
    <BaseInput
      v-model="modelValue.badge_text"
      label="Texto del Badge / Píldora Superior"
      placeholder="Ej: ¡Únete a la Tribu Hoy!"
    />

    <BaseInput
      v-model="modelValue.heading"
      label="Título Principal (Heading)"
      placeholder="Ej: ¿Listo para ganar tu primer premio?"
      required
    />

    <div class="flex flex-col gap-1.5">
      <label class="text-xs font-semibold text-slate-300">Subtítulo / Mensaje Descriptivo</label>
      <textarea
        v-model="modelValue.subtitle"
        rows="2"
        placeholder="Ej: El registro toma menos de 1 minuto y recibirás un bono de bienvenida..."
        class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
      ></textarea>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <BaseInput
        v-model="modelValue.button_text"
        label="Texto del Botón"
        placeholder="Ej: Crear mi Cuenta Gratis"
      />
      <BaseInput
        v-model="modelValue.button_url"
        label="Enlace / Ruta del Botón"
        placeholder="Ej: /registro"
      />
    </div>
  </div>
</template>
