# Inventario de Secretos y Políticas de Protección

Este documento inventaría de forma exhaustiva todos los secretos, claves API y tokens de la plataforma **Guaiqueríes de Margarita**, detallando su ubicación, alcance de visibilidad, políticas de rotación y reglas de exposición al cliente.

> [!CAUTION]
> **REGLA ABSOLUTA DE SEGURIDAD**: Ninguna clave privada o secreto con privilegios elevados (`SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `TURNSTILE_SECRET_KEY`, `VAPID_PRIVATE_KEY`, `hmac_redemption_secret`) debe ser expuesta al código cliente servido al navegador (archivos JavaScript de `apps/web` o `apps/admin`).

---

## 1. Matriz de Inventario de Secretos

| Secreto / Credencial | Ubicación Física | Alcance de Visibilidad | Exposición a Cliente | Período de Rotación |
| :--- | :--- | :--- | :--- | :--- |
| `SUPABASE_URL` | `.env`, Vercel, Supabase | Pública | Sí (`NUXT_PUBLIC_`, `VITE_`) | Indefinido (salvo cambio de dominio) |
| `SUPABASE_ANON_KEY` | `.env`, Vercel, Supabase | Pública (JWT) | Sí (`NUXT_PUBLIC_`, `VITE_`) | 12 meses |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Vault, Edge Functions | **Privada (Servidor)** | **NUNCA** | 6 - 12 meses |
| `hmac_redemption_secret` | `public.app_secrets` (Postgres) | **Privada (Servidor)** | **NUNCA** | 6 meses (Versionado `key_id`) |
| `ip_salt` | `public.app_secrets` (Postgres) | **Privada (Servidor)** | **NUNCA** | 12 meses (Hashes expiran en 30 días) |
| `RESEND_API_KEY_1` | `.env`, Supabase Edge Functions | **Privada (Servidor)** | **NUNCA** | 6 meses / tras incidente |
| `RESEND_API_KEY_2` | `.env`, Supabase Edge Functions | **Privada (Servidor)** | **NUNCA** | 6 meses / tras incidente |
| `VAPID_PUBLIC_KEY` | `.env`, Nuxt Config, Vite | Pública | Sí (`VITE_VAPID_PUBLIC_KEY`) | 12 meses |
| `VAPID_PRIVATE_KEY` | Supabase Edge Functions | **Privada (Servidor)** | **NUNCA** | 12 meses |
| `TURNSTILE_SITE_KEY` | `.env`, Nuxt Config | Pública | Sí (`NUXT_PUBLIC_TURNSTILE_SITE_KEY`) | 12 meses |
| `TURNSTILE_SECRET_KEY` | Supabase Edge Functions | **Privada (Servidor)** | **NUNCA** | 12 meses |
| `STAGING_*_TOKEN` / `PROD_*_TOKEN` | GitHub Actions Secrets | **Privada (CI/CD)** | **NUNCA** | 6 meses |

---

## 2. Definición Detallada por Secreto

### 2.1. Supabase Service Role Key (`SUPABASE_SERVICE_ROLE_KEY`)
- **Propósito**: Omitir las políticas Row Level Security (RLS) para tareas administrativas y Edge Functions.
- **Acceso**: Exclusivo para el entorno de ejecuciones en servidor (Deno Edge Functions) y variables secretas de CI.
- **Riesgo**: Crítico. Otorga acceso total de lectura/escritura a la base de datos Postgres.

### 2.2. Secreto HMAC de Códigos QR (`hmac_redemption_secret`)
- **Propósito**: Generar firmas HMAC-SHA256 para prevenir falsificaciones o clonación de códigos QR de canje.
- **Acceso**: Tabla `public.app_secrets` con RLS habilitado y permisos restringidos exclusivamente a `service_role` y funciones `SECURITY DEFINER`.
- **Rotación**: Soporta versionado mediante `key_id` con ventana de transición suave para que los códigos generados antes de la rotación continúen siendo válidos durante su ciclo de vida.

### 2.3. Claves API de Resend Email (`RESEND_API_KEY_1` / `RESEND_API_KEY_2`)
- **Propósito**: Envió transaccional de correos electrónicos (notificaciones, 2FA, confirmaciones).
- **Acceso**: Consumido únicamente dentro de las Edge Functions (`send-email` y `send-notifications`).
- **Conmutación**: Administrado automáticamente por la base de datos al alcanzar 3,000 envíos mensuales por clave.

---

## 3. Mínimo Privilegio en GitHub Actions & CI/CD

Los tokens de GitHub Actions deben estar configurados en el repositorio con alcances mínimos:

- **`GITHUB_TOKEN`**: Permisos de solo lectura (`contents: read`) para acciones de escaneo de código (`gitleaks-action`).
- **`STAGING_SUPABASE_*`**: Limitado al proyecto de prueba (Staging). Sin acceso a la base de datos de producción.
- **`PROD_SUPABASE_*`**: Asociado exclusivamente al entorno `production` en GitHub Actions con **Revisores Requeridos (Required Reviewers)** habilitado en la configuración de la rama `main`.
