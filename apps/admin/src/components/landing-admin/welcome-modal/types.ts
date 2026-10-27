export interface LoginModalSlide {
  id: string
  position: number
  image_url?: string | null
  title: string
  subtitle?: string | null
  cta_label: string
  cta_url: string
  status: 'draft' | 'published'
  starts_at: string
  ends_at?: string | null
  created_at: string
}

export interface WelcomeSlideFormData {
  id: string
  position: number
  image_url: string
  title: string
  subtitle: string
  cta_label: string
  cta_url: string
  status: 'draft' | 'published'
  starts_at: string
  ends_at: string
}
