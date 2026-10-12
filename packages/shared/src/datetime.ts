/**
 * Utilidades de fecha y hora para Guaiqueríes de Margarita.
 * Toda la plataforma opera en la zona horaria de Caracas:
 * America/Caracas (UTC-04:00 fijo, sin horario de verano).
 */

export const APP_TZ = 'America/Caracas'
export const CARACAS_OFFSET_MS = 4 * 60 * 60 * 1000 // UTC-4

/**
 * Convierte un valor de input datetime-local ("YYYY-MM-DDTHH:mm")
 * interpretándolo directamente como hora de Caracas (UTC-4) a ISO string (UTC).
 */
export function caracasInputToISO(value: string): string {
  if (!value) return ''
  const trimmed = value.slice(0, 16)
  return new Date(`${trimmed}:00-04:00`).toISOString()
}

/**
 * Convierte un string ISO o Date (UTC) al valor esperado por un input
 * datetime-local ("YYYY-MM-DDTHH:mm") en hora de Caracas.
 */
export function isoToCaracasInput(iso: string | Date): string {
  if (!iso) return ''
  const d = typeof iso === 'string' ? new Date(iso) : iso
  if (isNaN(d.getTime())) return ''
  return new Date(d.getTime() - CARACAS_OFFSET_MS).toISOString().slice(0, 16)
}

/**
 * Retorna la hora actual de Caracas formateada para un input datetime-local.
 * Permite sumar milisegundos (por ejemplo, para fechas de cierre por defecto).
 */
export function nowCaracasInput(plusMs = 0): string {
  const now = new Date(Date.now() + plusMs)
  return isoToCaracasInput(now)
}

/**
 * Formatea una fecha ISO o Date para visualización en la UI en hora de Caracas.
 * Ejemplo: "12 oct 2026, 12:30 p. m."
 */
export function formatCaracas(
  iso: string | Date,
  options?: Intl.DateTimeFormatOptions
): string {
  if (!iso) return ''
  const d = typeof iso === 'string' ? new Date(iso) : iso
  if (isNaN(d.getTime())) return ''

  const defaultOptions: Intl.DateTimeFormatOptions = {
    timeZone: APP_TZ,
    dateStyle: 'medium',
    timeStyle: 'short',
    ...options
  }

  return d.toLocaleString('es-VE', defaultOptions)
}
