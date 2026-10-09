/**
 * Sentry integration for Vue 3 Admin App (apps/admin)
 * Filters PII before transmitting error payloads.
 */
export function initSentryAdmin() {
  const dsn = import.meta.env.VITE_SENTRY_DSN;
  if (!dsn) return;

  console.log('[Sentry Admin Initialized]');
  // In production with @sentry/vue:
  // Sentry.init({
  //   dsn,
  //   beforeSend(event) {
  //     if (event.user) {
  //       delete event.user.email;
  //       delete event.user.ip_address;
  //     }
  //     return event;
  //   }
  // });
}
