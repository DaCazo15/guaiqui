import type { LandingCta, CtaType, CtaMediaType } from '@guaiqui/shared'

export interface CtaFormData {
  id: string
  name: string
  type: CtaType
  is_active: boolean
  is_published: boolean
  // Container mode
  badge_text: string
  heading: string
  subtitle: string
  button_text: string
  button_url: string
  bg_gradient: string
  // Phrase mode
  phrase_text: string
  font_family: string
  font_size: string
  letter_spacing: string
  font_weight: string
  text_color: string
  media_type: CtaMediaType
  media_value: string
}

export const DEFAULT_CTA_FORM: CtaFormData = {
  id: '',
  name: '',
  type: 'container',
  is_active: false,
  is_published: true,
  badge_text: '¡Únete a la Tribu Hoy!',
  heading: '¿Listo para ganar tu primer premio?',
  subtitle: 'El registro toma menos de 1 minuto y recibirás un bono de bienvenida de +100 puntos para comenzar.',
  button_text: 'Crear mi Cuenta Gratis',
  button_url: '/registro',
  bg_gradient: 'from-guaiqui-primary-dark via-emerald-900 to-slate-950',
  phrase_text: '¡EL ORGULLO DE NUEVA ESPARTA!',
  font_family: 'Barlow Condensed',
  font_size: 'text-4xl sm:text-6xl',
  letter_spacing: 'tracking-tight',
  font_weight: 'font-extrabold',
  text_color: 'text-white',
  media_type: 'none',
  media_value: ''
}

export const FONT_FAMILY_OPTIONS = [
  { value: 'Barlow Condensed', label: 'Barlow Condensed (Deportiva / Titulares)' },
  { value: 'Barlow', label: 'Barlow (Moderna / Sans)' },
  { value: 'Inter', label: 'Inter (Geométrica / Limpia)' },
  { value: 'Montserrat', label: 'Montserrat (Impacto / Urbana)' },
  { value: 'Playfair Display', label: 'Playfair Display (Elegante / Serif)' }
]

export const FONT_SIZE_OPTIONS = [
  { value: 'text-2xl sm:text-3xl', label: 'Mediano (2xl - 3xl)' },
  { value: 'text-3xl sm:text-4xl', label: 'Grande (3xl - 4xl)' },
  { value: 'text-4xl sm:text-5xl', label: 'Muy Grande (4xl - 5xl)' },
  { value: 'text-4xl sm:text-6xl', label: 'Gigante (4xl - 6xl)' },
  { value: 'text-5xl sm:text-7xl', label: 'Titular Épico (5xl - 7xl)' }
]

export const LETTER_SPACING_OPTIONS = [
  { value: 'tracking-tighter', label: 'Muy apretado (tighter)' },
  { value: 'tracking-tight', label: 'Apretado (tight)' },
  { value: 'tracking-normal', label: 'Normal (normal)' },
  { value: 'tracking-wide', label: 'Separado (wide)' },
  { value: 'tracking-widest', label: 'Muy separado (widest)' }
]

export const FONT_WEIGHT_OPTIONS = [
  { value: 'font-medium', label: 'Medio (Medium)' },
  { value: 'font-semibold', label: 'Seminegrita (Semibold)' },
  { value: 'font-bold', label: 'Negrita (Bold)' },
  { value: 'font-extrabold', label: 'Extra Negrita (Extrabold)' },
  { value: 'font-black', label: 'Black (Máximo grosor)' }
]

export const BG_GRADIENT_OPTIONS = [
  { value: 'from-guaiqui-primary-dark via-emerald-900 to-slate-950', label: 'Verde Tribu Oficial (Esmeralda & Pizarra)' },
  { value: 'from-emerald-950 via-guaiqui-primary to-slate-900', label: 'Verde Intenso & Oscuro' },
  { value: 'from-slate-950 via-slate-900 to-emerald-950', label: 'Noche Pizarra Minimalista' },
  { value: 'from-emerald-900 via-guaiqui-accent-dark to-slate-950', label: 'Bandana Margarita (Verde & Acento Rojizo)' }
]

export const POPULAR_ICONS = [
  { icon: 'bi-trophy-fill', label: 'Trofeo' },
  { icon: 'bi-lightning-charge-fill', label: 'Rayo / Energía' },
  { icon: 'bi-star-fill', label: 'Estrella' },
  { icon: 'bi-fire', label: 'Fuego / Pasión' },
  { icon: 'bi-award-fill', label: 'Premio' },
  { icon: 'bi-gem', label: 'Perla / Diamante' },
  { icon: 'bi-bullseye', label: 'Aro / Objetivo' },
  { icon: 'bi-megaphone-fill', label: 'Megáfono' },
  { icon: 'bi-heart-fill', label: 'Corazón Fan' },
  { icon: 'bi-shield-check', label: 'Escudo' }
]
