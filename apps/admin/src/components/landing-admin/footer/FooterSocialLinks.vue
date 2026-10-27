<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseTable, BaseBadge, BaseModal } from '@guaiqui/ui'
import { supabase } from '../../../lib/supabase'

export interface SocialLinkRow {
  id: string
  platform: string
  label: string
  url: string
  icon: string
  order_index: number
  is_published: boolean
}

const socialLinks = ref<SocialLinkRow[]>([])
const loadingSocial = ref(true)
const actionLoading = ref(false)
const socialSuccess = ref<string | null>(null)
const socialError = ref<string | null>(null)

const showSocialModal = ref(false)
const socialForm = ref({
  id: '',
  platform: 'instagram',
  label: '',
  url: '',
  icon: 'bi-instagram',
  order_index: 0,
  is_published: true
})

const platformPresets: Record<string, { label: string; icon: string }> = {
  instagram: { label: 'Instagram Oficial', icon: 'bi-instagram' },
  x: { label: 'X (Twitter)', icon: 'bi-twitter-x' },
  facebook: { label: 'Facebook', icon: 'bi-facebook' },
  youtube: { label: 'YouTube Oficial', icon: 'bi-youtube' },
  tiktok: { label: 'TikTok', icon: 'bi-tiktok' },
  whatsapp: { label: 'Canal de WhatsApp', icon: 'bi-whatsapp' },
  telegram: { label: 'Canal de Telegram', icon: 'bi-telegram' },
  custom: { label: 'Enlace Oficial', icon: 'bi-link-45deg' }
}

const onPlatformChange = () => {
  const preset = platformPresets[socialForm.value.platform]
  if (preset && !socialForm.value.id) {
    socialForm.value.label = preset.label
    socialForm.value.icon = preset.icon
  }
}

const columns = [
  { key: 'icon', label: 'Ícono', width: '70px', align: 'center' as const },
  { key: 'label', label: 'Red Social / Etiqueta' },
  { key: 'url', label: 'Enlace' },
  { key: 'order_index', label: 'Orden', width: '90px', align: 'center' as const },
  { key: 'is_published', label: 'Estado', width: '100px', align: 'center' as const },
  { key: 'actions', label: 'Acciones', width: '110px', align: 'right' as const }
]

const loadSocialLinks = async () => {
  loadingSocial.value = true
  socialError.value = null
  try {
    const { data, error } = await supabase
      .from('social_links')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    socialLinks.value = data || []
  } catch (err: any) {
    socialError.value = 'No se pudieron cargar las redes sociales.'
  } finally {
    loadingSocial.value = false
  }
}

const openNewSocial = () => {
  socialForm.value = {
    id: '',
    platform: 'instagram',
    label: platformPresets.instagram.label,
    url: '',
    icon: platformPresets.instagram.icon,
    order_index: socialLinks.value.length,
    is_published: true
  }
  showSocialModal.value = true
}

const editSocial = (row: SocialLinkRow) => {
  socialForm.value = {
    id: row.id,
    platform: row.platform,
    label: row.label,
    url: row.url,
    icon: row.icon,
    order_index: row.order_index,
    is_published: row.is_published
  }
  showSocialModal.value = true
}

const saveSocial = async () => {
  actionLoading.value = true
  socialError.value = null
  socialSuccess.value = null
  try {
    const payload = {
      platform: socialForm.value.platform,
      label: socialForm.value.label.trim(),
      url: socialForm.value.url.trim(),
      icon: socialForm.value.icon.trim() || 'bi-link-45deg',
      order_index: Number(socialForm.value.order_index) || 0,
      is_published: socialForm.value.is_published
    }

    if (socialForm.value.id) {
      const { error } = await supabase
        .from('social_links')
        .update(payload)
        .eq('id', socialForm.value.id)
      if (error) throw error
      socialSuccess.value = 'Red social actualizada correctamente.'
    } else {
      const { error } = await supabase
        .from('social_links')
        .insert([payload])
      if (error) throw error
      socialSuccess.value = 'Red social agregada correctamente.'
    }

    showSocialModal.value = false
    await loadSocialLinks()
    setTimeout(() => { socialSuccess.value = null }, 3500)
  } catch (err: any) {
    socialError.value = err.message || 'Error al guardar la red social.'
  } finally {
    actionLoading.value = false
  }
}

const deleteSocial = async (id: string, label: string) => {
  if (!confirm(`¿Eliminar la red social "${label}"?`)) return
  try {
    const { error } = await supabase
      .from('social_links')
      .delete()
      .eq('id', id)
    if (error) throw error
    socialSuccess.value = 'Red social eliminada correctamente.'
    await loadSocialLinks()
    setTimeout(() => { socialSuccess.value = null }, 3500)
  } catch (err: any) {
    socialError.value = err.message || 'Error al eliminar la red social.'
  }
}

