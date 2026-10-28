# Procedimiento de Alta de Personal (Staff & Admin Bootstrap Multi-Equipo)

## Visión General
Por diseño de seguridad y privacidad, **nadie se registra como personal de staff ni administrador desde la interfaz pública**. Todos los miembros del personal (`staff_members`) se dan de alta exclusivamente mediante scripts SQL o herramientas administrativas autorizadas directamente en PostgreSQL/Supabase con el rol `service_role`.

A partir de la arquitectura multi-equipo de la plataforma, existen dos niveles de administración:
1. **Administrador de Plataforma (`is_platform_admin`)**: Supervisa toda la plataforma, administra equipos, políticas legales, configuración económica global y anuncios. Su registro en `staff_members` tiene `team_id IS NULL`, rol `'admin'` y requiere autenticación de dos factores estricta (`aal2`).
2. **Personal de Club (`staff` / `admin`)**: Vinculado obligatoriamente a un equipo (`team_id = '<uuid_equipo>'`). Gestiona exclusivamente el contenido, inventario, canjes y métricas de su equipo.

---

## Invariante de Seguridad (`assert_min_admins`)
El sistema garantiza en todo momento que:
- Exista **al menos 1 administrador de plataforma activo** (`role = 'admin'`, `active = true`, `team_id IS NULL`).
- Exista **al menos 1 administrador de club activo por cada equipo activo** (`teams.status = 'active'`).

Cualquier operación que intente desactivar, eliminar o degradar al último administrador de plataforma o de un club activo será rechazada por la base de datos con un error `23514`.

---

## Procedimiento para Crear el Primer Administrador de Plataforma

> [!IMPORTANT]
> **No colocar credenciales ni usuarios reales en migraciones de base de datos.** Todo bootstrapping de usuarios reales debe ejecutarse manualmente vía SQL con `service_role` o la consola administrativa.

### Paso 1: Registrar la cuenta en Supabase Auth
Cree el usuario desde el panel de Supabase Auth (Authentication > Users > Add user) o mediante un script administrativo.

### Paso 2: Configurar MFA (AAL2 Obligatorio)
Los administradores de plataforma requieren autenticación TOTP de dos factores (`aal2`). Inicie sesión con la cuenta y active el factor TOTP en `/admin/login` o en la consola de Supabase.

### Paso 3: Asignar Rol de Plataforma vía SQL
Ejecute el siguiente comando con permisos de `postgres` o `service_role`:

```sql
INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES (
    '<UUID_DE_LA_CUENTA_DE_PLATAFORMA>',
    'admin',
    NULL, -- NULL identifica explícitamente a un Administrador de Plataforma
    true
)
ON CONFLICT (user_id) DO UPDATE 
SET role = 'admin', team_id = NULL, active = true;
```

---

## Procedimiento para Asignar Administradores y Staff de Club

Para dar de alta a un empleado de club (por ejemplo, Guaiqueríes de Margarita con ID `a0000000-0000-0000-0000-000000000001`):

```sql
-- Administrador de Club
INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES (
    '<UUID_DE_LA_CUENTA_DE_CLUB>',
    'admin',
    'a0000000-0000-0000-0000-000000000001', -- UUID del equipo
    true
)
ON CONFLICT (user_id) DO UPDATE 
SET role = 'admin', team_id = EXCLUDED.team_id, active = true;

-- Personal de Taquilla / Staff de Campo
INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES (
    '<UUID_DE_LA_CUENTA_DE_STAFF>',
    'staff',
    'a0000000-0000-0000-0000-000000000001',
    true
)
ON CONFLICT (user_id) DO UPDATE 
SET role = 'staff', team_id = EXCLUDED.team_id, active = true;
```

---

## Plan de Transición de Cuentas Existentes
1. La cuenta de administración actual queda asignada como **Administrador del Equipo #1 (Guaiqueríes de Margarita)** (`team_id = 'a0000000-0000-0000-0000-000000000001'`).
2. Se crea una cuenta independiente exclusiva para **Administración de Plataforma** (`team_id IS NULL`), cumpliendo con la separación de responsabilidades y el invariante `assert_min_admins`.

