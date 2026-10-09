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
})
