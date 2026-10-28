# Guaiqueríes de Margarita — Fan Zone

Plataforma oficial de fidelización y gamificación para fanáticos de **Guaiqueríes de Margarita**, equipo profesional de baloncesto del estado Nueva Esparta, Venezuela.

Los fanáticos se registran, juegan trivias, interactúan con dinámicas del equipo y acumulan **perlitas** (moneda virtual inmutable). Las perlitas se canjean por recompensas físicas y experiencias exclusivas (camisas oficiales, saludos personalizados de jugadores, accesos a entrenamientos, sorteos). **No hay venta de boletos ni pagos con dinero real.**

---

## 🏗️ Arquitectura y Stack Tecnológico

El proyecto es un **monorepo modular** gestionado con `pnpm workspaces`:

| Componente                    | Directorio        | Tecnología                                   | Descripción                                                                            |
| ----------------------------- | ----------------- | -------------------------------------------- | -------------------------------------------------------------------------------------- |
| **App Web / PWA**             | `apps/web`        | Nuxt 3, Tailwind CSS, Pinia                  | Landing pública y Progressive Web App del fanático                                     |
| **Panel Admin & Staff**       | `apps/admin`      | Vue 3, Vite, Vue Router, Pinia               | Canjes en taquilla, escáner QR, gestión de trivias, inventario, antifraude y analítica |
| **Componentes UI**            | `packages/ui`     | Vue 3 + Vite Library Mode                    | Design System institucional (`BaseButton`, `BaseModal`, `PearlAmount`, etc.)           |
| **Tipos y Lógica Compartida** | `packages/shared` | TypeScript                                   | Tipos de base de datos (`Database`, `Tables`), schemas, helpers de fecha y compresión  |
| **Backend & Base de Datos**   | `supabase/`       | Supabase, PostgreSQL 15, Deno Edge Functions | Ledger financiero inmutable, RLS estricto, auth, storage, pgTAP tests                  |
| **Testing**                   | Monorepo          | Vitest, Playwright, pgTAP                    | Pruebas unitarias, de integración, end-to-end y pruebas unitarias de base de datos     |

---

## 📋 Requisitos del Entorno

Asegúrate de contar con las siguientes herramientas instaladas:

- **Node.js**: `>= 20.0.0`
- **pnpm**: `>= 9.0.0`
- **Docker Desktop** o **Docker Engine** (en ejecución para la base de datos local)
- **Supabase CLI**: `>= 1.140.0` (`brew install supabase/tap/supabase` o `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git && scoop install supabase`)
- **Git**

---

## 🚀 Arranque Rápido Local

### 1. Clonar el repositorio e instalar dependencias

```bash
git clone https://github.com/DaCazo15/guaiqui.git
cd guaiqui
pnpm install
```

### 2. Configurar variables de entorno y MCP

Copia las plantillas de configuración:

```bash
cp .env.example .env
cp .mcp.example.json .mcp.json
```

> **Importante para MCP**: En `.mcp.json`, reemplaza `<PROJECT_REF>` por tu referencia de proyecto y conserva `read_only=true` salvo que requieras explícitamente aplicar cambios en Supabase.
>
> **Generación de salt de IP**: Para la variable `IP_SALT`, genera un hash criptográfico de 32 bytes con `openssl rand -hex 32`.

### 3. Iniciar Supabase Local

Levanta los contenedores Docker de Supabase, ejecuta las migraciones y genera los tipos:

```bash
# Iniciar servicios de Supabase (Postgres, Auth, Storage, Edge Runtime)
supabase start

# Resetear base de datos aplicando migraciones y seeds
supabase db reset

# Generar tipos TypeScript sincronizados con el esquema local
pnpm db:types
```

### 4. Ejecutar las Aplicaciones

```bash
# Terminal 1: Iniciar Nuxt (Landing pública y PWA del fan) en http://localhost:3000
pnpm dev:web

# Terminal 2: Iniciar Vue/Vite (Panel Staff y Admin) en http://localhost:3001
pnpm dev:admin
```

---

## 🛠️ Scripts Disponibles (`package.json`)

