<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseInput, BaseCard, BaseBadge, BaseTable, BaseModal } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import HeroAppearanceControl from '../hero/HeroAppearanceControl.vue'
import type { LandingSettings } from '@guaiqui/shared'

interface AnnouncementRow {
  id: string
  message: string
  link_url?: string
  is_published: boolean
  starts_at: string
  ends_at?: string
  created_at: string
}

const settings = ref<LandingSettings>({
  id: 1,
  hero_title: 'La Tribu Insular Vive en la Fan Zone Oficial',
  hero_subtitle: 'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.',
  hero_badge_text: 'Fan Zone Oficial • Temporada 2026',
  cta_primary_text: 'Únete a la Tribu Gratis',
  cta_primary_url: '/register',
  cta_secondary_text: 'Explorar Premios',
  cta_secondary_url: '#premios',
  hero_guarantee_1: '100% Gratuito',
  hero_guarantee_2: 'Sin tarjetas ni pagos',
  hero_guarantee_3: 'Premios y Perlitas Reales',
  dark_mode_enabled: true,
  theme_color: '#059669',
  hero_image_url: '',
  hero_carousel_enabled: true,
  hero_card_color: ''
})

const announcements = ref<AnnouncementRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const announcementsLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Announcement modal state
const showAnnouncementModal = ref(false)
const announcementForm = ref({
  id: '',
  message: '',
  link_url: '',
  is_published: true,
  starts_at: '',
  ends_at: ''
})

