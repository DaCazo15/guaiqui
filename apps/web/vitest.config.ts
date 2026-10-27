import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'
import path from 'path'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '~': path.resolve(__dirname, './'),
      '#imports': path.resolve(__dirname, './__tests__/mocks/imports.ts'),
      'vue': path.dirname(require.resolve('vue/package.json')),
      '@guaiqui/shared': path.resolve(__dirname, '../../packages/shared/src'),
      '@guaiqui/ui': path.resolve(__dirname, '../../packages/ui/src'),
    },
  },
  test: {
    name: 'web',
    environment: 'happy-dom',
    globals: true,
    exclude: ['**/node_modules/**', '**/e2e/**'],
  },
})
