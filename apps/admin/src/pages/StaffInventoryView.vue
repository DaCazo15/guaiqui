<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import StaffLayout from '../components/layout/StaffLayout.vue'
import InventoryAdjustModal from '../components/inventory/InventoryAdjustModal.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseSelect } from '@guaiqui/ui'
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
const actionLoading = ref(false)
const searchQuery = ref('')
const selectedCategory = ref('')

const selectedProduct = ref<ProductItem | null>(null)
const isAdjustModalOpen = ref(false)

// Editor & Delete Modal states
const showEditorModal = ref(false)
const showDeleteModal = ref(false)

const productForm = ref({
  id: '',
  name: '',
  description: '',
  category: 'physical',
  cost_pearls: 100,
  stock: 10,
  active: true,
  images: [] as string[]
})

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
  } catch (err: any) {
    alert('Error de conexión al ajustar existencias: ' + err.message)
  }
}

// Open modal for New Product Creation
const openNewProduct = () => {
  selectedProduct.value = null
  productForm.value = {
    id: '',
    name: '',
    description: '',
    category: 'physical',
    cost_pearls: 100,
    stock: 10,
    active: true,
    images: []
  }
  showEditorModal.value = true
}

// Open modal for Editing Product
const editProduct = (p: ProductItem) => {
  selectedProduct.value = p
  productForm.value = {
    id: p.id,
    name: p.name,
    description: p.description || '',
    category: p.category || 'physical',
    cost_pearls: p.cost_pearls,
    stock: p.stock,
    active: p.active,
    images: p.images || []
  }
  showEditorModal.value = true
}

// Save or Update Product
const saveProduct = async () => {
  if (!productForm.value.name.trim()) {
    alert('El nombre del producto es obligatorio.')
    return
  }

  actionLoading.value = true
  try {
    const payload = {
      id: productForm.value.id || undefined,
      name: productForm.value.name,
      description: productForm.value.description,
      category: productForm.value.category,
      cost_pearls: Number(productForm.value.cost_pearls),
      stock: Number(productForm.value.stock),
      active: productForm.value.active,
      images: productForm.value.images
    }

    const { error } = await supabase.rpc('admin_upsert_product', { p_product: payload })
    if (error) throw error

    showEditorModal.value = false
    await fetchProducts()
  } catch (err: any) {
    alert('Error al guardar el producto: ' + err.message)
  } finally {
    actionLoading.value = false
  }
}

// Open modal for Deleting Product
const confirmDeleteProduct = (p: ProductItem) => {
  selectedProduct.value = p
  showDeleteModal.value = true
}

const deleteProduct = async () => {
  if (!selectedProduct.value) return
  actionLoading.value = true
  try {
    const { error } = await supabase
      .from('products')
      .delete()
      .eq('id', selectedProduct.value.id)

    if (error) throw error

    showDeleteModal.value = false
    selectedProduct.value = null
    await fetchProducts()
  } catch (err: any) {
    alert('Error al eliminar producto: ' + err.message)
  } finally {
    actionLoading.value = false
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
          <p class="text-xs text-slate-400">Crear, modificar, eliminar y gestionar stock de premios canjeables</p>
        </div>

        <div class="flex items-center gap-3">
          <BaseButton variant="primary" @click="openNewProduct">
            <i class="bi bi-plus-lg mr-1.5"></i> Agregar Producto
          </BaseButton>
          <button
            @click="fetchProducts"
            :disabled="isLoading"
            class="p-2 text-slate-300 hover:text-white bg-slate-900 border border-slate-800 rounded-xl"
            title="Actualizar catálogo"
          >
            <i :class="['bi bi-arrow-clockwise text-lg', isLoading ? 'animate-spin' : '']"></i>
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
                  {{ item.cost_pearls }} 🦪
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
                  <div class="flex items-center justify-end gap-1.5">
                    <button
                      @click="editProduct(item)"
                      class="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
                      title="Editar Producto"
                    >
                      <i class="bi bi-pencil text-sm"></i>
                    </button>

                    <button
                      @click="openAdjustModal(item)"
                      class="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-emerald-400 border border-slate-700 text-xs font-semibold rounded-lg transition-all"
                      title="Ajustar Cantidad de Stock"
                    >
                      <i class="bi bi-pencil-square me-1"></i> Stock
                    </button>

                    <button
                      @click="confirmDeleteProduct(item)"
                      class="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-950/60 rounded-lg transition-colors"
                      title="Eliminar Producto"
                    >
                      <i class="bi bi-trash text-sm"></i>
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

      <!-- Product Editor Modal (Crear / Editar) -->
      <BaseModal
        v-if="showEditorModal"
        :is-open="showEditorModal"
        :title="productForm.id ? 'Editar Producto Canjeable' : 'Agregar Nuevo Producto Canjeable'"
        @close="showEditorModal = false"
      >
        <div class="space-y-4">
          <BaseInput label="Nombre del Producto" v-model="productForm.name" placeholder="Ej: Camiseta Oficial Guaiqueríes 2026" />
          <BaseInput label="Descripción" v-model="productForm.description" placeholder="Descripción breve del producto canjeable" />

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <BaseSelect
              label="Categoría"
              v-model="productForm.category"
              :options="[
                { value: 'physical', label: 'Físico (Camisetas, gorras)' },
                { value: 'experience', label: 'Experiencia (Saludos, entradas)' },
                { value: 'raffle', label: 'Sorteo' }
              ]"
            />
            <BaseInput label="Costo en Perlitas" type="number" v-model.number="productForm.cost_pearls" />
            <BaseInput label="Stock Inicial" type="number" v-model.number="productForm.stock" />
          </div>

          <div class="flex items-center pt-2">
            <label class="flex items-center gap-2 text-sm text-slate-200 cursor-pointer">
              <input type="checkbox" v-model="productForm.active" class="w-4 h-4 accent-emerald-500 rounded" />
              <span>Producto Activo en la Tienda</span>
            </label>
          </div>
        </div>

        <template #footer>
          <div class="flex items-center justify-end gap-3">
            <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
            <BaseButton variant="primary" :loading="actionLoading" @click="saveProduct">Guardar Producto</BaseButton>
          </div>
        </template>
      </BaseModal>

      <!-- Delete Confirmation Modal -->
      <BaseModal v-if="showDeleteModal" :is-open="showDeleteModal" title="Eliminar Producto" @close="showDeleteModal = false">
        <div class="space-y-4">
          <p class="text-sm text-slate-300">
            ¿Está seguro de eliminar permanentemente el producto <strong>{{ selectedProduct?.name }}</strong> del inventario?
          </p>
          <div class="p-3 bg-red-950/40 border border-red-800 text-xs text-red-300 rounded-lg">
            Esta acción lo eliminará de la tienda de canjes del fanático.
          </div>
        </div>
        <template #footer>
          <div class="flex items-center justify-end gap-3">
            <BaseButton variant="secondary" @click="showDeleteModal = false">Cancelar</BaseButton>
            <BaseButton variant="danger" :loading="actionLoading" @click="deleteProduct">Confirmar Eliminación</BaseButton>
          </div>
        </template>
      </BaseModal>
    </div>
  </StaffLayout>
</template>
