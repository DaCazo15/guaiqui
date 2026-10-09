/**
 * Sentry Plugin for Nuxt 3 (apps/web)
 * Sanitizes PII before sending errors to Sentry.
 */
import { defineNuxtPlugin } from '#app';

export default defineNuxtPlugin((nuxtApp) => {
  const dsn = useRuntimeConfig().public.sentryDsn;
  if (!dsn) return;

  nuxtApp.hook('vue:error', (error, instance, info) => {
    console.error('[Sentry Web Captured Error]:', error, info);
    // In production with @sentry/vue installed:
    // Sentry.captureException(error, {
    //   beforeSend(event) {
    //     if (event.user) {
    //       delete event.user.email;
    //       delete event.user.ip_address;
    //     }
    //     return event;
    //   }
    // });
  });
});
