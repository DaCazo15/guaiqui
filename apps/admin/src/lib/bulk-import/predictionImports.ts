import { caracasInputToISO } from '@guaiqui/shared'
import type { BulkImportConfig } from './types'
import { parseDateToISO } from './helpers'

export const pollsBulkConfig: BulkImportConfig = {
  type: 'polls',
  title: 'Carga Masiva de Encuestas & Predicciones',
  entityName: 'Encuestas',
  templateFileName: 'plantilla_encuestas_guaiqueries',
  columns: [
    { key: 'titulo', label: 'Pregunta / Título', required: true, example: '¿Quién será el MVP del partido?' },
    { key: 'descripcion', label: 'Descripción (Opcional)', example: 'Vota antes de que termine el primer cuarto.' },
    { key: 'opciones', label: 'Opciones (Separadas por punto y coma ;)', required: true, example: 'Pedro Chourio; Heissler Guillent; Michael Carrera; Otro' },
    { key: 'perlitas', label: 'Perlitas de Premio', example: 50 },
    { key: 'fecha_inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:MM)', example: '2026-05-10 18:00' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-10 21:00' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      titulo: '¿Quién será el MVP de la noche?',
      descripcion: 'Elige tu jugador preferido antes de que termine la primera mitad.',
      opciones: 'Pedro Chourio; Heissler Guillent; José Ascanio; Otro',
      perlitas: 50,
      fecha_inicio: '2026-05-10 18:00',
      fecha_cierre: '2026-05-10 20:30',
      estado: 'publicado'
    },
    {
      titulo: '¿Cuántos triples anotará Guaiqueríes hoy?',
      descripcion: 'Predicción perimetral del equipo insular.',
      opciones: 'Menos de 8 triples; Entre 8 y 12 triples; Más de 12 triples',
      perlitas: 40,
      fecha_inicio: '2026-05-12 18:00',
      fecha_cierre: '2026-05-12 19:30',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.titulo?.toString().trim()) {
      errors.push(`Fila ${index + 1}: El título de la encuesta es obligatorio`)
    }
    const rawOpts = row.opciones?.toString().trim()
    if (!rawOpts) {
      errors.push(`Fila ${index + 1}: Debes especificar al menos dos opciones separadas por punto y coma (;)`)
    } else {
      const split = rawOpts.split(/[;,]/).map((s: string) => s.trim()).filter(Boolean)
      if (split.length < 2) {
        errors.push(`Fila ${index + 1}: La encuesta debe tener al menos 2 opciones (ej: Opción 1; Opción 2)`)
      }
    }
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    let created = 0
    for (const r of rows) {
      const title = String(r.titulo).trim()
      const desc = r.descripcion ? String(r.descripcion).trim() : null
      const reward = r.perlitas ? Math.max(0, Number(r.perlitas)) : 50
      const status = String(r.estado || 'publicado').trim().toLowerCase() === 'borrador' ? 'draft' : 'published'

      const startsAt = r.fecha_inicio ? caracasInputToISO(String(r.fecha_inicio).trim()) : new Date().toISOString()
      const closesAt = r.fecha_cierre ? caracasInputToISO(String(r.fecha_cierre).trim()) : new Date(Date.now() + 2 * 86400000).toISOString()

      const rawOpts = String(r.opciones || '')
      const optionLabels = rawOpts.split(/[;,]/).map((s: string) => s.trim()).filter(Boolean)
      const optionsPayload = optionLabels.map((lbl: string, idx: number) => ({
        label: lbl,
        order_index: idx + 1
      }))

      const pollPayload = {
        title,
        description: desc,
        reward_pearls: reward,
        status,
        starts_at: startsAt,
        closes_at: closesAt
      }

      const { error } = await supabase.rpc('admin_upsert_trivia_poll', {
        p_poll: pollPayload,
        p_options: optionsPayload
      })
      if (error) throw error
      created++
    }

    return {
      successCount: created,
      message: `${created} encuesta(s) de predicción creada(s) exitosamente.`
    }
  }
}

