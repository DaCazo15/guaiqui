# Guaiqueries de Margarita — Plataforma de Fidelización de Fanáticos

## PRODUCTO

Plataforma de fidelización para **Guaiqueries de Margarita**, equipo profesional de baloncesto del estado Nueva Esparta, Venezuela.

- Los fanáticos se registran, juegan trivias y ganan **"perlitas"** (moneda virtual). Las perlitas se canjean por premios (camisas, saludos de jugadores, entradas a entrenamientos abiertos, sorteos).
- **NO hay venta de boletos ni pagos con dinero real.**
- Tres roles: `fan`, `staff` (empleado) y `admin`.

### App del fanático

Login, inicio, trivias, billetera, tienda de canje, plantilla, ranking, perfil y ajustes.

### Staff

Cola de canjes, escáner QR para verificar y entregar, inventario, consulta de fanáticos.

### Admin

Todo lo de staff + CRUD de trivias, productos, jugadores, partidos, reglas de la economía, usuarios y roles, segmentos de fanáticos, dashboard de analítica, auditoría.

### Landing pública

Hero, carrusel, cinta de anuncios, cómo funciona, plantilla, historia, equipo de trabajo, FAQ, políticas, footer, botones de registro e inicio de sesión.

---

## STACK

- **Monorepo** con pnpm workspaces:
  - `apps/web` — Nuxt 3 (landing + PWA del fanático)
  - `apps/admin` — Vue 3 + Vite (paneles de staff y admin)
  - `packages/ui` — Componentes compartidos
  - `packages/shared` — Tipos y utilidades
- **TypeScript estricto**, Tailwind CSS, Pinia, Vitest, Playwright, ESLint + Prettier.
- **Backend**: Supabase (Postgres, Auth, Storage, RLS). Migraciones SQL versionadas en `/supabase/migrations`. Los tipos TypeScript se generan desde el esquema.

---

## REGLAS NO NEGOCIABLES

1. **Ledger inmutable.** El saldo de perlitas NUNCA se guarda como valor editable por el cliente. Fuente de verdad: tabla `ledger_entries`, solo inserción (sin `UPDATE` ni `DELETE`). La tabla `wallets` guarda un saldo en caché que solo se modifica dentro de funciones transaccionales.
2. **Lógica en servidor.** La puntuación de trivias, el otorgamiento de perlitas y los canjes se calculan SOLO en servidor (funciones Postgres / Edge Functions). Nunca se envía la respuesta correcta al cliente.
3. **Transacciones atómicas.** Canjes, cancelaciones y entregas son transacciones atómicas con bloqueo de fila e idempotencia.
4. **Sin borrado de registros financieros.** Cancelar o reembolsar = insertar una entrada positiva en el libro que referencie la original. Nunca borrar.
5. **RLS activo** en todas las tablas. Cada rol solo accede a lo que le corresponde.
6. **Idioma del código vs. interfaz.** Identificadores de código, tablas y rutas en inglés; textos de interfaz en español (Venezuela). Textos preparados para i18n.
7. **Mobile-first y accesible.** Contraste AA, navegación por teclado, `alt` en imágenes, respetar `prefers-reduced-motion`, imágenes con carga diferida.
8. **Sin secretos en el repositorio.** Usar `.env.example`.
9. **Cero datos hardcodeados y sin seeds ficticios.** Toda la información de la interfaz (podio, tienda, partidos, rachas) debe ser 100% real, reactiva y asíncrona desde Supabase o Sofascore. Prohibido inventar datos, mocks o usuarios de relleno (como Carlos R. o María G.). Si hay pocos datos, mostrar únicamente los reales o estados vacíos. Prohibido sembrar seeds con datos ficticios.

---

## BRANDING

- **Verde predominante** en botones y elementos principales; **fondos blancos**; detalles en **rojo** (inspirados en la bandana) usados con moderación, **nunca en botones principales**.
- **Iconografía (Sin emojis)**: **NUNCA usar emojis** (🏀, 🏆, 🔥, ⚙️, etc.) en la interfaz. Usar exclusivamente **Bootstrap Icons** (`bi bi-*` o componentes SVG dedicados como `PearlIcon.vue` para las perlitas).
- Colores, tipografías y espaciado definidos como **design tokens** (variables CSS + configuración de Tailwind). Nada de colores hardcodeados.
- **Tipografía**:
  - `Barlow Condensed` para titulares y números destacados.
  - `Barlow` para cuerpo.
  - Autoalojadas (no Google Fonts CDN).

---

## FORMA DE TRABAJO

1. **Plan antes de código.** Antes de escribir código, presenta un plan breve.
2. **Fases pequeñas.** Trabaja por fases pequeñas, con commits claros.
3. **No inventar.** No inventes funcionalidades fuera de lo pedido. Si algo es ambiguo, pregunta.
4. **Resumen al terminar.** Al terminar cada fase, resume qué hiciste, cómo probarlo y qué queda pendiente.
5. **Commit y Push.** Al completar y verificar cada fase o cambio aprobado, realizar siempre `git commit` y `git push` al repositorio remoto.

### Convenciones de código Vue

- Preferir **composables y helpers** para lógica reutilizable.
- Preferir **slots sobre props** en modales y botones (componentes de presentación genéricos).
- Seguir la regla de **Vue Component Modularizer**: componentes de más de ~100-150 líneas de template deben descomponerse en subcomponentes enfocados (ver regla global `vue-component-modularizer`).
- **Animaciones (GSAP)**: Para animaciones usa GSAP y sus skills instaladas. Ante dudas consulta https://gsap.com/docs/v3/. En Vue, crea las animaciones dentro de `gsap.context()` y haz `revert()` al desmontar el componente. Respeta `prefers-reduced-motion` con `gsap.matchMedia()`. GSAP y todos sus plugins son gratuitos y se instalan desde el paquete npm 'gsap'.

---

## Reglas de todas las fases

1. Funciones nuevas en public: REVOKE ALL a PUBLIC y anon; GRANT EXECUTE solo a authenticated (o solo a service_role si es interna). Si son SECURITY DEFINER: search_path fijo, validar el rol del llamador dentro (assert_active_verified_fan, assert_staff o assert_admin) y rechazar perfiles con status = 'deleted' o 'suspended'. Sin SQL dinámico con interpolación. Toda función nueva entra en la allowlist de pgTAP.
2. Toda tabla nueva con RLS activo y políticas mínimas. Vistas y vistas materializadas no accesibles para anon ni authenticated, salvo indicación expresa.
3. Todo cambio de esquema es una migración nueva. No se edita una anterior y no se toca el proyecto remoto.
4. Ningún dato personal en logs, errores ni analítica.
5. Antes de codificar: leer migraciones, tipos y funciones reales, presentar un plan breve y esperar mi aprobación.
6. Cierre de fase en máximo 20 líneas: qué se hizo, qué queda pendiente y la salida literal de supabase test db, pnpm test y pnpm exec playwright test (con conteo de pasadas y falladas). Si algo no se pudo ejecutar, decirlo. Nunca marcar algo como probado sin su salida.
7. Al completar y verificar cada fase o tarea, hacer siempre commit con mensaje claro y push al repositorio remoto.

