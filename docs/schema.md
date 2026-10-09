# Supabase Database Schema — Guaiqueríes de Margarita

Plataforma de fidelización de fanáticos para **Guaiqueríes de Margarita**.

## Modelo de Entidad-Relación

```mermaid
erDiagram
    profiles ||--|| wallets : "has balance cache"
    profiles ||--o{ ledger_entries : "has transactions"
    profiles ||--o{ trivia_attempts : "submits"
    profiles ||--o{ redemptions : "requests"
    profiles ||--o{ risk_flags : "flagged for"
    profiles }o--o| players : "favorite_player"

    trivias ||--o{ trivia_questions : "contains"
    trivia_questions ||--o{ trivia_options : "has options"
    trivias ||--o{ trivia_attempts : "evaluated via"

    products ||--o{ redemptions : "redeemed as"
    redemptions ||--o{ redemption_history : "logs status changes"
    redemptions }o--o| staff_members : "approved / delivered by"

    staff_members ||--o{ scan_events : "scans QR"

    profiles {
        uuid id PK
        text display_name
        text avatar_url
        text municipality
        date birth_date
        text gender
        uuid favorite_player_id FK
        text shirt_size
        text referral_source
        jsonb notification_prefs
        enum status
        timestamptz created_at
    }

    wallets {
        uuid fan_id PK
        int balance_cache
        timestamptz updated_at
    }

    ledger_entries {
        uuid id PK
        uuid fan_id FK
        int amount
        enum type
        enum status
        text source_type
        text source_id
        text note
        uuid created_by FK
        timestamptz created_at
    }

    trivias {
        uuid id PK
        text title
        text description
        enum status
        timestamptz starts_at
        timestamptz ends_at
        int time_limit_seconds
        jsonb reward_rules
        int max_attempts
    }

    trivia_questions {
        uuid id PK
        uuid trivia_id FK
        text question_text
        int points
        int order_index
    }

    trivia_options {
        uuid id PK
        uuid question_id FK
        text option_text
        bool is_correct
    }

    trivia_attempts {
        uuid id PK
        uuid fan_id FK
        uuid trivia_id FK
        timestamptz started_at
        timestamptz expires_at
        timestamptz submitted_at
        jsonb answers
        int score
        int pearls_awarded
        bool suspicious
        int seed
        text idempotency_key
    }

    products {
        uuid id PK
        text name
        text description
        enum category
        int cost_pearls
        int stock
        jsonb variants
        bool active
        timestamptz valid_from
        timestamptz valid_until
        text_arr images
    }

    redemptions {
        uuid id PK
        uuid fan_id FK
        uuid product_id FK
        text variant
        int cost_pearls
        enum status
        text code_hash UK
        uuid approved_by FK
        timestamptz approved_at
        uuid delivered_by FK
        timestamptz delivered_at
        timestamptz expires_at
        text idempotency_key UK
    }

    redemption_history {
        uuid id PK
        uuid redemption_id FK
        enum previous_status
        enum new_status
        uuid changed_by FK
        text note
        timestamptz created_at
    }

    scan_events {
        uuid id PK
        uuid staff_id FK
        text code_hash
        enum result
        text device
        timestamptz created_at
    }

    players {
        uuid id PK
        text name
        int jersey_number
        text position
        text height
        int age
        text nationality
        text bio
        bool is_active
        bool is_star
    }

    games {
        uuid id PK
        text opponent
        text location
        timestamptz game_date
        bool is_home
        enum status
        int our_score
        int opponent_score
    }

    staff_members {
        uuid user_id PK
        enum role
        bool active
    }

    segments {
        uuid id PK
        text name
        jsonb filters
    }

    economy_settings {
        uuid id PK
        int daily_pearl_cap
        int weekly_pearl_cap
        jsonb streak_bonus_config
    }

    risk_flags {
        uuid id PK
        uuid fan_id FK
        text reason
        enum severity
        bool resolved
    }

    audit_log {
        uuid id PK
        uuid actor_id FK
        text action
        text entity
        text entity_id
        jsonb before
        jsonb after
        timestamptz created_at
    }
```

## Enums

| Enum               | Valores                                                                                           |
|---------------------|---------------------------------------------------------------------------------------------------|
| `user_status`       | `active`, `suspended`                                                                             |
| `staff_role`        | `staff`, `admin`                                                                                  |
| `ledger_type`       | `trivia_reward`, `redemption`, `refund`, `admin_adjustment`, `bonus`, `streak_bonus`               |
| `ledger_status`     | `confirmed`, `held`, `revoked`                                                                    |
| `trivia_status`     | `draft`, `published`, `archived`                                                                  |
| `product_category`  | `physical`, `experience`, `raffle`                                                                |
| `redemption_status` | `pending`, `approved`, `scheduled`, `delivered`, `completed`, `cancelled`, `rejected`, `issue`, `expired` |
| `scan_result`       | `success`, `invalid`, `already_delivered`, `expired`                                              |
| `game_status`       | `scheduled`, `live`, `finished`, `cancelled`                                                      |
| `risk_severity`     | `low`, `medium`, `high`                                                                           |

## Reglas Inmutables de la Economía de Perlitas

1. **Libro Contable Inmutable (`ledger_entries`)**:
   - `UPDATE` y `DELETE` están bloqueados a nivel de base de datos con un disparador (`BEFORE UPDATE OR DELETE ON ledger_entries`).
   - Todos los saldos se derivan de transacciones de suma.
   - La tabla `wallets` mantiene un saldo en caché (`balance_cache`) que solo es alterado mediante funciones transaccionales atómicas con bloqueo de fila (`FOR UPDATE`).
   - Índice único parcial `(source_type, source_id, type) WHERE status = 'confirmed'` previene pagos duplicados.

