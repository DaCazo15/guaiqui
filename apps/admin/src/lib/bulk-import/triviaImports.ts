import type { BulkImportConfig } from './types'
import { parseDateToISO, parseBoolean, normalizeChallengeType } from './helpers'

export const triviasBulkConfig: BulkImportConfig = {
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
}

export const whoIsBulkConfig: BulkImportConfig = {
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

export const flashTriviaBulkConfig: BulkImportConfig = {
  type: 'flash_trivia',
  title: 'Carga Masiva de Trivia Flash 60s',
  entityName: 'TriviaFlash',
  templateFileName: 'plantilla_trivia_flash_guaiqueries',
  columns: [
    { key: 'desafio_titulo', label: 'Título del Desafío Flash', required: true, example: 'Desafío Flash: Historia Insular' },
    { key: 'tiempo_segundos', label: 'Tiempo Límite (Segundos)', example: 60 },
    { key: 'perlitas_por_acierto', label: 'Perlitas por Pregunta Acertada', example: 10 },
    { key: 'pregunta', label: 'Pregunta', required: true, example: '¿Cuántos títulos tiene Guaiqueríes?' },
    { key: 'opcion_a', label: 'Opción A', required: true, example: '7' },
    { key: 'opcion_b', label: 'Opción B', required: true, example: '9' },
    { key: 'opcion_c', label: 'Opción C (Opcional)', example: '8' },
    { key: 'opcion_d', label: 'Opción D (Opcional)', example: '10' },
    { key: 'opcion_correcta', label: 'Opción Correcta (A, B, C o D)', required: true, example: 'B' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-30 23:59' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      desafio_titulo: 'Desafío Flash: Historia Insular',
      tiempo_segundos: 60,
      perlitas_por_acierto: 10,
      pregunta: '¿En qué gimnasio juega Guaiqueríes de local?',
      opcion_a: 'Gimnasio José Joaquín Papá Carrillo',
      opcion_b: 'Gimnasio Ciudad de La Asunción',
      opcion_c: 'Forum de Valencia',
      opcion_d: 'Domo José María Vargas',
      opcion_correcta: 'B',
      fecha_cierre: '2026-05-30 23:59',
      estado: 'publicado'
    },
    {
      desafio_titulo: 'Desafío Flash: Historia Insular',
      tiempo_segundos: 60,
      perlitas_por_acierto: 10,
      pregunta: '¿Cuál es el apodo oficial del equipo?',
      opcion_a: 'El Expreso Azul',
      opcion_b: 'Los Acorazados',
      opcion_c: 'La Tribu',
      opcion_d: 'Los Toros',
      opcion_correcta: 'C',
      fecha_cierre: '2026-05-30 23:59',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.desafio_titulo?.toString().trim()) errors.push(`Fila ${index + 1}: El título del desafío flash es obligatorio`)
    if (!row.pregunta?.toString().trim()) errors.push(`Fila ${index + 1}: La pregunta es obligatoria`)
    if (!row.opcion_a?.toString().trim()) errors.push(`Fila ${index + 1}: La opción A es obligatoria`)
    if (!row.opcion_b?.toString().trim()) errors.push(`Fila ${index + 1}: La opción B es obligatoria`)
    const opt = String(row.opcion_correcta || '').trim().toUpperCase()
    if (!['A', 'B', 'C', 'D'].includes(opt)) {
      errors.push(`Fila ${index + 1}: La opción correcta debe ser A, B, C o D`)
    }
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const groups = new Map<string, { meta: any; questions: any[] }>()

    for (const r of rows) {
      const title = String(r.desafio_titulo).trim()
      if (!groups.has(title)) {
        groups.set(title, {
          meta: {
            title,
            time_limit_seconds: Number(r.tiempo_segundos) || 60,
            pearls_per_correct: Number(r.perlitas_por_acierto) || 10,
            closes_at: r.fecha_cierre ? parseDateToISO(r.fecha_cierre) : new Date(Date.now() + 7 * 86400000).toISOString(),
            status: String(r.estado || '').toLowerCase().includes('borr') ? 'draft' : 'published'
          },
          questions: []
        })
      }
      groups.get(title)!.questions.push({
        question: String(r.pregunta).trim(),
        option_a: String(r.opcion_a).trim(),
        option_b: String(r.opcion_b).trim(),
        option_c: r.opcion_c ? String(r.opcion_c).trim() : null,
        option_d: r.opcion_d ? String(r.opcion_d).trim() : null,
        correct_option: String(r.opcion_correcta).trim().toUpperCase(),
        order_index: groups.get(title)!.questions.length + 1
      })
    }

    let challengeCount = 0
    let questionCount = 0

    for (const [, group] of groups) {
      const { error } = await supabase.rpc('admin_upsert_flash_challenge', {
        p_id: null,
        p_title: group.meta.title,
        p_description: 'Desafío contrarreloj de 60 segundos',
        p_time_limit_seconds: group.meta.time_limit_seconds,
        p_pearls_per_correct: group.meta.pearls_per_correct,
        p_status: group.meta.status,
        p_starts_at: new Date().toISOString(),
        p_closes_at: group.meta.closes_at,
        p_questions: group.questions
      })
      if (error) throw error
      challengeCount++
      questionCount += group.questions.length
    }

    return {
      successCount: questionCount,
      message: `${challengeCount} desafío(s) flash creado(s) con ${questionCount} preguntas en total.`
    }
  }
}

export const progressiveCluesBulkConfig: BulkImportConfig = {
  type: 'progressive_clues',
  title: 'Carga Masiva de Pistas Progresivas',
  entityName: 'PistasProgresivas',
  templateFileName: 'plantilla_pistas_progresivas_guaiqueries',
  columns: [
    { key: 'titulo', label: 'Título del Desafío', required: true, example: 'Jugador Legendario #1' },
    { key: 'dorsal_o_nombre_jugador', label: 'Dorsal o Nombre del Jugador', required: true, example: '8' },
    { key: 'pista_1', label: 'Pista 1 (Difícil - 60 Perlitas)', required: true, example: 'Lideró la liga en asistencias en la temporada 2018.' },
    { key: 'pista_2', label: 'Pista 2 (Media - 35 Perlitas)', required: true, example: 'Es conocido internacionalmente como "El Mago".' },
    { key: 'pista_3', label: 'Pista 3 (Fácil - 15 Perlitas)', required: true, example: 'Viste la camiseta número 8 de Guaiqueríes.' },
    { key: 'perlitas_pista_1', label: 'Perlitas Pista 1', example: 60 },
    { key: 'perlitas_pista_2', label: 'Perlitas Pista 2', example: 35 },
    { key: 'perlitas_pista_3', label: 'Perlitas Pista 3', example: 15 },
    { key: 'foto_revelacion', label: 'URL Foto Revelación (Opcional)', example: 'https://cdn.guaiqueries.com/players/cubillan.jpg' },
    { key: 'fecha_cierre', label: 'Fecha Cierre (YYYY-MM-DD HH:MM)', example: '2026-05-25 23:59' },
    { key: 'estado', label: 'Estado (publicado/borrador)', example: 'publicado' }
  ],
  sampleData: [
    {
      titulo: 'Jugador Legendario #1',
      dorsal_o_nombre_jugador: '8',
      pista_1: 'Lideró la liga en asistencias en la temporada 2018.',
      pista_2: 'Es conocido internacionalmente como "El Mago".',
      pista_3: 'Viste la camiseta número 8 de Guaiqueríes.',
      perlitas_pista_1: 60,
      perlitas_pista_2: 35,
      perlitas_pista_3: 15,
      foto_revelacion: 'https://cdn.guaiqueries.com/players/cubillan.jpg',
      fecha_cierre: '2026-05-25 23:59',
      estado: 'publicado'
    }
  ],
  validateRow: (row, index) => {
    const errors: string[] = []
    if (!row.titulo?.toString().trim()) errors.push(`Fila ${index + 1}: El título del desafío es obligatorio`)
    if (!row.dorsal_o_nombre_jugador?.toString().trim()) errors.push(`Fila ${index + 1}: El dorsal o nombre del jugador es obligatorio`)
    if (!row.pista_1?.toString().trim()) errors.push(`Fila ${index + 1}: La pista 1 es obligatoria`)
    if (!row.pista_2?.toString().trim()) errors.push(`Fila ${index + 1}: La pista 2 es obligatoria`)
    if (!row.pista_3?.toString().trim()) errors.push(`Fila ${index + 1}: La pista 3 es obligatoria`)
    return { valid: errors.length === 0, errors }
  },
  processRows: async (rows, supabase) => {
    const { data: players } = await supabase.from('players').select('id, name, jersey_number, photo_url')
    let count = 0

    for (const r of rows) {
      const query = String(r.dorsal_o_nombre_jugador).trim().toLowerCase()
      const num = Number(query)
      const matched = players?.find((pl: any) => (!isNaN(num) && pl.jersey_number === num) || pl.name.toLowerCase().includes(query))

      const playerName = matched ? matched.name : String(r.dorsal_o_nombre_jugador).trim()
      const playerId = matched ? matched.id : null
      const revealPhoto = r.foto_revelacion ? String(r.foto_revelacion).trim() : (matched?.photo_url || null)

      const startsAt = r.fecha_inicio ? parseDateToISO(r.fecha_inicio) : new Date().toISOString()
      const closesAt = r.fecha_cierre ? parseDateToISO(r.fecha_cierre) : new Date(Date.now() + 3 * 86400000).toISOString()
      const isDraft = String(r.estado || '').toLowerCase().includes('borr')

      const { error } = await supabase.rpc('admin_upsert_progressive_clue', {
        p_id: null,
        p_player_id: playerId,
        p_target_player_name: playerName,
        p_title: String(r.titulo).trim(),
        p_description: 'Desafío de pistas progresivas',
        p_clue_1: String(r.pista_1).trim(),
        p_clue_2: String(r.pista_2).trim(),
        p_clue_3: String(r.pista_3).trim(),
        p_pearls_clue_1: Number(r.perlitas_pista_1) || 60,
        p_pearls_clue_2: Number(r.perlitas_pista_2) || 35,
        p_pearls_clue_3: Number(r.perlitas_pista_3) || 15,
        p_reveal_photo_url: revealPhoto,
        p_status: isDraft ? 'draft' : 'published',
        p_starts_at: startsAt,
        p_closes_at: closesAt
      })
      if (error) throw error
      count++
    }

    return { successCount: count, message: `${count} desafío(s) de pistas progresivas importado(s) exitosamente.` }
  }
}
