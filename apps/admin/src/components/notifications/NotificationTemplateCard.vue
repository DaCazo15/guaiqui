<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import type { NotificationTemplate } from '@guaiqui/shared'

const props = defineProps<{
  template: NotificationTemplate
}>()

const emit = defineEmits<{
  (e: 'edit', template: NotificationTemplate): void
  (e: 'toggle-active', template: NotificationTemplate): void
}>()

const categoryBadge = computed(() => {
  if (props.template.category === 'trivias') {
    return {
      label: 'Trivias & Retos',
      classes: 'bg-emerald-950 text-emerald-400 border-emerald-800/80',
      icon: 'bi-patch-question-fill'
    }
  }
  if (props.template.category === 'economy') {
    return {
      label: 'Economía & Perlitas',
      classes: 'bg-amber-950 text-amber-400 border-amber-800/80',
      icon: 'bi-coin'
    }
  }
  return {
    label: 'Sistema',
    classes: 'bg-slate-900 text-slate-300 border-slate-700',
    icon: 'bi-gear-fill'
  }
})

const previewParams = computed(() => {
  return {
    trivia_title: 'Tiro Ganador vs Trotamundos',
    reward_pearls: '150',
    trivia_type: 'Preguntas',
    hours_left: '4',
    pearls: '250',
    note: 'Verificación de seguridad completada'
  }
})

const previewBody = computed(() => {
  let text = props.template.body_template
  const params = previewParams.value
  for (const [key, val] of Object.entries(params)) {
    text = text.replace(new RegExp(`{${key}}`, 'g'), val)
  }
  return text
})
</script>

<template>
  <BaseCard class="p-5 bg-slate-900 border-slate-800 rounded-2xl flex flex-col justify-between space-y-4 hover:border-slate-700 transition">
    <div class="space-y-3">
      <!-- Header: Category & Status -->
      <div class="flex items-center justify-between gap-2 border-b border-slate-800 pb-3">
        <span :class="['px-2.5 py-1 rounded-lg text-xs font-bold border flex items-center gap-1.5', categoryBadge.classes]">
          <i :class="['bi', categoryBadge.icon]"></i>
          <span>{{ categoryBadge.label }}</span>
        </span>

        <button
          type="button"
          @click="emit('toggle-active', template)"
          :class="[
            'px-2.5 py-0.5 rounded-full text-xs font-bold flex items-center gap-1.5 transition border',
            template.is_active
              ? 'bg-emerald-900/40 text-emerald-300 border-emerald-700/60 hover:bg-emerald-900/60'
              : 'bg-slate-800 text-slate-400 border-slate-700 hover:bg-slate-700'
          ]"
          :title="template.is_active ? 'Clic para desactivar' : 'Clic para activar'"
        >
          <span :class="['w-1.5 h-1.5 rounded-full', template.is_active ? 'bg-emerald-400 animate-pulse' : 'bg-slate-500']"></span>
          <span>{{ template.is_active ? 'Activa' : 'Inactiva' }}</span>
        </button>
      </div>

      <!-- Description and ID -->
      <div>
        <div class="flex items-center gap-2">
          <code class="text-[11px] font-mono text-emerald-400/90 bg-emerald-950/60 px-1.5 py-0.5 rounded border border-emerald-800/40">
            {{ template.id }}
          </code>
        </div>
        <p class="text-xs text-slate-400 mt-1 leading-relaxed">
          {{ template.description }}
        </p>
      </div>

      <!-- Live Template Box -->
      <div class="p-3 bg-slate-950 rounded-xl border border-slate-800/80 space-y-1.5 text-left">
        <div class="text-[11px] uppercase tracking-wider font-bold text-slate-500 flex items-center gap-1">
          <i class="bi bi-chat-left-text"></i>
          <span>Mensaje de la Notificación</span>
        </div>
        <h4 class="text-xs font-bold text-white leading-snug">
          {{ template.title_template }}
        </h4>
        <p class="text-[11px] text-slate-300 leading-relaxed font-mono whitespace-pre-wrap">
          {{ template.body_template }}
        </p>
      </div>

      <!-- Available Variables -->
      <div v-if="template.available_variables && template.available_variables.length > 0" class="space-y-1.5 pt-1">
        <span class="text-[11px] font-bold text-slate-400 block">Variables dinámicas:</span>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="v in template.available_variables"
            :key="v.key"
            class="text-[10px] font-mono font-semibold px-2 py-0.5 rounded bg-slate-800 text-emerald-300 border border-slate-700"
            :title="v.label"
          >
            {{"{" + v.key + "}"}}
          </span>
        </div>
      </div>
    </div>

    <!-- Footer Action -->
    <div class="pt-3 border-t border-slate-800 flex items-center justify-between">
      <span class="text-[11px] text-slate-500">
        {{ template.is_active ? 'Enviándose automáticamente' : 'Pausada' }}
      </span>

      <BaseButton
        variant="primary"
        size="sm"
        @click="emit('edit', template)"
      >
        <i class="bi bi-pencil-square me-1"></i> Modificar Plantilla
      </BaseButton>
    </div>
  </BaseCard>
</template>
