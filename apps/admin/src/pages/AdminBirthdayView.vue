<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import AdminLayout from '../components/layout/AdminLayout.vue'

interface BirthdaySettings {
  enabled: boolean
  title: string
  message: string
  image_url?: string | null
  send_hour: number
  grace_days: number
  bonus_pearls: number
}

const loading = ref(true)
const actionLoading = ref(false)
const testLoading = ref(false)
const successMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)
const testSuccessMessage = ref<string | null>(null)

const settings = ref<BirthdaySettings>({
  enabled: true,
  title: '¡Feliz Cumpleaños, Guaiquerí!',
  message: '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}! 🏀\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.',
  image_url: '',
  send_hour: 9,
  grace_days: 3,
  bonus_pearls: 0
})

const uploadLoading = ref(false)

const previewName = ref('Carlos')

onMounted(async () => {
  await fetchSettings()
})

async function fetchSettings() {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('birthday_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle()

    if (error) throw error
    if (data) {
      settings.value = {
        enabled: data.enabled ?? true,
        title: data.title || '¡Feliz Cumpleaños, Guaiquerí!',
        message: data.message || '',
        image_url: data.image_url || '',
        send_hour: data.send_hour ?? 9,
        grace_days: data.grace_days ?? 3,
        bonus_pearls: data.bonus_pearls ?? 0
      }
    }
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar la configuración de cumpleaños.'
  } finally {
    loading.value = false
  }
}

async function handleSaveSettings() {
  actionLoading.value = true
  successMessage.value = null
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('update_birthday_settings', {
      p_enabled: settings.value.enabled,
      p_title: settings.value.title,
      p_message: settings.value.message,
      p_image_url: settings.value.image_url || null,
      p_send_hour: settings.value.send_hour,
      p_grace_days: settings.value.grace_days,
      p_bonus_pearls: settings.value.bonus_pearls
    })

    if (error) throw error
    if (data?.success) {
      successMessage.value = 'Configuración de cumpleaños guardada con éxito.'
    } else {
      throw new Error(data?.message || 'Error al guardar.')
    }
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar la configuración.'
  } finally {
    actionLoading.value = false
  }
}

async function handleSendTestNotification() {
  testLoading.value = true
  testSuccessMessage.value = null
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('send_test_birthday_notification')
    if (error) throw error
    if (data?.success) {
      testSuccessMessage.value = 'Notificación de prueba enviada a tu usuario de admin.'
    }
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al enviar la prueba.'
  } finally {
    testLoading.value = false
  }
}

async function handleImageUpload(event: Event) {
  const input = event.target as HTMLInputElement
  if (!input.files || input.files.length === 0) return

  const file = input.files[0]
  uploadLoading.value = true
  errorMessage.value = null

  try {
    const fileExt = file.name.split('.').pop()
    const fileName = `birthday_${Date.now()}.${fileExt}`
    const filePath = `birthday/${fileName}`

    const { error: uploadErr } = await supabase.storage
      .from('site-media')
      .upload(filePath, file, { upsert: true })

    if (uploadErr) throw uploadErr

    const { data: publicData } = supabase.storage
      .from('site-media')
      .getPublicUrl(filePath)

    settings.value.image_url = publicData.publicUrl
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al subir la imagen a site-media.'
  } finally {
    uploadLoading.value = false
  }
}

const previewFormattedMessage = computed(() => {
  if (!settings.value.message) return ''
  const replaced = settings.value.message.replace(/{nombre}/g, previewName.value)
  const escaped = replaced
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
  
  const bolded = escaped.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
  return bolded.split('\n\n').map(p => `<p class="mb-2">${p.replace(/\n/g, '<br/>')}</p>`).join('')
})

const sendHourLabels: Record<number, string> = {
  0: '12:00 AM (Medianoche)',
  1: '01:00 AM',
  2: '02:00 AM',
  3: '03:00 AM',
  4: '04:00 AM',
  5: '05:00 AM',
  6: '06:00 AM',
  7: '07:00 AM',
  8: '08:00 AM',
  9: '09:00 AM (Recomendado)',
  10: '10:00 AM',
  11: '11:00 AM',
  12: '12:00 PM (Mediodía)',
  13: '01:00 PM',
  14: '02:00 PM',
  15: '03:00 PM',
  16: '04:00 PM',
  17: '05:00 PM',
  18: '06:00 PM',
  19: '07:00 PM',
  20: '08:00 PM',
  21: '09:00 PM',
  22: '10:00 PM',
  23: '11:00 PM'
}
</script>

