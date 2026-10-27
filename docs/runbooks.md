# Procedimientos Operativos (Runbooks) — Guaiqueríes de Margarita

## Runbook 1: Alta de Personal (Staff / Admin)
1. El usuario debe registrarse como fanático normal en la plataforma.
2. Un Administrador accede al panel en `admin.guaiqueris.com/admin/personal`.
3. Selecciona "Agregar Miembro de Personal", ingresa el ID de usuario o correo, asigna el rol (`staff` o `admin`) y activa el perfil.

---

## Runbook 2: Respuesta ante Alertas de Descalce en Billeteras (`reconcile_wallets`)
1. El job diario de `pg_cron` o una revisión manual detecta inconsistencias entre `wallets.balance` y la suma de `ledger_entries`.
2. Se genera un registro de severidad `critical` en `system_alerts`.
3. **Acción Operativa**:
   - Consultar `system_alerts` en `admin.guaiqueris.com/admin/auditoria`.
   - Ejecutar la función `reconcile_wallets()` desde la consola SQL o llamar a `admin_recalculate_wallet(user_id)`.
   - Verificar si hubo alguna transacción interrumpida e investigar `audit_logs`.

---

## Runbook 3: Rotación de Claves y Secretos
1. **Supabase Anon / Service Role Keys**:
   - Generar nuevas claves en Supabase Dashboard -> Settings -> API.
   - Actualizar las variables de entorno en Vercel y en GitHub Secrets.
   - Re-desplegar la aplicación.
2. **Cloudflare Turnstile Secret**:
   - Crear una nueva secret key en el Dashboard de Cloudflare.
   - Actualizar `TURNSTILE_SECRET_KEY` en Supabase Vault y Edge Functions.
3. **VAPID Keys**:
   - Generar par de llaves con `web-push generate-vapid-keys`.
   - Actualizar en Supabase Vault.

---

## Runbook 4: Restauración de Backups (PITR)
1. Ir al Dashboard de Supabase -> Database -> Backups.
2. Seleccionar restaurar a un proyecto temporal de staging primero para verificar la integridad.
3. Tras la verificación, aplicar el restore en producción si se trata de un incidente crítico de pérdida de datos.

---

## Runbook 5: Revisión y Liberación/Revocación de Perlitas Retenidas
1. Acceder a `admin.guaiqueris.com/admin/retenciones`.
2. Filtrar los casos por flag de riesgo (ej: `high_score_fast_time`, `multiple_accounts_same_ip`).
3. Evaluar la actividad del usuario en `audit_logs`.
4. Hacer clic en **Liberar Perlitas** (si es un caso legítimo) o **Revocar Perlitas** (si se confirma fraude). La acción genera una entrada inmutable en el libro contable.

---

## Runbook 6: Respuesta ante Exposición o Bypass de Captcha (Turnstile)
1. **Detección**: Si se detecta que el endpoint `verify-captcha` aceptó tokens inválidos, mocks fuera de local o hubo degradación del servicio Cloudflare:
2. **Auditoría Inmediata de Datos**:
   - Consultar `captcha_passes` creados en los últimos días:
     ```sql
     SELECT user_id, ip_hash, used, created_at
     FROM public.captcha_passes
     WHERE created_at >= NOW() - INTERVAL '7 days'
     ORDER BY created_at DESC;
     ```
   - Cruzar con `risk_flags` y `fraud_telemetry`:
     ```sql
     SELECT rf.fan_id, rf.flag, rf.severity, rf.details, rf.created_at
     FROM public.risk_flags rf
     WHERE rf.created_at >= NOW() - INTERVAL '7 days';
     ```
   - Consultar registros en `held_pearls` (entradas `ledger_entries` con `status = 'held'`):
     ```sql
     SELECT id, fan_id, amount, source_type, source_id, created_at
     FROM public.ledger_entries
     WHERE status = 'held' AND created_at >= NOW() - INTERVAL '7 days';
     ```
3. **Revocación de Perlitas y Contención**:
   - Para cualquier usuario con anomalías de captcha, IPs idénticas repetidas o flags de severidad alta, invocar la RPC `admin_revoke_held_pearls(p_ledger_id, p_reason)`.
   - Si se confirma actividad de bots masiva, suspender perfiles involucrados (`status = 'suspended'`) y reportar a soporte.
4. **Validación de Secretos**:
   - Rotar de inmediato `TURNSTILE_SECRET_KEY` en Cloudflare Dashboard y en Supabase Secrets.

