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


// ─── Helpers ───────────────────────────────────────────────
/** Formatea un saldo de perlitas para la UI (locale es-VE) */
export function formatPerlitas(amount: number): string {
  return new Intl.NumberFormat('es-VE').format(amount)
}
