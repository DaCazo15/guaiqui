/**
 * @guaiqui/shared — Tipos y utilidades compartidas
 */

// ─── Roles ─────────────────────────────────────────────────
/** Roles del sistema */
export type UserRole = 'fan' | 'staff' | 'admin'

export * from './constants'
export * from './datetime'
export * from './types/database'
export type { Database } from './types/database'
export * from './envValidation'
export * from './sofascoreData'
export * from './googleDrive'
export * from './imageCompression'
// ─── Helpers ───────────────────────────────────────────────
/**
 * Formatea un saldo de perlitas / puntos para la UI.
 * A partir de 100.000 puntos abrevia con sufijos en minúscula: k, m, b, etc.
 * Ejemplos: 100k, 1m, 10m, 100m, 1b.
 * Por debajo de 100.000 utiliza el formato estándar con separador de miles (locale es-VE).
 */
export function formatPerlitas(amount: number): string {
  if (typeof amount !== 'number' || isNaN(amount)) return '0'
  const abs = Math.abs(amount)
  if (abs >= 100_000) {
    const sign = amount < 0 ? '-' : ''
    let val: number
    let suffix: string

    if (abs >= 1_000_000_000) {
      val = abs / 1_000_000_000
      suffix = 'b'
    } else if (abs >= 1_000_000) {
      val = abs / 1_000_000
      suffix = 'm'
    } else {
      val = abs / 1_000
      suffix = 'k'
    }

    const formattedVal = val >= 100
      ? Math.round(val).toString()
      : (Math.round(val * 10) / 10).toString()

    return `${sign}${formattedVal}${suffix}`
  }
  return new Intl.NumberFormat('es-VE').format(amount)
}
