# Checklist Pre-Lanzamiento (Beta Cerrada y Producción)

**Estado general**: Listo para despliegue de Beta Cerrada (Post-Fase 19)

---

## 1. Seguridad y Autenticación

- [x] **Eliminación de Bypass de Captcha**: Eliminada toda variable de entorno que permita saltarse Cloudflare Turnstile en entornos de producción.
- [x] **Auditoría de Secretos en Bundles**: Script `scripts/verify-no-prod-secrets.mjs` verificado; ninguna variable `SERVICE_ROLE_KEY` ni tokens privados expuestos en `apps/web` o `apps/admin`.
- [x] **Auditoría de Vulnerabilidades**: Dependencias de producción auditadas con `pnpm run audit:ci` integrado en CI de GitHub Actions; `dompurify` actualizado a `^3.4.17` (CVEs resueltos).
- [x] **Rate Limiting y Protección RPC**: Límite de peticiones activo por IP/usuario en endpoints de autenticación, encuestas y trivias.
- [x] **Ledger Inmutable**: RLS activo en `ledger_entries`, `wallets` y `redemptions`. Bloqueo atómico (`FOR UPDATE`) en todas las transacciones de canje y entrega.

---

## 2. Calidad de Código y Arquitectura

- [x] **Modularización de Componentes Vue**: Todos los componentes y archivos de configuración masiva descomprimidos y modularizados a < 300 líneas por archivo conforme a la regla `vue-component-modularizer`.
- [x] **Limpieza del Repositorio**: Eliminados 52 archivos de backup de migraciones antiguas, directorios duplicados (.agent/) y archivos scratch temporales.
- [x] **Migración Squash Preparada**: Archivo consolidado `supabase/squash_draft/20261027_consolidated_squash.sql` listo para entornos limpios.
- [x] **Verificación de Tipos TypeScript**: `pnpm typecheck` exitoso con 0 errores en los 4 proyectos (`@guaiqui/shared`, `@guaiqui/ui`, `@guaiqui/web`, `@guaiqui/admin`).
- [x] **Suite de Pruebas Unitarias**: 20 archivos de prueba y 152 casos de prueba ejecutados al 100% de aprobación (`pnpm test`).

---

## 3. Contenido, Medios y Accesibilidad

- [x] **Cero Datos Hardcodeados / Seeds Ficticios**: Prohibición estricta de usuarios mock ("Carlos R.", "María G."). Podios, trivias y productos son 100% reales y reactivos.
- [x] **Iconografía Oficial sin Emojis**: 0 emojis en componentes UI. Uso exclusivo de **Bootstrap Icons** (`bi bi-*`) y componentes SVG dedicados (`PearlIcon.vue`).
- [x] **Optimización de Medios**: Formatos WebP con carga diferida y límites de subida controlados en Supabase Storage.
- [x] **Zona Horaria Estricta**: Todas las fechas se formatean y gestionan en `America/Caracas` (GMT-4).

---

## 4. Aspectos Legales y Políticas

- [x] **Naturaleza de las Perlitas**: Términos aprobados. Puntos virtuales promocionales sin valor monetario, no canjeables por dinero real y no transferibles.
- [x] **Edad Mínima**: Registro autónomo a partir de 13 años.
- [x] **Políticas de Privacidad**: Visibles en `/politicas/privacidad` detallando el tratamiento de `device_id` y analítica sin datos personales sensibles (PII).
- [x] **Términos y Condiciones**: Visibles en `/politicas/terminos`.

---

## 5. Operaciones de Staff y Cancha

- [x] **Escáner QR de Canjes**: Verificación criptográfica de token de canje y confirmación de entrega en tiempo real desde el panel de staff.
- [x] **Plan de Contingencia y Rollback**: Documentado en `docs/restore-drill.md` y `docs/deployment.md`.
- [x] **Monitoreo de Salud de la Base de Datos**: Función `public.health_check()` y conciliación de billeteras activas.
