/**
 * Constantes compartidas para Guaiqueríes de Margarita
 */

export const MUNICIPALITIES = [
  'Mariño',
  'Maneiro',
  'Arismendi',
  'Marcano',
  'Díaz',
  'Gómez',
  'Antolín del Campo',
  'García',
  'Tubores',
  'Península de Macanao',
  'Villalba (Isla de Coche)',
  'Otro estado de Venezuela',
  'Fuera de Venezuela',
] as const

export type Municipality = (typeof MUNICIPALITIES)[number]

export const GENDERS = [
  'Masculino',
  'Femenino',
  'No binario',
  'Otro',
  'Prefiero no decirlo',
] as const

export type Gender = (typeof GENDERS)[number]

export const SHIRT_SIZES = ['S', 'M', 'L', 'XL', '2XL', '3XL'] as const

export type ShirtSize = (typeof SHIRT_SIZES)[number]

export const REFERRAL_SOURCES = [
  'Redes sociales',
  'Amigos / Familia',
  'En el estadio / Juego',
  'Prensa / Radio / TV',
  'Otro',
] as const

export type ReferralSource = (typeof REFERRAL_SOURCES)[number]

export const CURRENT_LEGAL_VERSIONS = {
  terms: '1.0',
  privacy: '1.0',
  pearls_rules: '1.0',
} as const

// ─── Multi-tenant (Teams) ───────────────────────────────────
export const DEFAULT_TEAM_SLUG = 'guaiqueries'
export const DEFAULT_TEAM_ID = 'a0000000-0000-0000-0000-000000000001'

/**
 * Valida que un slug de equipo cumpla las restricciones del esquema:
 * - Solo caracteres alfanuméricos en minúsculas y guiones
 * - Longitud entre 2 y 50 caracteres
 */
export function isValidTeamSlug(slug: string): boolean {
  return /^[a-z0-9-]+$/.test(slug) && slug.length >= 2 && slug.length <= 50
}
