<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface FlashQuestionItem {
  id?: string
  question: string
  option_a: string
  option_b: string
  option_c?: string | null
  option_d?: string | null
  correct_option: string
  order_index?: number
}

interface FlashChallengeRow {
  id: string
  title: string
  description?: string | null
  time_limit_seconds: number
  pearls_per_correct: number
  status: 'draft' | 'published' | 'closed' | 'archived'
  starts_at: string
  closes_at: string
  questions_count?: number
  total_attempts?: number
}

const items = ref<FlashChallengeRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showBulkImportModal = ref(false)
const selectedItem = ref<FlashChallengeRow | null>(null)

// Form
const form = ref({
  id: '',
  title: '',
  description: '',
  time_limit_seconds: 60,
  pearls_per_correct: 10,
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: '',
  questions: [] as FlashQuestionItem[]
})

const columns = [
  { key: 'title', label: 'Desafío Flash' },
  { key: 'settings', label: 'Configuración' },
  { key: 'questions_count', label: 'Preguntas', align: 'center' as const },
  { key: 'attempts', label: 'Participantes', align: 'center' as const },
  { key: 'closes_at', label: 'Cierre' },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data: challenges, error } = await supabase
      .from('flash_trivia_challenges')
      .select('*')
      .order('closes_at', { ascending: false })

    if (error) throw error

    const [qRes, aRes] = await Promise.all([
      supabase.from('flash_trivia_questions').select('challenge_id'),
      supabase.from('flash_trivia_attempts').select('challenge_id')
    ])

    const qCountMap = new Map<string, number>()
    qRes.data?.forEach((q: any) => {
      qCountMap.set(q.challenge_id, (qCountMap.get(q.challenge_id) || 0) + 1)
    })

    const aCountMap = new Map<string, number>()
    aRes.data?.forEach((a: any) => {
      aCountMap.set(a.challenge_id, (aCountMap.get(a.challenge_id) || 0) + 1)
    })

    items.value = (challenges || []).map((c: any) => ({
      ...c,
      questions_count: qCountMap.get(c.id) || 0,
      total_attempts: aCountMap.get(c.id) || 0
    }))
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar desafíos flash'
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  selectedItem.value = null
  const nowStr = nowCaracasInput()
  const defaultClose = nowCaracasInput(168)
  form.value = {
    id: '',
    title: '',
    description: '',
    time_limit_seconds: 60,
    pearls_per_correct: 10,
    status: 'published',
    starts_at: nowStr,
    closes_at: defaultClose,
    questions: [
      {
        question: '',
        option_a: '',
        option_b: '',
        option_c: '',
        option_d: '',
        correct_option: 'A'
      }
    ]
  }
  showEditorModal.value = true
}

const openEditModal = async (item: FlashChallengeRow) => {
  selectedItem.value = item
  actionLoading.value = true
  try {
    const { data: questions } = await supabase
      .from('flash_trivia_questions')
      .select('*')
      .eq('challenge_id', item.id)
      .order('order_index', { ascending: true })

    form.value = {
      id: item.id,
      title: item.title,
      description: item.description || '',
      time_limit_seconds: item.time_limit_seconds,
      pearls_per_correct: item.pearls_per_correct,
      status: item.status === 'draft' ? 'draft' : 'published',
      starts_at: isoToCaracasInput(item.starts_at),
      closes_at: isoToCaracasInput(item.closes_at),
      questions: (questions || []).map((q: any) => ({
        id: q.id,
        question: q.question,
        option_a: q.option_a,
        option_b: q.option_b,
        option_c: q.option_c || '',
        option_d: q.option_d || '',
        correct_option: q.correct_option
      }))
    }
    showEditorModal.value = true
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar preguntas'
  } finally {
    actionLoading.value = false
  }
}

const addQuestion = () => {
  form.value.questions.push({
    question: '',
    option_a: '',
    option_b: '',
    option_c: '',
    option_d: '',
    correct_option: 'A'
  })
}

const removeQuestion = (idx: number) => {
  form.value.questions.splice(idx, 1)
}

