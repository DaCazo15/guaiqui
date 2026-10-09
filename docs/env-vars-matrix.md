# Matriz de Variables de Entorno por Entorno

| Variable | Descripción | Local (Docker) | Staging (Vercel Preview) | Producción (Vercel Prod) |
|---|---|---|---|---|
| `SUPABASE_URL` | URL REST API de Supabase | `http://127.0.0.1:54321` | `https://staging-ref.supabase.co` | `https://prod-ref.supabase.co` |
| `SUPABASE_ANON_KEY` | Clave pública cliente Supabase | (dev key) | (staging anon key) | (prod anon key) |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave secreta servidor | (dev service key) | (staging service key) | (prod service key) |
| `SENTRY_DSN` | DSN de Monitoreo Sentry | `""` | `https://...sentry.io/staging` | `https://...sentry.io/prod` |
| `TURNSTILE_SITE_KEY` | Key pública Cloudflare Turnstile | `1x00000000000000000000AA` | `1x00000000000000000000AA` | (real site key) |
| `TURNSTILE_SECRET_KEY` | Secret Cloudflare Turnstile | `1x00000000000000000000AA` | `1x00000000000000000000AA` | (real secret key) |
| `POSTHOG_API_KEY` | Key de analítica sin PII | `""` | `phc_staging...` | `phc_prod...` |
| `VAPID_PUBLIC_KEY` | Clave pública Push Notifications | (dev vapid) | (staging vapid) | (prod vapid) |
| `VAPID_PRIVATE_KEY` | Clave privada Push Notifications | (dev private) | (staging private) | (prod private) |
