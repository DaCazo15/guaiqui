import { describe, it, expect } from 'vitest'
import { formatPerlitas } from '../index'

describe('formatPerlitas', () => {
  it('formatea números con separador de miles', () => {
    const result = formatPerlitas(1000)
    // es-VE usa punto como separador de miles
    expect(result).toContain('1')
    expect(result).toContain('000')
  })

  it('retorna "0" para cero', () => {
    expect(formatPerlitas(0)).toBe('0')
  })

  it('maneja números negativos', () => {
    const result = formatPerlitas(-500)
    expect(result).toContain('500')
  })

  it('abrevia con k a partir de 100mil puntos', () => {
    expect(formatPerlitas(100_000)).toBe('100k')
    expect(formatPerlitas(150_000)).toBe('150k')
    expect(formatPerlitas(999_000)).toBe('999k')
  })

  it('abrevia con m para millones', () => {
    expect(formatPerlitas(1_000_000)).toBe('1m')
    expect(formatPerlitas(10_000_000)).toBe('10m')
    expect(formatPerlitas(100_000_000)).toBe('100m')
  })

  it('abrevia con b para billones/miles de millones', () => {
    expect(formatPerlitas(1_000_000_000)).toBe('1b')
    expect(formatPerlitas(10_000_000_000)).toBe('10b')
  })

  it('no abrevia números menores a 100mil', () => {
    expect(formatPerlitas(475)).toBe('475')
    expect(formatPerlitas(99_999)).toContain('99')
  })
})
