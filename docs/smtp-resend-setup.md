# Configuración de Servidor SMTP con Resend

Esta guía detalla los pasos para configurar el servicio de correos transaccionales (confirmaciones de cuenta, restablecimiento de contraseña y notificaciones) usando **Resend** a través del protocolo SMTP en la plataforma de **Guaiqueríes de Margarita**.

---

## 1. Variables de entorno

Tanto en desarrollo local como en producción se utiliza la API Key de Resend como contraseña SMTP:

- **Host**: `smtp.resend.com`
- **Port**: `465` (SSL) o `587` (TLS)
- **User**: `resend`
- **Password**: Tu clave API de Resend (`re_...`) almacenada en la variable `SMTP_PASS` (o `RESEND_API_KEY_1`).
- **Sender Name**: `Guaiqueríes de Margarita`
- **Sender Email**: Tu dirección con dominio verificado (ej: `notificaciones@guaiqueries.com`) o `onboarding@resend.dev` (exclusivo para pruebas hacia la cuenta del propietario).

---

## 2. Verificación de Dominio en Resend (Obligatorio para Envíos a Fanáticos)

> [!WARNING]
> Si utilizas el remitente de prueba `onboarding@resend.dev`, Resend **bloqueará cualquier envío a correos que no sean el titular de la cuenta de Resend** (error HTTP 403 / SMTP rejected). Para enviar correos a cualquier fanático, debes verificar un dominio propio.

### Pasos en Resend:
1. Inicia sesión en [Resend](https://resend.com) y ve a **Domains -> Add Domain**.
2. Ingresa tu dominio o subdominio de correo (por ejemplo: `guaiqueries.com` o `mail.guaiqueries.com`) y selecciona la región (us-east-1).
3. Resend te proporcionará registros DNS que debes agregar en tu proveedor de dominio (Cloudflare, GoDaddy, Namecheap, etc.):

| Tipo | Nombre / Host | Valor / Destino | Prioridad | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **TXT** | `@` (o `mail`) | `v=spf1 include:amazonses.com ~all` | - | **SPF** (Autoriza a Resend a enviar) |
| **CNAME** | `resend._domainkey` | `feedback-smtp.us-east-1.amazonses.com` (o el valor provisto) | - | **DKIM** (Firma criptográfica) |
| **TXT** | `_dmarc` | `v=DMARC1; p=none;` | - | **DMARC** (Protección anti-phishing) |
| **MX** | `feedback` | `feedback-smtp.us-east-1.amazonses.com` | `10` | Manejo de rebotes |

4. Una vez agregados los registros, haz clic en **Verify Domain** en Resend. El estado cambiará a **Verified** (suele tardar entre 2 y 15 minutos).

---

## 3. Configuración en Supabase

### A. Entorno Local (Supabase CLI)
Configurado automáticamente en `supabase/config.toml`:
```toml
[auth.email.smtp]
enabled = true
host = "smtp.resend.com"
port = 465
user = "resend"
pass = "env(SMTP_PASS)"
admin_email = "notificaciones@tudominio.com"  # O onboarding@resend.dev en pruebas
sender_name = "Guaiqueríes de Margarita"
```
Agrega `SMTP_PASS=re_tu_api_key` en tu archivo `supabase/.env` local y reinicia los contenedores con:
```bash
supabase stop && supabase start
```

### B. Proyecto en la Nube (Hosted Supabase Dashboard)
En el panel del proyecto `mtxyracavyogxxljelvx`:
1. Ve a **Project Settings** -> **Authentication** -> sección **SMTP Settings**.
2. Activa **Enable Custom SMTP**.
3. Completa los campos:
   - **Sender email**: El correo con tu dominio verificado en Resend (ej: `hola@guaiqueries.com`).
   - **Sender name**: `Guaiqueríes de Margarita`
   - **Host**: `smtp.resend.com`
   - **Port**: `465` (o `587`)
   - **Username**: `resend`
   - **Password**: Tu API Key de Resend (`re_9VBYEzJ9_...`).
4. Haz clic en **Save Changes**.
