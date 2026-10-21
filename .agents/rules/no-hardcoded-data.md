# Regla: Prohibición Estricta de Datos Hardcodeados y Seeds Ficticios

1. **Cero Mocks y Datos Ficticios en Frontend**:
   - Queda terminantemente prohibido utilizar datos estáticos, nombres de usuarios ficticios (e.g., "Carlos R.", "María G."), puntajes inventados, productos simulados o fechas inventadas en los componentes o vistas.
   - Toda la información mostrada al usuario DEBE ser real, reactiva y cargada de forma asíncrona desde Supabase o desde los datos oficiales de Sofascore.
   - Si no hay datos suficientes (por ejemplo, menos de 3 usuarios en el podio), la interfaz debe renderizar exclusivamente los usuarios reales existentes, o estados vacíos/abiertos limpios ("Disponible", "¡Sé el primero en puntuar!"). Nunca rellenar con nombres falsos.
   - La racha de días (`streak`) debe provenir estrictamente del valor de la base de datos (`streak_days`, `already_awarded_today`), jamás inferirse o completarse con el día de la semana (`getDay()`).

2. **Prohibición de Seeds Ficticios**:
   - No crear archivos ni migraciones con "seeds" de datos ficticios o usuarios inventados.
   - Los únicos datos sembrados permitidos son configuraciones del sistema, parámetros de economía de perlitas, o sincronizaciones oficiales de fuentes maestras verificadas (como Sofascore para la plantilla de jugadores y partidos oficiales).
