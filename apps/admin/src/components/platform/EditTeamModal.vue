<script setup lang="ts">
import { ref, watch } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { TeamRow } from './PlatformTeamsTable.vue'

const props = defineProps<{
  isOpen: boolean
  team: TeamRow | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'updated'): void
}>()

const name = ref('')
const shortName = ref('')
const sport = ref('baloncesto')
const primaryColor = ref('#005A36')
const secondaryColor = ref('#E31B23')
const logoUrl = ref('')

const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)
const isUploadingLogo = ref(false)

watch(() => props.team, (newTeam) => {
  if (newTeam) {
    name.value = newTeam.name || ''
    shortName.value = newTeam.short_name || ''
    sport.value = newTeam.sport || 'baloncesto'
    primaryColor.value = newTeam.primary_color || '#005A36'
    secondaryColor.value = newTeam.secondary_color || '#E31B23'
    logoUrl.value = newTeam.logo_url || ''
    errorMessage.value = null
  }
}, { immediate: true })

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

const handleSubmit = async () => {
  if (!props.team) return
  if (!name.value.trim()) {
    errorMessage.value = 'El nombre del club es obligatorio.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { error } = await supabase.rpc('admin_update_team', {
      p_team_id: props.team.id,
      p_name: name.value.trim(),
      p_short_name: shortName.value.trim() || null,
      p_sport: sport.value.trim(),
      p_primary_color: primaryColor.value,
      p_secondary_color: secondaryColor.value,
      p_logo_url: logoUrl.value || null
    })

    if (error) throw error

    emit('updated')
    emit('close')
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al actualizar el equipo.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <BaseModal :is-open="isOpen" :title="`Editar Club: ${team?.name || ''}`" @close="emit('close')">
    <form @submit.prevent="handleSubmit" class="space-y-4 text-xs">
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-lg">
        {{ errorMessage }}
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block font-semibold text-slate-300 mb-1">Nombre Oficial del Club *</label>
          <input
            v-model="name"
            type="text"
            required
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Nombre Corto / Siglas</label>
          <input
            v-model="shortName"
            type="text"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Deporte</label>
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
          <label class="block font-semibold text-slate-300 mb-1">Slug (Identificador URL)</label>
          <input
            :value="team?.slug"
            disabled
            class="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-400 font-mono cursor-not-allowed"
          />
        </div>
      </div>

      <!-- Colors -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-slate-800">
        <div>
          <label class="block font-semibold text-slate-300 mb-1">Color Primario</label>
          <div class="flex items-center gap-2">
            <input v-model="primaryColor" type="color" class="w-8 h-8 rounded border border-slate-700 bg-transparent cursor-pointer" />
            <input v-model="primaryColor" type="text" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 font-mono uppercase" />
          </div>
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Color Secundario</label>
          <div class="flex items-center gap-2">
            <input v-model="secondaryColor" type="color" class="w-8 h-8 rounded border border-slate-700 bg-transparent cursor-pointer" />
            <input v-model="secondaryColor" type="text" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 font-mono uppercase" />
          </div>
        </div>
      </div>

      <!-- Logo upload -->
      <div class="pt-2 border-t border-slate-800">
        <label class="block font-semibold text-slate-300 mb-1">Logo / Escudo</label>
        <div class="flex items-center gap-3">
          <div v-if="logoUrl" class="w-10 h-10 rounded-lg bg-slate-900 border border-slate-700 p-1 flex items-center justify-center shrink-0">
            <img :src="logoUrl" alt="Logo preview" class="w-full h-full object-contain" />
          </div>
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp,image/svg+xml"
            class="text-xs text-slate-400 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-slate-800 file:text-slate-200 hover:file:bg-slate-750"
            @change="handleFileUpload"
          />
          <span v-if="isUploadingLogo" class="text-xs text-emerald-400 animate-pulse">Subiendo...</span>
        </div>
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
          {{ isSubmitting ? 'Guardando...' : 'Guardar Cambios' }}
        </BaseButton>
      </div>
    </form>
  </BaseModal>
</template>
