/**
 * @guaiqui/shared — Tipos y utilidades compartidas
 */

// ─── Roles ─────────────────────────────────────────────────
/** Roles del sistema */
export type UserRole = 'fan' | 'staff' | 'admin'

export * from './constants'
export * from './types/database'

// ─── Helpers ───────────────────────────────────────────────
/** Formatea un saldo de perlitas para la UI (locale es-VE) */
export function formatPerlitas(amount: number): string {
  return new Intl.NumberFormat('es-VE').format(amount)
}
