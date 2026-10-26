import * as XLSX from 'xlsx'
import { caracasInputToISO } from '@guaiqui/shared'

export type BulkImportType = 'trivias' | 'players' | 'staff' | 'games' | 'products' | 'who_is'

export interface BulkColumnDef {
  key: string
  label: string
  required?: boolean
  description?: string
  example?: string | number
}

export interface BulkImportConfig {
  type: BulkImportType
  title: string
  entityName: string
  templateFileName: string
  columns: BulkColumnDef[]
  sampleData: Record<string, any>[]
  validateRow: (row: Record<string, any>, rowIndex: number) => { valid: boolean; errors: string[] }
  processRows: (rows: Record<string, any>[], supabase: any) => Promise<{ successCount: number; message: string }>
}

// Helpers
export function parseBoolean(value: any, defaultValue = true): boolean {
  if (value === undefined || value === null || value === '') return defaultValue
  if (typeof value === 'boolean') return value
  const str = String(value).trim().toLowerCase()
  return ['si', 'sí', 'true', '1', 'yes', 'y', 's', 'activo', 'publicado'].includes(str)
}

export function parseDateToISO(value: any): string {
  if (!value) return ''
  if (value instanceof Date) {
    return value.toISOString()
  }
  const str = String(value).trim()
  // If already standard ISO
  if (str.includes('T') && str.endsWith('Z')) return str

  // If YYYY-MM-DD HH:mm or YYYY-MM-DDTHH:mm
  const normalized = str.replace(' ', 'T')
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(normalized)) {
    return caracasInputToISO(normalized.slice(0, 16))
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
    return caracasInputToISO(`${str}T00:00`)
  }

  const parsed = new Date(str)
  if (!isNaN(parsed.getTime())) {
    return parsed.toISOString()
  }
  return ''
}

export function normalizeGroupCategory(val: any): 'directiva' | 'tecnico' | 'logistica' {
  if (!val) return 'tecnico'
  const s = String(val).trim().toLowerCase()
  if (s.includes('dir') || s.includes('presid') || s.includes('geren')) return 'directiva'
  if (s.includes('log') || s.includes('util') || s.includes('fisi') || s.includes('staff')) return 'logistica'
  return 'tecnico'
}

export function normalizeGameStatus(val: any): 'scheduled' | 'live' | 'finished' | 'cancelled' {
  if (!val) return 'scheduled'
  const s = String(val).trim().toLowerCase()
  if (s.includes('vivo') || s === 'live') return 'live'
  if (s.includes('fin') || s === 'finalizado') return 'finished'
  if (s.includes('canc') || s === 'cancelado') return 'cancelled'
  return 'scheduled'
}

export function normalizeProductCategory(val: any): 'physical' | 'experience' | 'raffle' {
  if (!val) return 'physical'
  const s = String(val).trim().toLowerCase()
  if (s.includes('exp') || s.includes('saludo') || s.includes('pase')) return 'experience'
  if (s.includes('sort') || s.includes('rifa') || s.includes('raffle')) return 'raffle'
  return 'physical'
}

export function normalizeChallengeType(val: any): 'silhouette' | 'dorsal' {
  if (!val) return 'silhouette'
  const s = String(val).trim().toLowerCase()
  if (s.includes('dor') || s.includes('num') || s.includes('camiset')) return 'dorsal'
  return 'silhouette'
}

