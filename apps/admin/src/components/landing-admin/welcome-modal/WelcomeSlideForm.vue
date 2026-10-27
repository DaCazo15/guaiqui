<script setup lang="ts">
import type { WelcomeSlideFormData } from './types'

defineProps<{
  form: WelcomeSlideFormData
  actionLoading: boolean
  uploadLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'save'): void
  (e: 'delete', id: string): void
  (e: 'upload', event: Event): void
}>()
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-5">
    <h4 class="text-sm font-semibold text-white border-b border-slate-800 pb-3">
      {{ form.id ? 'Editar Diapositiva' : 'Nueva Diapositiva' }}
    </h4>

    <form @submit.prevent="emit('save')" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Posición (1 a 5)
          </label>
          <input
            v-model.number="form.position"
            type="number"
            min="1"
            max="5"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
            required
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Estado de Publicación
          </label>
          <select
            v-model="form.status"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
          >
            <option value="draft">Borrador (Oculto)</option>
            <option value="published">Publicado (Visible)</option>
          </select>
        </div>
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
          Título Destacado
        </label>
        <input
          v-model="form.title"
          type="text"
          maxlength="100"
          class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
          required
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
          Subtítulo / Mensaje Informativo
        </label>
        <textarea
          v-model="form.subtitle"
          rows="2"
          maxlength="250"
          class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 resize-none"
        ></textarea>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Texto del Botón (CTA)
          </label>
          <input
            v-model="form.cta_label"
            type="text"
            maxlength="30"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
            required
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Ruta / Enlace Destino
          </label>
          <input
            v-model="form.cta_url"
            type="text"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
            required
          />
        </div>
      </div>

      <!-- Image Upload -->
      <div>
        <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
          Imagen de la Diapositiva
        </label>
        <div class="flex items-center gap-3">
          <input
            v-model="form.image_url"
            type="text"
            placeholder="https://..."
            class="flex-1 px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
          />
          <label class="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium rounded-xl cursor-pointer transition border border-slate-700 shrink-0 flex items-center gap-1.5">
            <i v-if="uploadLoading" class="bi bi-arrow-repeat animate-spin"></i>
            <i v-else class="bi bi-upload"></i>
            <span>Subir</span>
            <input
              type="file"
              accept="image/*"
              class="hidden"
              @change="emit('upload', $event)"
              :disabled="uploadLoading"
            />
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Válido Desde — Hora de Caracas (GMT-4)
          </label>
          <input
            v-model="form.starts_at"
            type="datetime-local"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
          />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Válido Hasta (Opcional) — Hora de Caracas (GMT-4)
          </label>
          <input
            v-model="form.ends_at"
            type="datetime-local"
            class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
          />
        </div>
      </div>

      <div class="pt-4 border-t border-slate-800 flex items-center justify-between">
        <button
          v-if="form.id"
          type="button"
          @click="emit('delete', form.id)"
          class="px-4 py-2 bg-red-950 hover:bg-red-900 text-red-300 font-semibold text-xs rounded-xl border border-red-800 transition-all flex items-center gap-1.5"
        >
          <i class="bi bi-trash"></i>
          <span>Eliminar</span>
        </button>

        <div class="flex items-center gap-3 ml-auto">
          <button
            type="submit"
            :disabled="actionLoading"
            class="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-sm rounded-xl transition-all flex items-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50"
          >
            <i v-if="actionLoading" class="bi bi-arrow-repeat animate-spin"></i>
            <i v-else class="bi bi-floppy-fill"></i>
            <span>Guardar Diapositiva</span>
          </button>
        </div>
      </div>
    </form>
  </div>
</template>
