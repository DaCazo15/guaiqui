import type { Config } from 'tailwindcss'
import preset from '../../packages/ui/tailwind.preset'

export default {
  presets: [preset],
  content: [
    './app.vue',
    './components/**/*.{vue,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './composables/**/*.ts',
    './data/**/*.ts',
    './plugins/**/*.ts',
    '../../packages/ui/src/**/*.{vue,ts}',
  ],
  safelist: [
    {
      pattern: /(from|via|to)-(emerald|green|amber|rose|red|teal|slate)-(600|700|800|900|950)/,
    },
  ],
} satisfies Config
