# Informe de Auditoría de Seguridad — Octubre 2026

## Resumen Ejecutivo
Se realizó una auditoría exhaustiva de seguridad sobre las políticas de Row Level Security (RLS), funciones `SECURITY DEFINER`, aislamiento de datos financieros (`wallets`, `ledger_entries`), separación de privilegios entre roles (`anon`, `authenticated`, `staff`, `admin`) y mecanismos de mitigación contra abusos (rate limiting y Turnstile captcha).

---

## 1. Matriz de Auditoría de Entidades y RLS

| Entidad / Tabla | RLS Activo | Acceso Directo Anon | Acceso Directo Fan (`authenticated`) | Acceso Staff | Acceso Admin | Estado & Remediación |
|---|---|---|---|---|---|---|
| `wallets` | Sí | Denegado | Solo lectura de su propia billetera (`fan_id = auth.uid()`). **Mutaciones denegadas por RLS.** | Solo lectura (`is_staff_or_admin`) | Solo lectura (`is_admin`). Modificación únicamente por RPC transaccional. | **Conforme**. Sin mutación directa permitida. |
| `ledger_entries` | Sí | Denegado | Solo lectura de sus registros confirmados (`fan_id = auth.uid() AND status = 'confirmed'`). Mutaciones denegadas. | Solo lectura | Solo lectura. Inserción exclusiva vía RPC de servidor. | **Conforme**. Trigger `trg_prevent_ledger_mutation` bloquea UPDATE y DELETE incluso para superuser/service_role. |
| `redemptions` | Sí | Denegado | Solo lectura de sus propios canjes (`fan_id = auth.uid()`). Inserción directa denegada. | Lectura y actualización de estado de entrega | Control total | **Conforme**. Canjes creados solo mediante RPC atómica `redeem_product`. |
| `inventory_movements` / `products` | Sí | `products`: lectura pública de activos | Solo lectura de catálogo | Solo lectura | Control total (CRUD de productos y ajustes de stock) | **Conforme**. Sin acceso cliente a inventario interno. |
| `staff_members` | Sí | Denegado | Solo lectura de su propia fila si es empleado | Solo lectura propia | Gestión completa de personal | **Conforme**. Solo administradores activos pueden modificar o invitar staff. |
| `audit_log` | Sí | Denegado | Denegado | Denegado | Solo lectura (`is_admin`) | **Conforme**. Trigger `trg_prevent_audit_log_mutation` impide UPDATE y DELETE. |
| `captcha_passes` | Sí | Denegado | Denegado (0 políticas públicas) | Denegado | Denegado desde cliente (solo Edge Functions y RPCs con `service_role`) | **Conforme**. Totalmente aislado. |
| `risk_flags` | Sí | Denegado | Denegado | Denegado | Lectura y gestión (`is_admin`) | **Conforme**. Aislado de fanáticos y empleados. |
| `held_pearls` (ledger con status 'held') | Sí | Denegado | Oculto para el fan (la política RLS de lectura filtra solo `status = 'confirmed'`) | Denegado | Lectura vía `admin_risk_queue` | **Conforme**. El saldo retenido no afecta el caché de billetera ni es visible al fan hasta su liberación. |
| `notification_outbox` | Sí | Denegado | Denegado | Denegado | Denegado desde cliente (solo background cron y webhooks vía `service_role`) | **Conforme**. Cola de despacho segura. |
| `notifications` | Sí | Denegado | Solo lectura de sus propias notificaciones (`user_id = auth.uid()`) | Solo lectura propia | Solo lectura propia | **Conforme**. Aislamiento estricto entre fanáticos. |
| `sponsor_videos` | Sí | Solo lectura de videos activos (`active = true`) | Solo lectura de activos | Gestión completa (`is_staff_or_admin`) | Gestión completa | **Conforme**. |
| `rate_limits` | Sí | Denegado | Denegado | Denegado | Solo accesible mediante RPC `check_rate_limit` | **Conforme**. |

