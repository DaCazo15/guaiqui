<script setup lang="ts">
import { BaseSelect, BaseInput } from '@guaiqui/ui'
import { BG_GRADIENT_OPTIONS, COLOR_PALETTE_PRESETS, type CtaFormData } from './ctaTypes'

const props = defineProps<{
  modelValue: CtaFormData
}>()

const selectPresetColor = (hex: string) => {
  props.modelValue.bg_color = hex
}
</script>

<template>
  <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
    <div class="flex items-center justify-between">
      <label class="text-xs font-semibold text-slate-300 flex items-center gap-1.5">
        <i class="bi bi-palette-fill text-emerald-400"></i>
        Color y Estilo de Fondo
      </label>
      <span class="text-[11px] text-slate-400">Escoge un color sólido o gradiente</span>
    </div>

    <!-- Quick Color Chips -->
    <div class="space-y-1.5">
      <span class="text-[11px] text-slate-400 font-medium">Colores sugeridos de la tribu:</span>
      <div class="flex flex-wrap items-center gap-2">
        <button
          v-for="preset in COLOR_PALETTE_PRESETS"
          :key="preset.value"
          type="button"
          :title="preset.label"
          @click="selectPresetColor(preset.value)"
          :class="[
            'h-7 px-2.5 rounded-lg text-xs font-medium border flex items-center gap-1.5 transition-all',
            modelValue.bg_color === preset.value
              ? 'ring-2 ring-emerald-400 border-white text-white font-semibold'
              : 'border-slate-700 text-slate-300 hover:border-slate-500'
          ]"
        >
          <span
            class="w-3.5 h-3.5 rounded-full border border-black/20 shrink-0"
            :style="{ background: preset.hex }"
          ></span>
          <span>{{ preset.label }}</span>
        </button>
      </div>
    </div>

    <!-- Custom Hex / Native Color Picker -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-slate-800">
      <div class="flex items-center gap-2">
        <div class="flex flex-col gap-1 flex-1">
          <label class="text-[11px] text-slate-400 font-medium">Color Personalizado (Hex)</label>
          <div class="flex items-center gap-2">
            <input
              type="color"
              :value="modelValue.bg_color || '#064e27'"
              @input="(e) => modelValue.bg_color = (e.target as HTMLInputElement).value"
              class="w-10 h-9 rounded-lg cursor-pointer bg-slate-800 border border-slate-700 p-0.5"
            />
            <input
              type="text"
              v-model="modelValue.bg_color"
              placeholder="#064E27 (o vacío para gradiente)"
              class="flex-1 rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-1.5 text-xs focus:border-guaiqui-primary focus:outline-hidden"
            />
          </div>
        </div>
      </div>

      <!-- Gradient fallback if no custom color selected -->
      <div v-if="!modelValue.bg_color" class="flex flex-col gap-1">
        <BaseSelect
          v-model="modelValue.bg_gradient"
          label="Gradiente Prediseñado"
          :options="BG_GRADIENT_OPTIONS"
        />
      </div>
      <div v-else class="flex items-center justify-end">
        <button
          type="button"
          @click="modelValue.bg_color = ''"
          class="text-xs text-slate-400 hover:text-emerald-400 inline-flex items-center gap-1"
        >
          <i class="bi bi-arrow-counterclockwise"></i> Volver a usar gradiente
        </button>
      </div>
    </div>
  </div>
</template>
