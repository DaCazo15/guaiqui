# Manuales del Usuario y Personal — Guaiqueríes de Margarita

## Manual del Empleado (Staff)

### 1. Cola de Canjes (`/staff/canjes`)
- Muestra la lista de premios pendientes por entrega en la arena o sede del club.
- Filtre por código de canje o nombre del fanático.

### 2. Escáner de Código QR (`/staff/escaner`)
- Permite usar la cámara del dispositivo móvil para escanear el boleto/código QR presentado por el fanático.
- En caso de fallos de la cámara, use la **Entrada Manual de Código** para ingresar la clave alfanumérica de 6-8 caracteres.
- Presione **Verificar y Entregar**. El estado del canje cambiará inmediatamente a `delivered`.

---

## Manual del Administrador (Admin)

### 1. Gestión de Trivias (`/admin/trivias`)
- Crear trivias seleccionando la fecha de vigencia, límite de tiempo por pregunta y recompensa en perlitas.
- Publicar la trivia solo cuando todas las preguntas tengan exactamente una opción marcada como correcta.

### 2. Tienda e Inventario (`/admin/tienda`)
- Crear y editar premios disponibles.
- Ajustar stock disponible. Cada modificación física queda registrada en `inventory_movements`.

### 3. Plantilla y Contenido (`/admin/plantilla`, `/admin/landing`)
- Actualizar nómina de jugadores, carrusel principal, anuncios superiores, FAQs e hitos históricos.

### 4. Analítica y Auditoría (`/admin/analitica`, `/admin/auditoria`)
- Consultar DAU/WAU/MAU, tasa de conversión de trivias, productos más canjeados e historial de auditoría de acciones administrativas.
