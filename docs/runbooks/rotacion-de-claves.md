# Runbook: Procedimiento de Rotación de Claves y Respuesta a Incidentes

Este documento detalla el procedimiento operativo para rotar secretos, claves API y tokens de la plataforma **Guaiqueríes de Margarita**, así como el protocolo de respuesta inmediata si se detecta una filtración.

---

## 1. Calendario Sugerido de Rotación

- **Cada 6 Meses**: Secreto HMAC para códigos QR (`hmac_secret`), Claves API de Resend Email, Tokens de GitHub Actions.
- **Cada 12 Meses**: `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, Claves VAPID de Web Push, `TURNSTILE_SECRET_KEY`, `ip_salt`.
- **Inmediatamente**: Ante cualquier sospecha de filtración o ante la salida de un desarrollador/administrador con acceso al repositorio.

---

## 2. Guía de Rotación por Componente

### 2.1. Secreto HMAC de Códigos QR (`public.app_secrets`)
La base de datos cuenta con versionado de llaves (`key_id`) y ventana de transición suave.

```sql
-- 1. Insertar la nueva versión del secreto (ej. v3)
INSERT INTO public.app_secrets (key_name, secret_value)
VALUES ('hmac_secret_v3', 'guaiqui_hmac_prod_sec_v3_2026_nuevo')
ON CONFLICT (key_name) DO UPDATE SET secret_value = EXCLUDED.secret_value;

-- 2. Actualizar la clave activa a v3
UPDATE public.app_secrets
SET secret_value = 'v3', updated_at = NOW()
WHERE key_name = 'hmac_active_key_id';

-- 3. Los canjes emitidos con v2 continuarán siendo verificados mediante el fallback dual.
```

### 2.2. Claves API de Resend Email (`RESEND_API_KEY_1` / `RESEND_API_KEY_2`)
1. Iniciar sesión en [Resend Dashboard](https://resend.com/api-keys).
2. Generar una nueva API Key con permiso `sending` únicamente.
3. Actualizar la variable correspondiente en **Supabase Dashboard** (*Project Settings -> Edge Functions -> Secrets*).
4. Actualizar el archivo `.env` del entorno correspondiente.
5. Eliminar la API Key antigua desde el panel de Resend.

### 2.3. Supabase Service Role Key y Contraseña de Base de Datos
1. Iniciar sesión en **Supabase Dashboard** (`https://app.supabase.com`).
2. Ir a **Project Settings -> API** -> **JWT Secrets** -> Hacer clic en **Generate new secret**.
3. *Atención*: Esto invalidará inmediatamente la `service_role_key` y la `anon_key` anteriores.
4. Actualizar inmediatamente las variables en Vercel, Supabase Edge Functions Secrets y GitHub Actions Secrets (`PROD_SUPABASE_ACCESS_TOKEN`, `PROD_SUPABASE_DB_PASSWORD`).

---

## 3. Protocolo de Respuesta ante Incidentes de Filtración

En caso de que un secreto privado sea confirmado como filtrado o comprometido:

1. **Aislamiento Inmediato**:
   - Revocar / deshabilitar la clave en el proveedor de origen (Resend, Cloudflare, Supabase).
2. **Rotación Forzada**:
   - Generar la nueva clave siguiendo el procedimiento de la sección 2.
3. **Auditoría de Impacto**:
   - Consultar `public.audit_logs` en Postgres para verificar peticiones realizadas durante la ventana del incidente:
   ```sql
   SELECT * FROM public.audit_logs 
   WHERE created_at >= NOW() - INTERVAL '24 hours' 
   ORDER BY created_at DESC;
   ```
4. **Notificación**:
   - Si la filtración involucra credenciales de acceso a la base de datos, notificar al equipo técnico y registrar el evento en el informe de incidentes.
