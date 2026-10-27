import type { BulkImportConfig } from './types'
import { parseBoolean, normalizeGroupCategory } from './helpers'

export const staffBulkConfig: BulkImportConfig = {
  type: 'staff',
  title: 'Carga Masiva de Cuerpo Técnico & Directiva',
  entityName: 'Miembros de Equipo',
  templateFileName: 'plantilla_cuerpo_tecnico_guaiqueries',
  columns: [
    { key: 'nombre', label: 'Nombre Completo', required: true, example: 'Yonaiker Ecker' },
    { key: 'cargo', label: 'Cargo / Rol', required: true, example: 'Director Técnico' },
    { key: 'categoria', label: 'Categoría (tecnico / directiva / logistica)', required: true, example: 'tecnico' },
    { key: 'orden', label: 'Orden de Visualización', example: 1 },
    { key: 'publicado', label: 'Publicado (SI/NO)', example: 'SI' },
    { key: 'url_foto', label: 'URL de Fotografía', example: '' }
  ],
  sampleData: [
    {
      nombre: 'Yonaiker Ecker',
      cargo: 'Director Técnico',
      categoria: 'tecnico',
      orden: 1,
      publicado: 'SI',
      url_foto: ''
    },
    {
      nombre: 'Gustavo Arismendi',
      cargo: 'Asistente Técnico',
      categoria: 'tecnico',
      orden: 2,
      publicado: 'SI',
      url_foto: ''
    },
    {
      nombre: 'Héctor Rodríguez',
      cargo: 'Presidente',
      categoria: 'directiva',
      orden: 1,
      publicado: 'SI',
      url_foto: ''
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.nombre?.toString().trim()) errors.push(`Fila ${index + 1}: El nombre es obligatorio`)
    if (!row.cargo?.toString().trim()) errors.push(`Fila ${index + 1}: El cargo es obligatorio`)
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const payloads = rows.map((r, idx) => ({
      name: String(r.nombre).trim(),
      role: String(r.cargo).trim(),
      group_category: normalizeGroupCategory(r.categoria),
      order_index: r.orden !== undefined && r.orden !== null && r.orden !== '' ? Number(r.orden) : idx + 1,
      is_published: parseBoolean(r.publicado, true),
      photo_url: r.url_foto ? String(r.url_foto).trim() : null
    }))

    const { error } = await supabase.from('site_team_members').insert(payloads)
    if (error) throw error

    return {
      successCount: payloads.length,
      message: `${payloads.length} miembro(s) registrado(s) correctamente.`
    }
  }
}
