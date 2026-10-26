import { describe, it, expect } from 'vitest'
import {
  BULK_CONFIGS,
  parseBoolean,
  normalizeGroupCategory,
  normalizeGameStatus,
  normalizeProductCategory,
  parseDateToISO
} from '../src/lib/bulkImportConfig'

describe('Bulk Import Configuration and Validation', () => {
  describe('Helper Functions', () => {
    it('parseBoolean parses spanish affirmative strings correctly', () => {
      expect(parseBoolean('SI')).toBe(true)
      expect(parseBoolean('si')).toBe(true)
      expect(parseBoolean('sí')).toBe(true)
      expect(parseBoolean('true')).toBe(true)
      expect(parseBoolean('1')).toBe(true)
      expect(parseBoolean('NO')).toBe(false)
      expect(parseBoolean('0')).toBe(false)
      expect(parseBoolean(null, true)).toBe(true)
    })

    it('normalizeGroupCategory maps categories correctly', () => {
      expect(normalizeGroupCategory('Cuerpo Técnico')).toBe('tecnico')
      expect(normalizeGroupCategory('Directiva')).toBe('directiva')
      expect(normalizeGroupCategory('Logística y Staff')).toBe('logistica')
      expect(normalizeGroupCategory('desconocido')).toBe('tecnico')
    })

    it('normalizeGameStatus maps game statuses correctly', () => {
      expect(normalizeGameStatus('scheduled')).toBe('scheduled')
      expect(normalizeGameStatus('En Vivo')).toBe('live')
      expect(normalizeGameStatus('Finalizado')).toBe('finished')
      expect(normalizeGameStatus('Cancelado')).toBe('cancelled')
    })

    it('normalizeProductCategory maps product categories correctly', () => {
      expect(normalizeProductCategory('physical')).toBe('physical')
      expect(normalizeProductCategory('Experiencia')).toBe('experience')
      expect(normalizeProductCategory('Sorteo')).toBe('raffle')
    })

    it('parseDateToISO converts Caracas time format to ISO', () => {
      const iso = parseDateToISO('2026-05-15 19:30')
      expect(iso).toContain('2026-05-15')
      expect(iso.endsWith('Z')).toBe(true)
    })
  })

  describe('Trivias Validation', () => {
    const config = BULK_CONFIGS.trivias

    it('validates a correct trivia row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('flags missing required fields in trivia row', () => {
      const invalidRow = {
        titulo_trivia: '',
        pregunta: '',
        opcion_1: '',
        opcion_2: '',
        opcion_correcta: 9
      }
      const result = config.validateRow(invalidRow, 0)
      expect(result.valid).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })
  })

  describe('Players Validation', () => {
    const config = BULK_CONFIGS.players

    it('validates a correct player row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('flags missing name or jersey number', () => {
      const invalidRow = {
        nombre: '',
        numero_camiseta: 'no-es-numero',
        posicion: ''
      }
      const result = config.validateRow(invalidRow, 1)
      expect(result.valid).toBe(false)
      expect(result.errors.length).toBeGreaterThanOrEqual(3)
    })
  })

  describe('Staff Validation', () => {
    const config = BULK_CONFIGS.staff

    it('validates a correct staff member row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('flags missing name or role', () => {
      const invalidRow = {
        nombre: '',
        cargo: ''
      }
      const result = config.validateRow(invalidRow, 0)
      expect(result.valid).toBe(false)
      expect(result.errors).toHaveLength(2)
    })
  })

  describe('Games Validation', () => {
    const config = BULK_CONFIGS.games

    it('validates a correct game schedule row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('includes url_logo_rival column and sample logo url', () => {
      const logoCol = config.columns.find(c => c.key === 'url_logo_rival')
      expect(logoCol).toBeDefined()
      expect(logoCol?.required).toBeFalsy()
      expect(config.sampleData[0].url_logo_rival).toBeTruthy()
    })

    it('maps url_logo_rival correctly in processRows', async () => {
      let insertedPayloads: any[] = []
      const mockSupabase = {
        from: (table: string) => ({
          insert: async (payloads: any[]) => {
            insertedPayloads = payloads
            return { error: null }
          }
        })
      }

      await config.processRows([
        {
          rival: 'Trotamundos de Carabobo',
          url_logo_rival: 'https://images.sofascore.com/team-348731.png',
          fecha_partido: '2026-06-12 19:30',
          sede: 'La Asunción',
          es_local: 'SI',
          estado: 'scheduled'
        }
      ], mockSupabase)

      expect(insertedPayloads).toHaveLength(1)
      expect(insertedPayloads[0].opponent).toBe('Trotamundos de Carabobo')
      expect(insertedPayloads[0].opponent_logo_url).toBe('https://images.sofascore.com/team-348731.png')
    })

    it('flags missing rival or game date', () => {
      const invalidRow = {
        rival: '',
        fecha_partido: ''
      }
      const result = config.validateRow(invalidRow, 0)
      expect(result.valid).toBe(false)
      expect(result.errors).toHaveLength(2)
    })
  })

  describe('Products Validation', () => {
    const config = BULK_CONFIGS.products

    it('validates a correct product row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('flags negative stock or invalid pearls cost', () => {
      const invalidRow = {
        nombre: '',
        costo_perlitas: -50,
        stock: -1
      }
      const result = config.validateRow(invalidRow, 0)
      expect(result.valid).toBe(false)
      expect(result.errors.length).toBeGreaterThanOrEqual(2)
    })
  })

  describe('Who Is Challenges Validation', () => {
    const config = BULK_CONFIGS.who_is

    it('validates a correct who_is challenge row', () => {
      const validRow = config.sampleData[0]
      const result = config.validateRow(validRow, 0)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('flags missing dorsal or player name', () => {
      const invalidRow = {
        dorsal_o_nombre: ''
      }
      const result = config.validateRow(invalidRow, 0)
      expect(result.valid).toBe(false)
      expect(result.errors).toHaveLength(1)
    })

    it('processes rows correctly by resolving player from roster', async () => {
      let insertedPayloads: any[] = []
      const mockSupabase = {
        from: (table: string) => {
          if (table === 'players') {
            return {
              select: () => ({
                data: [
                  { id: 'p-1', name: 'Alfonso Smith', jersey_number: 10 },
                  { id: 'p-2', name: 'José Martínez', jersey_number: 7 }
                ],
                error: null
              })
            }
          }
          if (table === 'guess_player_challenges') {
            return {
              insert: async (payloads: any[]) => {
                insertedPayloads = payloads
                return { error: null }
              }
            }
          }
          return {}
        }
      }

      const result = await config.processRows([
        {
          dorsal_o_nombre: '10',
          tipo: 'silueta',
          titulo: '¿Quién es este Guaiquerí?',
          pista: 'Base armador',
          perlitas: 50,
          estado: 'publicado'
        }
      ], mockSupabase)

      expect(result.successCount).toBe(1)
      expect(insertedPayloads).toHaveLength(1)
      expect(insertedPayloads[0].player_id).toBe('p-1')
      expect(insertedPayloads[0].challenge_type).toBe('silhouette')
      expect(insertedPayloads[0].dorsal_number).toBe(10)
    })
  })

  describe('polls config', () => {
    it('validates required fields: titulo and opciones', () => {
      const config = BULK_CONFIGS.polls
      expect(config.validateRow({}, 0).valid).toBe(false)
      expect(config.validateRow({ titulo: '¿Quién será MVP?' }, 0).valid).toBe(false)
      expect(config.validateRow({ titulo: '¿Quién será MVP?', opciones: 'Solo una' }, 0).valid).toBe(false)
      expect(config.validateRow({ titulo: '¿Quién será MVP?', opciones: 'Pedro; Heissler' }, 0).valid).toBe(true)
    })

    it('processes rows correctly calling admin_upsert_trivia_poll RPC', async () => {
      const config = BULK_CONFIGS.polls
      let rpcCalls: any[] = []

      const mockSupabase = {
        rpc: async (fn: string, args: any) => {
          rpcCalls.push({ fn, args })
          return { data: { id: 'poll-123' }, error: null }
        }
      }

      const result = await config.processRows([
        {
          titulo: '¿Quién meterá más triples?',
          descripcion: 'Elige tu favorito',
          opciones: 'Chourio; Guillent; Carrera',
          perlitas: 60,
          estado: 'publicado'
        }
      ], mockSupabase)

      expect(result.successCount).toBe(1)
      expect(rpcCalls).toHaveLength(1)
      expect(rpcCalls[0].fn).toBe('admin_upsert_trivia_poll')
      expect(rpcCalls[0].args.p_poll.title).toBe('¿Quién meterá más triples?')
      expect(rpcCalls[0].args.p_poll.reward_pearls).toBe(60)
      expect(rpcCalls[0].args.p_options).toHaveLength(3)
      expect(rpcCalls[0].args.p_options[0].label).toBe('Chourio')
    })
  })
})