// Configs by Entity
export const BULK_CONFIGS: Record<BulkImportType, BulkImportConfig> = {
  // 1. TRIVIAS
  trivias: {
    type: 'trivias',
    title: 'Carga Masiva de Trivias',
    entityName: 'Trivias',
    templateFileName: 'plantilla_trivias_guaiqueries',
    columns: [
      { key: 'titulo_trivia', label: 'Título de la Trivia', required: true, description: 'Título agrupador', example: 'Historia de la Tribu 2026' },
      { key: 'descripcion', label: 'Descripción', description: 'Instrucciones para los fanáticos', example: 'Demuestra cuánto sabes sobre Guaiqueríes' },
      { key: 'inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:mm)', required: true, description: 'Hora Caracas', example: '2026-05-01 09:00' },
      { key: 'fin', label: 'Fecha Fin (YYYY-MM-DD HH:mm)', required: true, description: 'Hora Caracas', example: '2026-05-08 23:59' },
      { key: 'tiempo_segundos', label: 'Tiempo Límite (Segundos)', description: 'Por defecto 60', example: 60 },
      { key: 'puntos_por_pregunta', label: 'Perlitas por Pregunta', description: 'Por defecto 50', example: 50 },
      { key: 'bono_perfecto', label: 'Bono Puntuación Perfecta', description: 'Por defecto 100', example: 100 },
      { key: 'pregunta', label: 'Texto de la Pregunta', required: true, description: 'Pregunta individual', example: '¿En qué año se fundó Guaiqueríes de Margarita?' },
      { key: 'puntos_pregunta', label: 'Puntos Pregunta', description: 'Puntos en el test (50)', example: 50 },
      { key: 'opcion_1', label: 'Opción 1', required: true, description: 'Primera alternativa', example: '1977' },
      { key: 'opcion_2', label: 'Opción 2', required: true, description: 'Segunda alternativa', example: '1980' },
      { key: 'opcion_3', label: 'Opción 3', description: 'Tercera alternativa (opcional)', example: '1975' },
      { key: 'opcion_4', label: 'Opción 4', description: 'Cuarta alternativa (opcional)', example: '1985' },
      { key: 'opcion_correcta', label: 'Opción Correcta (1-4)', required: true, description: 'Número del 1 al 4', example: 1 }
    ],
    sampleData: [
      {
        titulo_trivia: 'Historia y Títulos de la Tribu',
        descripcion: 'Responde sobre los campeonatos de Guaiqueríes',
        inicio: '2026-05-01 09:00',
        fin: '2026-05-15 23:59',
        tiempo_segundos: 60,
        puntos_por_pregunta: 50,
        bono_perfecto: 100,
        pregunta: '¿En qué año se fundó Guaiqueríes de Margarita?',
        puntos_pregunta: 50,
        opcion_1: '1977',
        opcion_2: '1980',
        opcion_3: '1975',
        opcion_4: '1985',
        opcion_correcta: 1
      },
      {
        titulo_trivia: 'Historia y Títulos de la Tribu',
        descripcion: 'Responde sobre los campeonatos de Guaiqueríes',
        inicio: '2026-05-01 09:00',
        fin: '2026-05-15 23:59',
        tiempo_segundos: 60,
        puntos_por_pregunta: 50,
        bono_perfecto: 100,
        pregunta: '¿Cuál es el apodo de la casa de Guaiqueríes en La Asunción?',
        puntos_pregunta: 50,
        opcion_1: 'La Choza',
        opcion_2: 'El Gimnasio Verde',
        opcion_3: 'El Coliseo Insular',
        opcion_4: 'La Cancha Nueva',
        opcion_correcta: 1
      },
      {
        titulo_trivia: 'Reglas y Básquetbol 2026',
        descripcion: 'Conocimientos generales de baloncesto',
        inicio: '2026-05-10 10:00',
        fin: '2026-05-20 22:00',
        tiempo_segundos: 45,
        puntos_por_pregunta: 40,
        bono_perfecto: 80,
        pregunta: '¿Cuántos segundos dura la posesión de tiro en FIBA?',
        puntos_pregunta: 40,
        opcion_1: '24 segundos',
        opcion_2: '30 segundos',
        opcion_3: '20 segundos',
        opcion_4: '14 segundos',
        opcion_correcta: 1
      }
    ],
    validateRow: (row, index) => {
      const errors: string[] = []
      if (!row.titulo_trivia?.toString().trim()) errors.push(`Fila ${index + 1}: El título de la trivia es obligatorio`)
      if (!row.inicio) errors.push(`Fila ${index + 1}: La fecha de inicio es obligatoria`)
      if (!row.fin) errors.push(`Fila ${index + 1}: La fecha de fin es obligatoria`)
      if (!row.pregunta?.toString().trim()) errors.push(`Fila ${index + 1}: La pregunta es obligatoria`)
      if (!row.opcion_1?.toString().trim()) errors.push(`Fila ${index + 1}: La opción 1 es obligatoria`)
      if (!row.opcion_2?.toString().trim()) errors.push(`Fila ${index + 1}: La opción 2 es obligatoria`)

      const optNum = Number(row.opcion_correcta)
      if (isNaN(optNum) || optNum < 1 || optNum > 4) {
        errors.push(`Fila ${index + 1}: La opción correcta debe ser un número del 1 al 4`)
      }
      return { valid: errors.length === 0, errors }
    },
    processRows: async (rows, supabase) => {
      // Group rows by trivia title
      const groups = new Map<string, any[]>()
      for (const r of rows) {
        const title = String(r.titulo_trivia).trim()
        if (!groups.has(title)) groups.set(title, [])
        groups.get(title)!.push(r)
      }

      let count = 0
      for (const [title, groupRows] of groups.entries()) {
        const first = groupRows[0]
        const payloadTrivia = {
          title,
          description: first.descripcion ? String(first.descripcion).trim() : '',
          starts_at: parseDateToISO(first.inicio),
          ends_at: parseDateToISO(first.fin),
          time_limit_seconds: Number(first.tiempo_segundos) || 60,
          target_segment_id: null,
          reward_rules: {
            per_correct_pearls: Number(first.puntos_por_pregunta) || 50,
            perfect_score_bonus: Number(first.bono_perfecto) || 100
          }
        }

        const questions = groupRows.map((qr, idx) => {
          const correctIdx = Number(qr.opcion_correcta)
          const options = [
            { option_text: String(qr.opcion_1).trim(), is_correct: correctIdx === 1 },
            { option_text: String(qr.opcion_2).trim(), is_correct: correctIdx === 2 }
          ]
          if (qr.opcion_3?.toString().trim()) {
            options.push({ option_text: String(qr.opcion_3).trim(), is_correct: correctIdx === 3 })
          }
          if (qr.opcion_4?.toString().trim()) {
            options.push({ option_text: String(qr.opcion_4).trim(), is_correct: correctIdx === 4 })
          }

          return {
            question_text: String(qr.pregunta).trim(),
            points: Number(qr.puntos_pregunta) || Number(first.puntos_por_pregunta) || 50,
            order_index: idx,
            options
          }
        })

        const { error } = await supabase.rpc('admin_upsert_trivia', {
          p_trivia: payloadTrivia,
          p_questions: questions
        })
        if (error) throw error
        count++
      }

      return {
        successCount: count,
        message: `${count} trivia(s) con ${rows.length} pregunta(s) importada(s) correctamente.`
      }
    }
  },

  // 2. PLAYERS
  players: {
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
          instagram_url: formattedIg
        }
      })

      const { error } = await supabase.from('players').insert(payloads)
      if (error) throw error

      return {
        successCount: payloads.length,
        message: `${payloads.length} jugador(es) agregado(s) a la plantilla exitosamente.`
      }
    }
  },

  // 3. STAFF / CUERPO TÉCNICO
  staff: {
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
  },

  // 4. GAMES / CALENDARIO
  games: {
    type: 'games',
    title: 'Carga Masiva de Calendario de Partidos',
    entityName: 'Partidos',
    templateFileName: 'plantilla_calendario_partidos_guaiqueries',
    columns: [
      { key: 'rival', label: 'Equipo Rival', required: true, example: 'Trotamundos de Carabobo' },
      { key: 'url_logo_rival', label: 'URL Logo del Rival', description: 'Enlace web directo a la imagen del escudo (opcional)', example: 'https://images.sofascore.com/team-logo.png' },
      { key: 'fecha_partido', label: 'Fecha y Hora (YYYY-MM-DD HH:mm)', required: true, example: '2026-06-15 19:30' },
      { key: 'sede', label: 'Sede / Gimnasio', example: 'Gimnasio Ciudad de La Asunción' },
      { key: 'es_local', label: 'Es Local (SI/NO)', example: 'SI' },
      { key: 'estado', label: 'Estado (scheduled / live / finished / cancelled)', example: 'scheduled' },
      { key: 'puntos_guaiqueries', label: 'Puntos Guaiqueríes', example: 0 },
      { key: 'puntos_rival', label: 'Puntos Rival', example: 0 }
    ],
    sampleData: [
      {
        rival: 'Trotamundos de Carabobo',
        url_logo_rival: 'https://api.sofascore.app/api/v1/team/348731/image',
        fecha_partido: '2026-06-12 19:30',
        sede: 'Gimnasio Ciudad de La Asunción',
        es_local: 'SI',
        estado: 'scheduled',
        puntos_guaiqueries: 0,
        puntos_rival: 0
      },
      {
        rival: 'Cocodrilos de Caracas',
        url_logo_rival: 'https://api.sofascore.app/api/v1/team/286915/image',
        fecha_partido: '2026-06-16 19:00',
        sede: 'Parque Naciones Unidas, Caracas',
        es_local: 'NO',
        estado: 'scheduled',
        puntos_guaiqueries: 0,
        puntos_rival: 0
      },
      {
        rival: 'Marinos de Oriente',
        url_logo_rival: 'https://api.sofascore.app/api/v1/team/348733/image',
        fecha_partido: '2026-06-20 18:30',
        sede: 'Gimnasio Ciudad de La Asunción',
        es_local: 'SI',
        estado: 'scheduled',
        puntos_guaiqueries: 0,
        puntos_rival: 0
      }
    ],
    validateRow: (row, index) => {
      const errors: string[] = []
      if (!row.rival?.toString().trim()) errors.push(`Fila ${index + 1}: El nombre del rival es obligatorio`)
      if (!row.fecha_partido) errors.push(`Fila ${index + 1}: La fecha y hora del partido es obligatoria`)
      return { valid: errors.length === 0, errors }
    },
    processRows: async (rows, supabase) => {
      const payloads = rows.map(r => {
        const rawLogo = r.url_logo_rival || r.url_logo || r.logo_rival || r.logo || r.logo_url || r.opponent_logo_url || ''
        const logoUrl = rawLogo ? String(rawLogo).trim() : null

        return {
          opponent: String(r.rival).trim(),
          opponent_logo_url: logoUrl,
          location: r.sede ? String(r.sede).trim() : 'Gimnasio Ciudad de La Asunción',
          game_date: parseDateToISO(r.fecha_partido),
          is_home: parseBoolean(r.es_local, true),
          status: normalizeGameStatus(r.estado),
          our_score: Number(r.puntos_guaiqueries) || 0,
          opponent_score: Number(r.puntos_rival) || 0
        }
      })

      const { error } = await supabase.from('games').insert(payloads)
      if (error) throw error

      return {
        successCount: payloads.length,
        message: `${payloads.length} partido(s) programado(s) en el calendario exitosamente.`
      }
    }
  },

  // 5. PRODUCTS / TIENDA DE CANJE
  products: {
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
  },

  // 6. WHO IS / ¿QUIÉN ES?
  who_is: {
    type: 'who_is',
    title: 'Carga Masiva de Retos ¿Quién es?',
    entityName: 'Retos ¿Quién es?',
    templateFileName: 'plantilla_quien_es_guaiqueries',
    columns: [
      { key: 'dorsal_o_nombre', label: 'Dorsal o Nombre del Jugador', required: true, example: '10' },
      { key: 'tipo', label: 'Tipo de Reto (silueta / dorsal)', required: true, example: 'silueta' },
      { key: 'titulo', label: 'Título del Reto', example: '¿Quién es este jugador de la Tribu?' },
      { key: 'pista', label: 'Pista (Opcional)', example: 'Posición: Base, campeón de la SuperLiga' },
      { key: 'perlitas', label: 'Perlitas de Recompensa', example: 50 },
      { key: 'url_imagen', label: 'URL Imagen Personalizada (Opcional)', example: '' },
      { key: 'inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:mm)', example: '2026-06-01 09:00' },
      { key: 'fin', label: 'Fecha Fin (YYYY-MM-DD HH:mm)', example: '2026-06-15 23:59' },
      { key: 'estado', label: 'Estado (publicado / borrador)', example: 'publicado' }
    ],
    sampleData: [
      {
        dorsal_o_nombre: '10',
        tipo: 'silueta',
        titulo: '¿Quién es este Guaiquerí?',
        pista: 'Líder en asistencias de la temporada.',
        perlitas: 50,
        url_imagen: '',
        inicio: '2026-06-01 09:00',
        fin: '2026-06-15 23:59',
        estado: 'publicado'
      },
      {
        dorsal_o_nombre: '7',
        tipo: 'dorsal',
        titulo: 'Adivina qué jugador viste este dorsal',
        pista: 'Alero estrella con gran tiro perimetral.',
        perlitas: 50,
        url_imagen: '',
        inicio: '2026-06-05 10:00',
        fin: '2026-06-20 22:00',
        estado: 'publicado'
      }
    ],
    validateRow: (row, index) => {
      const errors: string[] = []
      if (!row.dorsal_o_nombre?.toString().trim()) {
        errors.push(`Fila ${index + 1}: El dorsal o nombre del jugador es obligatorio.`)
      }
      return { valid: errors.length === 0, errors }
    },
    processRows: async (rows, supabase) => {
      const { data: players, error: pErr } = await supabase.from('players').select('id, name, jersey_number')
      if (pErr) throw pErr

      const playerList: any[] = players || []
      const payloads: any[] = []

      for (let i = 0; i < rows.length; i++) {
        const r = rows[i]
        const query = String(r.dorsal_o_nombre).trim().toLowerCase()
        const queryNumber = Number(query)

        const matchedPlayer = playerList.find((p: any) => {
          if (!isNaN(queryNumber) && p.jersey_number === queryNumber) return true
          return p.name.toLowerCase().includes(query)
        })

        if (!matchedPlayer) {
          throw new Error(`Fila ${i + 1}: No se encontró ningún jugador en la plantilla con dorsal o nombre "${r.dorsal_o_nombre}".`)
        }

        const isPublished = parseBoolean(r.estado, true)
        const challengeType = normalizeChallengeType(r.tipo)

        payloads.push({
          player_id: matchedPlayer.id,
          challenge_type: challengeType,
          title: r.titulo ? String(r.titulo).trim() : '¿Quién es este jugador?',
          clue: r.pista ? String(r.pista).trim() : null,
          custom_image_url: r.url_imagen ? String(r.url_imagen).trim() : null,
          dorsal_number: matchedPlayer.jersey_number,
          reward_pearls: Number(r.perlitas) || 50,
          status: isPublished ? 'published' : 'draft',
          starts_at: r.inicio ? parseDateToISO(r.inicio) : new Date().toISOString(),
          ends_at: r.fin ? parseDateToISO(r.fin) : new Date(Date.now() + 7 * 86400000).toISOString()
        })
      }

      const { error } = await supabase.from('guess_player_challenges').insert(payloads)
      if (error) throw error

      return {
        successCount: payloads.length,
        message: `${payloads.length} reto(s) de "¿Quién es?" programado(s) exitosamente.`
      }
    }
  }
}

