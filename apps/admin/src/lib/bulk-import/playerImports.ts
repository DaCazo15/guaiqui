import type { BulkImportConfig } from './types'
import { parseBoolean } from './helpers'

export const playerBulkConfig: BulkImportConfig = {
  type: 'players',
  title: 'Carga Masiva de Jugadores',
  entityName: 'Jugadores',
  templateFileName: 'plantilla_jugadores_guaiqueries',
  columns: [
    { key: 'nombre', label: 'Nombre Completo', required: true, example: 'José Ascanio' },
    { key: 'numero_camiseta', label: 'Dorsal (#)', required: true, example: 14 },
    { key: 'posicion', label: 'Posición', required: true, example: 'Ala-Pívot' },
    { key: 'estatura', label: 'Estatura', example: '2.03m' },
    { key: 'edad', label: 'Edad', example: 28 },
    { key: 'nacionalidad', label: 'Nacionalidad', example: 'Venezuela' },
    { key: 'es_estrella', label: 'Es Estrella (SI/NO)', example: 'SI' },
    { key: 'activo', label: 'Activo (SI/NO)', example: 'SI' },
    { key: 'instagram', label: 'Instagram (@usuario o URL)', example: '@ascanio14' },
    { key: 'url_foto', label: 'URL de Fotografía', example: 'https://...' },
    { key: 'biografia', label: 'Biografía breve', example: 'Pilar defensivo de la tribu y selección nacional.' }
  ],
  sampleData: [
    {
      nombre: 'José Ascanio',
      numero_camiseta: 14,
      posicion: 'Ala-Pívot',
      estatura: '2.03m',
      edad: 28,
      nacionalidad: 'Venezuela',
      es_estrella: 'SI',
      activo: 'SI',
      instagram: '@ascanio14',
      url_foto: '',
      biografia: 'Pilar defensivo de la tribu insular.'
    },
    {
      nombre: 'Pedro Chourio',
      numero_camiseta: 24,
      posicion: 'Escolta',
      estatura: '1.86m',
      edad: 34,
      nacionalidad: 'Venezuela',
      es_estrella: 'SI',
      activo: 'SI',
      instagram: '@pedrochourio',
      biografia: 'Capitán y referente perimetral de Guaiqueríes.'
    },
    {
      nombre: 'Gendry Correa',
      numero_camiseta: 7,
      posicion: 'Base',
      estatura: '1.88m',
      edad: 27,
      nacionalidad: 'Venezuela',
      es_estrella: 'NO',
      activo: 'SI',
      instagram: '@gendryc',
      biografia: 'Armador con gran visión y velocidad de contraataque.'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.nombre?.toString().trim()) errors.push(`Fila ${index + 1}: El nombre es obligatorio`)
    if (row.numero_camiseta === undefined || row.numero_camiseta === null || row.numero_camiseta === '') {
      errors.push(`Fila ${index + 1}: El número de camiseta es obligatorio`)
    } else if (isNaN(Number(row.numero_camiseta))) {
      errors.push(`Fila ${index + 1}: El dorsal debe ser un número`)
    }
    if (!row.posicion?.toString().trim()) errors.push(`Fila ${index + 1}: La posición es obligatoria`)
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const payloads = rows.map(r => {
      const rawIg = r.instagram?.toString().trim() || null
      const formattedIg = rawIg && !rawIg.startsWith('http') && !rawIg.includes('/')
        ? `https://instagram.com/${rawIg.replace(/^@/, '')}`
        : rawIg

      return {
        name: String(r.nombre).trim(),
        jersey_number: Number(r.numero_camiseta),
        position: String(r.posicion).trim(),
        height: r.estatura ? String(r.estatura).trim() : null,
        age: r.edad ? Number(r.edad) : null,
        nationality: r.nacionalidad ? String(r.nacionalidad).trim() : 'Venezuela',
        bio: r.biografia ? String(r.biografia).trim() : null,
        is_active: parseBoolean(r.activo, true),
        is_star: parseBoolean(r.es_estrella, false),
        instagram_url: formattedIg,
        photo_url: r.url_foto ? String(r.url_foto).trim() : null
      }
    })

    const { error } = await supabase.from('players').insert(payloads)
    if (error) throw error

    return {
      successCount: payloads.length,
      message: `${payloads.length} jugador(es) agregado(s) a la plantilla exitosamente.`
    }
  }
}
