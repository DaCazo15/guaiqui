# Pasos de Configuración Manual en Google Ad Manager (GAM) — Anuncios Recompensados

## 1. Crear la Red y Verificar Identidad
1. Acceder a [Google Ad Manager](https://admanager.google.com/).
2. Si es una cuenta nueva, completar la verificación de identidad de la entidad corporativa/deportiva.
3. Configurar la moneda principal de la red (USD) y la zona horaria (`America/Caracas` o UTC).

## 2. Crear la Unidad de Anuncio Recompensada (Ad Unit)
1. Ir a **Inventario > Unidades de anuncios > Nueva unidad de anuncios**.
2. **Nombre**: `FanZone_Web_Rewarded_1`
3. **Código de unidad**: `web_rewarded_1`
4. **Tamaño de anuncio**: Seleccionar **Vídeo out-of-page o anuncio recompensado de web (1x1v / OutOfPageFormat.REWARDED)**.
5. Guardar la unidad de anuncios y copiar el código completo del bloque (ej. `/21775744923/web_rewarded_1`).
6. Configurar la variable pública de entorno en Vercel/Nuxt:
   `NUXT_PUBLIC_GAM_AD_UNIT_PATH=/21775744923/web_rewarded_1`

## 3. Configurar Elementos de Línea (Line Items)
1. **Reservas Directas / Patrocinios**:
   - Crear un nuevo pedido en **Entrega > Pedidos**.
   - Añadir un elemento de línea con tipo "Vídeo o audio" o "Reserva".
   - Tamaño del elemento de línea: `1x1v`.
   - Orientación (Targeting): Seleccionar la unidad de anuncios recompensada creada en el paso 2.
2. **Ad Exchange / AdSense (Red de Demanda)**:
   - En **Entrega > Elementos de línea**, crear un elemento de línea tipo **Ad Exchange** o **Display (Estándar)** 1x1.
   - Habilitar el formato de anuncio recompensado (Rewarded Video / Web Rewarded).

## 4. Desactivar Protección In-stream estricta
1. Ir a **Protecciones > Reglas de inventario**.
2. Desactivar la protección **"Block non-instream video ads"** si la unidad de anuncio web reporta bloqueo en reproductor fuera de flujo (out-of-page).

## 5. Configurar Protecciones de Contenido y Categorías Sensibles
1. Ir a **Protecciones > Nueva protección > Contenido de anuncios**.
2. **Bloquear Categorías Sensibles**:
   - Apuestas y juegos de azar (Gambling).
   - Bebidas alcohólicas y tabaco.
   - Contenido para adultos / citas.
   - Farmacéuticos y productos milagro.
   - Política y religión.
3. **Bloqueo de Anunciantes Concretos**: Bloquear competidores directos o marcas no alineadas con los valores del equipo.
4. **Nota de Cumplimiento**: Google Ad Manager permite la exclusión de categorías sensibles, pero la publicidad *"100% únicamente deportiva"* solo queda estrictamente garantizada mediante anunciantes deportivos vendidos de forma directa a través de pedidos de reserva.

## 6. Configurar el Archivo `ads.txt`
1. Descargar la línea de vendedor proporcionada por Google Ad Manager en **Administración > Gestión de sitios > ads.txt**.
2. Copiar la línea generada (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`).
3. Reemplazar el marcador en el archivo `apps/web/public/ads.txt`.

## 7. Exportación Diaria para Conciliación y Prevención de Fraude
1. Ir a **Informes > Informes > Crear nuevo informe**.
2. **Filtro**: Unidad de anuncios = `FanZone_Web_Rewarded_1`.
3. **Métricas**: Impresiones de vídeos recompensados (Rewarded slot impressions).
4. **Frecuencia**: Informe diario exportado a medianoche.
5. Ingresar manualmente la cifra diaria de impresiones en el panel `/admin/anuncios-recompensados` para ejecutar el algoritmo de conciliación en servidor.