| Script                 | Comando                                                                         | Descripción                                                                    |
| ---------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `dev:web`              | `pnpm --filter @guaiqui/web dev`                                                | Inicia Nuxt 3 en modo desarrollo (`localhost:3000`)                            |
| `dev:admin`            | `pnpm --filter @guaiqui/admin dev`                                              | Inicia el panel de administración en modo desarrollo (`localhost:3001`)        |
| `build`                | `pnpm -r run --if-present build`                                                | Compila todos los paquetes y aplicaciones para producción                      |
| `typecheck`            | `pnpm -r run --if-present typecheck`                                            | Comprueba tipos TypeScript en todo el monorepo (`tsc` / `vue-tsc`)             |
| `lint`                 | `eslint .`                                                                      | Analiza el código con ESLint                                                   |
| `lint:fix`             | `eslint . --fix`                                                                | Corrige automáticamente problemas de formato y linting                         |
| `format`               | `prettier --write .`                                                            | Formatea archivos con Prettier                                                 |
| `format:check`         | `prettier --check .`                                                            | Valida el formato con Prettier sin modificar                                   |
| `test`                 | `vitest run`                                                                    | Ejecuta suites de pruebas unitarias y de integración con Vitest                |
| `test:e2e`             | `playwright test`                                                               | Ejecuta pruebas End-to-End con Playwright                                      |
| `test:db`              | `supabase test db`                                                              | Ejecuta pruebas unitarias de PostgreSQL (pgTAP) en `supabase/tests/`           |
| `db:reset`             | `supabase db reset`                                                             | Resetea la base de datos local y aplica todas las migraciones SQL              |
| `db:types`             | `supabase gen types typescript --local > packages/shared/src/types/database.ts` | Regenera la definición TypeScript del esquema de base de datos                 |
| `security:scan-bundle` | `node scripts/scan-bundle-leaks.mjs`                                            | Audita bundles compilados para prevenir fugas de secretos o claves de servicio |

---

## ⚡ Edge Functions (`supabase/functions/`)

Funciones sin servidor desarrolladas en TypeScript sobre el runtime de Deno:

- `check-email`: Verificación segura y opaca de existencia de correo para el flujo de registro.
- `compress-avatar`: Compresión server-side de avatares subidos a Supabase Storage.
- `create-staff`: Aprovisionamiento restringido de usuarios con roles `staff` o `admin`.
- `delete-account`: Ejecución conforme a privacidad para borrado y anonimización de cuentas de fans.
- `export-segment-csv`: Exportación asíncrona de listas de fanáticos para campañas.
- `reset-mfa`: Procedimiento seguro de contingencia para reseteo de doble factor a administradores.
- `revalidate-landing`: Revalidación de caché en landing page ante actualizaciones de CMS.
- `send-email`: Envío de notificaciones y confirmaciones transaccionales mediante Resend.
- `send-notifications`: Despacho de notificaciones Web Push vía VAPID.
- `use-recovery-code`: Validación y consumo de códigos de recuperación de respaldo.
- `verify-captcha`: Verificación de tokens de Cloudflare Turnstile con rate limiting y fingerprinting.

---

## 🧪 Pruebas y Pipeline de CI/CD

El repositorio cuenta con integración continua automatizada en GitHub Actions (`.github/workflows/ci.yml`). Cada Pull Request y Push valida rigurosamente:

1. **Gitleaks Secret Scanning**: Auditoría de commits para impedir filtración de credenciales.
2. **Verify No Production Secrets**: Verificación estricta de variables de entorno y archivos `.example`.
3. **Dependency Audit**: Escaneo de dependencias vulnerables (`pnpm audit`).
4. **Linting**: Reglas de ESLint aplicadas sobre Vue y TypeScript.
5. **Typecheck**: Verificación de tipos estricta sin emisión de código.
6. **Vitest**: Suites de pruebas unitarias para stores, composables y utilidades compartidas.
7. **pgTAP Database Tests**: Inicio de Supabase y validación de RLS, integridad de transacciones atómicas y ledger inmutable en `supabase/tests/`.
8. **Playwright E2E**: Pruebas de flujos críticos de usuario (registro, canjes, trivias y navegación administrativa).

---

## 📚 Índice de Documentación (`docs/`)

La carpeta `docs/` contiene las especificaciones técnicas, manuales y runbooks operativos del proyecto:

- **Arquitectura y Base de Datos**:
  - [`docs/architecture.md`](docs/architecture.md): Visión general de la arquitectura de la plataforma.
  - [`docs/schema.md`](docs/schema.md): Diccionario de datos, políticas RLS, funciones PL/pgSQL y ledger financiero.
  - [`docs/architecture/squash-draft/`](docs/architecture/squash-draft/): Histórico y borradores de consolidación de migraciones SQL.
