<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { supabase } from '../../../lib/supabase'

export interface FooterGeneralForm {
  footer_brand_description: string
  footer_location: string
  footer_support_text: string
  footer_support_hours: string
  footer_support_url: string
  footer_copyright: string
  footer_disclaimer: string
}

const loadingSettings = ref(true)
const savingSettings = ref(false)
const settingsSuccess = ref<string | null>(null)
const settingsError = ref<string | null>(null)

const footerForm = ref<FooterGeneralForm>({
  footer_brand_description: 'Plataforma oficial de fidelización de Guaiqueríes de Margarita. Fan Zone 2026.',
  footer_location: 'Gimnasio Ciudad de La Asunción, Nueva Esparta',
  footer_support_text: '¿Tienes alguna duda sobre tus puntos o tu canje?',
  footer_support_hours: 'Atención presencial en días de juego: 4:00 PM a 9:00 PM.',
  footer_support_url: '/contacto',
  footer_copyright: '© 2026 Guaiqueríes de Margarita. Todos los derechos reservados.',
  footer_disclaimer: 'Sin pagos con dinero real • 100% Fidelización Gratuita'
})

const loadSettings = async () => {
  loadingSettings.value = true
  settingsError.value = null
  try {
    const { data, error } = await supabase
      .from('landing_settings')
      .select('footer_brand_description, footer_location, footer_support_text, footer_support_hours, footer_support_url, footer_copyright, footer_disclaimer')
      .limit(1)
      .single()

    if (error) throw error
    if (data) {
      footerForm.value = {
        footer_brand_description: data.footer_brand_description || footerForm.value.footer_brand_description,
        footer_location: data.footer_location || footerForm.value.footer_location,
        footer_support_text: data.footer_support_text || footerForm.value.footer_support_text,
        footer_support_hours: data.footer_support_hours || footerForm.value.footer_support_hours,
        footer_support_url: data.footer_support_url || footerForm.value.footer_support_url,
        footer_copyright: data.footer_copyright || footerForm.value.footer_copyright,
        footer_disclaimer: data.footer_disclaimer || footerForm.value.footer_disclaimer
      }
    }
  } catch (err: any) {
    settingsError.value = 'No se pudieron cargar los textos del pie de página.'
  } finally {
    loadingSettings.value = false
  }
}

const saveFooterSettings = async () => {
  savingSettings.value = true
  settingsSuccess.value = null
  settingsError.value = null
  try {
    const { error } = await supabase
      .from('landing_settings')
      .update({
        footer_brand_description: footerForm.value.footer_brand_description,
        footer_location: footerForm.value.footer_location,
        footer_support_text: footerForm.value.footer_support_text,
        footer_support_hours: footerForm.value.footer_support_hours,
        footer_support_url: footerForm.value.footer_support_url,
        footer_copyright: footerForm.value.footer_copyright,
        footer_disclaimer: footerForm.value.footer_disclaimer,
        updated_at: new Date().toISOString()
      })
      .eq('id', 1)

    if (error) throw error
    settingsSuccess.value = 'Textos del pie de página actualizados exitosamente.'
    setTimeout(() => { settingsSuccess.value = null }, 3500)
  } catch (err: any) {
    settingsError.value = err.message || 'Error al guardar la configuración del pie de página.'
  } finally {
    savingSettings.value = false
  }
}

onMounted(() => {
  loadSettings()
})
</script>

<template>
  <div class="space-y-4 pt-4 border-t border-slate-800/80">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-3 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-card-text text-emerald-400"></i>
          Textos, Ubicación y Soporte del Footer
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Personaliza los textos informativos, sede física, horarios de atención y advertencias legales.
        </p>
      </div>
    </div>

    <!-- Settings Alerts -->
    <div v-if="settingsError" class="p-3.5 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-xs sm:text-sm flex items-center justify-between">
      <span>{{ settingsError }}</span>
      <button @click="settingsError = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="settingsSuccess" class="p-3.5 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-xs sm:text-sm flex items-center justify-between">
      <span>{{ settingsSuccess }}</span>
      <button @click="settingsSuccess = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <div v-if="loadingSettings" class="p-8 text-center text-slate-400 text-sm">
      Cargando configuración del pie de página...
    </div>

    <form v-else @submit.prevent="saveFooterSettings" class="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 sm:p-6 space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <!-- Brand Description -->
        <div class="space-y-1.5 md:col-span-2">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Descripción Institucional (Columna 1)
          </label>
          <input
            v-model="footerForm.footer_brand_description"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="Plataforma oficial de fidelización de Guaiqueríes de Margarita..."
          />
        </div>

        <!-- Location -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Sede Física & Gimnasio
          </label>
          <input
            v-model="footerForm.footer_location"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="Gimnasio Ciudad de La Asunción, Nueva Esparta"
          />
        </div>

        <!-- Support URL -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Enlace de Atención / Soporte
          </label>
          <input
            v-model="footerForm.footer_support_url"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="/contacto"
          />
        </div>

        <!-- Support Text -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Texto de Atención al Fanático
          </label>
          <input
            v-model="footerForm.footer_support_text"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="¿Tienes alguna duda sobre tus puntos o tu canje?"
          />
        </div>

        <!-- Support Hours -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Horario de Atención Presencial
          </label>
          <input
            v-model="footerForm.footer_support_hours"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="Atención presencial en días de juego: 4:00 PM a 9:00 PM."
          />
        </div>

        <!-- Copyright -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Línea de Copyright
          </label>
          <input
            v-model="footerForm.footer_copyright"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="© 2026 Guaiqueríes de Margarita. Todos los derechos reservados."
          />
        </div>

        <!-- Disclaimer -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-300">
            Aclaratoria Legal / Modelo de Puntos
          </label>
          <input
            v-model="footerForm.footer_disclaimer"
            type="text"
            class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors"
            placeholder="Sin pagos con dinero real • 100% Fidelización Gratuita"
          />
        </div>
      </div>

      <div class="flex justify-end pt-2">
        <BaseButton type="submit" variant="primary" :loading="savingSettings">
          <i class="bi bi-check2-circle mr-1.5"></i> Guardar Textos del Footer
        </BaseButton>
      </div>
    </form>
  </div>
</template>
