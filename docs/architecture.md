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

1. **Usuarios y Autenticación**: `profiles`, `staff_members`, `user_segments`.
2. **Economía e Inmutabilidad**: `wallets`, `ledger_entries` (Append-Only), `economy_settings`.
3. **Trivias y Participación**: `trivias`, `trivia_questions`, `trivia_options`, `trivia_attempts`.
4. **Tienda y Canjes**: `products`, `redemptions`, `inventory_movements`.
5. **Antifraude y Auditoría**: `captcha_passes`, `risk_flags`, `held_pearls`, `audit_logs`, `system_alerts`.
6. **Contenido Público**: `site_announcements`, `carousel_slides`, `history_milestones`, `site_team_members`, `faqs`, `site_stats`, `policy_documents`.