<template>
  <AdminLayout>
    <div class="space-y-6">
      <!-- Title & Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-white tracking-wide flex items-center gap-2">
            <i class="bi bi-gift text-emerald-400"></i>
            <span>Saludo de Cumpleaños</span>
          </h1>
          <p class="text-xs text-slate-400">
            Configura el mensaje automático, hora de envío, días de gracia y regalo de perlitas para los cumpleañeros.
          </p>
        </div>

        <button
          @click="handleSendTestNotification"
          :disabled="testLoading"
          class="flex items-center justify-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-emerald-400 font-semibold text-xs rounded-xl border border-slate-700 transition-all disabled:opacity-50"
        >
          <i v-if="testLoading" class="bi bi-arrow-repeat animate-spin text-sm"></i>
          <i v-else class="bi bi-send-fill text-sm"></i>
          <span>Enviarme una prueba</span>
        </button>
      </div>

      <!-- Feedback Alerts -->
      <div v-if="successMessage" class="p-4 bg-emerald-950/50 border border-emerald-800 rounded-xl text-emerald-200 text-sm flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-400 text-lg"></i>
        <span>{{ successMessage }}</span>
      </div>

      <div v-if="testSuccessMessage" class="p-4 bg-emerald-950/50 border border-emerald-800 rounded-xl text-emerald-200 text-sm flex items-center gap-2">
        <i class="bi bi-bell-fill text-emerald-400 text-lg"></i>
        <span>{{ testSuccessMessage }}</span>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/50 border border-red-800 rounded-xl text-red-200 text-sm flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-400 text-lg"></i>
        <span>{{ errorMessage }}</span>
      </div>

      <div v-if="loading" class="p-12 text-center text-slate-400">
        <i class="bi bi-arrow-repeat animate-spin text-2xl mb-2 block"></i>
        <span>Cargando parámetros...</span>
      </div>

      <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Form Column -->
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-5">
          <div class="flex items-center justify-between border-b border-slate-800 pb-4">
            <div>
              <h2 class="text-base font-semibold text-white">Parámetros del Saludo</h2>
              <p class="text-xs text-slate-400">Activa o desactiva la campaña y define las reglas de envío</p>
            </div>

            <label class="relative inline-flex items-center cursor-pointer">
              <input type="checkbox" v-model="settings.enabled" class="sr-only peer">
              <div class="w-11 h-6 bg-slate-800 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
            </label>
          </div>

          <form @submit.prevent="handleSaveSettings" class="space-y-4">
            <!-- Título -->
            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Título del Saludo
              </label>
              <input
                v-model="settings.title"
                type="text"
                required
                placeholder="¡Feliz Cumpleaños, Guaiquerí!"
                class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-sm focus:outline-none focus:border-emerald-500"
              />
            </div>

            <!-- Mensaje Markdown -->
            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Mensaje (Markdown)
              </label>
              <textarea
                v-model="settings.message"
                rows="5"
                required
                placeholder="Usa {nombre} para referenciar al fanático..."
                class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-sm focus:outline-none focus:border-emerald-500 font-mono text-xs"
              ></textarea>
              <p class="text-[11px] text-slate-400 mt-1">
                <i class="bi bi-info-circle mr-1"></i> Usa <code class="text-emerald-400">{nombre}</code> para insertar el nombre del fan y <code class="text-emerald-400">**texto**</code> para negrita.
              </p>
            </div>

            <!-- Imagen (site-media) -->
            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Imagen Destacada (Opcional)
              </label>

              <div class="flex items-center gap-3">
                <input
                  v-model="settings.image_url"
                  type="text"
                  placeholder="https://..."
                  class="flex-1 px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                />

                <label class="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-xl border border-slate-700 cursor-pointer flex items-center gap-1.5 shrink-0">
                  <i v-if="uploadLoading" class="bi bi-arrow-repeat animate-spin"></i>
                  <i v-else class="bi bi-upload"></i>
                  <span>Subir</span>
                  <input type="file" accept="image/*" class="hidden" @change="handleImageUpload">
                </label>
              </div>
            </div>

            <!-- Grid: Hora, Días de gracia, Bono -->
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
              <div>
                <label class="block text-[11px] font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Hora de Envío (Caracas)
                </label>
                <select
                  v-model.number="settings.send_hour"
                  class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                >
                  <option v-for="(lbl, h) in sendHourLabels" :key="h" :value="Number(h)">
                    {{ lbl }}
                  </option>
                </select>
              </div>

              <div>
                <label class="block text-[11px] font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Días de Gracia
                </label>
                <input
                  v-model.number="settings.grace_days"
                  type="number"
                  min="0"
                  max="30"
                  required
                  class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label class="block text-[11px] font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Bono Perlitas
                </label>
                <input
                  v-model.number="settings.bonus_pearls"
                  type="number"
                  min="0"
                  max="10000"
                  required
                  class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>

            <div class="pt-4 border-t border-slate-800 flex justify-end">
              <button
                type="submit"
                :disabled="actionLoading"
                class="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-sm rounded-xl transition-all flex items-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50"
              >
                <i v-if="actionLoading" class="bi bi-arrow-repeat animate-spin"></i>
                <i v-else class="bi bi-floppy-fill"></i>
                <span>Guardar Configuración</span>
              </button>
            </div>
          </form>
        </div>

        <!-- Live Preview Column -->
        <div class="space-y-3">
          <div class="flex items-center justify-between px-1">
            <h2 class="text-sm font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-2">
              <i class="bi bi-eye"></i> Vista Previa de la Tarjeta Fan
            </h2>
            <div class="flex items-center gap-2">
              <span class="text-xs text-slate-400">Nombre de ejemplo:</span>
              <input
                v-model="previewName"
                type="text"
                class="w-24 px-2 py-0.5 bg-slate-950 border border-slate-800 rounded-md text-white text-xs"
              />
            </div>
          </div>

          <!-- Preview Frame -->
          <div class="bg-slate-950 border border-slate-800 rounded-2xl p-4 md:p-6 space-y-4 shadow-xl">
            <!-- Header Banner -->
            <div class="relative overflow-hidden rounded-xl bg-gradient-to-br from-emerald-950 via-emerald-900 to-slate-900 text-white border border-emerald-800/50 p-5 text-center space-y-2">
              <div class="w-12 h-12 rounded-full bg-emerald-800/60 border border-emerald-400/30 text-amber-300 text-2xl mx-auto flex items-center justify-center">
                <i class="bi bi-gift-fill"></i>
              </div>
              <h3 class="font-bold text-xl uppercase tracking-wider text-white">
                ¡FELIZ CUMPLEAÑOS, <span class="text-amber-300">{{ previewName.toUpperCase() }}</span>!
              </h3>
              <p class="text-xs text-emerald-200">De parte de tus Guaiqueríes de Margarita</p>
              <div class="h-1.5 w-full bg-gradient-to-r from-red-700 via-red-500 to-red-700 rounded-full mt-2"></div>
            </div>

            <!-- Card Body -->
            <div class="bg-white text-slate-900 rounded-xl p-5 space-y-4 shadow-md">
              <div v-if="settings.image_url" class="rounded-lg overflow-hidden max-h-40 bg-slate-950 border border-slate-200">
                <img :src="settings.image_url" class="w-full h-full object-cover" />
              </div>

              <h4 class="text-lg font-bold text-slate-900 flex items-center gap-2">
                <i class="bi bi-balloon-fill text-red-500"></i>
                <span>{{ settings.title }}</span>
              </h4>

              <div class="text-xs text-slate-700 leading-relaxed" v-html="previewFormattedMessage"></div>

              <div class="pt-3 border-t border-slate-100 flex flex-wrap gap-2 items-center justify-between">
                <div class="flex gap-2">
                  <button v-if="settings.bonus_pearls > 0" class="px-3 py-1.5 bg-emerald-600 text-white font-semibold text-xs rounded-lg flex items-center gap-1.5">
                    <i class="bi bi-gift"></i>
                    <span>Reclamar {{ settings.bonus_pearls }} perlitas</span>
                  </button>
                  <button class="px-3 py-1.5 border border-slate-300 text-slate-700 font-semibold text-xs rounded-lg">
                    Ir a mis trivias
                  </button>
                </div>
                <button class="px-3 py-1.5 bg-slate-100 text-slate-700 font-semibold text-xs rounded-lg">
                  Compartir
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AdminLayout>
</template>
