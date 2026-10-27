import { caracasInputToISO } from '@guaiqui/shared'

export function parseBoolean(value: any, defaultValue = true): boolean {
  if (value === undefined || value === null || value === '') return defaultValue
  if (typeof value === 'boolean') return value
  const str = String(value).trim().toLowerCase()
  return ['si', 'sí', 'true', '1', 'yes', 'y', 's', 'activo', 'publicado'].includes(str)
}

export function parseDateToISO(value: any): string {
  if (!value) return ''
  if (value instanceof Date) {
    return value.toISOString()
  }
  const str = String(value).trim()
  // If already standard ISO
  if (str.includes('T') && str.endsWith('Z')) return str

  // If YYYY-MM-DD HH:mm or YYYY-MM-DDTHH:mm
  const normalized = str.replace(' ', 'T')
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(normalized)) {
    return caracasInputToISO(normalized.slice(0, 16))
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
    return caracasInputToISO(`${str}T00:00`)
  }

  const parsed = new Date(str)
  if (!isNaN(parsed.getTime())) {
    return parsed.toISOString()
  }
  return ''
}

export function normalizeGroupCategory(val: any): 'directiva' | 'tecnico' | 'logistica' {
  if (!val) return 'tecnico'
  const s = String(val).trim().toLowerCase()
  if (s.includes('dir') || s.includes('presid') || s.includes('geren')) return 'directiva'
  if (s.includes('log') || s.includes('util') || s.includes('fisi') || s.includes('staff')) return 'logistica'
  return 'tecnico'
}

export function normalizeGameStatus(val: any): 'scheduled' | 'live' | 'finished' | 'cancelled' {
  if (!val) return 'scheduled'
  const s = String(val).trim().toLowerCase()
  if (s.includes('vivo') || s === 'live') return 'live'
  if (s.includes('fin') || s === 'finalizado') return 'finished'
  if (s.includes('canc') || s === 'cancelado') return 'cancelled'
  return 'scheduled'
}

export function normalizeProductCategory(val: any): 'physical' | 'experience' | 'raffle' {
  if (!val) return 'physical'
  const s = String(val).trim().toLowerCase()
  if (s.includes('exp') || s.includes('saludo') || s.includes('pase')) return 'experience'
  if (s.includes('sort') || s.includes('rifa') || s.includes('raffle')) return 'raffle'
  return 'physical'
}

export function normalizeChallengeType(val: any): 'silhouette' | 'dorsal' {
  if (!val) return 'silhouette'
  const s = String(val).trim().toLowerCase()
  if (s.includes('dor') || s.includes('num') || s.includes('camiset')) return 'dorsal'
  return 'silhouette'
}
