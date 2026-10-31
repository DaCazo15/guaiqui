<script setup lang="ts">
import { onMounted } from 'vue'
import { BaseCard, BaseButton, PearlIcon, PearlAmount } from '@guaiqui/ui'
import { useReferrals } from '~/composables/useReferrals'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Programa de Referidos — Fan Zone',
  description: 'Invita a tus amigos a la Fan Zone y gana perlitas con cada registro y trivia.',
})

const referrals = useReferrals()

onMounted(async () => {
  await referrals.fetchReferralSummary()
})

const shareViaWhatsApp = () => {
  if (!referrals.referralLink.value) return
  const text = encodeURIComponent(
    `¡Únete a la Fan Zone de baloncesto, juega trivias y canjea premios reales! Regístrate con mi enlace: ${referrals.referralLink.value}`
  )
  window.open(`https://api.whatsapp.com/send?text=${text}`, '_blank')
}
</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Invita Amigos y <span class="text-guaiqui-primary">Gana Perlitas</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted mt-1">
          Comparte tu código o enlace de referido y acumula puntos con cada fanático que se sume.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <NuxtLink to="/app/perlitas-pendientes">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-hourglass-split mr-1.5 text-guaiqui-primary"></i>
            Perlitas por Asignar
          </BaseButton>
        </NuxtLink>
        <NuxtLink to="/app/billetera">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-wallet2 mr-1.5 text-guaiqui-primary"></i>
            Mi Billetera
          </BaseButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Referral Link & Code Card -->
    <BaseCard class="p-6 bg-gradient-to-br from-guaiqui-primary-soft/30 via-white to-white border border-guaiqui-primary/30 rounded-guaiqui-xl shadow-guaiqui-sm">
      <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div class="space-y-2">
          <span class="text-xs font-bold text-guaiqui-primary uppercase tracking-wider bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Tu Código Personal de Referido
          </span>
          <div class="flex items-center gap-3 pt-1">
            <span class="font-display font-black text-3xl sm:text-4xl text-guaiqui-text tracking-widest bg-slate-100 border border-slate-200 px-4 py-1.5 rounded-guaiqui-lg select-all">
              {{ referrals.summary.value.code || '...' }}
            </span>
            <button
              type="button"
              class="px-3 py-2 rounded-guaiqui-md bg-white border border-guaiqui-border hover:bg-slate-50 text-xs font-bold uppercase tracking-wider text-guaiqui-text transition-colors flex items-center gap-1.5 cursor-pointer shadow-guaiqui-xs"
              @click="referrals.copyCode()"
            >
              <i :class="referrals.copied.value ? 'bi bi-check2 text-emerald-600' : 'bi bi-copy'"></i>
              <span>{{ referrals.copied.value ? 'Copiado' : 'Copiar' }}</span>
            </button>
          </div>
          <p class="text-xs text-guaiqui-text-muted">
            Tus amigos pueden ingresar este código al momento de registrarse en la plataforma.
          </p>
        </div>

        <!-- Share Actions -->
        <div class="w-full md:w-auto flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5 shrink-0">
          <button
            type="button"
            class="px-4 py-2.5 rounded-guaiqui-lg bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-xs uppercase tracking-wider transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-guaiqui-xs"
            @click="referrals.copyLink()"
          >
            <i :class="referrals.copied.value ? 'bi bi-check-lg text-sm' : 'bi bi-link-45deg text-base'"></i>
            <span>{{ referrals.copied.value ? '¡Enlace Copiado!' : 'Copiar Enlace' }}</span>
          </button>

          <button
            type="button"
            class="px-4 py-2.5 rounded-guaiqui-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs uppercase tracking-wider transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-guaiqui-xs"
            @click="shareViaWhatsApp()"
          >
            <i class="bi bi-whatsapp text-sm"></i>
            <span>Compartir</span>
          </button>
        </div>
      </div>
    </BaseCard>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
      <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center text-2xl shrink-0">
          <i class="bi bi-people-fill"></i>
        </div>
        <div>
          <span class="text-xs font-bold text-guaiqui-text-muted uppercase tracking-wider block">Total Invitados</span>
          <span class="font-display font-black text-2xl text-guaiqui-text block">
            {{ referrals.summary.value.total_referred }}
          </span>
          <span class="text-[11px] text-guaiqui-text-muted">Amigos registrados</span>
        </div>
      </BaseCard>

      <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center text-2xl shrink-0">
          <i class="bi bi-check-circle-fill"></i>
        </div>
        <div>
          <span class="text-xs font-bold text-guaiqui-text-muted uppercase tracking-wider block">Calificados</span>
          <span class="font-display font-black text-2xl text-purple-700 block">
            {{ referrals.summary.value.qualified_count }}
          </span>
          <span class="text-[11px] text-guaiqui-text-muted">Jugaron al menos 1 trivia</span>
        </div>
      </BaseCard>

      <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center text-2xl shrink-0">
          <i class="bi bi-gem"></i>
        </div>
        <div>
          <span class="text-xs font-bold text-guaiqui-text-muted uppercase tracking-wider block">Puntos Obtenidos</span>
          <div class="flex items-baseline gap-1">
            <PearlAmount :amount="referrals.summary.value.points_earned" size="lg" animated />
          </div>
          <span class="text-[11px] text-guaiqui-text-muted">Por registros y trivias</span>
        </div>
      </BaseCard>
    </div>

    <!-- Referrals List Card -->
    <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm">
      <div class="flex items-center justify-between border-b border-guaiqui-border/60 pb-3 mb-4">
        <h2 class="font-display font-black text-base text-guaiqui-text uppercase tracking-wider flex items-center gap-2">
          <i class="bi bi-person-lines-fill text-guaiqui-primary"></i>
          <span>Lista de Amigos Referidos</span>
        </h2>
        <span class="text-xs font-bold text-guaiqui-text-muted">
          {{ referrals.summary.value.referrals.length }} registrados
        </span>
      </div>

      <!-- Empty state -->
      <div
        v-if="referrals.summary.value.referrals.length === 0"
        class="py-12 text-center space-y-3"
      >
        <div class="w-14 h-14 rounded-full bg-slate-50 text-slate-400 mx-auto flex items-center justify-center text-2xl border border-slate-200">
          <i class="bi bi-person-plus"></i>
        </div>
        <div>
          <p class="text-base font-bold text-guaiqui-text">Aún no tienes referidos registrados</p>
          <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto mt-1">
            Comparte tu código o enlace por WhatsApp y redes sociales para empezar a sumar perlitas juntos.
          </p>
        </div>
        <div class="pt-2">
          <button
            type="button"
            class="px-4 py-2 bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white text-xs font-bold uppercase tracking-wider rounded-guaiqui-md transition-colors cursor-pointer inline-flex items-center gap-2 shadow-guaiqui-xs"
            @click="referrals.copyLink()"
          >
            <i class="bi bi-link-45deg"></i>
            <span>Copiar mi enlace de invitación</span>
          </button>
        </div>
      </div>

      <!-- Referrals list -->
      <div v-else class="divide-y divide-guaiqui-border/60">
        <div
          v-for="refItem in referrals.summary.value.referrals"
          :key="refItem.id"
          class="py-3.5 flex items-center justify-between gap-3"
        >
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-emerald-900 text-emerald-100 flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-emerald-500/30">
              <img
                v-if="refItem.avatar_url"
                :src="refItem.avatar_url"
                :alt="refItem.referred_name"
                class="w-full h-full object-cover"
              />
              <span v-else>
                {{ refItem.referred_name.charAt(0).toUpperCase() }}
              </span>
            </div>
            <div>
              <p class="text-sm font-bold text-guaiqui-text leading-tight">
                {{ refItem.referred_name }}
              </p>
              <p class="text-xs text-guaiqui-text-muted mt-0.5">
                Registrado el {{ new Date(refItem.created_at).toLocaleDateString('es-VE') }}
              </p>
            </div>
          </div>

          <!-- Status badge -->
          <div>
            <span
              v-if="refItem.status === 'qualified'"
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300 font-bold text-xs"
            >
              <i class="bi bi-patch-check-fill text-emerald-600"></i>
              Calificado (+5 pts)
            </span>
            <span
              v-else
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-100 text-slate-700 border border-slate-300 font-medium text-xs"
            >
              <i class="bi bi-clock"></i>
              Registrado
            </span>
          </div>
        </div>
      </div>
    </BaseCard>

    <!-- How it works guide -->
    <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs space-y-3">
      <h2 class="text-sm font-bold text-guaiqui-text flex items-center gap-2">
        <i class="bi bi-lightbulb-fill text-amber-500"></i>
        <span>Reglas del Programa de Referidos</span>
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 pt-1">
        <div class="p-3.5 bg-slate-50 border border-slate-200 rounded-guaiqui-lg space-y-1">
          <div class="flex items-center gap-2 text-xs font-bold text-guaiqui-text">
            <span class="w-5 h-5 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-[10px]">1</span>
            <span>Bono por Registro (5 Perlitas)</span>
          </div>
          <p class="text-xs text-guaiqui-text-muted pl-7">
            Al registrarse tu amigo con tu enlace o código, recibes una concesión de 5 perlitas con 90 días de vigencia para asignarla al equipo de tu preferencia.
          </p>
        </div>

        <div class="p-3.5 bg-slate-50 border border-slate-200 rounded-guaiqui-lg space-y-1">
          <div class="flex items-center gap-2 text-xs font-bold text-guaiqui-text">
            <span class="w-5 h-5 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-[10px]">2</span>
            <span>Bono por Primera Trivia (5 Perlitas)</span>
          </div>
          <p class="text-xs text-guaiqui-text-muted pl-7">
            Cuando tu referido complete con éxito su primera trivia de un equipo que sigas activamente, se acreditarán 5 perlitas automáticas a tu billetera de ese equipo.
          </p>
        </div>
      </div>
    </BaseCard>
  </div>
</template>
