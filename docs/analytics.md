# Guaiqueríes de Margarita — Documentación de Analítica y Embudo de Conversión

Este documento define la taxonomía de eventos y la configuración del embudo de conversión en PostHog Cloud para la plataforma Fan Zone de Guaiqueríes de Margarita.

---

## 1. Principios de Privacidad y Cumplimiento

1. **Cero PII (Personally Identifiable Information)**: Ningún evento o propiedad incluye correo electrónico, nombre, saldo de perlitas, dirección o número de teléfono.
2. **Identificación Estricta**: Los usuarios se identifican únicamente con su `auth.uid()` interno de Supabase.
3. **Consentimiento Previsto (Opt-In)**: La analítica solo se inicializa si el usuario acepta explícitamente en el banner de cookies o en la pantalla de ajustes.
4. **Respeto a Do Not Track (DNT)**: Si la cabecera `DNT` o la preferencia del navegador está activa, se inhabilita el rastreo.
5. **Sin Grabaciones de Sesión**: La función de grabación de pantalla y autocaptura está desactivada globalmente (`autocapture: false`, `disable_session_recording: true`).

---

## 2. Taxonomía de Eventos Mínimos

| Nombre de Evento | Descripción / Momento de Disparo | Propiedades Permitidas (Sin PII) |
| :--- | :--- | :--- |
| `cta_click` | Clics en botones principales de llamado a la acción (ej. en landing) | `section` (string), `target` (string) |
| `signup_started` | El usuario inicia el formulario de registro | Ninguna |
| `signup_completed` | El usuario completa con éxito la creación de cuenta | Ninguna |
| `email_verified` | El usuario confirma su correo electrónico | Ninguna |
| `trivia_started` | El usuario inicia un intento de trivia | `trivia_id` (uuid string) |
| `trivia_completed` | El usuario finaliza y envía el intento de trivia | `trivia_id` (uuid string), `score` (int) |
| `redemption_created` | El usuario solicita un canje en la tienda | `product_id` (uuid string), `cost_pearls` (int) |
| `push_permission_prompted` | Se presenta la tarjeta explicativa para notificaciones push | Ninguna |
| `push_permission_granted` | El usuario aprueba el permiso de notificaciones push | Ninguna |

---

## 3. Embudo de Conversión en PostHog (Funnel Analysis)

Para evaluar la retención y conversión del usuario en la plataforma, configurar el siguiente embudo de 4 pasos en la consola de PostHog:

### Embudo Principal: Registro → Activación → Retención → Conversión

1. **Paso 1: Inicio de Registro** (`signup_started`)
   - Mide el interés inicial del usuario al hacer clic en registrarse.
2. **Paso 2: Verificación de Cuenta** (`email_verified`)
   - Mide la tasa de confirmación de correo y activación de la cuenta.
3. **Paso 3: Primera Trivia Completada** (`trivia_completed`)
   - Mide la primera interacción de juego/engagement del fanático.
4. **Paso 4: Primer Canje Creado** (`redemption_created`)
   - Mide la conversión final en la economía de recompensas.

---

## 4. Reescritura Vercel (`/ingest`)

Para evitar bloqueadores de anuncios (ad-blockers), Vercel redirige las solicitudes de analítica mediante las siguientes reglas definidas en `vercel.json`:

- `/ingest/static/*` → `https://us-assets.i.posthog.com/static/*`
- `/ingest/*` → `https://us.i.posthog.com/*`
- `/ingest/decide` → `https://us.i.posthog.com/decide`
