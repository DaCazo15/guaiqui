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

---

## Procedimiento de Consolidación de Migraciones (Squash para Lanzamiento)

Para nuevos despliegues limpios o entornos de desarrollo a partir de la versión consolidada:

1. **Generación del Squash**:
   - El script y archivos consolidados se encuentran archivados en:
     `docs/architecture/squash-draft/`
   - Los 4 archivos de migración de referencia son:
     - `20261016000001_schema_and_types.sql`: Esquema base, tablas y tipos ENUM.
     - `20261016000002_functions_and_triggers.sql`: Funciones PL/pgSQL, triggers y validaciones.
     - `20261016000003_rls_policies.sql`: Políticas de Row-Level Security y permisos de ejecución.
     - `20261016000004_initial_seed.sql`: Configuración inicial, slots de anuncios y roles de sistema.

2. **Validación en Entorno Local**:
   - En una rama temporal, sustituir el contenido de `supabase/migrations/` por los 4 archivos generados.
   - Ejecutar:
     ```bash
     supabase db reset
     supabase test db
     ```
   - Verificar que todos los tests pgTAP pasen al 100% idénticos al historial previo.

3. **ADVERTENCIA CRÍTICA PARA STAGING Y PRODUCCIÓN**:
   - **NUNCA** sustituir las migraciones en `supabase/migrations` directamente en repositorios conectados a Staging o Producción existentes sin un respaldo completo y actualización controlada de la tabla `supabase_migrations.schema_migrations`.
   - Las instancias existentes ya tienen registrado el historial de versiones individual. Aplicar el squash sin sincronizar la tabla de migraciones causará desincronización o fallos de migración.

