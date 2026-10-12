import { describe, it, expect } from 'vitest'
import {
  APP_TZ,
  caracasInputToISO,
  isoToCaracasInput,
  nowCaracasInput,
  formatCaracas
} from '../datetime'

describe('datetime helpers (America/Caracas)', () => {
  it('defines APP_TZ as America/Caracas', () => {
    expect(APP_TZ).toBe('America/Caracas')
  })

  it('converts datetime-local input to ISO string correctly (UTC-4)', () => {
    // 2026-10-12T10:00 en Caracas es 2026-10-12T14:00:00.000Z
    const input = '2026-10-12T10:00'
    const iso = caracasInputToISO(input)
    expect(iso).toBe('2026-10-12T14:00:00.000Z')
  })

  it('converts ISO string to Caracas datetime-local input correctly', () => {
    const iso = '2026-10-12T14:00:00.000Z'
    const input = isoToCaracasInput(iso)
    expect(input).toBe('2026-10-12T10:00')
  })

  it('performs round-trip conversion without drift: isoToCaracasInput(caracasInputToISO(x)) === x', () => {
    const originalInput = '2026-12-25T19:30'
    const iso = caracasInputToISO(originalInput)
    const resultInput = isoToCaracasInput(iso)
    expect(resultInput).toBe(originalInput)
  })

  it('handles edge dates (midnight, year transitions)', () => {
    const newYearInput = '2027-01-01T00:00'
    const iso = caracasInputToISO(newYearInput)
    expect(iso).toBe('2027-01-01T04:00:00.000Z')
    expect(isoToCaracasInput(iso)).toBe(newYearInput)
  })

  it('generates nowCaracasInput with plusMs offset', () => {
    const inputNow = nowCaracasInput()
    expect(inputNow).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/)

    const oneDayMs = 24 * 60 * 60 * 1000
    const inputTomorrow = nowCaracasInput(oneDayMs)
    expect(inputTomorrow).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/)
  })

  it('formats dates in America/Caracas locale es-VE', () => {
    const iso = '2026-10-12T14:00:00.000Z'
    const formatted = formatCaracas(iso)
    expect(formatted).toBeTruthy()
    // En hora de Caracas son las 10:00 am
    expect(formatted).toContain('10:00')
  })

  describe('behavior across different system timezones', () => {
    const testTimezones = ['UTC', 'America/New_York', 'Asia/Tokyo']

    testTimezones.forEach((tz) => {
      it(`behaves consistently when process.env.TZ = '${tz}'`, () => {
        const originalTz = process.env.TZ
        try {
          process.env.TZ = tz
          const input = '2026-06-15T15:45'
          const iso = caracasInputToISO(input)
          expect(iso).toBe('2026-06-15T19:45:00.000Z')
          expect(isoToCaracasInput(iso)).toBe(input)
        } finally {
          process.env.TZ = originalTz
        }
      })
    })
  })
})
