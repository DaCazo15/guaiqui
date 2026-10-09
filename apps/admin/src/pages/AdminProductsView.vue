<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface ProductRow {
  id: string
  name: string
  description?: string
  category: 'physical' | 'experience' | 'raffle'
  cost_pearls: number
  stock: number
  variants: any[]
  active: boolean
  valid_from: string
  valid_until?: string
  images: string[]
  created_at: string
}

const products = ref<ProductRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const selectedProduct = ref<ProductRow | null>(null)
const uploadingImage = ref(false)

const productForm = ref({
  id: '',
  name: '',
  description: '',
  category: 'physical' as 'physical' | 'experience' | 'raffle',
  cost_pearls: 100,
  stock: 10,
  variantsText: 'S, M, L, XL',
  active: true,
  valid_from: '',
  valid_until: '',
  images: [] as string[]
})

const columns = [
  { key: 'name', label: 'Producto' },
  { key: 'category', label: 'Categoría' },
  { key: 'cost_pearls', label: 'Costo (Perlitas)' },
  { key: 'stock', label: 'Stock Disponible' },
  { key: 'active', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadProducts = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error
    products.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewProduct = () => {
  selectedProduct.value = null
  const now = new Date()
  productForm.value = {
    id: '',
    name: '',
    description: '',
    category: 'physical',
    cost_pearls: 100,
    stock: 10,
    variantsText: '',
    active: true,
    valid_from: now.toISOString().slice(0, 16),
    valid_until: '',
    images: []
  }
  showEditorModal.value = true
}

const editProduct = (p: ProductRow) => {
  selectedProduct.value = p
  productForm.value = {
    id: p.id,
    name: p.name,
    description: p.description || '',
    category: p.category,
    cost_pearls: p.cost_pearls,
    stock: p.stock,
    variantsText: Array.isArray(p.variants) ? p.variants.join(', ') : '',
    active: p.active,
    valid_from: p.valid_from ? new Date(p.valid_from).toISOString().slice(0, 16) : '',
    valid_until: p.valid_until ? new Date(p.valid_until).toISOString().slice(0, 16) : '',
    images: p.images || []
  }
  showEditorModal.value = true
}

const handleImageUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  if (!target.files || target.files.length === 0) return

  const file = target.files[0]
  if (file.size > 5 * 1024 * 1024) {
    errorMessage.value = 'El tamaño de la imagen no puede superar 5 MB.'
    return
  }

  uploadingImage.value = true
  try {
    const fileExt = file.name.split('.').pop()
    const filePath = `product_${Date.now()}.${fileExt}`

    const { error: uploadErr } = await supabase.storage
      .from('product-images')
      .upload(filePath, file)

    if (uploadErr) throw uploadErr

    const { data: publicUrlData } = supabase.storage
      .from('product-images')
      .getPublicUrl(filePath)

    productForm.value.images.push(publicUrlData.publicUrl)
    successMessage.value = 'Imagen subida correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    uploadingImage.value = false
  }
}

const removeImage = (index: number) => {
  productForm.value.images.splice(index, 1)
}

const saveProduct = async () => {
  actionLoading.value = true
  errorMessage.value = null
  try {
    const variantsList = productForm.value.variantsText
      .split(',')
      .map(v => v.trim())
      .filter(v => v.length > 0)

    const payload = {
      id: productForm.value.id || undefined,
      name: productForm.value.name,
      description: productForm.value.description,
      category: productForm.value.category,
      cost_pearls: Number(productForm.value.cost_pearls),
      stock: Number(productForm.value.stock),
      variants: variantsList,
      active: productForm.value.active,
      valid_from: productForm.value.valid_from ? new Date(productForm.value.valid_from).toISOString() : new Date().toISOString(),
      valid_until: productForm.value.valid_until ? new Date(productForm.value.valid_until).toISOString() : null,
      images: productForm.value.images
    }

    const { error } = await supabase.rpc('admin_upsert_product', { p_product: payload })
    if (error) throw error

    successMessage.value = 'Producto guardado correctamente.'
    showEditorModal.value = false
    await loadProducts()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadProducts)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Catálogo de Productos</h1>
          <p class="text-sm text-slate-400">Administrar catálogo de canje, stock, costos y variaciones.</p>
        </div>
        <BaseButton variant="primary" @click="openNewProduct">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Producto
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(products as any[])" :loading="loading" empty-text="No hay productos en el catálogo">
        <template #cell-name="{ row }">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-center overflow-hidden shrink-0">
              <img v-if="(row as ProductRow).images && (row as ProductRow).images.length > 0" :src="(row as ProductRow).images[0]" class="w-full h-full object-cover" />
              <i v-else class="bi bi-box-seam text-slate-500 text-lg"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100">{{ (row as ProductRow).name }}</div>
              <div class="text-xs text-slate-400 truncate max-w-xs">{{ (row as ProductRow).description }}</div>
            </div>
          </div>
        </template>

        <template #cell-category="{ row }">
          <span class="text-xs capitalize font-medium text-slate-300">{{ (row as ProductRow).category }}</span>
        </template>

        <template #cell-cost_pearls="{ row }">
          <span class="text-sm font-bold font-mono text-emerald-400">{{ (row as ProductRow).cost_pearls }} perlitas</span>
        </template>

        <template #cell-stock="{ row }">
          <span :class="['text-xs font-semibold px-2 py-0.5 rounded-full border font-mono', Number((row as ProductRow).stock) <= 5 ? 'bg-red-950 text-red-400 border-red-800' : 'bg-slate-900 text-slate-300 border-slate-800']">
            {{ (row as ProductRow).stock }} unid.
          </span>
        </template>

        <template #cell-active="{ row }">
          <BaseBadge :variant="(row as ProductRow).active ? 'success' : 'soft'">
            {{ (row as ProductRow).active ? 'Activo' : 'Inactivo' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editProduct(row as ProductRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg" title="Editar producto">
              <i class="bi bi-pencil"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Product Editor Modal -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Producto" @close="showEditorModal = false" size="lg">
      <div class="space-y-4">
        <BaseInput label="Nombre del Producto" v-model="productForm.name" placeholder="Ej: Camiseta Oficial 2026" />
        <BaseInput label="Descripción" v-model="productForm.description" placeholder="Descripción corta del producto" />

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <BaseSelect
            label="Categoría"
            v-model="productForm.category"
            :options="[
              { value: 'physical', label: 'Físico (Camisetas, gorras)' },
              { value: 'experience', label: 'Experiencia (Saludos, pases)' },
              { value: 'raffle', label: 'Sorteo' }
            ]"
          />
          <BaseInput label="Costo en Perlitas" type="number" v-model="productForm.cost_pearls" />
          <BaseInput label="Stock Inicial" type="number" v-model="productForm.stock" />
        </div>

        <BaseInput label="Variantes (separadas por coma)" v-model="productForm.variantsText" placeholder="S, M, L, XL" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Válido Desde" type="datetime-local" v-model="productForm.valid_from" />
          <BaseInput label="Válido Hasta (Opcional)" type="datetime-local" v-model="productForm.valid_until" />
        </div>

        <div class="space-y-2 border-t border-slate-800 pt-3">
          <label class="block text-xs font-semibold text-slate-400">Imágenes del Producto (Bucket product-images)</label>
          <div class="flex flex-wrap items-center gap-3">
            <div v-for="(img, idx) in productForm.images" :key="idx" class="w-16 h-16 rounded-lg bg-slate-900 border border-slate-800 relative group overflow-hidden">
              <img :src="img" class="w-full h-full object-cover" />
              <button @click="removeImage(idx)" class="absolute inset-0 bg-red-950/80 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                <i class="bi bi-trash"></i>
              </button>
            </div>

            <label class="w-16 h-16 rounded-lg border-2 border-dashed border-slate-800 hover:border-emerald-500 flex flex-col items-center justify-center cursor-pointer transition-colors text-slate-500 hover:text-emerald-400">
              <i v-if="!uploadingImage" class="bi bi-upload text-xl"></i>
              <i v-else class="bi bi-arrow-repeat animate-spin text-xl"></i>
              <span class="text-[10px] mt-1">Subir</span>
              <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" @change="handleImageUpload" :disabled="uploadingImage" />
            </label>
          </div>
        </div>

        <div class="p-3 rounded-lg bg-slate-900 text-xs text-slate-400 border border-slate-800 flex items-center gap-2">
          <i class="bi bi-info-circle text-emerald-400"></i>
          <span>Los cambios de precio no afectarán los canjes ya realizados (costo congelado en cada orden).</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveProduct">Guardar Producto</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
