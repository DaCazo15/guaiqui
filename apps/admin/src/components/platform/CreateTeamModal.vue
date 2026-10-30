<script setup lang="ts">
import { ref } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'created'): void
}>()

const name = ref('')
const slug = ref('')
const sport = ref('baloncesto')
const shortName = ref('')
const primaryColor = ref('#005A36')
const secondaryColor = ref('#E31B23')
const logoUrl = ref('')
const adminEmail = ref('')
const adminName = ref('')
const initialPaidMonths = ref(1)

const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)
const isUploadingLogo = ref(false)

const handleNameBlur = () => {
  if (!slug.value && name.value) {
    slug.value = name.value
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 50)
  }
}

const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  isUploadingLogo.value = true
  errorMessage.value = null
  try {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`
    const filePath = `logos/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('team-logos')
      .upload(filePath, file, { upsert: true })

    if (uploadError) throw uploadError

    const { data: { publicUrl } } = supabase.storage
      .from('team-logos')
      .getPublicUrl(filePath)

    logoUrl.value = publicUrl
  } catch (err: any) {
    errorMessage.value = `Error al subir logo: ${err.message}`
  } finally {
    isUploadingLogo.value = false
  }
}

const resetForm = () => {
  name.value = ''
  slug.value = ''
  sport.value = 'baloncesto'
  shortName.value = ''
  primaryColor.value = '#005A36'
  secondaryColor.value = '#E31B23'
  logoUrl.value = ''
  adminEmail.value = ''
  adminName.value = ''
  initialPaidMonths.value = 1
  errorMessage.value = null
}

const handleSubmit = async () => {
  if (!name.value.trim()) {
    errorMessage.value = 'El nombre del club es obligatorio.'
    return
  }
  if (!slug.value.trim() || !/^[a-z0-9-]+$/.test(slug.value.trim())) {
    errorMessage.value = 'El slug debe contener solo minúsculas, números y guiones.'
    return
  }
  if (!adminEmail.value.trim() || !adminEmail.value.includes('@')) {
    errorMessage.value = 'Debe indicar un correo electrónico válido para el administrador del club.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) throw new Error('No hay sesión activa.')

    const res = await supabase.functions.invoke('create-team', {
      body: {
        name: name.value.trim(),
        slug: slug.value.trim(),
        sport: sport.value.trim(),
        short_name: shortName.value.trim() || null,
        primary_color: primaryColor.value,
        secondary_color: secondaryColor.value,
        logo_url: logoUrl.value || null,
        admin_email: adminEmail.value.trim(),
        admin_name: adminName.value.trim() || null,
        initial_paid_months: initialPaidMonths.value
      }
    })

    if (res.error) {
      throw new Error(res.error.message || 'Error invocando la función create-team')
    }

    if (res.data?.error) {
      throw new Error(res.data.error)
    }

    resetForm()
    emit('created')
    emit('close')
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al crear el equipo.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <BaseModal :is-open="isOpen" title="Alta de Nuevo Equipo / Franquicia" @close="emit('close')">
    <form @submit.prevent="handleSubmit" class="space-y-4 text-xs">
      <!-- Error alert -->
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-lg">
        {{ errorMessage }}
      </div>

      <!-- Team Identity Fields -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block font-semibold text-slate-300 mb-1">Nombre Oficial del Club *</label>
          <input
            v-model="name"
            type="text"
            required
            placeholder="Ej: Cocodrilos de Caracas"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
            @blur="handleNameBlur"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Slug URL (único) *</label>
          <input
            v-model="slug"
            type="text"
            required
            placeholder="cocodrilos"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 font-mono focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Deporte Principal</label>
          <select
            v-model="sport"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          >
            <option value="baloncesto">Baloncesto</option>
            <option value="beisbol">Béisbol</option>
            <option value="futbol">Fútbol</option>
            <option value="voleibol">Voleibol</option>
          </select>
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Nombre Corto / Apodo</label>
          <input
            v-model="shortName"
            type="text"
            placeholder="Ej: Saurios"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          />
        </div>
      </div>

      <!-- Colors & Logo -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2 border-t border-slate-800">
        <div>
          <label class="block font-semibold text-slate-300 mb-1">Color Primario</label>
          <div class="flex items-center gap-2">
            <input v-model="primaryColor" type="color" class="w-8 h-8 rounded border border-slate-700 bg-transparent cursor-pointer" />
            <input v-model="primaryColor" type="text" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 font-mono text-xs uppercase" />
          </div>
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Color Secundario</label>
          <div class="flex items-center gap-2">
            <input v-model="secondaryColor" type="color" class="w-8 h-8 rounded border border-slate-700 bg-transparent cursor-pointer" />
            <input v-model="secondaryColor" type="text" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 font-mono text-xs uppercase" />
          </div>
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Meses Iniciales</label>
          <input
            v-model.number="initialPaidMonths"
            type="number"
            min="1"
            max="36"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 font-mono focus:ring-1 focus:ring-emerald-500"
          />
        </div>
      </div>

      <!-- Logo upload -->
      <div>
        <label class="block font-semibold text-slate-300 mb-1">Escudo / Logo Oficial</label>
        <div class="flex items-center gap-3">
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp,image/svg+xml"
            class="text-xs text-slate-400 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-slate-800 file:text-slate-200 hover:file:bg-slate-750"
            @change="handleFileUpload"
          />
          <span v-if="isUploadingLogo" class="text-xs text-emerald-400 animate-pulse">Subiendo...</span>
        </div>
      </div>

      <!-- Initial Admin Account -->
      <div class="pt-3 border-t border-slate-800">
        <h4 class="font-bold text-slate-200 mb-2 flex items-center gap-1.5">
          <i class="bi bi-person-badge text-emerald-400"></i> Primer Administrador del Club
        </h4>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block font-semibold text-slate-300 mb-1">Correo Electrónico *</label>
            <input
              v-model="adminEmail"
              type="email"
              required
              placeholder="admin@club.com"
              class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
            />
          </div>

          <div>
            <label class="block font-semibold text-slate-300 mb-1">Nombre Completo</label>
            <input
              v-model="adminName"
              type="text"
              placeholder="Ej: Carlos Silva"
              class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
            />
          </div>
        </div>
        <p class="text-[11px] text-slate-400 mt-1.5">
          Se enviará una invitación por correo para que el directivo configure su contraseña y acceda al panel.
        </p>
      </div>

      <!-- Actions -->
      <div class="flex items-center justify-end gap-2.5 pt-4 border-t border-slate-800">
        <BaseButton
          variant="secondary"
          size="sm"
          type="button"
          :disabled="isSubmitting"
          @click="emit('close')"
        >
          Cancelar
        </BaseButton>
        <BaseButton
          variant="primary"
          size="sm"
          type="submit"
          :disabled="isSubmitting"
          class="!bg-emerald-600 hover:!bg-emerald-500 !text-white font-semibold"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin mr-1"></i>
          {{ isSubmitting ? 'Creando Franquicia...' : 'Confirmar y Dar de Alta' }}
        </BaseButton>
      </div>
    </form>
  </BaseModal>
</template>