onMounted(() => {
  loadSocialLinks()
})
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-3 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-share text-emerald-400"></i>
          Redes Sociales Oficiales del Club
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Configura los enlaces que aparecen en el pie de página de la landing y app.
        </p>
      </div>

      <BaseButton variant="primary" size="sm" @click="openNewSocial">
        <i class="bi bi-plus-lg mr-1.5"></i> Agregar Red Social
      </BaseButton>
    </div>

    <!-- Social Alerts -->
    <div v-if="socialError" class="p-3.5 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-xs sm:text-sm flex items-center justify-between">
      <span>{{ socialError }}</span>
      <button @click="socialError = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="socialSuccess" class="p-3.5 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-xs sm:text-sm flex items-center justify-between">
      <span>{{ socialSuccess }}</span>
      <button @click="socialSuccess = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <BaseTable
      :columns="columns"
      :data="(socialLinks as any[])"
      :loading="loadingSocial"
      empty-text="No hay redes sociales registradas. Haz clic en 'Agregar Red Social'."
    >
      <template #cell-icon="{ row }">
        <div class="w-8 h-8 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center text-emerald-400 text-base mx-auto">
          <i :class="['bi', (row as SocialLinkRow).icon || 'bi-link-45deg']"></i>
        </div>
      </template>

      <template #cell-label="{ row }">
        <div class="font-semibold text-white text-xs sm:text-sm">
          {{ (row as SocialLinkRow).label }}
        </div>
      </template>

      <template #cell-url="{ row }">
        <a :href="(row as SocialLinkRow).url" target="_blank" rel="noopener noreferrer" class="text-xs text-emerald-400 hover:underline truncate max-w-xs inline-block">
          {{ (row as SocialLinkRow).url }}
        </a>
      </template>

      <template #cell-order_index="{ row }">
        <span class="font-mono text-xs text-slate-400">#{{ (row as SocialLinkRow).order_index }}</span>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="(row as SocialLinkRow).is_published ? 'success' : 'soft'" size="sm">
          {{ (row as SocialLinkRow).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editSocial(row as SocialLinkRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteSocial((row as SocialLinkRow).id, (row as SocialLinkRow).label)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Social Link -->
    <BaseModal
      v-if="showSocialModal"
      :is-open="showSocialModal"
      :title="socialForm.id ? 'Editar Red Social' : 'Nueva Red Social'"
      @close="showSocialModal = false"
    >
      <form @submit.prevent="saveSocial" class="space-y-4">
        <div>
          <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Plataforma</label>
          <select
            v-model="socialForm.platform"
            @change="onPlatformChange"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500"
          >
            <option value="instagram">Instagram</option>
            <option value="x">X (Twitter)</option>
            <option value="facebook">Facebook</option>
            <option value="youtube">YouTube</option>
            <option value="tiktok">TikTok</option>
            <option value="whatsapp">WhatsApp</option>
            <option value="telegram">Telegram</option>
            <option value="custom">Otra Red / Enlace</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Etiqueta / Nombre Visible *</label>
          <input
            v-model="socialForm.label"
            type="text"
            required
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500"
            placeholder="Instagram Oficial"
          />
        </div>

        <div>
          <label class="block text-xs font-bold text-slate-300 uppercase mb-1">URL / Enlace Directo *</label>
          <input
            v-model="socialForm.url"
            type="url"
            required
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500"
            placeholder="https://www.instagram.com/guaiqueriesbbc/"
          />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Ícono Bootstrap Icons</label>
            <div class="flex items-center gap-2">
              <span class="w-8 h-8 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center text-emerald-400">
                <i :class="['bi', socialForm.icon || 'bi-link-45deg']"></i>
              </span>
              <input
                v-model="socialForm.icon"
                type="text"
                class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-xs text-white font-mono focus:outline-none focus:border-emerald-500"
                placeholder="bi-instagram"
              />
            </div>
          </div>
          <div>
            <label class="block text-xs font-bold text-slate-300 uppercase mb-1">Orden</label>
            <input
              v-model.number="socialForm.order_index"
              type="number"
              class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500"
            />
          </div>
        </div>

        <div class="flex items-center gap-2 pt-2">
          <input
            v-model="socialForm.is_published"
            id="social_is_published"
            type="checkbox"
            class="rounded border-slate-700 bg-slate-950 text-emerald-600 focus:ring-emerald-500"
          />
          <label for="social_is_published" class="text-xs text-slate-300 font-medium">
            Visible en el pie de página
          </label>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-slate-800">
          <BaseButton type="button" variant="ghost" @click="showSocialModal = false">
            Cancelar
          </BaseButton>
          <BaseButton type="submit" variant="primary" :loading="actionLoading">
            Guardar Red Social
          </BaseButton>
        </div>
      </form>
    </BaseModal>
  </div>
</template>