const saveItem = async () => {
  if (!form.value.title.trim()) {
    errorMessage.value = 'El título es obligatorio.'
    return
  }
  if (!form.value.questions.length) {
    errorMessage.value = 'Debes agregar al menos 1 pregunta.'
    return
  }

  for (let i = 0; i < form.value.questions.length; i++) {
    const q = form.value.questions[i]
    if (!q.question.trim() || !q.option_a.trim() || !q.option_b.trim()) {
      errorMessage.value = `Pregunta #${i + 1}: Completa el texto y al menos las opciones A y B.`
      return
    }
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const startsAtISO = form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString()
    const closesAtISO = form.value.closes_at ? caracasInputToISO(form.value.closes_at) : new Date(Date.now() + 7 * 86400000).toISOString()

    const questionsPayload = form.value.questions.map((q, idx) => ({
      id: q.id || null,
      question: q.question.trim(),
      option_a: q.option_a.trim(),
      option_b: q.option_b.trim(),
      option_c: q.option_c?.trim() || null,
      option_d: q.option_d?.trim() || null,
      correct_option: q.correct_option,
      order_index: idx + 1
    }))

    const { error } = await supabase.rpc('admin_upsert_flash_challenge', {
      p_id: form.value.id || null,
      p_title: form.value.title.trim(),
      p_description: form.value.description.trim() || null,
      p_time_limit_seconds: Number(form.value.time_limit_seconds) || 60,
      p_pearls_per_correct: Number(form.value.pearls_per_correct) || 10,
      p_status: form.value.status,
      p_starts_at: startsAtISO,
      p_closes_at: closesAtISO,
      p_questions: questionsPayload
    })

    if (error) throw error
    successMessage.value = form.value.id ? 'Desafío flash actualizado.' : 'Desafío flash creado con éxito.'
    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar desafío flash'
  } finally {
    actionLoading.value = false
  }
}