const announcementColumns = [
  { key: 'message', label: 'Mensaje de la Cinta' },
  { key: 'link_url', label: 'Enlace' },
  { key: 'is_published', label: 'Publicado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadData = async () => {
  loading.value = true
  try {
    const { data: setts } = await supabase.from('landing_settings').select('*').eq('id', 1).maybeSingle()
    if (setts) {
      settings.value = setts
    }
  } catch (err: any) {
    console.error('Error loading hero settings:', err)
  } finally {
    loading.value = false
  }
}

const loadAnnouncements = async () => {
  announcementsLoading.value = true
  try {
    const { data, error } = await supabase
      .from('site_announcements')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error
    announcements.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    announcementsLoading.value = false
  }
}

const saveSettings = async () => {
  actionLoading.value = true
  errorMessage.value = null
  successMessage.value = null
  try {
    const { error } = await supabase.from('landing_settings').upsert({
      ...settings.value,
      id: 1,
      updated_at: new Date().toISOString()
    })
    if (error) throw error
    successMessage.value = 'Configuración del Hero actualizada exitosamente.'
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar configuración.'
  } finally {
    actionLoading.value = false
  }
}

const openNewAnnouncement = () => {
  announcementForm.value = {
    id: '',
    message: '',
    link_url: '',
    is_published: true,
    starts_at: nowCaracasInput(),
    ends_at: ''
  }
  showAnnouncementModal.value = true
}

const editAnnouncement = (row: AnnouncementRow) => {
  announcementForm.value = {
    id: row.id,
    message: row.message,
    link_url: row.link_url || '',
    is_published: row.is_published,
    starts_at: row.starts_at ? isoToCaracasInput(row.starts_at) : '',
    ends_at: row.ends_at ? isoToCaracasInput(row.ends_at) : ''
  }
  showAnnouncementModal.value = true
}

const saveAnnouncement = async () => {
  if (!announcementForm.value.message) {
    errorMessage.value = 'El mensaje del anuncio es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      message: announcementForm.value.message,
      link_url: announcementForm.value.link_url || null,
      is_published: announcementForm.value.is_published,
      starts_at: announcementForm.value.starts_at ? caracasInputToISO(announcementForm.value.starts_at) : caracasInputToISO(nowCaracasInput()),
      ends_at: announcementForm.value.ends_at ? caracasInputToISO(announcementForm.value.ends_at) : null
    }

    if (announcementForm.value.id) {
      const { error } = await supabase.from('site_announcements').update(payload).eq('id', announcementForm.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('site_announcements').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Anuncio guardado correctamente.'
    showAnnouncementModal.value = false
    await loadAnnouncements()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteAnnouncement = async (id: string) => {
  if (!confirm('¿Desea eliminar este anuncio de la cinta?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('site_announcements').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Anuncio eliminado.'
    await loadAnnouncements()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadData()
  loadAnnouncements()
})
</script>

<template>
  <div class="space-y-8">
    <!-- Feedback Alerts -->
    <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="successMessage" class="p-4 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <!-- 1. CINTA DE ANUNCIOS (Integrada en la Sección Hero) -->
    <BaseCard class="bg-slate-900 border-slate-800 shadow-xl p-6 space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-800 pb-4">
        <div>
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-megaphone-fill text-emerald-400"></i> Cinta de Anuncios (En Cabecera del Hero)
          </h3>
          <p class="text-xs text-slate-400 mt-1">
            Mensajes emergentes con enlace y vigencia mostrados en el tope de la sección Hero.
          </p>
        </div>
        <BaseButton variant="primary" size="sm" @click="openNewAnnouncement">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Anuncio
        </BaseButton>
      </div>

      <BaseTable
        :columns="announcementColumns"
        :data="announcements"
        :loading="announcementsLoading"
        empty-text="No hay anuncios activos en la cinta del Hero"
      >
        <template #cell-message="{ row }">
          <span class="font-semibold text-white">{{ (row as any).message }}</span>
        </template>

        <template #cell-link_url="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ (row as any).link_url || '-' }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="(row as any).is_published ? 'success' : 'soft'">
            {{ (row as any).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editAnnouncement(row as any)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteAnnouncement((row as any).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </BaseCard>

    <!-- 2. CONTENIDO PRINCIPAL DEL HERO -->
    <BaseCard class="bg-slate-900 border-slate-800 shadow-xl p-6 space-y-6">
      <h3 class="text-lg font-bold text-white flex items-center gap-2 border-b border-slate-800 pb-4">
        <i class="bi bi-pen text-emerald-400"></i> Textos y Botones del Hero
      </h3>

      <div class="grid grid-cols-1 gap-4">
        <BaseInput
          label="Insignia Superior / Badge del Hero"
          v-model="settings.hero_badge_text"
          placeholder="Ej: Fan Zone Oficial • Temporada 2026"
        />
        <BaseInput label="Título Principal de la Landing" v-model="settings.hero_title" />
        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Subtítulo / Descripción Hero</label>
          <textarea
            v-model="settings.hero_subtitle"
            rows="3"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500 placeholder-slate-500"
          ></textarea>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4 border-t border-slate-800">
        <BaseInput label="Texto Botón Principal (CTA)" v-model="settings.cta_primary_text" />
        <BaseInput label="Enlace Botón Principal" v-model="settings.cta_primary_url" />
        <BaseInput label="Texto Botón Secundario" v-model="settings.cta_secondary_text" />
        <BaseInput label="Enlace Botón Secundario" v-model="settings.cta_secondary_url" />
      </div>

      <!-- Sellos de Confianza / Garantías del Hero -->
      <div class="space-y-3 pt-4 border-t border-slate-800">
        <div class="flex items-center justify-between">
          <label class="text-xs font-bold text-white flex items-center gap-1.5">
            <i class="bi bi-shield-check text-emerald-400"></i> Sellos de Confianza (Pie del Hero)
          </label>
          <span class="text-[11px] text-slate-400">3 distintivos que aparecen debajo de los botones</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BaseInput
            label="Sello 1"
            v-model="settings.hero_guarantee_1"
            placeholder="Ej: 100% Gratuito"
          />
          <BaseInput
            label="Sello 2"
            v-model="settings.hero_guarantee_2"
            placeholder="Ej: Sin tarjetas ni pagos"
          />
          <BaseInput
            label="Sello 3"
            v-model="settings.hero_guarantee_3"
            placeholder="Ej: Premios y Perlitas Reales"
          />
        </div>
      </div>

      <!-- Apariencia y Tema del Hero -->
      <HeroAppearanceControl
        v-model:hero-image-url="settings.hero_image_url"
        v-model:hero-card-color="settings.hero_card_color"
        v-model:dark-mode-enabled="settings.dark_mode_enabled"
        v-model:theme-color="settings.theme_color"
      />

      <div class="flex justify-end pt-4">
        <BaseButton variant="primary" :loading="actionLoading" @click="saveSettings">
          <i class="bi bi-check-lg mr-1.5"></i> Guardar Cambios del Hero
        </BaseButton>
      </div>
    </BaseCard>

    <!-- Modal Editor de Anuncio -->
    <BaseModal v-if="showAnnouncementModal" :is-open="showAnnouncementModal" title="Editor de Anuncio" @close="showAnnouncementModal = false">
      <div class="space-y-4">
        <BaseInput label="Mensaje del Anuncio" v-model="announcementForm.message" placeholder="Ej: ¡Hoy jugamos en casa! Trivias abiertas..." />
        <BaseInput label="Enlace al hacer click (Opcional)" v-model="announcementForm.link_url" placeholder="https://..." />
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Válido Desde — Hora de Caracas (GMT-4)" type="datetime-local" v-model="announcementForm.starts_at" />
          <BaseInput label="Válido Hasta (Opcional) — Hora de Caracas (GMT-4)" type="datetime-local" v-model="announcementForm.ends_at" />
        </div>
        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="announcementForm.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Cinta del Hero</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showAnnouncementModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveAnnouncement">Guardar Anuncio</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