export const overUnderBulkConfig: BulkImportConfig = {
  type: 'over_under',
  title: 'Carga Masiva de Mayor o Menor (Over/Under)',
  entityName: 'OverUnder',
  templateFileName: 'plantilla_over_under_guaiqueries',
  columns: [
    { key: 'titulo', label: 'Título del Pronóstico', required: true, example: 'Puntos totales Guaiqueríes' },
    { key: 'descripcion', label: 'Descripción (Opcional)', example: '¿Superará la tribu los 84.5 puntos ante Trotamundos?' },
    { key: 'tipo_estadistica', label: 'Tipo Estadística (puntos/triples/rebotes/asistencias)', required: true, example: 'puntos' },
    { key: 'linea_valor', label: 'Valor de la Línea (Número ej: 84.5)', required: true, example: 84.5 },
    { key: 'dorsal_o_nombre_jugador', label: 'Dorsal o Nombre del Jugador (Opcional)', example: '8' },
    { key: 'perlitas', label: 'Perlitas de Premio', example: 40 },
    { key: 'fecha_inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:MM)', example: '2026-05-15 12:00' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-15 19:30' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      titulo: 'Puntos de Guaiqueríes vs Trotamundos',
      descripcion: 'Línea de anotación colectiva',
      tipo_estadistica: 'puntos',
      linea_valor: 84.5,
      dorsal_o_nombre_jugador: '',
      perlitas: 40,
      fecha_inicio: '2026-05-15 12:00',
      fecha_cierre: '2026-05-15 19:30',
      estado: 'publicado'
    },
    {
      titulo: 'Triples anotados por David Cubillán',
      descripcion: 'Efectividad perimetral del base estelar',
      tipo_estadistica: 'triples',
      linea_valor: 2.5,
      dorsal_o_nombre_jugador: '8',
      perlitas: 50,
      fecha_inicio: '2026-05-15 12:00',
      fecha_cierre: '2026-05-15 19:30',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.titulo?.toString().trim()) {
      errors.push(`Fila ${index + 1}: El título del pronóstico es obligatorio`)
    }
    const rawVal = row.linea_valor
    if (rawVal === undefined || rawVal === null || rawVal === '' || isNaN(Number(rawVal))) {
      errors.push(`Fila ${index + 1}: La línea debe ser un valor numérico válido (ej: 84.5)`)
    }
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const { data: players } = await supabase.from('players').select('id, name, jersey_number')
    let count = 0

    for (const r of rows) {
      let matchedPlayerId: string | null = null
      if (r.dorsal_o_nombre_jugador && players?.length) {
        const q = String(r.dorsal_o_nombre_jugador).trim().toLowerCase()
        const num = Number(q)
        const p = players.find((pl: any) => (!isNaN(num) && pl.jersey_number === num) || pl.name.toLowerCase().includes(q))
        if (p) matchedPlayerId = p.id
      }

      const startsAt = r.fecha_inicio ? parseDateToISO(r.fecha_inicio) : new Date().toISOString()
      const closesAt = r.fecha_cierre ? parseDateToISO(r.fecha_cierre) : new Date(Date.now() + 2 * 86400000).toISOString()
      const isDraft = String(r.estado || '').toLowerCase().includes('borr')

      const { error } = await supabase.rpc('admin_upsert_over_under', {
        p_id: null,
        p_game_id: null,
        p_player_id: matchedPlayerId,
        p_title: String(r.titulo).trim(),
        p_description: r.descripcion ? String(r.descripcion).trim() : null,
        p_stat_type: r.tipo_estadistica ? String(r.tipo_estadistica).trim().toLowerCase() : 'points',
        p_line_value: Number(r.linea_valor),
        p_reward_pearls: Number(r.perlitas) || 40,
        p_status: isDraft ? 'draft' : 'published',
        p_starts_at: startsAt,
        p_closes_at: closesAt
      })
      if (error) throw error
      count++
    }

    return { successCount: count, message: `${count} pronóstico(s) Over/Under importado(s) exitosamente.` }
  }
}

