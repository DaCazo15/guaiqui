import type { Config } from 'tailwindcss'
import preset from '../../packages/ui/tailwind.preset'

export default {
  presets: [preset],
  content: [
    './index.html',
    './src/**/*.{vue,ts,tsx}',
    '../../packages/ui/src/**/*.{vue,ts}',
  ],
} satisfies Config
