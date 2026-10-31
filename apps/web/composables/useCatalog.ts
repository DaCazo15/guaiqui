import { ref, computed } from 'vue'
import { useSupabaseClient } from '#imports'

export interface Product {
  id: string
  team_id?: string
  name: string
  description: string | null
  category: 'physical' | 'experience' | 'raffle'
  cost_pearls: number
  stock: number
  variants: string[] | { [key: string]: any }
  active: boolean
  valid_from: string
  valid_until: string | null
  images: string[]
  created_at: string
  team?: {
    id: string
    name: string
    slug: string
    short_name?: string | null
    logo_url: string | null
    status: 'active' | 'inactive'
  }
}

export const useCatalog = () => {
  const supabase = useSupabaseClient()
  const products = ref<Product[]>([])
  const currentProduct = ref<Product | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchProducts = async (teamId?: string) => {
    loading.value = true
    error.value = null
    try {
      let query = supabase
        .from('products')
        .select('*, team:teams(id, name, slug, short_name, logo_url, status)')
        .eq('active', true)
        .order('cost_pearls', { ascending: true })

      if (teamId) {
        query = query.eq('team_id', teamId)
      }

      const { data, error: dbError } = await query

      if (dbError) throw dbError
      products.value = (data as unknown as Product[]) || []
    } catch (err: any) {
      error.value = err.message || 'Error al cargar el catálogo de premios'
    } finally {
      loading.value = false
    }
  }

  const fetchProductById = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      const { data, error: dbError } = await supabase
        .from('products')
        .select('*, team:teams(id, name, slug, short_name, logo_url, status)')
        .eq('id', id)
        .single()

      if (dbError) throw dbError
      currentProduct.value = data as unknown as Product
      return data as unknown as Product
    } catch (err: any) {
      error.value = err.message || 'Error al cargar el producto'
      return null
    } finally {
      loading.value = false
    }
  }

  return {
    products: computed(() => products.value),
    currentProduct: computed(() => currentProduct.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    fetchProducts,
    fetchProductById,
  }
}
