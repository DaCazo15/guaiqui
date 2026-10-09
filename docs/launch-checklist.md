# Checklist Pre-Lanzamiento (Contenido y Legal)

## Contenido y Medios

- [x] **Reemplazo de datos de relleno**: Todos los nombres de prueba, trivias dummy e imágenes placeholder han sido reemplazados por contenido oficial de Guaiqueríes de Margarita.
- [x] **Optimización de imágenes**: Uso de `@nuxt/image` y formatos WebP para logos, banderas y fotos de jugadores.
- [x] **Iconografía estricta**: Cumplimiento del skill `bootstrap-icons`. 0 emojis nativos en plantillas o componentes UI.

---

## Aspectos Legales y Políticas

- [x] **Políticas de Privacidad**: Documentadas en `policy_documents` con especificación explícita sobre el uso de `device_id`, `ip_hash` y analítica de producto (PostHog sin PII).
- [x] **Reglas de Perlitas**: Aprobadas legalmente. Texto que establece que las perlitas son puntos virtuales promocionales, **sin valor monetario, no canjeables por dinero real y no transferibles**.
- [x] **Política de Edad Mínima**: Decisión legal de requerir una edad mínima de **13 años** para registro autónomo de fanáticos.
- [x] **Revisión por Asesor Legal**: Documentos guardados en la tabla `policy_documents` y accesibles en `/politicas/*`.
