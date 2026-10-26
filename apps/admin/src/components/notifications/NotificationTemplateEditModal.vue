<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { BaseModal, BaseButton, BaseInput } from '@guaiqui/ui'
import type { NotificationTemplate } from '@guaiqui/shared'

const props = defineProps<{
  modelValue: boolean
  template: NotificationTemplate | null
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', payload: { id: string; title_template: string; body_template: string; is_active: boolean }): void
}>()

const localTitle = ref('')
const localBody = ref('')
const localIsActive = ref(true)
const bodyTextareaRef = ref<HTMLTextAreaElement | null>(null)

watch(() => props.template, (tmpl) => {
  if (tmpl) {
    localTitle.value = tmpl.title_template
    localBody.value = tmpl.body_template
    localIsActive.value = tmpl.is_active
  }
}, { immediate: true })

const insertVariable = (key: string) => {
  const token = `{${key}}`
  if (!bodyTextareaRef.value) {
    localBody.value += ` ${token}`
    return
  }
  const el = bodyTextareaRef.value
  const start = el.selectionStart || localBody.value.length
  const end = el.selectionEnd || localBody.value.length
  localBody.value = localBody.value.substring(0, start) + token + localBody.value.substring(end)
}

const mockValues: Record<string, string> = {
  trivia_title: 'Tiro Ganador vs Trotamundos',
  reward_pearls: '150',
  trivia_type: 'Preguntas',
  hours_left: '4',
  pearls: '250',
  note: 'Verificación de seguridad completada'
}

const livePreviewTitle = computed(() => {
  let text = localTitle.value || 'Título de notificación'
  for (const [key, val] of Object.entries(mockValues)) {
    text = text.replace(new RegExp(`{${key}}`, 'g'), val)
  }
  return text
})

const livePreviewBody = computed(() => {
  let text = localBody.value || 'Cuerpo del mensaje...'
  for (const [key, val] of Object.entries(mockValues)) {
    text = text.replace(new RegExp(`{${key}}`, 'g'), val)
  }
  return text
})

const handleSave = () => {
  if (!props.template) return
  emit('save', {
    id: props.template.id,
    title_template: localTitle.value,
    body_template: localBody.value,
    is_active: localIsActive.value
  })
}

const handleClose = () => {
  emit('update:modelValue', false)
}
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    title="Modificar Plantilla de Notificación"
    size="lg"
    @close="handleClose"
  >
    <div v-if="template" class="space-y-6 text-left">
      <!-- Info Header -->
      <div class="p-3 bg-slate-900 border border-slate-800 rounded-xl flex items-center justify-between gap-3">
        <div>
          <span class="text-[11px] font-mono text-emerald-400 font-bold uppercase tracking-wider block">
            ID: {{ template.id }}
          </span>
          <p class="text-xs text-slate-300 mt-0.5">
            {{ template.description }}
          </p>
        </div>
        <span class="text-xs font-bold text-slate-400 bg-slate-950 px-2.5 py-1 rounded-lg border border-slate-800 shrink-0">
          {{ template.category === 'trivias' ? 'Trivias' : 'Economía' }}
        </span>
      </div>

      <!-- Form Inputs -->
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-bold text-slate-300 mb-1">
            Título de la Notificación
          </label>
          <BaseInput
            v-model="localTitle"
            placeholder="Ej: ¡Nueva trivia disponible en La Tribu!"
            class="w-full"
          />
        </div>

        <div>
          <div class="flex items-center justify-between mb-1">
            <label class="block text-xs font-bold text-slate-300">
              Mensaje / Cuerpo de la Notificación
            </label>
            <span class="text-[11px] text-slate-500">
              Usa las variables dinámicas abajo
            </span>
          </div>

          <textarea
            ref="bodyTextareaRef"
            v-model="localBody"
            rows="4"
            class="w-full px-3 py-2 text-xs bg-slate-950 text-slate-100 rounded-xl border border-slate-700 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 font-mono resize-y"
            placeholder="Escribe el mensaje de la notificación..."
          ></textarea>
        </div>

        <!-- Available variables list with click-to-insert -->
        <div v-if="template.available_variables && template.available_variables.length > 0" class="space-y-2">
          <div class="flex items-center gap-1.5 text-xs text-slate-400 font-semibold">
            <i class="bi bi-magic text-emerald-400"></i>
            <span>Haz clic en una variable para insertarla en el mensaje:</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="v in template.available_variables"
              :key="v.key"
              type="button"
              @click="insertVariable(v.key)"
              class="px-2.5 py-1 text-xs font-mono font-bold rounded-lg bg-emerald-950/80 text-emerald-300 border border-emerald-700/60 hover:bg-emerald-800 hover:text-white transition flex items-center gap-1.5 shadow-sm"
              :title="`Insertar ${v.label}`"
            >
              <i class="bi bi-plus-circle text-[11px]"></i>
              <span>{{"{" + v.key + "}"}}</span>
              <span class="text-[10px] text-emerald-400/80 font-sans font-normal">({{ v.label }})</span>
            </button>
          </div>
        </div>

        <!-- Status Toggle -->
        <div class="pt-2 border-t border-slate-800 flex items-center justify-between">
          <div>
            <label class="text-xs font-bold text-white block">Estado de la Notificación</label>
            <span class="text-[11px] text-slate-400">Si está inactiva, el sistema no despachará esta notificación automática.</span>
          </div>
          <button
            type="button"
            @click="localIsActive = !localIsActive"
            :class="[
              'relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none',
              localIsActive ? 'bg-emerald-600' : 'bg-slate-700'
            ]"
          >
            <span
              :class="[
                'inline-block h-4 w-4 transform rounded-full bg-white transition-transform',
                localIsActive ? 'translate-x-6' : 'translate-x-1'
              ]"
            />
          </button>
        </div>
      </div>

      <!-- Live Device Preview -->
      <div class="space-y-2 pt-2 border-t border-slate-800">
        <span class="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
          <i class="bi bi-phone"></i>
          <span>Previsualización en Pantalla de Fanático</span>
        </span>

        <div class="p-4 bg-slate-950 border border-slate-800 rounded-2xl shadow-inner">
          <div class="bg-slate-900 border border-slate-700/80 rounded-xl p-3 flex items-start gap-3 shadow-lg">
            <div class="w-9 h-9 rounded-full bg-emerald-950 border border-emerald-600/50 flex items-center justify-center text-emerald-400 shrink-0">
              <i class="bi bi-bell-fill text-sm"></i>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between gap-2">
                <span class="text-[11px] font-bold text-white truncate">
                  {{ livePreviewTitle }}
                </span>
                <span class="text-[10px] text-slate-400 shrink-0">ahora</span>
              </div>
              <p class="text-[11px] text-slate-300 mt-0.5 leading-relaxed">
                {{ livePreviewBody }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-2">
        <BaseButton variant="outline" size="sm" @click="handleClose" :disabled="loading">
          Cancelar
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="handleSave" :disabled="loading || !localTitle || !localBody">
          <i class="bi bi-check2-circle me-1"></i>
          <span>{{ loading ? 'Guardando...' : 'Guardar Cambios' }}</span>
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>