export const mysteryPlaysBulkConfig: BulkImportConfig = {
  type: 'mystery_plays',
  title: 'Carga Masiva de «¿Qué pasó después?» (Jugada Misteriosa)',
  entityName: 'JugadasMisteriosas',
  templateFileName: 'plantilla_jugadas_misteriosas_guaiqueries',
  columns: [
    { key: 'titulo', label: 'Título del Desafío', required: true, example: 'Penetración clave de Chourio vs Centauros' },
    { key: 'pregunta', label: 'Pregunta', required: true, example: '¿Cómo culminó esta jugada en el 4to cuarto?' },
    { key: 'video_url', label: 'URL Video de la Jugada (Opcional)', example: 'https://cdn.guaiqueries.com/videos/play1.mp4' },
    { key: 'imagen_portada', label: 'URL Imagen de Portada (Opcional)', example: 'https://cdn.guaiqueries.com/covers/play1.jpg' },
    { key: 'opcion_a', label: 'Opción A', required: true, example: 'Triple sobre la chicharra' },
    { key: 'opcion_b', label: 'Opción B', required: true, example: 'Falta y vale (2+1)' },
    { key: 'opcion_c', label: 'Opción C', required: true, example: 'Asistencia de fantasía por la espalda' },
    { key: 'opcion_d', label: 'Opción D', required: true, example: 'Bloqueo salvaje del rival' },
    { key: 'opcion_correcta', label: 'Opción Correcta (A, B, C o D)', required: true, example: 'B' },
    { key: 'video_revelacion', label: 'URL Video Revelación (Opcional)', example: 'https://cdn.guaiqueries.com/videos/play1_reveal.mp4' },
    { key: 'perlitas', label: 'Perlitas de Recompensa', example: 50 },
    { key: 'fecha_inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:MM)', example: '2026-05-10 10:00' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-14 23:59' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      titulo: 'Penetración clave de Chourio vs Centauros',
      pregunta: '¿Cómo culminó esta jugada en el 4to cuarto?',
      video_url: 'https://cdn.guaiqueries.com/videos/play1.mp4',
      imagen_portada: 'https://cdn.guaiqueries.com/covers/play1.jpg',
      opcion_a: 'Triple sobre la chicharra',
      opcion_b: 'Falta y vale (2+1)',
      opcion_c: 'Asistencia de fantasía por la espalda',
      opcion_d: 'Bloqueo salvaje del rival',
      opcion_correcta: 'B',
      video_revelacion: 'https://cdn.guaiqueries.com/videos/play1_reveal.mp4',
      perlitas: 50,
      fecha_inicio: '2026-05-10 10:00',
      fecha_cierre: '2026-05-14 23:59',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.titulo?.toString().trim()) errors.push(`Fila ${index + 1}: El título del desafío es obligatorio`)
    if (!row.pregunta?.toString().trim()) errors.push(`Fila ${index + 1}: La pregunta es obligatoria`)
    if (!row.opcion_a?.toString().trim()) errors.push(`Fila ${index + 1}: La opción A es obligatoria`)
    if (!row.opcion_b?.toString().trim()) errors.push(`Fila ${index + 1}: La opción B es obligatoria`)
    if (!row.opcion_c?.toString().trim()) errors.push(`Fila ${index + 1}: La opción C es obligatoria`)
    if (!row.opcion_d?.toString().trim()) errors.push(`Fila ${index + 1}: La opción D es obligatoria`)
    const opt = String(row.opcion_correcta || '').trim().toUpperCase()
    if (!['A', 'B', 'C', 'D'].includes(opt)) {
      errors.push(`Fila ${index + 1}: La opción correcta debe ser A, B, C o D`)
    }
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    let count = 0
    for (const r of rows) {
      const startsAt = r.fecha_inicio ? parseDateToISO(r.fecha_inicio) : new Date().toISOString()
      const closesAt = r.fecha_cierre ? parseDateToISO(r.fecha_cierre) : new Date(Date.now() + 3 * 86400000).toISOString()
      const isDraft = String(r.estado || '').toLowerCase().includes('borr')

      const { error } = await supabase.rpc('admin_upsert_mystery_play', {
        p_id: null,
        p_game_id: null,
        p_title: String(r.titulo).trim(),
        p_description: r.descripcion ? String(r.descripcion).trim() : null,
        p_video_url: r.video_url ? String(r.video_url).trim() : null,
        p_cover_image_url: r.imagen_portada ? String(r.imagen_portada).trim() : null,
        p_question: String(r.pregunta).trim(),
        p_option_a: String(r.opcion_a).trim(),
        p_option_b: String(r.opcion_b).trim(),
        p_option_c: String(r.opcion_c).trim(),
        p_option_d: String(r.opcion_d).trim(),
        p_correct_option: String(r.opcion_correcta).trim().toUpperCase(),
        p_reveal_video_url: r.video_revelacion ? String(r.video_revelacion).trim() : null,
        p_reward_pearls: Number(r.perlitas) || 50,
        p_status: isDraft ? 'draft' : 'published',
        p_starts_at: startsAt,
        p_closes_at: closesAt
      })
      if (error) throw error
      count++
    }

    return { successCount: count, message: `${count} jugada(s) misteriosa(s) importada(s) con éxito.` }
  }
}

