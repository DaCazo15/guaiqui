<script setup lang="ts">
import { ref } from 'vue'
import {
  BaseButton,
  BaseInput,
  BaseSelect,
  BaseCheckbox,
  BaseCard,
  BaseBadge,
  BaseModal,
  BaseToast,
  BaseTabs,
  BaseAccordion,
  BaseTable,
  EmptyState,
  Skeleton,
  PearlIcon,
  PearlAmount,
  type TabItem,
  type AccordionItem,
  type TableColumn,
  type ToastType,
} from '@guaiqui/ui'

// Head meta
useHead({
  title: 'Guía de Estilos & Design Tokens — Guaiqueríes de Margarita',
  meta: [
    { name: 'description', content: 'Sistema de diseño y catálogo interactivo de componentes UI' },
  ],
})

// State for interactive components
const buttonLoading = ref(false)
const inputValue = ref('fanatico@guaiqueries.com')
const selectValue = ref('nueva_esparta')
const checkboxValue = ref(true)

const isModalOpen = ref(false)

const activeTab = ref('general')
const mainTabs: TabItem[] = [
  { id: 'general', label: 'General & Tokens' },
  { id: 'components', label: 'Componentes UI', badge: 15 },
  { id: 'accessibility', label: 'Accesibilidad' },
]

// Accordion data
const accordionItems: AccordionItem[] = [
  {
    id: '1',
    title: '¿Cómo se ganan las Perlitas?',
    content: 'Las perlitas se acumulan respondiendo trivias correctamente, completando desafíos y manteniendo rachas diarias de visitas a la plataforma.',
  },
  {
    id: '2',
    title: '¿Se pueden comprar Perlitas con dinero real?',
    content: 'No. La economía de la plataforma es 100% gratuita y basada en mérito/fidelización. No hay micropagos ni compras de boletos con dinero real.',
  },
  {
    id: '3',
    title: '¿Dónde retiro mis premios canjeados?',
    content: 'Los premios físicos y entradas a entrenamientos se escanean y retiran en el Gimnasio Ciudad de La Asunción mostrando el código QR de canje al staff.',
  },
]

// Select options
const stateOptions = [
  { label: 'Nueva Esparta', value: 'nueva_esparta' },
  { label: 'Distrito Capital', value: 'distrito_capital' },
  { label: 'Anzoátegui', value: 'anzoategui' },
]

// Table data
const tableColumns: TableColumn[] = [
  { key: 'fan', label: 'Fanático' },
  { key: 'level', label: 'Nivel' },
  { key: 'perlitas', label: 'Saldo Perlitas', align: 'right' },
  { key: 'status', label: 'Estado', align: 'center' },
]

const tableData = [
  { fan: 'Carlos Mendoza', level: 'Capitán VIP', perlitas: 12500, status: 'Activo' },
  { fan: 'María Rodríguez', level: 'Super Fan', perlitas: 8400, status: 'Activo' },
  { fan: 'José Luis Marcano', level: 'Iniciante', perlitas: 450, status: 'Pendiente' },
  { fan: 'Elena Salazar', level: 'Tribuna Verde', perlitas: 3200, status: 'Activo' },
]

// Toasts management
interface ToastItem {
  id: number
  type: ToastType
  title: string
  message: string
}
const toasts = ref<ToastItem[]>([])
let toastIdCounter = 1

const triggerToast = (type: ToastType) => {
  const titles = {
    info: 'Información del Juego',
    success: '¡Perlitas Abonadas!',
    warning: 'Tiempo Límite',
    danger: 'Error de Conexión',
  }
  const messages = {
    info: 'La próxima trivia abre hoy a las 7:00 PM.',
    success: 'Has ganado +150 perlitas por responder correctamente.',
    warning: 'Te quedan 10 segundos para enviar tu respuesta.',
    danger: 'No se pudo conectar con el servidor. Reintenta.',
  }

  const newToast: ToastItem = {
    id: toastIdCounter++,
    type,
    title: titles[type],
    message: messages[type],
  }
  toasts.value.push(newToast)
}

const removeToast = (id: number) => {
  toasts.value = toasts.value.filter((t) => t.id !== id)
}

