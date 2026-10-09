# Manual de Despliegue y Plan de Reversión — Guaiqueríes de Margarita

## Entornos

1. **Local (Docker)**: Supabase CLI local (`supabase start`).
2. **Staging**: Proyecto de Supabase dedicado para Staging + Vercel Previews (los deployments de PR apuntan SIEMPRE a Staging).
3. **Producción**: Proyecto de Supabase dedicado para Producción + Vercel Production (`guaiqueris.com` y `admin.guaiqueris.com`).

---

## Procedimiento de Despliegue

### 1. Migraciones a Staging (Automático)
- Cada merge a `main` desencadena la GitHub Action `.github/workflows/cd-staging.yml`.
- Se ejecuta `supabase db push` contra el proyecto de Staging.
- Se corren los tests `@smoke` de Playwright.

### 2. Migraciones a Producción (Manual)
- Se activa manualmente la GitHub Action `.github/workflows/cd-production.yml` (workflow_dispatch).
- Requiere aprobación en el GitHub Environment `production`.
- La acción ejecuta `supabase migration list` para verificar desfases y `supabase db push` para aplicar migraciones.

---

## Plan de Reversión (Rollback)

Dado que **las migraciones de base de datos son estrictamente hacia adelante** (forward-only), ante una falla crítica en producción:

1. **Reversión del Código Frontend (Vercel)**:
   - Ir al Dashboard de Vercel -> Proyecto -> Deployments.
   - Seleccionar el deployment previo estable y hacer clic en **Instant Rollback**.

2. **Reversión de Base de Datos (Supabase Pro PITR / Backup)**:
   - Acceder al Dashboard de Supabase -> Database -> Backups.
   - Para Point-in-Time Recovery (PITR), seleccionar la estampa de tiempo inmediatamente anterior al despliegue fallido.
   - Aplicar el restore a la base de datos de producción.
