/**
 * Tailwind CSS preset con los design tokens de Guaiqueries de Margarita.
 *
 * Se importa como preset en el tailwind.config.ts de cada app.
 * Los colores, tipografías y espaciados definidos aquí usan variables CSS para permitir
 * cambios centralizados sin recompilar assets.
 *
 * REGLA: nunca usar colores hardcodeados; siempre referenciar tokens.
 */
export default {
  theme: {
    extend: {
      colors: {
        guaiqui: {
          primary: {
            DEFAULT: 'var(--g-color-primary)',
            dark: 'var(--g-color-primary-dark)',
            soft: 'var(--g-color-primary-soft)',
          },
          accent: {
            DEFAULT: 'var(--g-color-accent)',
            dark: 'var(--g-color-accent-dark)',
            soft: 'var(--g-color-accent-soft)',
          },
          bg: 'var(--g-color-bg)',
          surface: {
            DEFAULT: 'var(--g-color-surface)',
            hover: 'var(--g-color-surface-hover)',
          },
          border: 'var(--g-color-border)',
          text: {
            DEFAULT: 'var(--g-color-text)',
            muted: 'var(--g-color-text-muted)',
            subtle: 'var(--g-color-text-subtle)',
          },
          status: {
            success: {
              DEFAULT: 'var(--g-color-success)',
              soft: 'var(--g-color-success-soft)',
            },
            warning: {
              DEFAULT: 'var(--g-color-warning)',
              soft: 'var(--g-color-warning-soft)',
            },
            danger: {
              DEFAULT: 'var(--g-color-danger)',
              soft: 'var(--g-color-danger-soft)',
            },
            info: {
              DEFAULT: 'var(--g-color-info)',
              soft: 'var(--g-color-info-soft)',
            },
          },
          perlita: {
            DEFAULT: 'var(--g-color-perlita)',
            soft: 'var(--g-color-perlita-soft)',
          },
        },
      },
      fontFamily: {
        display: ['var(--g-font-display)', '"Barlow Condensed"', '-apple-system', 'sans-serif'],
        body: ['var(--g-font-body)', 'Barlow', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        'guaiqui-sm': 'var(--g-radius-sm)',
        'guaiqui-md': 'var(--g-radius-md)',
        'guaiqui-lg': 'var(--g-radius-lg)',
        'guaiqui-xl': 'var(--g-radius-xl)',
        'guaiqui-full': 'var(--g-radius-full)',
      },
      boxShadow: {
        'guaiqui-sm': 'var(--g-shadow-sm)',
        'guaiqui-md': 'var(--g-shadow-md)',
        'guaiqui-lg': 'var(--g-shadow-lg)',
      },
    },
  },
}
