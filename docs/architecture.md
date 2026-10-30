# Arquitectura del Sistema — Guaiqueríes de Margarita

## Diagrama de Arquitectura Global

```mermaid
flowchart TD
    subgraph Clientes ["Clientes Frontend (Vercel)"]
        Web["Fan App / Landing (Nuxt 3)<br/>guaiqueris.com"]
        Admin["Admin / Staff Panel (Vue 3 + Vite)<br/>admin.guaiqueris.com"]
    end

    subgraph CDN ["Seguridad & Edge CDN"]
        VercelEdge["Vercel Edge Network<br/>(HSTS, CSP, Header Security)"]
        Turnstile["Cloudflare Turnstile<br/>(Captcha Antifraude)"]
        PostHog["PostHog (Analítica sin PII)"]
    end

    subgraph Supabase ["Supabase Backend"]
        Auth["Supabase Auth<br/>(OAuth Google + Email Confirm)"]
        DB[(PostgreSQL Database<br/>RLS, Immutable Ledger, pg_cron)]
        Storage["Supabase Storage<br/>(Avatares, Imágenes)"]
        EdgeFunctions["Edge Functions<br/>(verify-captcha, send-email, push)"]
    end

    Web --> VercelEdge
    Admin --> VercelEdge
    VercelEdge --> Auth
    VercelEdge --> DB
    VercelEdge --> Storage
    Web --> Turnstile
    Web --> PostHog
    EdgeFunctions --> DB
```

---

## Esquema de Base de Datos y Módulos Principales

1. **Multi-Tenancy y Directorio de Equipos**: `teams`, `teams_public`, `team_follows`.
2. **Usuarios y Control de Acceso (RBAC + Multi-Tenant)**:
   - `profiles`: Identidad única del fanático compartida en la plataforma.
   - `staff_members`: Empleados de club (`team_id NOT NULL`) y administradores de plataforma (`team_id IS NULL`).
   - `team_follows`: Relación explícita fanático-equipo que habilita ganar perlitas y recibir beneficios.
3. **Economía e Inmutabilidad Multi-Equipo**:
   - `wallets`: Billetera aislada por equipo `(fan_id, team_id)` con `balance_cache`.
   - `ledger_entries`: Libro contable append-only inmutable (`team_id NOT NULL`).
   - `economy_settings`: Topes globales por usuario sumando todos los equipos y reglas de economía.
4. **Trivias y Participación**: `trivias`, `trivia_questions`, `trivia_options`, `trivia_attempts` (acotados por `team_id`).
5. **Tienda y Canjes**: `products`, `redemptions`, `redemption_history` (catálogo y canjes aislados por club).
6. **Antifraude y Auditoría**: `risk_flags` (mixta: club ve banderas de su equipo, plataforma ve todas), `held_pearls`, `audit_log`, `system_alerts`.
7. **Contenido Público**: `site_announcements`, `carousel_slides`, `history_milestones`, `site_team_members`, `faqs`, `site_stats`, `policy_documents`.
