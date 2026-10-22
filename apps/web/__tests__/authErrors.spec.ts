import { describe, it, expect } from 'vitest'
import { translateAuthError } from '../utils/authErrors'

describe('translateAuthError', () => {
  it('traduce credenciales inválidas', () => {
    expect(translateAuthError('Invalid login credentials')).toBe('Correo o contraseña incorrectos.')
  })

  it('traduce usuario ya registrado', () => {
    expect(translateAuthError('User already registered')).toBe(
      'Ya existe una cuenta registrada con este correo. Por favor inicia sesión o utiliza otro correo.'
    )
  })

  it('traduce errores de límite de tasa', () => {
    expect(translateAuthError('rate limit exceeded')).toBe(
      'Límite de envíos excedido. Espera unos minutos e inténtalo de nuevo.'
    )
  })

  it('traduce correo no confirmado', () => {
    expect(translateAuthError('Email not confirmed')).toBe(
      'Tu correo aún no ha sido verificado. Revisa tu bandeja de entrada o spam.'
    )
  })

  it('devuelve mensaje por defecto ante mensaje vacío o desconocido', () => {
    expect(translateAuthError('')).toBe('Ocurrió un error inesperado.')
    expect(translateAuthError('Mensaje genérico')).toBe('Mensaje genérico')
  })
})
