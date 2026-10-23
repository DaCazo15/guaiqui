---
name: bootstrap-icons
description: >-
  Enforces using Bootstrap Icons for all UI iconography and strictly prohibits the use of raw emojis in interfaces.
---

# UI Iconography Standard: Bootstrap Icons (No Emojis)

This rule establishes the standard for iconography across the entire application.

---

## 1. Prohibición Estricta de Emojis

- **NUNCA usar emojis** (ej. 🏆, 🏀, 👤, ⚙️, 🔥, 🪙, ⭐, 🫧, etc.) como iconos en la interfaz, botones, menús, estados vacíos, modales o badges.
- Los emojis varían según el sistema operativo (iOS, Android, Windows, macOS) y degradan la apariencia profesional del producto.

---

## 2. Uso Exclusivo de Bootstrap Icons

- Utilizar **Bootstrap Icons** (`bi bi-*` o sus equivalentes en componentes/SVG) para todos los elementos visuales e iconográficos:
  - Navegación y menús (`bi-house`, `bi-person`, `bi-gear`, `bi-trophy`, `bi-cart`, etc.).
  - Acciones y botones (`bi-check`, `bi-x`, `bi-pencil`, `bi-trash`, `bi-qr-code`, etc.).
  - Estados y alertas (`bi-info-circle`, `bi-check-circle`, `bi-exclamation-triangle`, `bi-x-circle`, etc.).
  - Componentes dedicados del sistema de diseño (como `PearlIcon.vue` para las perlitas en lugar del emoji 🫧).

---

## 3. Guía de Implementación en Componentes Vue

- Integrar mediante clases estándar de Bootstrap Icons o componentes SVG dedicados.
- Asegurar que los iconos tengan los tamaños y colores acordes a los tokens de diseño (ej. `w-5 h-5 text-brand-green`, etc.).
- Incluir `aria-hidden="true"` en los iconos decorativos y etiquetas accesibles para lectores de pantalla.
