<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface PolicyRow {
  id: string
  slug: 'terminos' | 'privacidad' | 'perlitas' | 'canjes'
  version: string
  content_markdown: string
  published_at: string
  is_active: boolean
  created_at: string
}

const policies = ref<PolicyRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const selectedSlug = ref<'terminos' | 'privacidad' | 'perlitas' | 'canjes'>('terminos')

const showPublishModal = ref(false)
const form = ref({
  slug: 'terminos' as 'terminos' | 'privacidad' | 'perlitas' | 'canjes',
  version: 'v1.1',
  content_markdown: ''
})

const policyLabels: Record<string, string> = {
  terminos: 'Términos y Condiciones',
  privacidad: 'Política de Privacidad',
  perlitas: 'Reglas de Perlitas',
  canjes: 'Políticas de Canje'
}

const columns = [
  { key: 'slug', label: 'Documento' },
  { key: 'version', label: 'Versión' },
  { key: 'published_at', label: 'Publicado el' },
  { key: 'is_active', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadPolicies = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('policy_documents')
      .select('*')
      .order('published_at', { ascending: false })

    if (error) throw error
    policies.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewVersion = (slug: 'terminos' | 'privacidad' | 'perlitas' | 'canjes') => {
  const active = policies.value.find((p) => p.slug === slug && p.is_active)
  let nextVer = 'v1.1'
  if (active?.version) {
    const parts = active.version.replace('v', '').split('.')
    if (parts.length >= 2) {
      const minor = parseInt(parts[1], 10) + 1
      nextVer = `v${parts[0]}.${minor}`
    }
  }

  form.value = {
    slug,
    version: nextVer,
    content_markdown: active?.content_markdown || `# ${policyLabels[slug]}\n\nContenido de la política en Markdown...`
  }
  showPublishModal.value = true
}

const viewContent = (row: PolicyRow) => {
  form.value = {
    slug: row.slug,
    version: row.version,
    content_markdown: row.content_markdown
  }
  showPublishModal.value = true
}

const publishNewVersion = async () => {
  if (!form.value.version || !form.value.content_markdown) {
    errorMessage.value = 'La versión y el contenido en Markdown son obligatorios.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_publish_policy', {
      p_slug: form.value.slug,
      p_version: form.value.version,
      p_content: form.value.content_markdown
    })

    if (error) throw error

    successMessage.value = `Nueva versión ${form.value.version} de "${policyLabels[form.value.slug]}" publicada con éxito.`
    showPublishModal.value = false
    await loadPolicies()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadPolicies)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-slate-900">Políticas Legales y Control de Versiones</h1>
          <p class="text-sm text-slate-600">Publicar nuevas versiones de Términos, Privacidad, Perlitas y Canjes. Publicar una nueva versión desactivará la anterior y requerirá re-aceptación de los fanáticos.</p>
        </div>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-50 border border-red-200 text-red-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- Legal Quick Actions Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="slugKey in (['terminos', 'privacidad', 'perlitas', 'canjes'] as const)" :key="slugKey" class="p-5 bg-white border border-slate-200 rounded-2xl shadow-xs flex flex-col justify-between space-y-3">
          <div>
            <div class="flex items-center justify-between">
              <span class="font-bold text-slate-900 text-sm">{{ policyLabels[slugKey] }}</span>
              <BaseBadge :variant="policies.find(p => p.slug === slugKey && p.is_active) ? 'success' : 'soft'">
                {{ policies.find(p => p.slug === slugKey && p.is_active)?.version || 'Sin Versión' }}
              </BaseBadge>
            </div>
            <p class="text-xs text-slate-500 mt-2">
              Publicado el: {{ policies.find(p => p.slug === slugKey && p.is_active)?.published_at ? new Date(policies.find(p => p.slug === slugKey && p.is_active)!.published_at).toLocaleDateString() : 'N/A' }}
            </p>
          </div>
          <BaseButton variant="secondary" class="w-full text-xs" @click="openNewVersion(slugKey)">
            <i class="bi bi-file-earmark-diff mr-1.5 text-emerald-600"></i> Publicar Nueva Versión
          </BaseButton>
        </div>
      </div>

      <!-- History Table -->
      <div class="pt-4">
        <h2 class="text-lg font-bold text-slate-900 mb-4">Historial de Versiones Publicadas</h2>
        <BaseTable :columns="columns" :data="policies" :loading="loading" empty-text="No hay versiones registradas">
          <template #cell-slug="{ row }">
            <span class="font-semibold text-slate-900">{{ policyLabels[(row as any).slug] || (row as any).slug }}</span>
          </template>

          <template #cell-version="{ row }">
            <span class="font-mono text-emerald-600 font-bold text-sm">{{ (row as any).version }}</span>
          </template>

          <template #cell-published_at="{ row }">
            <span class="text-xs text-slate-600">{{ new Date((row as any).published_at).toLocaleString() }}</span>
          </template>

          <template #cell-is_active="{ row }">
            <BaseBadge :variant="(row as any).is_active ? 'success' : 'soft'">
              {{ (row as any).is_active ? 'Vigente Actual' : 'Archivada' }}
            </BaseBadge>
          </template>

          <template #cell-actions="{ row }">
            <div class="flex items-center justify-end gap-1.5">
              <button @click="viewContent(row as any)" class="p-1.5 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors" title="Ver / Editar Markdown">
                <i class="bi bi-eye"></i>
              </button>
            </div>
          </template>
        </BaseTable>
      </div>
    </div>

    <!-- Modal Publisher -->
    <BaseModal v-if="showPublishModal" :is-open="showPublishModal" :title="`Publicar ${policyLabels[form.slug]}`" @close="showPublishModal = false">
      <div class="space-y-4">
        <BaseInput label="Identificador de Versión (ej: v1.1)" v-model="form.version" placeholder="v1.1" />

        <div>
          <label class="block text-xs font-semibold text-slate-700 mb-1">Contenido de la Política (Markdown)</label>
          <textarea
            v-model="form.content_markdown"
            rows="12"
            class="w-full font-mono text-xs bg-white border border-slate-300 text-slate-900 rounded-xl px-3 py-2 focus:outline-none focus:border-emerald-500"
            placeholder="# Titulo de la política..."
          ></textarea>
        </div>

        <p class="text-xs text-amber-800 bg-amber-50 border border-amber-200 p-3 rounded-xl">
          <i class="bi bi-exclamation-triangle mr-1"></i>
          Al hacer clic en "Publicar Versión", esta versión pasará a ser la única vigente. Los usuarios registrados que hayan aceptado versiones anteriores deberán volver a aceptar las políticas.
        </p>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showPublishModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="publishNewVersion">Publicar Versión</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
