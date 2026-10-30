<script setup lang="ts">
import { useRouter } from 'vue-router'
import { BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const handleSignOut = async () => {
  await authStore.signOut()
  router.replace({ name: 'login' })
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 flex items-center justify-center p-4">
    <div class="max-w-md w-full p-6 sm:p-8 rounded-2xl bg-slate-900 border border-slate-800 text-center shadow-2xl space-y-5">
      <div class="w-16 h-16 rounded-2xl bg-red-950/60 border border-red-800 text-red-400 flex items-center justify-center mx-auto text-3xl shadow-inner">
        <i class="bi bi-slash-circle"></i>
      </div>

      <div class="space-y-2">
        <h1 class="text-xl sm:text-2xl font-bold font-title text-white">
          Equipo Temporalmente No Disponible
        </h1>
        <p class="text-xs sm:text-sm text-slate-400 leading-relaxed">
          El servicio para su club se encuentra actualmente en estado <strong class="text-red-400">Inactivo</strong> debido al vencimiento del período de suscripción o por decisión administrativa.
        </p>
      </div>

      <div class="p-4 rounded-xl bg-slate-850 border border-slate-800 text-left text-xs space-y-2 text-slate-300">
        <div class="font-semibold text-slate-200 flex items-center gap-1.5">
          <i class="bi bi-info-circle text-amber-400"></i> ¿Qué implica este estado?
        </div>
        <ul class="list-disc list-inside space-y-1 text-slate-400 text-[11px]">
          <li>Las operaciones del personal en taquilla y administración están pausadas.</li>
          <li>Los saldos y canjes de sus fanáticos están resguardados y no se pierden.</li>
          <li>Para reactivar las operaciones de inmediato, comuníquese con la administración central de la plataforma.</li>
        </ul>
      </div>

      <div class="pt-2 flex flex-col sm:flex-row items-center justify-center gap-3">
        <BaseButton
          variant="secondary"
          size="sm"
          class="w-full sm:w-auto"
          @click="handleSignOut"
        >
          <i class="bi bi-box-arrow-right mr-1"></i> Cerrar Sesión
        </BaseButton>
      </div>
    </div>
  </div>
</template>
