# Procedimiento de Alta de Personal (Staff & Admin Bootstrap)

## Visión General
Por diseño de seguridad y privacidad, **nadie se registra como personal de staff ni administrador desde la interfaz pública**. Todos los miembros del personal (`staff_members`) se dan de alta exclusivamente mediante scripts SQL o herramientas administrativas autorizadas directamente en PostgreSQL/Supabase.

---

## Estructura de Roles de Personal (`staff_role`)
- `staff`: Personal de atención y verificación en campo (cola de canjes, escaneo QR, incidencias, consulta básica de fanáticos e inventario).
- `admin`: Personal con control total (todo lo de staff + administración de economía, productos, trivias, usuarios y auditoría).

---

## Procedimiento de Alta (Entornos de Producción y Staging)

1. **Paso 1: Registro del Usuario en Supabase Auth**
   El usuario debe registrarse previamente con su correo corporativo mediante el flujo estándar de Supabase Auth o un invitado de Auth Admin.

2. **Paso 2: Obtener el `UUID` del usuario**
   Consulte la tabla `auth.users` o `public.profiles`:
   ```sql
   SELECT id, email, display_name FROM public.profiles WHERE email = 'ejemplo.staff@guaiqueries.com';
   ```

3. **Paso 3: Asignar Rol de Staff/Admin**
   Ejecute el siguiente bloque SQL en la consola de Supabase SQL Editor o CLI:
   ```sql
   INSERT INTO public.staff_members (user_id, role, active)
   VALUES ('<UUID_DEL_USUARIO>', 'staff', true)
   ON CONFLICT (user_id) DO UPDATE 
   SET role = EXCLUDED.role, active = true;
   ```

4. **Paso 4: Verificación**
   Verifique que el usuario puede acceder al panel admin `/login` y ser redirigido a `/staff/cola`.

---

## Semillero para Desarrollo (Seed Local)
En entorno local de desarrollo, el archivo `supabase/seed.sql` genera automáticamente usuarios con rol `staff` y `admin` para pruebas con las siguientes credenciales:

- **Staff Fanaticos**: `staff@guaiqueries.com` / `Password123!`
- **Admin General**: `admin@guaiqueries.com` / `Password123!`
