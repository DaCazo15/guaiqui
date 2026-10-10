# Runbook: Restablecimiento de Emergencia de 2FA (MFA)

Este documento describe el procedimiento seguro y oficial para recuperar el acceso a una cuenta administrativa en caso de pérdida total de factores de verificación en dos pasos (dispositivo MFA extraviado, sin códigos de recuperación).

> [!IMPORTANT]
> **REGLA DE SEGURIDAD ABSOLUTA**: No existen accesos traseros (backdoors) ni códigos maestros en la aplicación. Todo restablecimiento de emergencia debe ejecutarse utilizando las herramientas administrativas oficiales de Supabase o la Service Role Key por el titular del proyecto.

---

## 1. Procedimiento desde el Panel de Supabase (Recomendado)

1. Iniciar sesión en el **Supabase Dashboard** (`https://app.supabase.com`).
2. Seleccionar el proyecto **Guaiqueríes de Margarita**.
3. Navegar a **Authentication** -> **Users**.
4. Buscar el usuario del Administrador afectado por correo electrónico.
5. Hacer clic en los tres puntos (`...`) del usuario y seleccionar **View user details** o **Manage Factors**.
6. En la sección **Multi-Factor Authentication (MFA)**, hacer clic en **Unenroll** o **Delete Factor** en el factor TOTP activo.
7. El usuario podrá iniciar sesión con su correo y contraseña y realizar la inscripción de un nuevo dispositivo 2FA.

---

## 2. Procedimiento mediante SQL Editor (Consola de Administración)

Si el panel visual no muestra los factores, ingresar al **SQL Editor** del proyecto Supabase y ejecutar:

```sql
-- 1. Eliminar factores TOTP del administrador afectado
DELETE FROM auth.mfa_factors
WHERE user_id = 'ID_DEL_ADMINISTRADOR_AQUI'
  AND factor_type = 'totp';

-- 2. Invalidar códigos de recuperación anteriores
DELETE FROM public.mfa_recovery_codes
WHERE user_id = 'ID_DEL_ADMINISTRADOR_AQUI';

-- 3. Registrar auditoría de emergencia
INSERT INTO public.audit_logs (actor_id, action, target_table, target_id, details)
VALUES (
    'ID_DEL_ADMINISTRADOR_AQUI',
    'emergency_mfa_reset',
    'auth.mfa_factors',
    'ID_DEL_ADMINISTRADOR_AQUI',
    '{"reason": "Emergency MFA reset via SQL Editor by project owner"}'::jsonb
);
```

---

## 3. Garantía del Mínimo de 2 Administradores

La base de datos impone la invariante `assert_min_admins()`, asegurando que nunca exista menos de **2 administradores activos**. Si un administrador es suspendido o desactivado, la base de datos rechazará la transacción si ello deja al sistema con 1 solo administrador.