/**
 * Exporta y descarga la plantilla en formato Excel (.xlsx) o CSV (.csv)
 */
export function downloadTemplate(type: BulkImportType, format: 'xlsx' | 'csv') {
  const config = BULK_CONFIGS[type]
  if (!config) return

  // Create worksheet with sample data
  const ws = XLSX.utils.json_to_sheet(config.sampleData, {
    header: config.columns.map(c => c.key)
  })

  // Set column widths nicely
  ws['!cols'] = config.columns.map(c => ({
    wch: Math.max(c.label.length, c.key.length, 18)
  }))

  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, config.entityName)

  if (format === 'xlsx') {
    XLSX.writeFile(wb, `${config.templateFileName}.xlsx`)
  } else {
    XLSX.writeFile(wb, `${config.templateFileName}.csv`, { bookType: 'csv' })
  }
}

/**
 * Parsea un archivo File (Excel o CSV) y devuelve el array de objetos json
 */
export async function parseSpreadsheetFile(file: File): Promise<Record<string, any>[]> {
  const arrayBuffer = await file.arrayBuffer()
  const wb = XLSX.read(arrayBuffer, {
    type: 'array',
    cellDates: false,
    raw: false
  })

  const firstSheetName = wb.SheetNames[0]
  if (!firstSheetName) return []

  const ws = wb.Sheets[firstSheetName]
  const rawRows: Record<string, any>[] = XLSX.utils.sheet_to_json(ws, {
    raw: false,
    defval: ''
  })

  // Normalizar llaves eliminando espacios, minúsculas y caracteres invisibles
  return rawRows.map(row => {
    const normalized: Record<string, any> = {}
    for (const [key, value] of Object.entries(row)) {
      const cleanKey = key.trim().toLowerCase().replace(/\s+/g, '_')
      normalized[cleanKey] = value
    }
    return normalized
  })
}