const toggleButtonLoading = () => {
  buttonLoading.value = true
  setTimeout(() => {
    buttonLoading.value = false
  }, 2000)
}
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text font-body pb-20">
    <!-- Header Showcase -->
    <header class="bg-gradient-to-r from-guaiqui-primary-dark via-guaiqui-primary to-emerald-950 text-white py-12 px-4 sm:px-8 border-b-4 border-guaiqui-accent shadow-guaiqui-md">
      <div class="max-w-6xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <div class="flex items-center gap-2 mb-2">
            <BaseBadge variant="accent" size="sm">Fase 2</BaseBadge>
            <span class="text-xs uppercase tracking-widest font-semibold text-emerald-200">Design System</span>
          </div>
          <h1 class="font-display font-extrabold text-4xl sm:text-5xl tracking-tight uppercase">
            Guaiqueríes de Margarita
          </h1>
          <p class="text-emerald-100 text-sm sm:text-base mt-2 max-w-xl">
            Catálogo de componentes UI, design tokens y reglas visuales para la plataforma de fidelización.
          </p>
        </div>

        <div class="flex items-center gap-3 bg-white/10 backdrop-blur-md p-4 rounded-guaiqui-lg border border-white/20">
          <PearlIcon size="xl" animated />
          <div>
            <div class="text-xs font-semibold uppercase tracking-wider text-emerald-200">Moneda Virtual</div>
            <div class="font-display text-2xl font-bold text-white">Perlitas</div>
          </div>
        </div>
      </div>
    </header>

    <!-- Navigation Tabs -->
    <div class="max-w-6xl mx-auto px-4 sm:px-8 mt-8">
      <BaseTabs v-model="activeTab" :tabs="mainTabs" full-width />
    </div>

    <!-- Main Content Area -->
    <main class="max-w-6xl mx-auto px-4 sm:px-8 mt-8 space-y-12">
      <!-- SECTION 1: DESIGN TOKENS -->
      <section v-if="activeTab === 'general' || activeTab === 'all'" class="space-y-8">
        <div>
          <h2 class="font-display font-bold text-2xl text-guaiqui-text uppercase tracking-tight mb-1">
            Design Tokens & Variables CSS
          </h2>
          <p class="text-sm text-guaiqui-text-muted">
            Paleta de colores oficial con contraste verificado AA, fuentes Barlow y radios de borde del branding.
          </p>
        </div>

        <!-- Color Palette Grid -->
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
          <!-- Primary -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-primary text-white shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Primary</div>
            <div class="text-xs opacity-90 font-mono">#0B7A3B</div>
            <div class="text-xs mt-2">Verde Principal</div>
          </div>

          <!-- Primary Dark -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-primary-dark text-white shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Primary Dark</div>
            <div class="text-xs opacity-90 font-mono">#064E27</div>
            <div class="text-xs mt-2">Verde Oscuro</div>
          </div>

          <!-- Primary Soft -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-primary-soft text-guaiqui-primary-dark border border-green-200 shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Primary Soft</div>
            <div class="text-xs opacity-90 font-mono">#E7F5EC</div>
            <div class="text-xs mt-2">Fondo Suave</div>
          </div>

          <!-- Accent -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-accent text-white shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Accent (Bandana)</div>
            <div class="text-xs opacity-90 font-mono">#C8102E</div>
            <div class="text-xs mt-2">Rojo Moderado</div>
          </div>

          <!-- Surface -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-surface text-guaiqui-text border border-guaiqui-border shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Surface</div>
            <div class="text-xs text-guaiqui-text-muted font-mono">#F7F8F7</div>
            <div class="text-xs mt-2">Superficies Tarjetas</div>
          </div>

          <!-- Text -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-text text-white shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Text Dark</div>
            <div class="text-xs opacity-90 font-mono">#111827</div>
            <div class="text-xs mt-2">Texto Principal</div>
          </div>

          <!-- Text Muted -->
          <div class="p-4 rounded-guaiqui-lg bg-guaiqui-text-muted text-white shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Text Muted</div>
            <div class="text-xs opacity-90 font-mono">#4B5563</div>
            <div class="text-xs mt-2">Texto Secundario</div>
          </div>

          <!-- Perlita Gold -->
          <div class="p-4 rounded-guaiqui-lg bg-amber-500 text-amber-950 shadow-guaiqui-sm">
            <div class="font-display font-bold text-lg">Perlita Gold</div>
            <div class="text-xs opacity-90 font-mono">#F59E0B</div>
            <div class="text-xs mt-2">Moneda de Canje</div>
          </div>
        </div>

        <!-- Typography Section -->
        <BaseCard header="Tipografía Oficial (Barlow & Barlow Condensed)">
          <div class="space-y-4">
            <div>
              <div class="text-xs uppercase font-bold text-guaiqui-text-muted mb-1">Titulares — Barlow Condensed</div>
              <h1 class="font-display font-extrabold text-3xl sm:text-4xl uppercase text-guaiqui-text">
                GUAIQUERÍES DE MARGARITA 80 AÑOS DE HISTORIA
              </h1>
            </div>

            <div class="border-t border-guaiqui-border pt-4">
              <div class="text-xs uppercase font-bold text-guaiqui-text-muted mb-1">Cuerpo — Barlow</div>
              <p class="text-base text-guaiqui-text leading-relaxed">
                Los fanáticos acumulan <strong>perlitas</strong> participando en trivias exclusivas de cada partido.
                Las cifras utilizan la clase <code class="bg-gray-100 px-1 py-0.5 rounded font-mono text-xs text-guaiqui-accent">tabular-nums</code> para una alineación numérica perfecta:
              </p>
              <div class="mt-2 text-2xl font-bold font-display tabular-nums text-guaiqui-primary">
                12.500 PERLITAS | 98.4% EFECTIVIDAD TRIVIAS
              </div>
            </div>
          </div>
        </BaseCard>
      </section>

      <!-- SECTION 2: COMPONENTS SHOWCASE -->
      <section v-if="activeTab === 'components' || activeTab === 'general'" class="space-y-12">
        <div>
          <h2 class="font-display font-bold text-2xl text-guaiqui-text uppercase tracking-tight mb-1">
            Catálogo de Componentes UI (`packages/ui`)
          </h2>
          <p class="text-sm text-guaiqui-text-muted">
            Componentes modulares de presentación. Prohibidos los colores hardcodeados; todos usan tokens.
          </p>
        </div>

        <!-- Buttons Section -->
        <BaseCard header="1. BaseButton (Variantes, Tamaños y Carga)">
          <div class="space-y-6">
            <div>
              <div class="text-xs font-bold uppercase text-guaiqui-text-muted mb-3">Variantes principales</div>
              <div class="flex flex-wrap gap-3">
                <BaseButton variant="primary">Primario Verde</BaseButton>
                <BaseButton variant="secondary">Secundario</BaseButton>
                <BaseButton variant="ghost">Fantasma</BaseButton>
                <BaseButton variant="danger">Peligro / Acción</BaseButton>
              </div>
            </div>

            <div class="border-t border-guaiqui-border pt-4">
              <div class="text-xs font-bold uppercase text-guaiqui-text-muted mb-3">Tamaños y Estados</div>
              <div class="flex flex-wrap items-center gap-3">
                <BaseButton size="sm">Pequeño (sm)</BaseButton>
                <BaseButton size="md">Mediano (md)</BaseButton>
                <BaseButton size="lg">Grande (lg)</BaseButton>
                <BaseButton :loading="buttonLoading" @click="toggleButtonLoading">
                  {{ buttonLoading ? 'Procesando...' : 'Probar Carga' }}
                </BaseButton>
                <BaseButton disabled>Deshabilitado</BaseButton>
              </div>
            </div>
          </div>
        </BaseCard>

        <!-- Inputs, Selects & Checkbox -->
        <BaseCard header="2. Formularios (BaseInput, BaseSelect & BaseCheckbox)">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <BaseInput
              v-model="inputValue"
              label="Correo Electrónico"
              hint="Recibirás notificaciones de trivias aquí."
              required
            />

            <BaseInput
              label="Código de Canje"
              model-value="QR-INVALIDO-99"
              error="El código ingresado ya venció o no existe."
            />

            <BaseSelect
              v-model="selectValue"
              label="Estado de Residencia"
              :options="stateOptions"
              hint="Para asignarte al segmento de fanáticos regional."
            />

            <div class="space-y-3 pt-2">
              <div class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text">Preferencias</div>
              <BaseCheckbox
                v-model="checkboxValue"
                label="Deseo recibir alertas de trivias antes de cada partido"
                hint="Notificación 15 minutos antes del salto entre dos."
              />
              <BaseCheckbox
                :model-value="false"
                label="Acepto recibir correos con promociones de patrocinadores"
                disabled
              />
            </div>
          </div>
        </BaseCard>

        <!-- Badges & Perlitas Showcase -->
        <BaseCard header="3. BaseBadge & PearlAmount (Economía de Perlitas)">
          <div class="space-y-6">
            <div>
              <div class="text-xs font-bold uppercase text-guaiqui-text-muted mb-3">Variantes de Badges</div>
              <div class="flex flex-wrap gap-2">
                <BaseBadge variant="primary">Primario</BaseBadge>
                <BaseBadge variant="accent">Bandana Rojo</BaseBadge>
                <BaseBadge variant="success" dot>Entregado</BaseBadge>
                <BaseBadge variant="warning" dot>En Cola</BaseBadge>
                <BaseBadge variant="danger" dot>Cancelado</BaseBadge>
                <BaseBadge variant="info">Staff</BaseBadge>
                <BaseBadge variant="soft">Suave</BaseBadge>
                <BaseBadge variant="perlita">Perlitas</BaseBadge>
              </div>
            </div>

            <div class="border-t border-guaiqui-border pt-4">
              <div class="text-xs font-bold uppercase text-guaiqui-text-muted mb-3">Formateador de Perlitas (PearlAmount + PearlIcon SVG)</div>
              <div class="flex flex-wrap items-baseline gap-6 bg-amber-50/50 p-4 rounded-guaiqui-lg border border-amber-200">
                <PearlAmount :amount="50" size="sm" show-label />
                <PearlAmount :amount="1250" size="md" show-label />
                <PearlAmount :amount="15000" size="lg" show-label />
                <PearlAmount :amount="250000" size="xl" show-label />
              </div>
            </div>
          </div>
        </BaseCard>

        <!-- Cards, Accordion & Tabs -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <BaseCard header="4. BaseCard (Variantes de Contenedor)">
            <template #header>Variantes de Tarjeta</template>
            <div class="space-y-3 text-sm">
              <BaseCard variant="flat" padding="sm">
                <strong>Variante Flat:</strong> Superficie gris suave sin sombra.
              </BaseCard>

              <BaseCard variant="outline" padding="sm">
                <strong>Variante Outline:</strong> Borde simple sutil.
              </BaseCard>

              <BaseCard variant="interactive" padding="sm">
                <strong>Variante Interactive:</strong> Pasa el cursor sobre mí para ver la sombra y el borde verde.
              </BaseCard>
            </div>
          </BaseCard>

          <BaseCard header="5. BaseAccordion (Preguntas Frecuentes)">
            <BaseAccordion :items="accordionItems" default-open-id="1" />
          </BaseCard>
        </div>

        <!-- Table Showcase -->
        <BaseCard header="6. BaseTable (Tabla Adaptativa para Admin/Staff)">
          <BaseTable :columns="tableColumns" :data="tableData">
            <template #cell-perlitas="{ value }">
              <PearlAmount :amount="value" size="sm" />
            </template>
            <template #cell-status="{ value }">
              <BaseBadge :variant="value === 'Activo' ? 'success' : 'warning'" dot size="sm">
                {{ value }}
              </BaseBadge>
            </template>
          </BaseTable>
        </BaseCard>

        <!-- EmptyState & Skeleton -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <BaseCard header="7. EmptyState">
            <EmptyState
              title="No hay canjes en esta categoría"
              message="Actualmente no tienes premios solicitados o en proceso de entrega."
            >
              <template #action>
                <BaseButton variant="primary" size="sm">Ir a la Tienda de Canje</BaseButton>
              </template>
            </EmptyState>
          </BaseCard>

          <BaseCard header="8. Skeleton Placeholder">
            <div class="space-y-4">
              <div class="flex items-center gap-3">
                <Skeleton variant="circular" />
                <div class="space-y-2 flex-1">
                  <Skeleton variant="text" width="60%" />
                  <Skeleton variant="text" width="40%" />
                </div>
              </div>
              <Skeleton variant="rectangular" height="100px" />
            </div>
          </BaseCard>
        </div>

        <!-- Modals & Toasts Triggers -->
        <BaseCard header="9. Componentes Flotantes (BaseModal & BaseToast)">
          <div class="flex flex-wrap gap-4 items-center">
            <BaseButton variant="primary" @click="isModalOpen = true">
              Abrir BaseModal de Prueba
            </BaseButton>

            <div class="flex flex-wrap gap-2">
              <BaseButton variant="secondary" size="sm" @click="triggerToast('info')">
                Toast Info
              </BaseButton>
              <BaseButton variant="secondary" size="sm" @click="triggerToast('success')">
                Toast Éxito
              </BaseButton>
              <BaseButton variant="secondary" size="sm" @click="triggerToast('warning')">
                Toast Alerta
              </BaseButton>
              <BaseButton variant="secondary" size="sm" @click="triggerToast('danger')">
                Toast Error
              </BaseButton>
            </div>
          </div>
        </BaseCard>
      </section>

      <!-- SECTION 3: ACCESSIBILITY -->
      <section v-if="activeTab === 'accessibility'" class="space-y-6">
        <BaseCard header="Normas de Accesibilidad (AA) Cumplidas">
          <ul class="space-y-3 text-sm text-guaiqui-text">
            <li class="flex items-start gap-2">
              <i class="bi bi-check-lg text-guaiqui-primary font-bold"></i>
              <span><strong>Navegación por Teclado:</strong> Todos los elementos interactivos incluyen <code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">focus-visible:ring-2</code> visible.</span>
            </li>
            <li class="flex items-start gap-2">
              <i class="bi bi-check-lg text-guaiqui-primary font-bold"></i>
              <span><strong>Contraste AA:</strong> Relación de contraste probada entre fondo blanco <code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">#FFFFFF</code> y verde principal <code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">#0B7A3B</code> (> 4.5:1).</span>
            </li>
            <li class="flex items-start gap-2">
              <i class="bi bi-check-lg text-guaiqui-primary font-bold"></i>
              <span><strong>Modales Accesibles:</strong> Cierre con tecla <code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">ESC</code>, bloqueo de scroll en body y atributos <code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">role="dialog" aria-modal="true"</code>.</span>
            </li>
            <li class="flex items-start gap-2">
              <i class="bi bi-check-lg text-guaiqui-primary font-bold"></i>
              <span><strong>Sin Colores Hardcodeados:</strong> 100% de los componentes consumen tokens de Tailwind y variables CSS centralizadas.</span>
            </li>
          </ul>
        </BaseCard>
      </section>
    </main>

    <!-- Modal Component Instance -->
    <BaseModal
      v-model:open="isModalOpen"
      title="Confirmar Canje de Premio"
      size="md"
      @close="isModalOpen = false"
    >
      <div class="space-y-4">
        <p class="text-sm text-guaiqui-text leading-relaxed">
          ¿Estás seguro de que deseas canjear <strong>Camiseta Oficial Guaiqueríes 2026</strong> por:
        </p>

        <div class="bg-amber-50 p-4 rounded-guaiqui-lg border border-amber-200 flex items-center justify-between">
          <span class="text-sm font-semibold text-amber-900">Costo total:</span>
          <PearlAmount :amount="3500" size="lg" show-label />
        </div>

        <p class="text-xs text-guaiqui-text-muted">
          Al confirmar, se generará un código QR inmutable en tu billetera para ser escaneado por el staff en el gimnasio.
        </p>
      </div>

      <template #footer>
        <BaseButton variant="secondary" @click="isModalOpen = false">
          Cancelar
        </BaseButton>
        <BaseButton variant="primary" @click="isModalOpen = false; triggerToast('success')">
          Confirmar Canje
        </BaseButton>
      </template>
    </BaseModal>

    <!-- Floating Toasts Container -->
    <div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none">
      <div v-for="toast in toasts" :key="toast.id" class="pointer-events-auto">
        <BaseToast
          :type="toast.type"
          :title="toast.title"
          :message="toast.message"
          @close="removeToast(toast.id)"
        />
      </div>
    </div>
  </div>
</template>
