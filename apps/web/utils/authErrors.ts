/**
 * Guaiqueríes de Margarita — Auth Error Translator
 *
 * Mapea mensajes y códigos de error en inglés de GoTrue / Supabase Auth
 * a mensajes claros, amigables y accesibles en español (Venezuela).
 */

export function translateAuthError(msg: string): string {
  if (!msg) return 'Ocurrió un error inesperado.'
  const lower = msg.toLowerCase()

  if (lower.includes('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.'
  }

  if (lower.includes('user already registered') || lower.includes('ya existe una cuenta registrada')) {
    return 'Ya existe una cuenta registrada con este correo. Por favor inicia sesión o utiliza otro correo.'
  }

  if (lower.includes('error sending confirmation email') || lower.includes('sending confirmation email')) {
    return 'Error al enviar el correo de confirmación. Revisa la configuración SMTP/Resend en Supabase o el límite de envíos.'
  }

  if (lower.includes('email not confirmed')) {
    return 'Tu correo aún no ha sido verificado. Revisa tu bandeja de entrada o spam.'
  }

  if (lower.includes('password should be at least')) {
    return 'La contraseña debe tener al menos 8 caracteres.'
  }

  if (lower.includes('rate limit')) {
    return 'Límite de envíos excedido. Espera unos minutos e inténtalo de nuevo.'
  }

  if (lower.includes('unsupported provider') || lower.includes('provider is not enabled')) {
    return 'El inicio de sesión con Google aún no está configurado en el servidor Supabase.'
  }

  return msg
}
