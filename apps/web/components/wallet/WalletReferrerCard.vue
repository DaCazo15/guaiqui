<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useReferrals } from '~/composables/useReferrals'

const {
  referredBy,
  claimReferralCode,
  claiming,
  claimError,
  claimSuccess,
} = useReferrals()

const inputCode = ref('')

async function handleSubmit() {
  if (!inputCode.value.trim()) return
  const res = await claimReferralCode(inputCode.value)
  if (res.success) {
    inputCode.value = ''
  }
}
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm">
    <div class="flex items-center gap-3 mb-4">
      <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center shrink-0 text-xl font-bold">
        <i class="bi bi-person-heart"></i>
      </div>
      <div>
        <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide">
          ¿Quién te refirió?
        </h2>
        <p class="text-xs text-guaiqui-text-muted">
          Vinculación de comunidad y fidelidad con otros fanáticos.
        </p>
      </div>
    </div>

    <!-- Caso 1: Ya tiene referente -->
    <div
      v-if="referredBy.has_referrer"
      class="p-4 bg-emerald-50 border border-emerald-200 rounded-guaiqui-lg flex items-center justify-between gap-3 text-emerald-900"
    >
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-full bg-emerald-200 text-emerald-800 flex items-center justify-center font-bold text-sm shrink-0">
          <img
            v-if="referredBy.referrer_avatar"
            :src="referredBy.referrer_avatar"
            :alt="referredBy.referrer_name || 'Referente'"
            class="w-full h-full object-cover rounded-full"
          />
          <span v-else>{{ referredBy.referrer_name?.charAt(0) || 'F' }}</span>
        </div>
        <div>
          <p class="text-xs font-semibold text-emerald-700 uppercase tracking-wider">
            Comunidad Vinculada
          </p>
          <p class="text-sm font-bold text-emerald-950">
            Eres referido de <span class="underline decoration-emerald-400">{{ referredBy.referrer_name }}</span>
          </p>
        </div>
      </div>
      <div class="text-emerald-600 text-xl">
        <i class="bi bi-check-circle-fill"></i>
      </div>
    </div>

    <!-- Caso 2: Aún no tiene referente -->
    <div v-else class="space-y-4">
      <p class="text-xs text-guaiqui-text-muted">
        ¿Un amigo te invitó a la plataforma? Ingresa su código de referido a continuación para vincularte a su red:
      </p>

      <form @submit.prevent="handleSubmit" class="flex flex-col sm:flex-row gap-2.5">
        <input
          v-model="inputCode"
          type="text"
          placeholder="Código de referido (ej. 8 caracteres)"
          class="flex-1 px-4 py-2.5 bg-gray-50 border border-guaiqui-border rounded-guaiqui-lg text-sm text-guaiqui-text font-mono uppercase tracking-wider focus:outline-none focus:ring-2 focus:ring-guaiqui-primary focus:bg-white transition-all"
          maxlength="20"
          :disabled="claiming"
        />
        <BaseButton
          type="submit"
          variant="primary"
          size="sm"
          class="justify-center px-5 shrink-0"
          :disabled="claiming || !inputCode.trim()"
        >
          <span v-if="claiming" class="inline-block animate-spin mr-1">
            <i class="bi bi-arrow-repeat"></i>
          </span>
          <i v-else class="bi bi-link-45deg mr-1"></i>
          Vincular Referente
        </BaseButton>
      </form>

      <!-- Mensajes de feedback -->
      <p v-if="claimError" class="text-xs text-rose-600 font-semibold flex items-center gap-1.5 animate-in fade-in">
        <i class="bi bi-exclamation-circle-fill"></i>
        {{ claimError }}
      </p>
      <p v-if="claimSuccess" class="text-xs text-emerald-600 font-semibold flex items-center gap-1.5 animate-in fade-in">
        <i class="bi bi-check-circle-fill"></i>
        {{ claimSuccess }}
      </p>
    </div>
  </BaseCard>
</template>
