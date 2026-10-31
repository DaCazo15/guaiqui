<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useFriendships } from '~/composables/useFriendships'
import { useReferrals } from '~/composables/useReferrals'

const { sendFriendRequest, sending, error, success } = useFriendships()
const { summary, copied, copyCode } = useReferrals()

const targetInput = ref('')

async function handleSubmit() {
  if (!targetInput.value.trim()) return
  const res = await sendFriendRequest(targetInput.value)
  if (res.success) {
    targetInput.value = ''
  }
}
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-6">
    <!-- Header -->
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center shrink-0 text-xl font-bold">
        <i class="bi bi-person-plus-fill"></i>
      </div>
      <div>
        <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide">
          Agregar Fanático a Amigos
        </h2>
        <p class="text-xs text-guaiqui-text-muted">
          Conecta con otros fanáticos usando su código de fanático o nombre de usuario.
        </p>
      </div>
    </div>

    <!-- Tu propio código para compartir -->
    <div class="p-4 bg-slate-50 border border-slate-200 rounded-guaiqui-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <span class="text-[11px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">
          Tu Código Personal de Fanático
        </span>
        <span class="font-mono font-black text-xl text-guaiqui-text tracking-widest select-all">
          {{ summary.code || '...' }}
        </span>
      </div>
      <BaseButton
        variant="outline"
        size="sm"
        class="shrink-0"
        @click="copyCode"
      >
        <i :class="copied ? 'bi bi-check2 text-emerald-600' : 'bi bi-copy'" class="mr-1.5"></i>
        <span>{{ copied ? '¡Copiado!' : 'Copiar mi código' }}</span>
      </BaseButton>
    </div>

    <!-- Formulario para agregar -->
    <form @submit.prevent="handleSubmit" class="space-y-3">
      <label for="friend-code-input" class="text-xs font-bold uppercase tracking-wider text-guaiqui-text block">
        Ingresa el código o nombre del fanático
      </label>
      <div class="flex flex-col sm:flex-row gap-2.5">
        <input
          id="friend-code-input"
          v-model="targetInput"
          type="text"
          placeholder="Código de 8 caracteres (ej. SOCIAL01)"
          class="flex-1 px-4 py-2.5 bg-gray-50 border border-guaiqui-border rounded-guaiqui-lg text-sm text-guaiqui-text font-mono uppercase tracking-wider focus:outline-none focus:ring-2 focus:ring-guaiqui-primary focus:bg-white transition-all"
          maxlength="40"
          :disabled="sending"
        />
        <BaseButton
          type="submit"
          variant="primary"
          size="sm"
          class="justify-center px-6 shrink-0"
          :disabled="sending || !targetInput.trim()"
        >
          <span v-if="sending" class="inline-block animate-spin mr-1">
            <i class="bi bi-arrow-repeat"></i>
          </span>
          <i v-else class="bi bi-send-fill mr-1.5"></i>
          Enviar Solicitud
        </BaseButton>
      </div>

      <!-- Feedback -->
      <p v-if="error" class="text-xs text-rose-600 font-semibold flex items-center gap-1.5 animate-in fade-in">
        <i class="bi bi-exclamation-circle-fill"></i>
        {{ error }}
      </p>
      <p v-if="success" class="text-xs text-emerald-600 font-semibold flex items-center gap-1.5 animate-in fade-in">
        <i class="bi bi-check-circle-fill"></i>
        {{ success }}
      </p>
    </form>
  </BaseCard>
</template>