const deleteItem = async (item: FlashChallengeRow) => {
  if (!confirm(`¿Eliminar desafío flash "${item.title}"?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('flash_trivia_challenges').delete().eq('id', item.id)
    if (error) throw error
    successMessage.value = 'Desafío flash eliminado.'
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar'
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="space-y-4">
    <!-- Feedback alerts -->
    <div v-if="errorMessage" class="p-4 rounded-xl bg-red-950/40 border border-red-800/80 text-red-200 text-sm flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>
      <button @click="errorMessage = null" class="text-red-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>

    <div v-if="successMessage" class="p-4 rounded-xl bg-emerald-950/40 border border-emerald-800/80 text-emerald-200 text-sm flex items-center justify-between">
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-400"></i>
        <span>{{ successMessage }}</span>
      </div>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
    </div>

    <!-- Header Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
      <div>
        <h2 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-stopwatch-fill text-emerald-400"></i>
          Trivia Flash (Contrarreloj 60s)
        </h2>
        <p class="text-xs text-slate-400">
          Ráfaga de preguntas rápidas con cronómetro regresivo y recompensa acumulativa por cada respuesta correcta.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="outline" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openCreateModal">
          <i class="bi bi-plus-circle me-1"></i>
          Nuevo Desafío Flash
        </BaseButton>
      </div>
    </div>

    <!-- Table -->
    <BaseTable :columns="columns" :data="items" :loading="loading" empty-text="No hay desafíos flash creados.">
      <template #title="{ item }">
        <div class="font-bold text-white text-sm">{{ item.title }}</div>
        <div v-if="item.description" class="text-xs text-slate-400">{{ item.description }}</div>
      </template>

      <template #settings="{ item }">
        <div class="text-xs text-slate-300">
          <span class="font-mono text-emerald-400 font-bold">{{ item.time_limit_seconds }}s</span>
          <span class="text-slate-500 mx-1">•</span>
          <span class="text-amber-300 font-bold">+{{ item.pearls_per_correct }} perlitas/acierto</span>
        </div>
      </template>

      <template #questions_count="{ item }">
        <span class="px-2 py-0.5 rounded text-xs font-bold bg-slate-800 text-slate-300 border border-slate-700">
          {{ item.questions_count }} preguntas
        </span>
      </template>

      <template #attempts="{ item }">
        <span class="text-xs font-bold text-slate-300">
          <i class="bi bi-people-fill text-slate-400 me-1"></i> {{ item.total_attempts }}
        </span>
      </template>

      <template #closes_at="{ item }">
        <span class="text-xs text-slate-300 font-mono">{{ formatCaracas(item.closes_at) }}</span>
      </template>

      <template #status_badge="{ item }">
        <BaseBadge v-if="item.status === 'published'" variant="primary">Activo</BaseBadge>
        <BaseBadge v-else-if="item.status === 'closed'" variant="warning">Cerrado</BaseBadge>
        <BaseBadge v-else variant="soft">Borrador</BaseBadge>
      </template>

      <template #actions="{ item }">
        <div class="flex items-center justify-end gap-1.5">
          <button
            @click="openEditModal(item)"
            class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded transition"
            title="Editar y administrar preguntas"
          >
            <i class="bi bi-pencil-square"></i>
          </button>
          <button
            @click="deleteItem(item)"
            class="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-950/40 rounded transition"
            title="Eliminar"
          >
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Create/Edit Modal -->
    <BaseModal v-model="showEditorModal" :title="form.id ? 'Editar Desafío Flash' : 'Nuevo Desafío Flash'" size="lg">
      <div class="space-y-4 text-left max-h-[70vh] overflow-y-auto pe-1">
        <BaseInput v-model="form.title" label="Título del Desafío Flash *" placeholder="Ej: Flash: Leyendas de Guaiqueríes" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.time_limit_seconds" type="number" label="Tiempo Límite (Segundos) *" />
          <BaseInput v-model="form.pearls_per_correct" type="number" label="Perlitas por Respuesta Correcta *" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.starts_at" type="datetime-local" label="Fecha Inicio (Caracas)" />
          <BaseInput v-model="form.closes_at" type="datetime-local" label="Fecha Cierre (Caracas)" />
        </div>

        <BaseSelect
          v-model="form.status"
          label="Estado de Publicación"
          :options="[
            { value: 'published', label: 'Publicado (Activo)' },
            { value: 'draft', label: 'Borrador (Oculto)' },
          ]"
        />

        <!-- Questions Editor -->
        <div class="pt-4 border-t border-slate-800 space-y-3">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
              <i class="bi bi-list-check text-emerald-400"></i>
              Banco de Preguntas ({{ form.questions.length }})
            </h3>
            <BaseButton variant="outline" size="sm" @click="addQuestion">
              <i class="bi bi-plus me-1"></i> Agregar Pregunta
            </BaseButton>
          </div>

          <div v-for="(q, idx) in form.questions" :key="idx" class="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-2 relative group">
            <div class="flex items-center justify-between text-xs font-bold text-emerald-400">
              <span>Pregunta #{{ idx + 1 }}</span>
              <button v-if="form.questions.length > 1" @click="removeQuestion(idx)" class="text-red-400 hover:text-red-300">
                <i class="bi bi-trash"></i> Quitar
              </button>
            </div>

            <BaseInput v-model="q.question" label="Texto de la Pregunta *" placeholder="Ej: ¿En qué año se fundó el club?" />

            <div class="grid grid-cols-2 gap-2 text-xs">
              <BaseInput v-model="q.option_a" label="Opción A *" placeholder="1977" />
              <BaseInput v-model="q.option_b" label="Opción B *" placeholder="1980" />
              <BaseInput v-model="q.option_c" label="Opción C" placeholder="1975" />
              <BaseInput v-model="q.option_d" label="Opción D" placeholder="1983" />
            </div>

            <BaseSelect
              v-model="q.correct_option"
              label="Opción Correcta"
              :options="[
                { value: 'A', label: 'Opción A' },
                { value: 'B', label: 'Opción B' },
                { value: 'C', label: 'Opción C' },
                { value: 'D', label: 'Opción D' },
              ]"
            />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" size="sm" :loading="actionLoading" @click="saveItem">Guardar Desafío Flash</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      v-model:is-open="showBulkImportModal"
      type="flash_trivia"
      @imported="loadData"
    />
  </div>
</template>
