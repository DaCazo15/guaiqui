<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import InventoryAdjustModal from '../components/inventory/InventoryAdjustModal.vue'
import { BaseBadge, BaseInput, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface ProductItem {
  id: string
  name: string
  description?: string
  category: string
  cost_pearls: number
  stock: number
  active: boolean
  images?: string[]
  created_at?: string
}

const products = ref<ProductItem[]>([])
const isLoading = ref(true)
const searchQuery = ref('')
const selectedCategory = ref('')

const selectedProduct = ref<ProductItem | null>(null)
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
  return products.value.filter(p => {
    const q = searchQuery.value.toLowerCase().trim()
    const matchesSearch = !q || p.name.toLowerCase().includes(q) || (p.description && p.description.toLowerCase().includes(q))
    const matchesCat = !selectedCategory.value || p.category === selectedCategory.value
    return matchesSearch && matchesCat
  })
})

// Open modal for Stock Adjustment
const openAdjustModal = (product: ProductItem) => {
  selectedProduct.value = product
  isAdjustModalOpen.value = true
}

const handleConfirmAdjust = async ({ delta, reason }: { delta: number; reason: string }) => {
  if (!selectedProduct.value) return
  try {
    const { error } = await supabase.rpc('adjust_stock', {
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
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    alert('Error de conexión al ajustar existencias: ' + msg)
  }
}

onMounted(() => {
  fetchProducts()
})
</script>

<template>
  <StaffLayout>
    <div class="space-y-6 max-w-7xl mx-auto">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-white tracking-wide font-title">Inventario de Taquilla y Canjes</h1>
          <p class="text-xs text-slate-400">Consulta de catálogo y ajuste de existencias físicas para taquilla</p>
        </div>

        <div class="flex items-center gap-3">
          <button
            :disabled="isLoading"
            class="px-3 py-2 text-xs font-semibold text-slate-300 hover:text-white bg-slate-900 hover:bg-slate-800 border border-slate-800 rounded-xl flex items-center gap-2 transition-colors"
            title="Actualizar catálogo"
            @click="fetchProducts"
          >
            <i :class="['bi bi-arrow-clockwise text-sm', isLoading ? 'animate-spin' : '']"></i>
            <span>Actualizar</span>
          </button>
        </div>
      </div>

      <!-- Search & Filters Toolbar -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 bg-slate-900 p-4 rounded-xl border border-slate-800">
        <BaseInput v-model="searchQuery" placeholder="Buscar por nombre..." />
        <BaseSelect
          v-model="selectedCategory"
          placeholder="Todas las categorías"
          :options="[
            { value: '', label: 'Todas las categorías' },
            { value: 'physical', label: 'Físico (Camisetas, gorras)' },
            { value: 'experience', label: 'Experiencia' },
            { value: 'raffle', label: 'Sorteo' }
          ]"
        />
        <div class="flex items-center justify-end text-xs text-slate-400 font-mono">
          Total: {{ filteredProducts.length }} productos
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
                <th class="py-3.5 px-4 text-center">Stock</th>
                <th class="py-3.5 px-4 text-center">Estado</th>
                <th class="py-3.5 px-4 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr v-for="item in filteredProducts" :key="item.id" class="hover:bg-slate-800/40 transition-colors">
                <td class="py-3 px-4 font-medium text-white">
                  <div class="flex items-center gap-3">
                    <img
                      v-if="item.images && item.images.length > 0"
                      :src="item.images[0]"
                      class="w-9 h-9 rounded-lg object-cover bg-slate-800 border border-slate-700 shrink-0"
                    />
                    <div v-else class="w-9 h-9 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center shrink-0 text-slate-500">
                      <i class="bi bi-box-seam"></i>
                    </div>
                    <div>
                      <span class="block font-bold text-slate-100 text-sm">{{ item.name }}</span>
                      <span v-if="item.description" class="text-[11px] text-slate-400 font-normal truncate max-w-xs block">{{ item.description }}</span>
                    </div>
                  </div>
                </td>

                <td class="py-3 px-4 text-center">
                  <span class="px-2 py-0.5 bg-slate-800 rounded-md text-[11px] font-mono uppercase text-slate-300">
                    {{ item.category }}
                  </span>
                </td>

                <td class="py-3 px-4 text-center font-semibold text-emerald-400 font-mono text-sm">
                  {{ item.cost_pearls }} <i class="bi bi-gem text-emerald-400 ms-0.5"></i>
                </td>

                <td class="py-3 px-4 text-center font-mono font-bold text-sm">
                  <span :class="item.stock <= 5 ? 'text-amber-400' : 'text-white'">
                    {{ item.stock }}
                  </span>
                </td>

                <td class="py-3 px-4 text-center">
                  <BaseBadge :variant="item.active ? 'success' : 'soft'">
                    {{ item.active ? 'Activo' : 'Inactivo' }}
                  </BaseBadge>
                </td>

                <td class="py-3 px-4 text-right">
                  <div class="flex items-center justify-end">
                    <button
                      class="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-emerald-400 border border-slate-700 text-xs font-semibold rounded-lg transition-all inline-flex items-center gap-1.5"
                      title="Ajustar Cantidad de Stock"
                      @click="openAdjustModal(item)"
                    >
                      <i class="bi bi-pencil-square"></i>
                      <span>Ajustar Stock</span>
                    </button>
                  </div>
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
