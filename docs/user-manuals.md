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

---

## Manual del Fanático (App Multi-Equipo)

### 1. Directorio y Seguir Equipos (`/app/equipos`)
- Explore los clubes profesionales de baloncesto disponibles en la plataforma.
- Al presionar **Seguir**, se activa su billetera de perlitas para ese equipo y comenzará a recibir notificaciones de trivias y promociones.

### 2. Hub del Equipo y Selector Rápido (`/app/e/[slug]`)
- Al pulsar **Trivias** o **Tienda** en el menú de navegación, se despliega un panel con las tarjetas de los equipos que usted sigue, mostrando su saldo actual de perlitas en cada uno.
- Al seleccionar un club, ingresará al Hub oficial de ese equipo con sus pestañas dedicadas:
  - **Trivias**: Trivias clásicas y dinámicas (encuestas, over/under, pistas progresivas, etc.) exclusivas del club. Las perlitas ganadas y la racha de días consecutivos se contabilizan exclusivamente en ese equipo.
  - **Tienda**: Catálogo oficial de indumentaria, gorras, accesos VIP y saludos de jugadores. Los canjes se debitan únicamente del saldo disponible que posea en dicho club.

### 3. Equipos Inactivos
- Si un club se encuentra temporalmente inactivo, verá un banner informativo en su Hub. Durante este período no se permite jugar trivias ni realizar nuevos canjes, pero conservará intactos sus saldos históricos y pases previamente emitidos.

### 4. Mis Canjes y Pases Digitales (`/app/canjes`)
- Consulta unificada de todos sus canjes realizados en la plataforma.
- Puede filtrar por equipo mediante las pestañas superiores. Cada tarjeta muestra el escudo del club, fecha, estado de entrega y acceso directo al pase digital QR para retirar en el estadio o tienda física.

### 5. Bono Anual de Cumpleaños (`/app/cumpleanos`)
- Si es su semana de cumpleaños, podrá reclamar una tarjeta y bono de perlitas de regalo por cada equipo que siga activamente. Cada bono se abona a la billetera correspondiente al equipo que lo felicita.
