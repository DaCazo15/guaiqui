<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import InventoryAdjustModal from '../components/inventory/InventoryAdjustModal.vue'
import { supabase } from '../lib/supabase'

const products = ref<any[]>([])
const isLoading = ref(true)
const searchQuery = ref('')

const selectedProduct = ref<any | null>(null)
const isAdjustModalOpen = ref(false)

const fetchProducts = async () => {
  isLoading.value = true
  try {
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .order('name', { ascending: true })

    if (error) {
      console.error('Error fetching inventory:', error)
      products.value = []
    } else {
      products.value = data || []
    }
  } finally {
    isLoading.value = false
  }
}

const filteredProducts = computed(() => {
  if (!searchQuery.value.trim()) return products.value
  const q = searchQuery.value.toLowerCase()
  return products.value.filter(p =>
    p.name.toLowerCase().includes(q) ||
    p.category.toLowerCase().includes(q)
  )
})

const openAdjustModal = (product: any) => {
  selectedProduct.value = product
  isAdjustModalOpen.value = true
}

const handleConfirmAdjust = async ({ delta, reason }: { delta: number; reason: string }) => {
  if (!selectedProduct.value) return
  try {
    const { data, error } = await supabase.rpc('adjust_stock', {
      p_product_id: selectedProduct.value.id,
      p_delta: delta,
      p_reason: reason
    })

    if (error) {
      alert('Error al ajustar inventario: ' + error.message)
    } else {
      isAdjustModalOpen.value = false
      selectedProduct.value = null
      await fetchProducts()
    }
  } catch (err: any) {
    alert('Error de conexión al ajustar existencias: ' + err.message)
  }
}

onMounted(() => {
  fetchProducts()
})
</script>

<template>
  <StaffLayout>
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-white tracking-wide">Inventario de Taquilla</h1>
          <p class="text-xs text-slate-400">Consulta de premios, stock disponible y ajuste justificado de existencias</p>
        </div>

        <div class="flex items-center gap-3">
          <div class="relative w-full sm:w-64">
            <span class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
              <i class="bi bi-search"></i>
            </span>
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar producto..."
              class="w-full pl-9 pr-3 py-1.5 bg-slate-900 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
            />
          </div>

          <button
            @click="fetchProducts"
            :disabled="isLoading"
            class="p-2 text-slate-300 hover:text-white bg-slate-900 border border-slate-800 rounded-xl"
          >
            <i :class="['bi bi-arrow-clockwise text-lg', isLoading ? 'animate-spin' : '']"></i>
          </button>
        </div>
      </div>

      <!-- Inventory Table -->
      <div class="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
        <div v-if="isLoading" class="p-12 text-center text-slate-400">
          <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-400 block mb-2"></i>
          <span class="text-xs">Cargando catálogo de productos...</span>
        </div>

        <div v-else-if="filteredProducts.length === 0" class="p-12 text-center text-slate-500">
          <i class="bi bi-box text-4xl block mb-2 text-slate-600"></i>
          <span class="text-sm">No se encontraron productos en inventario.</span>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full text-left text-xs text-slate-300">
            <thead class="bg-slate-950/80 text-slate-400 uppercase tracking-wider font-semibold border-b border-slate-800">
              <tr>
                <th class="py-3.5 px-4">Producto</th>
                <th class="py-3.5 px-4 text-center">Categoría</th>
                <th class="py-3.5 px-4 text-center">Costo Perlitas</th>
                <th class="py-3.5 px-4 text-center">Stock Disponible</th>
                <th class="py-3.5 px-4 text-center">Estado</th>
                <th class="py-3.5 px-4 text-right">Acción</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr v-for="item in filteredProducts" :key="item.id" class="hover:bg-slate-800/40 transition-colors">
                <td class="py-3 px-4 font-medium text-white">
                  <div>
                    <span class="block font-bold">{{ item.name }}</span>
                    <span v-if="item.description" class="text-[11px] text-slate-400 font-normal truncate max-w-xs block">{{ item.description }}</span>
                  </div>
                </td>

                <td class="py-3 px-4 text-center">
                  <span class="px-2 py-0.5 bg-slate-800 rounded-md text-[11px] font-mono uppercase text-slate-300">
                    {{ item.category }}
                  </span>
                </td>

                <td class="py-3 px-4 text-center font-semibold text-emerald-400">
                  {{ item.cost_pearls }} 🦪
                </td>

                <td class="py-3 px-4 text-center font-mono font-bold text-sm">
                  <span :class="item.stock <= 5 ? 'text-amber-400' : 'text-white'">
                    {{ item.stock }}
                  </span>
                </td>

                <td class="py-3 px-4 text-center">
                  <span
                    :class="[
                      'px-2 py-0.5 rounded-full text-[11px] font-medium border',
                      item.active ? 'bg-emerald-950 text-emerald-300 border-emerald-800' : 'bg-slate-800 text-slate-400 border-slate-700'
                    ]"
                  >
                    {{ item.active ? 'Activo' : 'Inactivo' }}
                  </span>
                </td>

                <td class="py-3 px-4 text-right">
                  <button
                    @click="openAdjustModal(item)"
                    class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-emerald-400 hover:text-emerald-300 border border-slate-700 text-xs font-semibold rounded-xl transition-all"
                  >
                    <i class="bi bi-pencil-square me-1"></i> Ajustar Stock
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Adjust Stock Modal -->
      <InventoryAdjustModal
        :is-open="isAdjustModalOpen"
        :product="selectedProduct"
        @close="isAdjustModalOpen = false"
        @submit="handleConfirmAdjust"
      />
    </div>
  </StaffLayout>
</template>
