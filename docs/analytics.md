# Guía de Analítica y Registro de Eventos (GA4 & PostHog)

Este documento especifica la arquitectura de la capa de analítica, el inventario de eventos y la guía de configuración manual en **Google Analytics 4 (GA4)**.

> [!IMPORTANT]
> **REGLA DE PRIVACIDAD ABSOLUTA**: Queda estrictamente prohibido enviar información de identificación personal (PII) como correo electrónico, nombres, fechas de nacimiento, saldos o municipios en los identificadores de usuario (`user_id`), dimensiones personalizadas o propiedades de eventos. El `user_id` contiene exclusivamente el UUID anónimo interno generado por Supabase y solo se transmite bajo consentimiento explícito del fanático.

---

## 1. Configuración General

- **Medición de GA4**: Se configura con la variable pública `NUXT_PUBLIC_GA_MEASUREMENT_ID` (Formato: `G-XXXXXXXXXX`). *(Nota: Los ID de medición web de GA4 son identificadores públicos de flujo, no secretos)*.
- **Despachador Unificado**: El composable `useAnalytics()` despacha eventos a GA4 y PostHog simultáneamente si están configurados y el usuario ha otorgado su consentimiento en la categoría "Analítica".
- **Desactivación de Rastreo**: Se deshabilitan explícitamente las señales de Google (`allow_google_signals: false`) y la personalización de anuncios (`allow_ad_personalization_signals: false`).

---

## 2. Inventario de Eventos

Todos los nombres de eventos siguen la convención `snake_case` con un máximo de 40 caracteres y hasta 25 parámetros.

### 2.1. Navegación e Interacción General
| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `page_view` | Cambio de ruta en SPA (rutas normalizadas, ej: `/app/canjes/:id`) | `page_path` |
| `ui_click` | Clic en elementos de interfaz con la directiva `v-track` | `section`, `element_id`, `destination` |
| `cta_click` | Clic en llamadas a la acción destacadas | `section`, `element_id`, `destination` |

### 2.2. Registro y Autenticación
| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `signup_started` | Inicio del proceso de registro | `method` |
| `signup_completed` | Registro completado exitosamente *(Evento clave)* | `method` |
| `email_verified` | Verificación de correo confirmada | `user_id` |

### 2.3. Juegos y Canjes
| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `trivia_started` | Inicio de una trivia | `trivia_id` |
| `trivia_completed` | Trivia finalizada *(Evento clave)* | `trivia_id`, `score`, `perfect_score` |
| `redemption_created` | Canje de producto realizado *(Evento clave)* | `product_id`, `pearl_cost` |

### 2.4. Notificaciones Push (Fase 8B)
| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `push_permission_requested` | Solicitud de permiso de notificaciones push | `prompt_trigger` |
| `push_permission_granted` | Permiso de notificaciones concedido | - |
| `push_permission_denied` | Permiso de notificaciones rechazado | - |

### 2.5. Modal Carrusel de Bienvenida (Fase 16)
| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `login_modal_viewed` | Modal de bienvenida mostrado al fanático | - |
| `login_modal_slide_viewed` | Diapositiva vista en el carrusel | `position`, `title` |
| `login_modal_cta_clicked` | Clic en el botón principal de la diapositiva | `position`, `cta_url` |
| `login_modal_closed` | Modal cerrado por el usuario | - |

### 2.6. Anuncios Recompensados / Sponsors (Fase 18)
*Nota de diseño: Para evitar los nombres de eventos reservados de GA4 (`ad_click`, `ad_impression`, etc.), los eventos de anuncios recompensados usan la nomenclatura oficial `rewarded_ad_*`:*

| Nombre del Evento | Descripción | Parámetros Permitidos |
| :--- | :--- | :--- |
| `rewarded_ad_requested` | Solicitud de carga de video publicitario | `ad_id` |
| `rewarded_ad_ready` | Video listo para reproducirse | `ad_id` |
| `rewarded_ad_opted_in` | El usuario aceptó ver el video por perlitas | `ad_id` |
| `rewarded_ad_granted` | Video completado y recompensa otorgada *(Evento clave)* | `ad_id`, `reward_pearls` |
| `rewarded_ad_closed_early` | Usuario cerró el video antes de finalizar | `ad_id`, `watched_seconds` |
| `rewarded_ad_no_fill` | No hay anuncios disponibles | `ad_id` |
| `rewarded_ad_daily_limit_reached` | Se alcanzó el límite máximo diario de anuncios | `ad_id` |

---

## 3. Pasos Manuales de Configuración en GA4

1. **Crear Propiedad y Flujo de Datos Web**:
   - En la consola de Google Analytics, crear una propiedad para **Guaiqueríes Fan Zone**.
   - Crear un **Flujo de datos Web** y copiar el **ID de medición** (`G-XXXXXXXXXX`).
2. **Ajuste de Retención de Datos**:
   - Ir a *Administración -> Ajustes de datos -> Retención de datos*.
   - Cambiar la retención de datos de eventos a **14 meses**.
3. **Desactivar Señales de Google**:
   - En *Administración -> Ajustes de datos -> Recogida de datos*, deshabilitar **Google signals**.
4. **Registrar Dimensiones Personalizadas**:
   - Ir a *Administración -> Definiciones personalizadas -> Crear dimensiones personalizadas*:
     - `section` (Ámbito de evento)
     - `element_id` (Ámbito de evento)
     - `ad_id` (Ámbito de evento)
     - `slide_position` (Ámbito de evento)
5. **Marcar Eventos Clave (Conversiones)**:
   - Ir a *Administración -> Eventos -> Marcar como evento clave*:
     - `signup_completed`
     - `trivia_completed`
     - `redemption_created`
     - `rewarded_ad_granted`
6. **Verificación**:
   - Usar `DebugView` en GA4 para verificar el tráfico en tiempo real y conectar a **Looker Studio** para paneles visuales.
