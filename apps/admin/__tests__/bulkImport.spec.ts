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
})
