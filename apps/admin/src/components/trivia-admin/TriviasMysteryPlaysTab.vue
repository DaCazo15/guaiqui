<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput, formatCaracas } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface MysteryPlayRow {
  id: string
  title: string
  description?: string | null
  video_url?: string | null
  cover_image_url?: string | null
  question: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  correct_option: string
  reveal_video_url?: string | null
  reward_pearls: number
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  total_votes?: number
  correct_votes?: number
}

const items = ref<MysteryPlayRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modals
const showEditorModal = ref(false)
const showBulkImportModal = ref(false)
const selectedItem = ref<MysteryPlayRow | null>(null)

// Form
const form = ref({
  id: '',
  title: '',
  description: '',
  video_url: '',
  cover_image_url: '',
  question: '',
  option_a: '',
  option_b: '',
  option_c: '',
  option_d: '',
  correct_option: 'A',
  reveal_video_url: '',
  reward_pearls: 50,
  status: 'published' as 'published' | 'draft',
  starts_at: '',
  closes_at: ''
})

const columns = [
  { key: 'title', label: 'Jugada / Pregunta' },
  { key: 'options_preview', label: 'Opciones de Desenlace' },
  { key: 'correct', label: 'Respuesta Correcta', align: 'center' as const },
  { key: 'closes_at', label: 'Cierre' },
  { key: 'reward', label: 'Premio', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const loadData = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('mystery_play_challenges')
      .select('*')
      .order('closes_at', { ascending: false })

    if (error) throw error

    const { data: votes } = await supabase.from('mystery_play_votes').select('challenge_id, is_correct')
    const voteMap = new Map<string, { total: number; correct: number }>()
    votes?.forEach((v: any) => {
      if (!voteMap.has(v.challenge_id)) voteMap.set(v.challenge_id, { total: 0, correct: 0 })
      const m = voteMap.get(v.challenge_id)!
      m.total++
      if (v.is_correct) m.correct++
    })

    items.value = (data || []).map((r: any) => {
      const v = voteMap.get(r.id) || { total: 0, correct: 0 }
      return {
        ...r,
        total_votes: v.total,
        correct_votes: v.correct
      }
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar jugadas'
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  selectedItem.value = null
  const nowStr = nowCaracasInput()
  const defaultClose = nowCaracasInput(72)
  form.value = {
    id: '',
    title: '',
    description: '',
    video_url: '',
    cover_image_url: '',
    question: '¿Cómo culminó esta jugada?',
    option_a: '',
    option_b: '',
    option_c: '',
    option_d: '',
    correct_option: 'A',
    reveal_video_url: '',
    reward_pearls: 50,
    status: 'published',
    starts_at: nowStr,
    closes_at: defaultClose
  }
  showEditorModal.value = true
}

const openEditModal = (item: MysteryPlayRow) => {
  selectedItem.value = item
  form.value = {
    id: item.id,
    title: item.title,
    description: item.description || '',
    video_url: item.video_url || '',
    cover_image_url: item.cover_image_url || '',
    question: item.question,
    option_a: item.option_a,
    option_b: item.option_b,
    option_c: item.option_c,
    option_d: item.option_d,
    correct_option: item.correct_option,
    reveal_video_url: item.reveal_video_url || '',
    reward_pearls: item.reward_pearls,
    status: item.status === 'draft' ? 'draft' : 'published',
    starts_at: isoToCaracasInput(item.starts_at),
    closes_at: isoToCaracasInput(item.closes_at)
  }
  showEditorModal.value = true
}

const saveItem = async () => {
  if (!form.value.title.trim() || !form.value.question.trim()) {
    errorMessage.value = 'El título y la pregunta son obligatorios.'
    return
  }
  if (!form.value.option_a.trim() || !form.value.option_b.trim() || !form.value.option_c.trim() || !form.value.option_d.trim()) {
    errorMessage.value = 'Debes completar las 4 opciones de desenlace.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const startsAtISO = form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString()
    const closesAtISO = form.value.closes_at ? caracasInputToISO(form.value.closes_at) : new Date(Date.now() + 3 * 86400000).toISOString()

    const { error } = await supabase.rpc('admin_upsert_mystery_play', {
      p_id: form.value.id || null,
      p_game_id: null,
      p_title: form.value.title.trim(),
      p_description: form.value.description.trim() || null,
      p_video_url: form.value.video_url.trim() || null,
      p_cover_image_url: form.value.cover_image_url.trim() || null,
      p_question: form.value.question.trim(),
      p_option_a: form.value.option_a.trim(),
      p_option_b: form.value.option_b.trim(),
      p_option_c: form.value.option_c.trim(),
      p_option_d: form.value.option_d.trim(),
      p_correct_option: form.value.correct_option,
      p_reveal_video_url: form.value.reveal_video_url.trim() || null,
      p_reward_pearls: Number(form.value.reward_pearls) || 50,
      p_status: form.value.status,
      p_starts_at: startsAtISO,
      p_closes_at: closesAtISO
    })

    if (error) throw error
    successMessage.value = form.value.id ? 'Jugada actualizada.' : 'Jugada misteriosa creada exitosamente.'
    showEditorModal.value = false
    await loadData()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar jugada misteriosa'
  } finally {
    actionLoading.value = false
  }
}

const deleteItem = async (item: MysteryPlayRow) => {
  if (!confirm(`¿Eliminar jugada "${item.title}"?`)) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('mystery_play_challenges').delete().eq('id', item.id)
    if (error) throw error
    successMessage.value = 'Jugada eliminada.'
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
          <i class="bi bi-play-circle-fill text-emerald-400"></i>
          «¿Qué pasó después?» (La Jugada Misteriosa)
        </h2>
        <p class="text-xs text-slate-400">
          Jugadas en video o imagen que se pausan en el momento cumbre. El fanático adivina el desenlace.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="outline" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i>
          Carga Masiva
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openCreateModal">
          <i class="bi bi-plus-circle me-1"></i>
          Nueva Jugada
        </BaseButton>
      </div>
    </div>

    <!-- Table -->
    <BaseTable :columns="columns" :data="items" :loading="loading" empty-text="No hay jugadas misteriosas creadas aún.">
      <template #title="{ item }">
        <div class="font-bold text-white text-sm">{{ item.title }}</div>
        <div class="text-xs text-emerald-400 flex items-center gap-1 mt-0.5">
          <i class="bi bi-question-circle"></i> {{ item.question }}
        </div>
      </template>

      <template #options_preview="{ item }">
        <div class="grid grid-cols-2 gap-1 text-[11px] max-w-xs">
          <div class="truncate text-slate-300"><span class="font-bold text-emerald-400">A:</span> {{ item.option_a }}</div>
          <div class="truncate text-slate-300"><span class="font-bold text-emerald-400">B:</span> {{ item.option_b }}</div>
          <div class="truncate text-slate-300"><span class="font-bold text-emerald-400">C:</span> {{ item.option_c }}</div>
          <div class="truncate text-slate-300"><span class="font-bold text-emerald-400">D:</span> {{ item.option_d }}</div>
        </div>
      </template>

      <template #correct="{ item }">
        <span class="w-6 h-6 rounded-full bg-emerald-600/30 text-emerald-400 font-bold border border-emerald-500/40 inline-flex items-center justify-center text-xs">
          {{ item.correct_option }}
        </span>
      </template>

      <template #closes_at="{ item }">
        <span class="text-xs text-slate-300 font-mono">{{ formatCaracas(item.closes_at) }}</span>
      </template>

      <template #reward="{ item }">
        <span class="inline-flex items-center gap-1 text-xs font-bold text-amber-300">
          <i class="bi bi-gem"></i> {{ item.reward_pearls }}
        </span>
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
            title="Editar"
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
    <BaseModal v-model="showEditorModal" :title="form.id ? 'Editar Jugada Misteriosa' : 'Nueva Jugada Misteriosa'">
      <div class="space-y-4 text-left">
        <BaseInput v-model="form.title" label="Título del Desafío *" placeholder="Ej: Penetración de David Cubillán" />
        <BaseInput v-model="form.question" label="Pregunta para el fanático *" placeholder="Ej: ¿Cómo culminó esta jugada en el 4to cuarto?" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.video_url" label="URL Video de la Jugada (Opcional)" placeholder="https://..." />
          <BaseInput v-model="form.cover_image_url" label="URL Imagen de Portada / Pausa (Opcional)" placeholder="https://..." />
        </div>

        <div class="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-2">
          <div class="text-xs font-bold text-slate-300 uppercase tracking-wider">Opciones de Respuesta</div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <BaseInput v-model="form.option_a" label="Opción A *" placeholder="Ej: Triple sobre la chicharra" />
            <BaseInput v-model="form.option_b" label="Opción B *" placeholder="Ej: Falta y vale (2+1)" />
            <BaseInput v-model="form.option_c" label="Opción C *" placeholder="Ej: Asistencia por la espalda" />
            <BaseInput v-model="form.option_d" label="Opción D *" placeholder="Ej: Bloqueo salvaje" />
          </div>

          <div class="pt-2 border-t border-slate-800">
            <BaseSelect
              v-model="form.correct_option"
              label="Opción Correcta Real *"
              :options="[
                { value: 'A', label: 'Opción A' },
                { value: 'B', label: 'Opción B' },
                { value: 'C', label: 'Opción C' },
                { value: 'D', label: 'Opción D' },
              ]"
            />
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.reveal_video_url" label="URL Video de Revelación (Opcional)" placeholder="Video completo con el desenlace" />
          <BaseInput v-model="form.reward_pearls" type="number" label="Perlitas de Recompensa" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput v-model="form.starts_at" type="datetime-local" label="Fecha Inicio (Caracas)" />
          <BaseInput v-model="form.closes_at" type="datetime-local" label="Fecha Cierre (Caracas)" />
        </div>

        <BaseSelect
          v-model="form.status"
          label="Estado de Publicación"
          :options="[
            { value: 'published', label: 'Publicado (Disponible)' },
            { value: 'draft', label: 'Borrador (Oculto)' },
          ]"
        />
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" size="sm" :loading="actionLoading" @click="saveItem">Guardar</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      v-model:is-open="showBulkImportModal"
      type="mystery_plays"
      @imported="loadData"
    />
  </div>
</template>
