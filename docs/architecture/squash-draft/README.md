# Borrador de Consolidación de Migraciones (Squash Draft)

Este directorio contiene los artefactos del borrador de consolidación ("squash") de la base de datos de **Guaiqueríes de Margarita**, junto con el script generador asociado.

## Propósito y Estado Actual

- **Estado**: **Archivado / No activo**.
- **Fuente de verdad activa**: La fuente de verdad oficial del esquema de base de datos son las migraciones incrementales versionadas ubicadas en `supabase/migrations/` (36 migraciones).
- **Justificación**: Reescribir o sustituir las migraciones aplicadas en entornos remotos (Staging / Producción) rompería el registro histórico de `supabase_migrations.schema_migrations` y causaría desincronización en CI/CD y despliegues.

## Contenido

1. `20261016000001_schema_and_types.sql`: Consolidación del esquema base, extensiones, tipos ENUM y tablas.
2. `20261016000002_functions_and_triggers.sql`: Consolidación de funciones PL/pgSQL, triggers y RPCs con permisos endurecidos.
3. `20261016000003_rls_policies.sql`: Políticas de Row Level Security (RLS) para todas las tablas y storage buckets.
4. `20261016000004_initial_seed.sql`: Datos semilla base de configuración (economía, riesgo, cumpleaños, documentos legales).
5. `generate_squash_all.mjs`: Script utilitario utilizado para construir el borrador original a partir de la introspección de Postgres.

## Uso Futuro

Estos archivos se preservan como referencia técnica ante una eventual decisión de reinicio total o inicialización de un nuevo entorno limpio independiente (greenfield) donde no se requiera preservar el historial de migraciones previas.