- **Seguridad y Runbooks de Operación**:
  - [`docs/security-audit-2026-10.md`](docs/security-audit-2026-10.md): Reporte de auditoría y medidas de hardening pre-beta.
  - [`docs/secrets-inventory.md`](docs/secrets-inventory.md): Catálogo de credenciales, roles y rotación de claves.
  - [`docs/runbooks.md`](docs/runbooks.md): Procedimientos operativos estándar y atención de incidencias.
  - [`docs/runbooks/rotacion-de-claves.md`](docs/runbooks/rotacion-de-claves.md): Procedimiento de rotación de secrets de producción.
  - [`docs/runbooks/emergency_mfa_reset.md`](docs/runbooks/emergency_mfa_reset.md): Guía de recuperación para MFA de staff y admin.
  - [`docs/restore-drill.md`](docs/restore-drill.md): Protocolo y bitácora de simulacro de recuperación ante desastres (DRP).
  - [`docs/privacy-notes.md`](docs/privacy-notes.md): Directrices de protección de datos personales y minimización de logs.
- **Despliegue y Configuración**:
  - [`docs/deployment.md`](docs/deployment.md): Guía de despliegue en Vercel y Supabase Cloud.
  - [`docs/env-vars-matrix.md`](docs/env-vars-matrix.md): Matriz de variables requeridas por ambiente (local, staging, producción).
  - [`docs/launch-checklist.md`](docs/launch-checklist.md) y [`docs/launch-plan.md`](docs/launch-plan.md): Lista de control previa y plan de lanzamiento.
  - [`docs/smtp-resend-setup.md`](docs/smtp-resend-setup.md): Configuración del servicio transaccional de correo con Resend.
  - [`docs/ad-manager-setup.md`](docs/ad-manager-setup.md): Integración con Google Ad Manager (GAM) para anuncios recompensados.
  - [`docs/analytics.md`](docs/analytics.md): Eventos y seguimiento de métricas anónimas.
  - [`docs/staff-bootstrap.md`](docs/staff-bootstrap.md): Instrucciones para creación de las primeras cuentas de staff.
  - [`docs/user-manuals.md`](docs/user-manuals.md): Manual de operación para personal de taquilla y tienda.

---

## 🔒 Variables de Entorno por Aplicación

Las variables se configuran en el archivo `.env` de la raíz del monorepo o en los paneles de despliegue correspondientes:

### Supabase Core & Servicios

- `SUPABASE_URL`: Endpoint de la API REST de Supabase (`http://127.0.0.1:54321` en local).
- `SUPABASE_ANON_KEY`: Clave pública para clientes web anónimos y autenticados.
- `SUPABASE_SERVICE_ROLE_KEY`: Clave privilegiada para scripts de administración y Edge Functions.

### Web & PWA (`apps/web`)

- `NUXT_PUBLIC_SUPABASE_URL`: URL pública de Supabase inyectada en Nuxt.
- `NUXT_PUBLIC_SUPABASE_KEY`: Clave pública anónima de Supabase inyectada en Nuxt.
- `NUXT_PUBLIC_TURNSTILE_SITE_KEY`: Site key de Cloudflare Turnstile (en local usar dummy `1x00000000000000000000AA`).
- `NUXT_PUBLIC_POSTHOG_KEY` / `NUXT_PUBLIC_POSTHOG_HOST`: Credenciales de analítica sin PII.
- `NUXT_PUBLIC_GAM_AD_UNIT_PATH`: Identificador del bloque publicitario de Google Ad Manager.

### Admin & Staff (`apps/admin`)

- `VITE_SUPABASE_URL`: URL del proyecto Supabase para el cliente Vite.
- `VITE_SUPABASE_ANON_KEY`: Clave anónima pública de Supabase para el panel administrativo.
- `VITE_VAPID_PUBLIC_KEY`: Clave pública VAPID para registro de suscripciones Push.

### Notificaciones y Seguridad

- `TURNSTILE_SECRET_KEY`: Clave secreta privada de Cloudflare Turnstile (utilizada en Edge Functions).
- `IP_SALT`: Salt de 32 bytes para anonimización y hashing de direcciones IP en logs antifraude.
- `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT`: Claves criptográficas para el protocolo Web Push RFC 8292.
- `RESEND_API_KEY_1` / `RESEND_API_KEY_2`: Claves de API para balanceo y redundancia de envío de correos vía Resend.

---

## 📄 Licencia

Privado — Todos los derechos reservados. **Guaiqueríes de Margarita BBC**.
