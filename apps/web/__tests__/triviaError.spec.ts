import { describe, it, expect } from 'vitest'
import { translateTriviaError } from '../stores/trivias'

describe('translateTriviaError', () => {
  it('differentiates ATTEMPT_EXPIRED vs TRIVIA_EXPIRED correctly', () => {
    const attemptExpiredMsg = translateTriviaError('Error: ATTEMPT_EXPIRED')
    expect(attemptExpiredMsg).toBe('Se agotó tu tiempo para responder.')

    const triviaExpiredMsg = translateTriviaError('Error: TRIVIA_EXPIRED')
    expect(triviaExpiredMsg).toBe('Esta trivia ya cerró.')
  })

  it('translates TRIVIA_ALREADY_PLAYED', () => {
    const msg = translateTriviaError('Error: TRIVIA_ALREADY_PLAYED')
    expect(msg).toBe('Ya has participado en esta trivia previamente.')
  })

  it('translates TRIVIA_NOT_STARTED', () => {
    const msg = translateTriviaError('Error: TRIVIA_NOT_STARTED')
    expect(msg).toBe('Esta trivia aún no ha comenzado. Estará disponible próximamente.')
  })

  it('translates CAPTCHA_REQUIRED to friendly message', () => {
    const msg = translateTriviaError('P0001: CAPTCHA_REQUIRED')
    expect(msg).toBe('Por favor, completa la verificación de seguridad antes de comenzar.')
  })

  it('translates assert_active_verified_fan to friendly message', () => {
    const msg = translateTriviaError('function public.assert_active_verified_fan(uuid) does not exist')
    expect(msg).toBe('Debes tener tu correo electrónico verificado para participar.')
  })

  it('handles unknown messages gracefully by returning original message', () => {
    const custom = 'Error de red inesperado'
    expect(translateTriviaError(custom)).toBe(custom)
  })
})
