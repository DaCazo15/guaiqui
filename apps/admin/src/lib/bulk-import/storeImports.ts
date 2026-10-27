import type { BulkImportConfig } from './types'
import { parseBoolean, parseDateToISO, normalizeProductCategory } from './helpers'

export const productsBulkConfig: BulkImportConfig = {
  type: 'products',
  title: 'Carga Masiva de Productos de Canje',
  entityName: 'Productos',
  templateFileName: 'plantilla_tienda_canje_guaiqueries',
  columns: [
    { key: 'nombre', label: 'Nombre del Producto', required: true, example: 'Camiseta Oficial Edición Isla 2026' },
    { key: 'descripcion', label: 'Descripción', example: 'Jersey oficial de juego con escudo bordado.' },
    { key: 'categoria', label: 'Categoría (physical / experience / raffle)', required: true, example: 'physical' },
    { key: 'costo_perlitas', label: 'Costo en Perlitas', required: true, example: 1200 },
    { key: 'stock', label: 'Stock Disponible', required: true, example: 30 },
    { key: 'variantes', label: 'Variantes (separadas por comas)', example: 'S, M, L, XL' },
    { key: 'activo', label: 'Activo en Tienda (SI/NO)', example: 'SI' },
    { key: 'valido_desde', label: 'Válido Desde (YYYY-MM-DD HH:mm)', example: '2026-05-01 00:00' },
    { key: 'valido_hasta', label: 'Válido Hasta (YYYY-MM-DD HH:mm)', example: '' },
    { key: 'imagenes', label: 'URLs Imágenes (separadas por coma)', example: '' }
  ],
  sampleData: [
    {
      nombre: 'Camiseta Oficial Edición Isla 2026',
      descripcion: 'Jersey oficial verde con detalles dorados y escudo bordado.',
      categoria: 'physical',
      costo_perlitas: 1200,
      stock: 35,
      variantes: 'S, M, L, XL',
      activo: 'SI',
      valido_desde: '2026-05-01 00:00',
      valido_hasta: '',
      imagenes: ''
    },
    {
      nombre: 'Balón Oficial Autografiado por la Plantilla',
      descripcion: 'Balón Molten oficial de la SPB firmado por todo el roster.',
      categoria: 'physical',
      costo_perlitas: 2500,
      stock: 5,
      variantes: '',
      activo: 'SI',
      valido_desde: '2026-05-01 00:00',
      valido_hasta: '',
      imagenes: ''
    },
    {
      nombre: 'Saludo en Video Personalizado de Jugador Estrella',
      descripcion: 'Video exclusivo deseándote feliz cumpleaños o saludo de ánimo.',
      categoria: 'experience',
      costo_pearls: 800,
      stock: 20,
      variantes: '',
      activo: 'SI',
      valido_desde: '2026-05-01 00:00',
      valido_hasta: '',
      imagenes: ''
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.nombre?.toString().trim()) errors.push(`Fila ${index + 1}: El nombre del producto es obligatorio`)
    const cost = Number(row.costo_perlitas)
    if (isNaN(cost) || cost <= 0) errors.push(`Fila ${index + 1}: El costo en perlitas debe ser mayor a 0`)
    const stock = Number(row.stock)
    if (isNaN(stock) || stock < 0) errors.push(`Fila ${index + 1}: El stock no puede ser negativo`)
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    let count = 0
    for (const r of rows) {
      const variantsList = r.variantes
        ? String(r.variantes).split(',').map((v: string) => v.trim()).filter(Boolean)
        : []

      const imagesList = r.imagenes
        ? String(r.imagenes).split(',').map((img: string) => img.trim()).filter(Boolean)
        : []

      const payload = {
        name: String(r.nombre).trim(),
        description: r.descripcion ? String(r.descripcion).trim() : '',
        category: normalizeProductCategory(r.categoria),
        cost_pearls: Number(r.costo_perlitas),
        stock: Number(r.stock),
        variants: variantsList,
        active: parseBoolean(r.activo, true),
        valid_from: r.valido_desde ? parseDateToISO(r.valido_desde) : new Date().toISOString(),
        valid_until: r.valido_hasta ? parseDateToISO(r.valido_hasta) : null,
        images: imagesList
      }

      const { error } = await supabase.rpc('admin_upsert_product', { p_product: payload })
      if (error) throw error
      count++
    }

    return {
      successCount: count,
      message: `${count} producto(s) guardado(s) en la tienda de canje.`
    }
  }
}
