// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',

  devtools: { enabled: true },

  modules: ['@nuxtjs/tailwindcss', '@pinia/nuxt', '@nuxtjs/supabase'],

  supabase: {
    url: process.env.NUXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'http://127.0.0.1:54321',
    key: process.env.NUXT_PUBLIC_SUPABASE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      exclude: [ 
        '/',
        '/registro',
        '/login',
        '/recuperar',
        '/restablecer-contrasena',
        '/verificar-correo',
        '/politicas/*',
        '/aceptar-terminos',
        '/historia',
        '/salon-de-la-fama',
        '/plantilla',
        '/equipo-de-trabajo',
        '/como-funciona',
        '/faq',
        '/contacto'
      ],
    },
  },

  typescript: {
    strict: true,
  },

  css: ['@guaiqui/ui/src/styles/tokens.css', '~/assets/css/main.css'],

  tailwindcss: {
    cssPath: '~/assets/css/main.css',
  },

  app: {
    head: {
      title: 'Guaiqueries de Margarita — Fan Zone',
      htmlAttrs: { lang: 'es' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        {
          name: 'description',
          content: 'Plataforma de fidelización de Guaiqueries de Margarita',
        },
        { name: 'theme-color', content: '#005a36' },
      ],
      link: [
        { rel: 'manifest', href: '/manifest.json' },
      ],
    },
  },

  runtimeConfig: {
    public: {
      turnstileSiteKey: process.env.NUXT_PUBLIC_TURNSTILE_SITE_KEY || '0x4AAAAAAFTd4sjJvea-Cegw',
      gaMeasurementId: process.env.NUXT_PUBLIC_GA_MEASUREMENT_ID || 'G-P6EY10HB0B',
    },
  },
})