2. **Evaluación 100% en Servidor**:
   - Las soluciones de las trivias (`trivia_options.is_correct`) nunca viajan al cliente antes de enviar las respuestas.
   - Las funciones `start_trivia_attempt` y `submit_trivia_attempt` evalúan puntos y otorgan perlitas en una única transacción en el servidor.
   - Detección de comportamiento sospechoso: si el tiempo de resolución es < 3 segundos, el intento se marca `suspicious`, los puntos se ponen en estado `held` y se crea un `risk_flag`.

3. **Canjes Atómicos y Prevención de Doble Entrega**:
   - La función `redeem_product` bloquea la billetera y el producto (`FOR UPDATE`), verifica saldo y stock, genera el código QR hash y descuenta perlitas y stock de forma atómica.
   - La función `deliver_redemption` ejecuta una actualización condicional `WHERE status IN ('pending', 'approved', 'scheduled')` para impedir la entrega doble de un mismo código QR.
   - Clave de idempotencia `(fan_id, idempotency_key)` única en `redemptions`.

4. **Transacciones de Reembolso**:
   - Cancelar o rechazar un canje inserta una entrada POSITIVA en `ledger_entries` con `type = 'refund'` y restaura el stock. Nunca borra ni modifica registros existentes.

## Funciones RPC Transaccionales

| Función | Descripción | Bloqueo |
|---------|-------------|---------|
| `start_trivia_attempt(trivia_id, idempotency_key)` | Crea intento con expiración y semilla de barajado. Idempotente. | — |
| `submit_trivia_attempt(attempt_id, answers, idempotency_key)` | Evalúa en servidor, aplica anti-cheat, inserta ledger + wallet atómicamente. | `FOR UPDATE` en attempt |
| `redeem_product(product_id, variant, idempotency_key)` | Verifica saldo/stock, descuenta todo atómicamente, genera código QR. | `FOR UPDATE` en wallet + product |
| `cancel_redemption(redemption_id, reason)` | Fan cancela pendientes; staff cancela pending/approved/scheduled. Reembolsa. | `FOR UPDATE` en redemption |
| `approve_redemption(redemption_id, note)` | Staff aprueba canje pendiente. | `FOR UPDATE` en redemption |
| `reject_redemption(redemption_id, reason)` | Staff rechaza y reembolsa perlitas + stock. | `FOR UPDATE` en redemption |
| `deliver_redemption(code_hash, device)` | Entrega por escaneo QR. Previene doble entrega. | `FOR UPDATE` en redemption |
| `report_redemption_issue(redemption_id, reason)` | Staff reporta problema con entrega. | `FOR UPDATE` en redemption |
| `verify_redemption_code(code_hash)` | Lectura de la tarjeta del canje, sin consumir. | — |
| `admin_adjust_pearls(fan_id, amount, reason)` | Ajuste manual con motivo obligatorio + audit_log. | `FOR UPDATE` en wallet |

## RLS (Row-Level Security)

| Tabla | Fan | Staff | Admin |
|-------|-----|-------|-------|
| `profiles` | Lee/edita solo su perfil | Lee todos | Todo |
| `wallets` | Lee solo su billetera | Lee todas | Todo |
| `ledger_entries` | Lee solo sus entradas | Lee todas | Todo |
| `trivias` | Lee publicadas/archivadas | Lee todas | Todo |
| `trivia_options` | Lee texto (sin `is_correct` vía RPC) | Lee todas | Todo |
| `trivia_attempts` | Lee solo las suyas | Lee todas | Todo |
| `products` | Lee activos | Edita stock | Todo |
| `redemptions` | Lee solo los suyos | Gestiona todos | Todo |
| `players` | Lee activos | Lee activos/inactivos | Todo |
| `games` | Lee todos | Lee todos | Todo |
| `segments`, `economy_settings`, `risk_flags`, `audit_log` | — | — | Todo |
| `scan_events` | — | Lee/crea | Todo |

> **Nadie** escribe directamente en `ledger_entries` ni `wallets` desde el cliente. Toda escritura pasa por funciones `SECURITY DEFINER`.

## Pruebas de Integridad

Archivo: `supabase/tests/test_integrity.sql`

| # | Test | Qué verifica |
|---|------|-------------|
| 1 | Ledger UPDATE bloqueado | Trigger rechaza `UPDATE` en `ledger_entries` |
| 2 | Ledger DELETE bloqueado | Trigger rechaza `DELETE` en `ledger_entries` |
| 3 | Balance no negativo | CHECK `balance_cache >= 0` en `wallets` |
| 4 | Costo de producto > 0 | CHECK `cost_pearls > 0` en `products` |
| 5 | Idempotency key única | UNIQUE `(fan_id, idempotency_key)` en `redemptions` |
| 6 | Pago duplicado bloqueado | Índice único parcial en `ledger_entries` |
| 7 | Canje concurrente | Solo 1 de 2 canjes con saldo justo pasa |
| 8 | Doble entrega | Conditional UPDATE afecta 0 filas en segundo intento |
| 9 | Cache = SUM(ledger) | `balance_cache == SUM(amount) WHERE confirmed` |
| 10 | Trivia duplicada | UNIQUE `(fan_id, trivia_id, idempotency_key)` |
| 11 | code_hash único | UNIQUE `code_hash` en `redemptions` |
| 12 | Stock no negativo | CHECK `stock >= 0` en `products` |
