<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface FaqRow {
  id: string
  question: string
  answer: string
  order_index: number
  is_published: boolean
  created_at: string
}

const faqs = ref<FaqRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref({
  id: '',
  question: '',
  answer: '',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'question', label: 'Pregunta Frecuente' },
  { key: 'order_index', label: 'Orden', align: 'center' as const },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const asFaq = (r: unknown): FaqRow => r as FaqRow

const loadFaqs = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('faqs')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    faqs.value = (data as FaqRow[]) || []
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    question: '',
    answer: '',
    order_index: faqs.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: FaqRow) => {
  form.value = {
    id: row.id,
    question: row.question,
    answer: row.answer,
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const saveRow = async () => {
  if (!form.value.question || !form.value.answer) {
    errorMessage.value = 'La pregunta y la respuesta son obligatorias.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      question: form.value.question,
      answer: form.value.answer,
      order_index: form.value.order_index,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('faqs').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('faqs').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Pregunta frecuente guardada.'
    showModal.value = false
    await loadFaqs()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar esta pregunta frecuente?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('faqs').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'FAQ eliminada.'
    await loadFaqs()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadFaqs)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Preguntas Frecuentes (FAQ)</h1>
          <p class="text-sm text-slate-400 mt-1">Administrar preguntas y respuestas del centro de ayuda en la landing.</p>
        </div>
        <BaseButton variant="primary" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Nueva FAQ
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

      <BaseTable :columns="columns" :data="faqs" :loading="loading" empty-text="No hay preguntas frecuentes registradas">
        <template #cell-question="{ row }">
          <div>
            <p class="font-semibold text-white">{{ asFaq(row).question }}</p>
            <p class="text-xs text-slate-400 line-clamp-2 mt-0.5">{{ asFaq(row).answer }}</p>
          </div>
        </template>

        <template #cell-order_index="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ asFaq(row).order_index }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="asFaq(row).is_published ? 'success' : 'soft'">
            {{ asFaq(row).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(asFaq(row))" class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow(asFaq(row).id)" class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" title="Pregunta Frecuente" @close="showModal = false">
      <div class="space-y-4">
        <BaseInput label="Pregunta" v-model="form.question" placeholder="Ej: ¿Cómo gano perlitas?" />
        
        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Respuesta</label>
          <textarea
            v-model="form.answer"
            rows="4"
            class="w-full bg-slate-950 border border-slate-800 text-slate-100 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-emerald-500"
            placeholder="Escribe la respuesta explicativa..."
          ></textarea>
        </div>

        <BaseInput label="Orden de Aparición" type="number" v-model.number="form.order_index" />

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Web</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar FAQ</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
