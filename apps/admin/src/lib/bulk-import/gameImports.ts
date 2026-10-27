import type { BulkImportConfig } from './types'
import { parseBoolean, parseDateToISO, normalizeGameStatus } from './helpers'

export const gamesBulkConfig: BulkImportConfig = {
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
}
