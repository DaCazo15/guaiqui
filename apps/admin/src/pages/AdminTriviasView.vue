<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface OptionForm {
  id?: string
  option_text: string
  is_correct: boolean
}

interface QuestionForm {
  id?: string
  question_text: string
  points: number
  order_index: number
  options: OptionForm[]
}

interface TriviaRow {
  id: string
  title: string
  description?: string
  status: 'draft' | 'published' | 'archived'
  starts_at: string
  ends_at: string
  time_limit_seconds: number
  target_segment_id?: string
  reward_rules: { per_correct_pearls?: number; perfect_score_bonus?: number }
  max_attempts: number
  created_at: string
}

interface SegmentOption {
  id: string
  name: string
}

const trivias = ref<TriviaRow[]>([])
const segments = ref<SegmentOption[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modal states
const showEditorModal = ref(false)
const showPreviewModal = ref(false)
const showDeleteModal = ref(false)
const selectedTrivia = ref<TriviaRow | null>(null)

// Form state
const triviaForm = ref({
  id: '',
  title: '',
  description: '',
  starts_at: '',
  ends_at: '',
  time_limit_seconds: 60,
  target_segment_id: '',
  per_correct_pearls: 50,
  perfect_score_bonus: 100,
  questions: [] as QuestionForm[]
})

const columns = [
  { key: 'title', label: 'Título' },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'starts_at', label: 'Inicio' },
  { key: 'ends_at', label: 'Fin' },
  { key: 'reward_rules', label: 'Recompensas' },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadTriviasAndSegments = async () => {
  loading.value = true
  try {
    const { data: triviaData, error: tErr } = await supabase
      .from('trivias')
      .select('*')
      .order('created_at', { ascending: false })

    if (tErr) throw tErr
    trivias.value = triviaData || []

    const { data: segmentData } = await supabase
      .from('segments')
      .select('id, name')
      .order('name', { ascending: true })

    segments.value = segmentData || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewTrivia = () => {
  selectedTrivia.value = null

  triviaForm.value = {
    id: '',
    title: '',
    description: '',
    starts_at: nowCaracasInput(),
    ends_at: nowCaracasInput(24 * 60 * 60 * 1000),
    time_limit_seconds: 60,
    target_segment_id: '',
    per_correct_pearls: 50,
    perfect_score_bonus: 100,
    questions: [
      {
        question_text: '',
        points: 50,
        order_index: 0,
        options: [
          { option_text: '', is_correct: true },
          { option_text: '', is_correct: false }
        ]
      }
    ]
  }
  showEditorModal.value = true
}

const editTrivia = async (t: TriviaRow) => {
  selectedTrivia.value = t
  triviaForm.value = {
    id: t.id,
    title: t.title,
    description: t.description || '',
    starts_at: isoToCaracasInput(t.starts_at),
    ends_at: isoToCaracasInput(t.ends_at),
    time_limit_seconds: t.time_limit_seconds || 60,
    target_segment_id: t.target_segment_id || '',
    per_correct_pearls: t.reward_rules?.per_correct_pearls ?? 50,
    perfect_score_bonus: t.reward_rules?.perfect_score_bonus ?? 100,
    questions: []
  }

  const { data: qData } = await supabase
    .from('trivia_questions')
    .select('*, options:trivia_options(*)')
    .eq('trivia_id', t.id)
    .order('order_index', { ascending: true })

  if (qData) {
    triviaForm.value.questions = qData.map((q: any) => ({
      id: q.id,
      question_text: q.question_text,
      points: q.points,
      order_index: q.order_index,
      options: (q.options || []).map((o: any) => ({
        id: o.id,
        option_text: o.option_text,
        is_correct: o.is_correct
      }))
    }))
  }

  showEditorModal.value = true
}

const addQuestion = () => {
  triviaForm.value.questions.push({
    question_text: '',
    points: 50,
    order_index: triviaForm.value.questions.length,
    options: [
      { option_text: '', is_correct: true },
      { option_text: '', is_correct: false }
    ]
  })
}

const removeQuestion = (index: number) => {
  triviaForm.value.questions.splice(index, 1)
}

const addOption = (qIndex: number) => {
  triviaForm.value.questions[qIndex].options.push({
    option_text: '',
    is_correct: false
  })
}

const removeOption = (qIndex: number, oIndex: number) => {
  triviaForm.value.questions[qIndex].options.splice(oIndex, 1)
}

const setCorrectOption = (qIndex: number, targetOptIndex: number) => {
  triviaForm.value.questions[qIndex].options.forEach((opt, idx) => {
    opt.is_correct = idx === targetOptIndex
  })
}

const saveTrivia = async () => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const payloadTrivia = {
      id: triviaForm.value.id || undefined,
      title: triviaForm.value.title,
      description: triviaForm.value.description,
      starts_at: caracasInputToISO(triviaForm.value.starts_at),
      ends_at: caracasInputToISO(triviaForm.value.ends_at),
      time_limit_seconds: Number(triviaForm.value.time_limit_seconds),
      target_segment_id: triviaForm.value.target_segment_id || null,
      reward_rules: {
        per_correct_pearls: Number(triviaForm.value.per_correct_pearls),
        perfect_score_bonus: Number(triviaForm.value.perfect_score_bonus)
      }
    }

    const { error } = await supabase.rpc('admin_upsert_trivia', {
      p_trivia: payloadTrivia,
      p_questions: triviaForm.value.questions
    })

    if (error) throw error
    successMessage.value = 'Trivia guardada correctamente.'
    showEditorModal.value = false
    await loadTriviasAndSegments()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const publishTrivia = async (id: string) => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_publish_trivia', { p_trivia_id: id })
    if (error) throw error
    successMessage.value = 'Trivia publicada exitosamente.'
    await loadTriviasAndSegments()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const duplicateTrivia = async (id: string) => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_duplicate_trivia', { p_trivia_id: id })
    if (error) throw error
    successMessage.value = 'Trivia duplicada correctamente.'
    await loadTriviasAndSegments()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const confirmDeleteTrivia = (t: TriviaRow) => {
  selectedTrivia.value = t
  showDeleteModal.value = true
}

const deleteTrivia = async () => {
  if (!selectedTrivia.value) return
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.from('trivias').delete().eq('id', selectedTrivia.value.id)
    if (error) throw error

    successMessage.value = `Trivia "${selectedTrivia.value.title}" eliminada correctamente.`
    showDeleteModal.value = false
    await loadTriviasAndSegments()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const previewTrivia = async (t: TriviaRow) => {
  selectedTrivia.value = t
  await editTrivia(t)
  showEditorModal.value = false
  showPreviewModal.value = true
}

onMounted(loadTriviasAndSegments)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-white">Gestión de Trivias</h1>
          <p class="text-sm text-slate-400">Crear, modificar, tiempo limitado, segmentar y eliminar trivias para los fanáticos.</p>
        </div>
        <BaseButton variant="primary" @click="openNewTrivia">
          <i class="bi bi-plus-lg mr-1.5"></i> Nueva Trivia
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="trivias" :loading="loading" empty-text="No hay trivias registradas">
        <template #cell-status="{ row }">
          <BaseBadge :variant="(row as any).status === 'published' ? 'success' : (row as any).status === 'draft' ? 'warning' : 'soft'">
            {{ (row as any).status === 'published' ? 'Publicada' : (row as any).status === 'draft' ? 'Borrador' : 'Archivada' }}
          </BaseBadge>
        </template>

        <template #cell-starts_at="{ row }">
          <span class="text-xs text-slate-400">{{ (row as any).starts_at ? formatCaracas((row as any).starts_at) : '' }}</span>
        </template>

        <template #cell-ends_at="{ row }">
          <span class="text-xs text-slate-400">{{ (row as any).ends_at ? formatCaracas((row as any).ends_at) : '' }}</span>
        </template>

        <template #cell-reward_rules="{ row }">
          <span class="text-xs font-mono font-bold text-emerald-400">
            +{{ (row as any).reward_rules?.per_correct_pearls || 0 }} / preg
          </span>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="previewTrivia(row as any)" class="p-1.5 text-sky-400 hover:bg-sky-950/60 rounded-lg transition-colors" title="Vista previa">
              <i class="bi bi-eye"></i>
            </button>
            <button @click="editTrivia(row as any)" class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar trivia">
              <i class="bi bi-pencil"></i>
            </button>
            <button v-if="(row as any).status === 'draft'" @click="publishTrivia((row as any).id)" class="p-1.5 text-emerald-400 hover:bg-emerald-950/60 rounded-lg transition-colors" title="Publicar trivia">
              <i class="bi bi-send"></i>
            </button>
            <button @click="duplicateTrivia((row as any).id)" class="p-1.5 text-purple-400 hover:bg-purple-950/60 rounded-lg transition-colors" title="Duplicar">
              <i class="bi bi-copy"></i>
            </button>
            <button @click="confirmDeleteTrivia(row as any)" class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors" title="Eliminar trivia">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Editor Modal -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Trivia" @close="showEditorModal = false" size="xl">
      <div class="space-y-6">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Título de la Trivia" v-model="triviaForm.title" placeholder="Ej: Trivia Clásico Oriental" />
          <BaseInput label="Fecha y Hora de Inicio — Hora de Caracas (GMT-4)" type="datetime-local" v-model="triviaForm.starts_at" />
          <BaseInput label="Fecha y Hora de Cierre — Hora de Caracas (GMT-4)" type="datetime-local" v-model="triviaForm.ends_at" />

          <BaseSelect
            label="Grupo / Segmento Objetivo de Fanáticos"
            v-model="triviaForm.target_segment_id"
            :options="[
              { value: '', label: 'Todos los fanáticos (Público)' },
              ...segments.map(s => ({ value: s.id, label: s.name }))
            ]"
          />

          <div class="grid grid-cols-2 gap-2">
            <BaseInput label="Perlitas x Acierto" type="number" v-model="triviaForm.per_correct_pearls" />
            <BaseInput label="Bono Perfecto" type="number" v-model="triviaForm.perfect_score_bonus" />
          </div>
        </div>

        <div class="space-y-4">
          <div class="flex items-center justify-between border-t border-slate-800 pt-4">
            <h3 class="font-bold text-white">Preguntas y Opciones</h3>
            <BaseButton size="sm" variant="secondary" @click="addQuestion">
              <i class="bi bi-plus-lg mr-1"></i> Agregar Pregunta
            </BaseButton>
          </div>

          <div v-for="(q, qIdx) in triviaForm.questions" :key="qIdx" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-3">
            <div class="flex items-center justify-between gap-3">
              <span class="text-xs font-bold uppercase text-emerald-400 font-mono">Pregunta #{{ qIdx + 1 }}</span>
              <button @click="removeQuestion(qIdx)" class="text-red-400 hover:text-red-300 text-xs">
                <i class="bi bi-trash"></i> Eliminar Pregunta
              </button>
            </div>

            <BaseInput v-model="q.question_text" placeholder="Texto de la pregunta" />

            <div class="space-y-2 pl-4 border-l-2 border-slate-800">
              <div class="text-xs font-semibold text-slate-400 flex items-center justify-between">
                <span>Opciones de respuesta</span>
                <button @click="addOption(qIdx)" class="text-emerald-400 hover:underline text-xs">+ Opción</button>
              </div>

              <div v-for="(opt, oIdx) in q.options" :key="oIdx" class="flex items-center gap-2">
                <input
                  type="radio"
                  :name="`correct-${qIdx}`"
                  :checked="opt.is_correct"
                  @change="setCorrectOption(qIdx, oIdx)"
                  class="accent-emerald-600 w-4 h-4 cursor-pointer"
                />
                <input
                  type="text"
                  v-model="opt.option_text"
                  placeholder="Opción de respuesta"
                  class="flex-1 bg-slate-900 border border-slate-700 text-sm text-slate-100 rounded-lg px-3 py-1.5 focus:border-emerald-500 focus:outline-none"
                />
                <button @click="removeOption(qIdx, oIdx)" class="text-slate-400 hover:text-red-400 text-sm">
                  <i class="bi bi-x-lg"></i>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveTrivia">Guardar Trivia</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Delete Modal -->
    <BaseModal v-if="showDeleteModal" :is-open="showDeleteModal" title="Eliminar Trivia" @close="showDeleteModal = false">
      <div class="space-y-4">
        <p class="text-sm text-slate-300">
          ¿Está seguro de eliminar permanentemente la trivia <strong class="text-white">{{ selectedTrivia?.title }}</strong>?
        </p>
        <div class="p-3 bg-red-950/60 border border-red-800 text-xs text-red-200 rounded-lg">
          Esta acción eliminará la trivia y sus preguntas de forma definitiva.
        </div>
      </div>
      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showDeleteModal = false">Cancelar</BaseButton>
          <BaseButton variant="danger" :loading="actionLoading" @click="deleteTrivia">Confirmar Eliminación</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Preview Modal -->
    <BaseModal v-if="showPreviewModal" :is-open="showPreviewModal" title="Vista Previa de Trivia" @close="showPreviewModal = false">
      <div class="space-y-6">
        <div class="p-4 rounded-xl bg-emerald-950/60 border border-emerald-800 text-emerald-200">
          <h3 class="text-xl font-bold font-title text-white">{{ triviaForm.title }}</h3>
          <p class="text-xs text-emerald-300 mt-1">Recompensa: +{{ triviaForm.per_correct_pearls }} perlitas por acierto</p>
        </div>

        <div class="space-y-4">
          <div v-for="(q, idx) in triviaForm.questions" :key="idx" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-3">
            <div class="font-semibold text-white text-sm">{{ idx + 1 }}. {{ q.question_text }}</div>
            <div class="space-y-2">
              <div v-for="(opt, oIdx) in q.options" :key="oIdx" class="p-3 rounded-lg bg-slate-900 border border-slate-800 text-sm text-slate-200 flex items-center justify-between">
                <span>{{ opt.option_text }}</span>
                <span v-if="opt.is_correct" class="text-xs text-emerald-400 font-mono font-bold">(Respuesta Correcta)</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </BaseModal>
  </AdminLayout>
</template>
