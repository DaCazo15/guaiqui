-- Migration: 20261010000035_fase17_privacy_policy_ga4.sql
-- Description: Privacy Policy update (v1.1) detailing Google Analytics 4 integration, cookie consent, PII prohibition, and opt-out mechanisms.

-- Deactivate previous active version of privacidad
UPDATE public.policy_documents
SET is_active = false, updated_at = NOW()
WHERE slug = 'privacidad' AND is_active = true;

-- Insert new active version v1.1
INSERT INTO public.policy_documents (slug, version, content_markdown, is_active)
VALUES (
  'privacidad',
  'v1.1',
  '# Política de Privacidad y Uso de Analítica (v1.1)

Nos tomamos muy en serio la protección de tus datos personales. 

## 1. Recolección de Datos y Analítica
Utilizamos **Google Analytics 4 (GA4)** y **PostHog** de forma anónima únicamente cuando otorgas tu consentimiento explícito a través del banner de privacidad de nuestra Fan Zone.

### 2. Lo que Medimos (Sin Datos Personales)
- Interacciones de navegación e inicio de sesión.
- Participación en trivias y canjes en la tienda oficial.
- Rendimiento y clics en elementos de la plataforma.

### 3. Lo que NUNCA Recolectamos ni Enviamos
- Tu dirección de correo electrónico, nombre, fecha de nacimiento o municipio.
- Tu saldo de perlitas o información financiera.
- Ninguna información personal identificable (PII).

### 4. Cómo Retirar tu Consentimiento
Puedes modificar o retirar tu consentimiento en cualquier momento haciendo clic en **"Configuración de Cookies"** en el pie de página de la aplicación web o desde la sección de **Ajustes**. Al rechazar la analítica, se detendrá el envío de eventos y se eliminarán automáticamente las cookies asociadas a Google Analytics (`_ga`).',
  true
)
ON CONFLICT (slug, version) DO UPDATE 
SET content_markdown = EXCLUDED.content_markdown, is_active = true, updated_at = NOW();
