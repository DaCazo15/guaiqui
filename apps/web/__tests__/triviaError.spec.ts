import { describe, it, expect } from 'vitest'
import { translateTriviaError } from '../stores/trivias'

describe('translateTriviaError', () => {
  it('differentiates ATTEMPT_EXPIRED vs TRIVIA_EXPIRED correctly', () => {
    const attemptExpiredMsg = translateTriviaError('Error: ATTEMPT_EXPIRED')
    expect(attemptExpiredMsg).toBe('Tu tiempo para este intento terminó.')

    const triviaExpiredMsg = translateTriviaError('Error: TRIVIA_EXPIRED')
    expect(triviaExpiredMsg).toBe('El plazo para participar en esta trivia ha finalizado.')
  })

  it('translates TRIVIA_ALREADY_PLAYED', () => {
    const msg = translateTriviaError('Error: TRIVIA_ALREADY_PLAYED')
    expect(msg).toBe('Ya has participado en esta trivia previamente.')
  })

  it('translates TRIVIA_NOT_STARTED', () => {
    const msg = translateTriviaError('Error: TRIVIA_NOT_STARTED')
    expect(msg).toBe('Esta trivia aún no ha comenzado. Estará disponible próximamente.')
  })

  it('handles unknown messages gracefully by returning original message', () => {
    const custom = 'Error de red inesperado'
    expect(translateTriviaError(custom)).toBe(custom)
  })
})
