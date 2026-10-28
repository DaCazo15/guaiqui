import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import pluginVue from 'eslint-plugin-vue'
import eslintConfigPrettier from 'eslint-config-prettier'
import globals from 'globals'

export default [
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        useHead: 'readonly',
        useRoute: 'readonly',
        useRouter: 'readonly',
        defineNuxtConfig: 'readonly',
        definePageMeta: 'readonly',
        navigateTo: 'readonly',
        useSeoMeta: 'readonly',
        useSupabaseClient: 'readonly',
        useSupabaseUser: 'readonly',
      },
    },
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  eslintConfigPrettier,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
      },
    },
    rules: {
      'vue/multi-word-component-names': 'off',
    },
  },
  {
    ignores: [
      '**/node_modules/',
      '**/dist/',
      '**/.output/',
      '**/.nuxt/',
      '**/coverage/',
    ],
  },
]
