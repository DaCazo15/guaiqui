import { describe, it, expect } from 'vitest'
import { extractSubdomain } from '../composables/useTenantSubdomain'

describe('extractSubdomain', () => {
  it('extrae el subdominio de un hostname de producción estándar', () => {
    expect(extractSubdomain('guaiqueries.guaiqui.com')).toBe('guaiqueries')
    expect(extractSubdomain('trotamundos.guaiqui.com')).toBe('trotamundos')
    expect(extractSubdomain('cocodrilos.guaiqui.com.ve')).toBe('cocodrilos')
  })

  it('extrae el subdominio en entorno de desarrollo localhost con y sin puerto', () => {
    expect(extractSubdomain('guaiqueries.localhost:3000')).toBe('guaiqueries')
    expect(extractSubdomain('guaiqueries.localhost')).toBe('guaiqueries')
    expect(extractSubdomain('trotamundos.localhost:8080')).toBe('trotamundos')
  })

  it('retorna null para dominios raíz sin subdominio', () => {
    expect(extractSubdomain('guaiqui.com')).toBeNull()
    expect(extractSubdomain('localhost:3000')).toBeNull()
    expect(extractSubdomain('localhost')).toBeNull()
    expect(extractSubdomain('')).toBeNull()
  })

  it('retorna null para subdominios reservados del sistema', () => {
    expect(extractSubdomain('www.guaiqui.com')).toBeNull()
    expect(extractSubdomain('admin.guaiqui.com')).toBeNull()
    expect(extractSubdomain('app.guaiqui.com')).toBeNull()
    expect(extractSubdomain('api.guaiqui.com')).toBeNull()
    expect(extractSubdomain('staff.guaiqui.com')).toBeNull()
    expect(extractSubdomain('staging.guaiqui.com')).toBeNull()
    expect(extractSubdomain('www.localhost:3000')).toBeNull()
  })

  it('retorna null para direcciones IP', () => {
    expect(extractSubdomain('127.0.0.1:3000')).toBeNull()
    expect(extractSubdomain('192.168.1.10')).toBeNull()
  })
})
