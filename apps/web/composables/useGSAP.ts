import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

let isRegistered = false

/**
 * Composable for standardized, SSR-safe GSAP and ScrollTrigger access in Nuxt.
 */
export function useGSAP() {
  if (process.client && !isRegistered) {
    gsap.registerPlugin(ScrollTrigger)
    isRegistered = true
  }

  return {
    gsap,
    ScrollTrigger,
  }
}
