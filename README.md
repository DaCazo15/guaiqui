# Guaiqueries de Margarita — Fan Zone

Plataforma de fidelización para fanáticos de **Guaiqueries de Margarita**, equipo profesional de baloncesto del estado Nueva Esparta, Venezuela.

## Stack

| Capa | Tecnología |
|------|-----------|
| **Web (landing + PWA)** | Nuxt 3, Tailwind CSS, Pinia |
| **Admin (staff + admin)** | Vue 3, Vite, Vue Router, Pinia, Tailwind CSS |
| **Componentes compartidos** | `@guaiqui/ui` (Vue 3 + Vite library mode) |
| **Tipos y utilidades** | `@guaiqui/shared` |
| **Backend** | Supabase (Postgres, Auth, Storage, RLS) |
| **Testing** | Vitest (unit), Playwright (E2E) |
| **CI** | GitHub Actions |

## Requisitos

- **Node.js** >= 20
- **pnpm** >= 9

## Arranque local

```bash
# 1. Clonar el repo
git clone <url> && cd guaiqui

# 2. Copiar variables de entorno y configuración de MCP
cp .env.example .env
cp .mcp.example.json .mcp.json
# Nota: Configurar <PROJECT_REF> en .mcp.json y mantener 'read_only=true' salvo que sea estrictamente necesario.

# 3. Instalar dependencias
pnpm install

# 4. Levantar la app web (landing + fan zone) — puerto 3000
pnpm dev:web

# 5. Levantar el panel admin — puerto 3001
pnpm dev:admin
```

## Scripts disponibles

| Comando | Descripción |
|---------|-------------|
| `pnpm dev:web` | Inicia Nuxt en modo desarrollo (puerto 3000) |
| `pnpm dev:admin` | Inicia Vite en modo desarrollo (puerto 3001) |
| `pnpm build` | Compila todos los paquetes y apps |
| `pnpm lint` | Ejecuta ESLint en todo el monorepo |
| `pnpm lint:fix` | Ejecuta ESLint con corrección automática |
| `pnpm format` | Formatea con Prettier |
| `pnpm test` | Ejecuta tests unitarios con Vitest |
| `pnpm test:e2e` | Ejecuta tests E2E con Playwright |
| `pnpm typecheck` | Verifica tipos en todos los paquetes |

## Estructura del monorepo

```
guaiqui/
├── apps/
│   ├── web/            # Nuxt 3 — landing + PWA del fanático
│   └── admin/          # Vue 3 + Vite — panel staff/admin
├── packages/
│   ├── ui/             # Componentes Vue compartidos
│   └── shared/         # Tipos y utilidades
├── supabase/
│   ├── config.toml     # Configuración local
│   └── migrations/     # Migraciones SQL versionadas
├── tests/              # Tests E2E (Playwright)
└── .github/workflows/  # CI: lint + typecheck + test
```

## Variables de entorno

Copia `.env.example` a `.env` y configura los valores de tu instancia local de Supabase.

## Licencia

Privado — Todos los derechos reservados.
