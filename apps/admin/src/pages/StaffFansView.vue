<script setup lang="ts">
import { ref } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import FanCard from '../components/fans/FanCard.vue'
import { supabase } from '../lib/supabase'

const searchQuery = ref('')
const fans = ref<any[]>([])
const isLoading = ref(false)
const hasSearched = ref(false)
const searchError = ref<string | null>(null)

const handleSearch = async () => {
  const query = searchQuery.value.trim()
  if (query.length < 3) {
    searchError.value = 'Ingrese al menos 3 caracteres para buscar un fanático.'
    return
  }

  searchError.value = null
  isLoading.value = true
  hasSearched.value = true

  try {
    const { data, error } = await supabase.rpc('staff_search_fans', {
      p_query: query,
      p_limit: 10
    })

    if (error) {
      console.error('Error searching fans:', error)
      searchError.value = error.message || 'Error al buscar fanáticos.'
      fans.value = []
    } else {
      fans.value = data || []
    }
  } catch (err: any) {
    searchError.value = err.message || 'Error de conexión.'
    fans.value = []
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <StaffLayout>
    <div class="space-y-6 max-w-4xl mx-auto">
      <div>
        <h1 class="text-2xl font-bold text-white tracking-wide">Consulta de Fanáticos</h1>
        <p class="text-xs text-slate-400">Verificación de saldo en billetera e historial de canjes en taquilla</p>
      </div>

      <!-- Search Input -->
      <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 sm:p-6 shadow-xl space-y-3">
        <form @submit.prevent="handleSearch" class="flex flex-col sm:flex-row gap-3">
          <div class="relative flex-1">
            <span class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500">
              <i class="bi bi-search"></i>
            </span>

            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar por nombre (mínimo 3 letras)..."
              class="w-full pl-10 pr-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
            />
          </div>

          <button
            type="submit"
            :disabled="isLoading"
            class="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-xl shadow-md transition-all disabled:opacity-50"
          >
            <i v-if="isLoading" class="bi bi-arrow-repeat animate-spin me-1"></i>
            <i v-else class="bi bi-person-search me-1"></i>
            <span>Buscar Fanático</span>
          </button>
        </form>

        <p v-if="searchError" class="text-xs text-amber-400 flex items-center gap-1 font-medium">
          <i class="bi bi-exclamation-triangle-fill"></i>
          {{ searchError }}
        </p>

        <p class="text-[11px] text-slate-500">
          Nota de Privacidad: Las búsquedas en taquilla están auditadas. No se exponen datos personales ni de contacto.
        </p>
      </div>

      <!-- Results -->
      <div v-if="isLoading" class="p-12 text-center bg-slate-900 border border-slate-800 rounded-2xl">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-400 block mb-2"></i>
        <span class="text-xs text-slate-300">Buscando en la base de fanáticos...</span>
      </div>

      <div v-else-if="hasSearched && fans.length === 0" class="p-12 text-center bg-slate-900 border border-slate-800 rounded-2xl text-slate-500">
        <i class="bi bi-person-x text-4xl block mb-2 text-slate-600"></i>
        <span class="text-sm font-medium">No se encontraron fanáticos con el término ingresado.</span>
      </div>

      <div v-else class="space-y-4">
        <FanCard v-for="fan in fans" :key="fan.id" :fan="fan" />
      </div>
    </div>
  </StaffLayout>
</template>
