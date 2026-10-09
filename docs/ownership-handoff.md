# Checklist de Transferencia de Titularidad y Tabla de Costos

## Checklist de Cuentas y Custodia

- [ ] **Dominio y DNS**: Transferencia o delegación de registrador DNS a Cloudflare / Proveedor del cliente.
- [ ] **Vercel**: Transferencia de los dos proyectos (`guaiqui-web` y `guaiqui-admin`) a la cuenta de equipo del cliente.
- [ ] **Supabase**: Invitación del cliente como `Owner` de la organización Supabase en Producción y Staging.
- [ ] **GitHub**: Transferencia de la propiedad del repositorio `DaCazo15/guaiqui` a la organización GitHub del cliente.
- [ ] **Resend (Email SMTP)**: Verificación de los registros SPF, DKIM y DMARC en el DNS del cliente y entrega de API Keys.
- [ ] **Sentry**: Adición del cliente como administrador del proyecto en Sentry.io.
- [ ] **PostHog**: Transferencia de la propiedad del espacio de trabajo.
- [ ] **Google Cloud Platform**: Entrega de credenciales OAuth Client ID / Secret para Login de Google.
- [ ] **Custodia de Claves VAPID y Turnstile**: Archivo seguro de claves en gestor de contraseñas de la directiva.

---

## Tabla de Costos Mensuales Estimados por Servicio

| Servicio | Plan Recomendado | Uso Estimado | Costo Estimado (USD/mes) |
|---|---|---|---|
| **Supabase** | Pro Plan | Base de Datos, Auth, Storage, PITR, Daily Cron | \$25.00 |
| **Vercel** | Pro Plan (Equipo) | Alojamiento Frontend + Preview Deployments | \$20.00 / miembro |
| **Resend** | Pro / Starter | Transaccionales (Confirmación, Canjes) | \$0 - \$20.00 |
| **Sentry** | Developer / Team | Error Tracking y Performance Monitoring | \$0 - \$26.00 |
| **PostHog** | Hobby / Scale | Analítica de Producto sin PII | \$0 (Free Tier) |
| **Cloudflare** | Free Tier | DNS, SSL y Turnstile Captcha | \$0.00 |
| **Dominio `.com`** | Anual | Registrador DNS | \$12 - \$15 / año |
| **TOTAL ESTIMADO** | | | **~\$45 - \$90 USD / mes** |