---

## 2. Auditoría de Funciones SECURITY DEFINER y `search_path`

1. **Revisión de `search_path`**:
   - Todas las funciones `SECURITY DEFINER` cuentan con `SET search_path TO 'public', 'extensions', 'pg_temp'` (o `'public', 'pg_temp'`), previniendo secuestro de esquemas por resolución insegura de operadores o tipos.
2. **Permisos y `GRANT` a `anon`**:
   - `REVOKE ALL FROM PUBLIC, anon` ejecutado sobre todas las funciones de lógica sensible.
   - **Exenciones legítimas a `anon`**:
     - `is_admin_check()`
     - `is_staff_or_admin(uuid)`
     - `is_admin(uuid)`
     - *Justificación*: Estas funciones retornan un booleano y son invocadas internamente dentro de las expresiones `USING` de políticas RLS aplicadas a tablas públicas (ej. `landing_ctas`, `hero_carousel_slides`). Sin el permiso `GRANT EXECUTE ... TO anon`, las consultas anónimas de la landing pública fallan con HTTP 401 (`permission denied for function`).
     - Al estar marcadas como `STABLE` y validar `auth.uid()`, cuando son invocadas por `anon` (`auth.uid() IS NULL`) devuelven inmediatamente `FALSE` sin ejecutar lógica privilegiada.

---

## 3. Cobertura de Rate Limiting (`check_rate_limit`)

Se auditó y aplicó `check_rate_limit` sobre todos los puntos de entrada que otorgan perlitas o consumen recursos:
- `start_ad_session`: 10 llamadas por 60s.
- `claim_birthday_bonus`: 3 llamadas por 60s *(Añadido en migración 20261027000001)*.
- `start_trivia_attempt`: 5 intentos por 60s.
- `redeem_product`: 3 canjes por 60s.
- `submit_trivia_poll_vote` (encuestas): 5 votos por 60s *(Añadido en migración 20261027000001)*.
- `submit_guess_player_vote` (¿Quién es?): 5 intentos por 60s *(Añadido en migración 20261027000001)*.
- `submit_over_under_vote`: 5 pronósticos por 60s *(Añadido en migración 20261027000001)*.
- `submit_score_prediction_vote`: 5 pronósticos por 60s *(Añadido en migración 20261027000001)*.
- `submit_mystery_play_vote`: 5 votos por 60s *(Añadido en migración 20261027000001)*.
- `submit_flash_trivia_session`: 5 sesiones por 60s *(Añadido en migración 20261027000001)*.
- `submit_progressive_clue_vote`: 5 votos por 60s *(Añadido en migración 20261027000001)*.

---

## 4. Requisitos de Captcha para Operaciones de Alto Valor

- En `redeem_product`, para productos cuyo costo en perlitas sea igual o superior a `high_value_product_pearls` (configuración dinámica en `risk_settings`, por defecto 3,000 perlitas), se requiere obligatoriamente un registro en `captcha_passes` no expirado y con `used = false`.
- Dicho pase se consume atómicamente (`used = true`) en la misma transacción, impidiendo el uso reiterado del mismo token.

---

## 5. Hallazgos Corregidos de Esquema en Modalidades Extendidas

Durante la auditoría de RPCs de modalidades extendidas (`20261026000004_create_extended_trivias.sql`), se detectó que `submit_mystery_play_vote`, `submit_flash_trivia_session`, `submit_progressive_clue_vote`, `admin_resolve_over_under` y `admin_resolve_score_prediction` intentaban consultar e insertar en columnas inexistentes (`wallet_id`, `metadata`, `cached_balance`, `total_earned`).
- **Remediación**: Se reescribieron en la migración `20261027000001_security_audit_hardening.sql` adaptándolas estrictamente al esquema consolidado (`fan_id`, `amount`, `type`, `status`, `source_type`, `source_id`, `note` en `ledger_entries`, y `balance_cache` en `wallets`).
