import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

export default defineNuxtPlugin(() => {
  if (import.meta.client) {
    gsap.registerPlugin(ScrollTrigger)

    // Ensure ScrollTrigger refreshes when dynamic content loads or images finish loading
    window.addEventListener('load', () => {
      ScrollTrigger.refresh()
    })
  }

  return {
    provide: {
      gsap,
      ScrollTrigger,
    },
  }
})
