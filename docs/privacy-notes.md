# Notas de Privacidad y Cumplimiento Legal — Guaiqueríes Fan Zone

## Resumen para Asesores Legales y Equipo de Protección de Datos

En cumplimiento con los principios de minimización de datos y protección del fanático (Fase 11 - Antifraude), la plataforma de fidelización **Guaiqueríes de Margarita Fan Zone** implementa los siguientes mecanismos técnicos de seguridad y prevención de abusos:

### 1. Manejo de Identificadores de Dispositivo (`device_id`)
- **Propósito**: Prevenir ataques automatizados y creación masiva de cuentas falsas desde un mismo equipo.
- **Implementación**: Es un identificador aleatorio de formato UUID generado localmente en el navegador del usuario (`localStorage`). **No constituye una huella digital invasiva (browser fingerprinting)** ni recopila número de serie, dirección MAC o datos de hardware.
- **Retención**: Los registros de telemetría de dispositivo se eliminan de forma automatizada cada 30 días (`purge_fraud_telemetry`).

### 2. Hash de Dirección IP (`ip_hash`)
- **Propósito**: Detección de patrones anómalos de registro simultáneo respetando la arquitectura de red local (CGNAT / IPs compartidas por múltiples usuarios en Venezuela).
- **Pseudonimización**: La dirección IP en texto claro **NUNCA se almacena en la base de datos**. Se genera una función resumen criptográfica HMAC-SHA256 irreversible con secreto único.
- **Retención**: Los registros de `ip_hash` se purgan de la base de datos tras 30 días de antigüedad.

### 3. Principio de No Inculpación y Retención sin Bloqueos Automáticos
- Toda sospecha de fraude retiene temporalmente las perlitas nuevas (`status = 'held'`) para revisión manual por parte del equipo de administración.
- Ninguna acción automatizada suspende o cancela cuentas sin intervención del personal autorizado.
- La interfaz de usuario muestra únicamente mensajes neutros e informativos ("Tus perlitas se encuentran en proceso de verificación").

---
*Nota: Este documento describe la arquitectura técnica y debe ser incorporado / revisado en la Política de Privacidad oficial por el asesor jurídico del club.*
