<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  scanData: any
  isLoadingAction: boolean
}>()

const emit = defineEmits<{
  (e: 'deliver'): void
  (e: 'reportIssue'): void
  (e: 'clear'): void
}>()

const isApproved = computed(() => props.scanData?.result === 'OK_APPROVED' || props.scanData?.result === 'OK_SCHEDULED' || props.scanData?.status === 'approved' || props.scanData?.status === 'scheduled')
const isDelivered = computed(() => props.scanData?.result === 'ALREADY_DELIVERED' || props.scanData?.status === 'delivered' || props.scanData?.status === 'completed')

const displayName = computed(() => props.scanData?.display_name || props.scanData?.fan_display_name)
const avatarUrl = computed(() => props.scanData?.avatar_url || props.scanData?.fan_avatar_url)
const productTitle = computed(() => props.scanData?.product_title || props.scanData?.product_name)
const variantTitle = computed(() => props.scanData?.variant_title || props.scanData?.variant)
const isExperience = computed(() => props.scanData?.is_experience ?? (props.scanData?.product_category === 'experience'))

const resultBadge = computed(() => {
  const result = props.scanData?.result
  const status = props.scanData?.status

  if (result === 'OK_APPROVED' || result === 'OK_SCHEDULED' || status === 'approved' || status === 'scheduled') {
    return {
      class: 'bg-emerald-950/80 border-emerald-700 text-emerald-300',
      icon: 'bi-check-circle-fill text-emerald-400',
      title: status === 'scheduled' || result === 'OK_SCHEDULED' ? 'Experiencia Agendada y Lista para Asistencia' : 'Canje Válido y Listo para Entrega',
      label: status === 'scheduled' || result === 'OK_SCHEDULED' ? 'AGENDADO' : 'APROBADO'
    }
  } else if (result === 'ALREADY_DELIVERED' || status === 'delivered' || status === 'completed') {
    return {
      class: 'bg-amber-950/80 border-amber-700 text-amber-300',
      icon: 'bi-info-circle-fill text-amber-400',
      title: 'Premio o Asistencia Ya Registrada Previamente',
      label: 'YA ENTREGADO'
    }
  } else if (status === 'cancelled' || status === 'rejected' || status === 'expired') {
    return {
      class: 'bg-red-950/80 border-red-700 text-red-300',
      icon: 'bi-x-circle-fill text-red-400',
      title: 'Canje Cancelado, Rechazado o Expirado',
      label: 'INVÁLIDO'
    }
  } else {
    return {
      class: 'bg-slate-900 border-slate-800 text-slate-300',
      icon: 'bi-shield-exclamation text-slate-400',
      title: props.scanData?.message || 'Código No Encontrado o Inválido',
      label: 'ERROR'
    }
  }
})
</script>

<template>
  <div v-if="scanData" class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-6">
    <!-- Status Header Banner -->
    <div :class="['p-4 rounded-xl border flex items-center justify-between gap-3', resultBadge.class]">
      <div class="flex items-center gap-3">
        <i :class="['bi text-2xl', resultBadge.icon]"></i>
        <div>
          <h3 class="font-bold text-sm text-white">{{ resultBadge.title }}</h3>
          <p v-if="scanData.message" class="text-xs opacity-90">{{ scanData.message }}</p>
        </div>
      </div>

      <span class="px-2.5 py-1 rounded-full text-xs font-mono font-bold bg-slate-950/60 border border-current">
        {{ resultBadge.label }}
      </span>
    </div>

    <!-- Fan & Product Details (PRIVACY ENFORCED: No email, birthdate, gender, size, or metadata!) -->
    <div v-if="displayName || productTitle" class="grid grid-cols-1 md:grid-cols-2 gap-4 bg-slate-950/60 p-4 rounded-xl border border-slate-800/80">
      <!-- Fan Info -->
      <div class="flex items-center gap-3 border-b md:border-b-0 md:border-r border-slate-800 pb-3 md:pb-0 md:pr-3">
        <div class="w-12 h-12 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-bold text-lg overflow-hidden flex-shrink-0">
          <img v-if="avatarUrl" :src="avatarUrl" :alt="displayName" class="w-full h-full object-cover" />
          <span v-else>{{ (displayName || 'F')[0] }}</span>
        </div>
        <div>
          <span class="text-[11px] text-slate-500 uppercase tracking-wider font-semibold block">Fanático</span>
          <span class="font-bold text-sm text-white">{{ displayName }}</span>
        </div>
      </div>

      <!-- Product Info -->
      <div class="space-y-1">
        <span class="text-[11px] text-slate-500 uppercase tracking-wider font-semibold block">Premio / Canje</span>
        <div class="font-bold text-sm text-emerald-400">{{ productTitle }}</div>
        <div class="flex items-center gap-2 text-xs text-slate-400">
          <span v-if="variantTitle" class="px-2 py-0.5 bg-slate-800 rounded-md font-mono text-[11px]">Talla/Variante: {{ variantTitle }}</span>
          <span v-if="scanData.cost_pearls" class="font-semibold text-emerald-400 flex items-center gap-1">
            <span>{{ scanData.cost_pearls }}</span>
            <i class="bi bi-gem text-xs"></i>
            <span>perlitas</span>
          </span>
        </div>
      </div>
    </div>

    <!-- Action Buttons -->
    <div class="flex flex-col sm:flex-row items-center justify-between gap-3 pt-2">
      <button
        @click="emit('clear')"
        class="w-full sm:w-auto px-4 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl transition-all"
      >
        <i class="bi bi-arrow-left me-1"></i> Limpiar / Nuevo Escaneo
      </button>

      <div class="flex items-center gap-2 w-full sm:w-auto">
        <button
          v-if="isApproved"
          @click="emit('reportIssue')"
          class="flex-1 sm:flex-none px-4 py-2.5 bg-amber-950/60 hover:bg-amber-900 border border-amber-800 text-amber-300 text-xs font-semibold rounded-xl transition-all"
        >
          <i class="bi bi-exclamation-triangle me-1"></i> Reportar Problema
        </button>

        <button
          v-if="isApproved"
          @click="emit('deliver')"
          :disabled="isLoadingAction"
          class="flex-1 sm:flex-none px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white text-xs font-bold rounded-xl transition-all shadow-lg shadow-emerald-950/60 disabled:opacity-50"
        >
          <i v-if="isLoadingAction" class="bi bi-arrow-repeat animate-spin me-1"></i>
          <i v-else class="bi bi-check2-circle text-base me-1"></i>
          <span>{{ isExperience ? 'Registrar Asistencia' : 'Entregar Canje' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
