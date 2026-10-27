# Plan de Lanzamiento (Launch Plan) — Guaiqueríes de Margarita

**Última actualización**: 2026-10-27 (Post-Hardening Fase 19)

---

## 1. Alcance y Filosofía del Producto

Plataforma oficial de fidelización para los fanáticos de **Guaiqueríes de Margarita**.
- **Sin dinero real**: No hay pasarelas de pago, no hay apuestas, ni venta de entradas con dinero fiat. Las **perlitas** son puntos de fidelización 100% gratuitos y promocionales.
- **Seguridad y Confianza**: Ledger inmutable append-only (`ledger_entries`), funciones transaccionales atómicas en servidor, RLS estricto y protección anti-bots mediante Cloudflare Turnstile.
- **Sin datos ficticios**: Toda la información mostrada es asíncrona, reactiva y real de la plantilla, partidos y tienda.

---

## 2. Fases de Despliegue

### Fase 1: Beta Cerrada (20 Fanáticos + 5 Staff)
- **Duración estimada**: 3 a 5 días.
- **Participantes**:
  - 20 fanáticos seleccionados del club oficial de aficionados.
  - 5 miembros de directiva y logística de cancha (roles `staff` y `admin`).
- **Objetivos de Prueba**:
  1. Flujo completo de registro / login con verificación de correo o Google OAuth.
  2. Participación en retos interactivos: trivias contrarreloj, retos ¿Quién es? (silueta/dorsal), encuestas de partido y predicciones Over/Under.
  3. Validación de saldo en billetera (`wallets` en sincronía con `ledger_entries`).
  4. Flujo de canje en tienda: generación de QR de canje.
  5. Entrega física en gimnasio (La Choza): escaneo de QR por el personal con rol `staff`, verificación atómica y entrega (`claim_redemption_with_staff_qr`).
  6. Resiliencia de red y modo offline básico de la PWA.

### Fase 2: Criterios Estrictos de Aprobación (Gates para Apertura Pública)
1. **0 Alertas Críticas en `system_alerts`**:
   - Sin descalces de saldo entre `wallets.balance_cached` y la suma de `ledger_entries`.
   - Sin errores de concurrencia o doble gasto de perlitas.
2. **Latencia y Rendimiento**:
   - $P_{95} < 250$ms en llamadas a Edge Functions y RPCs de Supabase.
   - Puntuación Lighthouse Mobile > 90 en Performance, Accesibilidad y SEO en `apps/web`.
3. **Auditoría de Dependencias y Código**:
   - 0 vulnerabilidades críticas o altas en dependencias de producción (`pnpm run audit:ci`).
   - 0 fallos en suite de pruebas unitarias (152/152 pruebas pasadas).
   - 0 errores en compilación TypeScript (`pnpm typecheck`).
4. **Verificación de Staff en Cancha**:
   - 100% de canjes de prueba validados mediante escáner QR de staff sin incidencias.

### Fase 3: Apertura Pública y Difusión Oficial
- Anuncio oficial en canales de comunicación y redes de Guaiqueríes (`@guaiqueries_bbc`).
- Habilitación del registro público general en `guaiqueris.com`.
- Monitoreo activo durante el primer partido en vivo en el Gimnasio Ciudad de La Asunción.

---

## 3. Matriz de Monitoreo y Contingencia

| Indicador / Evento | Umbral de Alerta | Acción Inmediata |
| :--- | :--- | :--- |
| Desbalance en `reconcile_wallets` | > 0 filas desincronizadas | Congelar canjes temporalmente vía feature flag e investigar ledger |
| Falla en Turnstile Captcha | > 5% tokens rechazados | Verificar claves de Cloudflare en Dashboard y status de API |
| Pico de tráfico en partido en vivo | > 500 req/s | Auto-scale Supabase compute y revalidar cache CDN en Nuxt |
| Error en escáner QR | Canje no encontrado | Verificar rol de staff y conexión de red en sede |