export const scorePredictionsBulkConfig: BulkImportConfig = {
  type: 'score_predictions',
  title: 'Carga Masiva de Adivina el Marcador',
  entityName: 'MarcadorExacto',
  templateFileName: 'plantilla_marcador_exacto_guaiqueries',
  columns: [
    { key: 'titulo', label: 'Título del Pronóstico', required: true, example: 'Adivina el Marcador: Guaiqueríes vs Marinos' },
    { key: 'descripcion', label: 'Descripción (Opcional)', example: 'Acierta los puntos de ambos equipos y gana el bote.' },
    { key: 'rival', label: 'Nombre del Rival (Para vincular al partido)', example: 'Marinos de Oriente' },
    { key: 'perlitas_exacto', label: 'Perlitas por Marcador Exacto', example: 200 },
    { key: 'perlitas_cercano', label: 'Perlitas por Marcador Cercano (<=4 pts)', example: 50 },
    { key: 'fecha_inicio', label: 'Fecha Inicio (YYYY-MM-DD HH:MM)', example: '2026-05-18 10:00' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-18 19:30' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      titulo: 'Adivina el Marcador: Guaiqueríes vs Marinos de Oriente',
      descripcion: 'Clásico oriental en La Choza',
      rival: 'Marinos',
      perlitas_exacto: 200,
      perlitas_cercano: 50,
      fecha_inicio: '2026-05-18 10:00',
      fecha_cierre: '2026-05-18 19:30',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.titulo?.toString().trim()) {
      errors.push(`Fila ${index + 1}: El título del pronóstico es obligatorio`)
    }
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const { data: games } = await supabase.from('games').select('id, opponent_name, game_date').order('game_date', { ascending: true })
    let count = 0

    for (const r of rows) {
      let matchedGameId: string | null = null
      if (r.rival && games?.length) {
        const q = String(r.rival).trim().toLowerCase()
        const g = games.find((gm: any) => gm.opponent_name.toLowerCase().includes(q))
        if (g) matchedGameId = g.id
      }
      if (!matchedGameId && games?.length) {
        matchedGameId = games[0].id
      }

      if (!matchedGameId) {
        throw new Error('No hay partidos en el calendario para vincular la predicción de marcador.')
      }

      const startsAt = r.fecha_inicio ? parseDateToISO(r.fecha_inicio) : new Date().toISOString()
      const closesAt = r.fecha_cierre ? parseDateToISO(r.fecha_cierre) : new Date(Date.now() + 2 * 86400000).toISOString()
      const isDraft = String(r.estado || '').toLowerCase().includes('borr')

      const { error } = await supabase.rpc('admin_upsert_score_prediction', {
        p_id: null,
        p_game_id: matchedGameId,
        p_title: String(r.titulo).trim(),
        p_description: r.descripcion ? String(r.descripcion).trim() : null,
        p_exact_reward_pearls: Number(r.perlitas_exacto) || 200,
        p_closest_reward_pearls: Number(r.perlitas_cercano) || 50,
        p_status: isDraft ? 'draft' : 'published',
        p_starts_at: startsAt,
        p_closes_at: closesAt
      })
      if (error) throw error
      count++
    }

    return { successCount: count, message: `${count} predicción(es) de marcador importada(s) con éxito.` }
  }
}
