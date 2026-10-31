<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'

export interface BirthdayGreetingCard {
  team_id: string
  team_name: string
  team_slug: string
  team_logo?: string | null
  primary_color?: string | null
  title: string
  message: string
  image_url?: string | null
  bonus_pearls: number
  claimed: boolean
  display_name?: string
}

const props = defineProps<{
  card: BirthdayGreetingCard
  claimLoading?: boolean
}>()

const emit = defineEmits<{
  (e: 'claim', teamId: string): void
  (e: 'share', card: BirthdayGreetingCard): void
}>()

const formattedMessage = computed(() => {
  if (!props.card.message) return ''
  const escaped = props.card.message
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
  const bolded = escaped.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
  return bolded.split('\n\n').map(p => `<p class="mb-3">${p.replace(/\n/g, '<br/>')}</p>`).join('')
})
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-6 md:p-8 rounded-guaiqui-xl space-y-6 shadow-guaiqui-md text-guaiqui-text">
    <!-- Team Badge Header -->
    <div class="flex items-center justify-between border-b border-guaiqui-border pb-4">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-slate-900/5 p-1 border border-slate-200 flex items-center justify-center shrink-0">
          <img
            v-if="card.team_logo"
            :src="card.team_logo"
            :alt="card.team_name"
            class="w-full h-full object-contain"
          />
          <i v-else class="bi bi-shield-shaded text-xl text-emerald-600"></i>
        </div>
        <div>
          <h3 class="font-bold text-slate-900 text-base leading-tight">{{ card.team_name }}</h3>
          <span class="text-xs text-slate-500 font-medium">Felicitación oficial</span>
        </div>
      </div>

      <span
        v-if="card.claimed"
        class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200"
      >
        <i class="bi bi-check-circle-fill"></i>
        Bono Reclamado
      </span>
    </div>

    <!-- Media Image (Optional defined by admin) -->
    <div v-if="card.image_url" class="rounded-guaiqui-lg overflow-hidden border border-guaiqui-border bg-slate-950 max-h-72 flex items-center justify-center">
      <img
        :src="card.image_url"
        :alt="card.title || 'Felicitación de cumpleaños'"
        loading="lazy"
        class="w-full h-full object-cover"
      />
    </div>

    <!-- Card Title & Message -->
    <div class="space-y-4">
      <h2 class="text-xl md:text-2xl font-bold text-guaiqui-text flex items-center gap-2">
        <i class="bi bi-balloon-fill text-red-500"></i>
        <span>{{ card.title }}</span>
      </h2>

      <div
        class="text-sm md:text-base text-guaiqui-text leading-relaxed prose prose-emerald max-w-none"
        v-html="formattedMessage"
      ></div>
    </div>

    <!-- Action Buttons -->
    <div class="pt-4 border-t border-guaiqui-border flex flex-col sm:flex-row flex-wrap gap-3 items-center justify-between">
      <div class="flex flex-wrap gap-3 w-full sm:w-auto">
        <!-- Button: Claim Bonus (if pearls > 0) -->
        <BaseButton
          v-if="card.bonus_pearls && card.bonus_pearls > 0"
          variant="primary"
          size="md"
          :disabled="card.claimed"
          :loading="claimLoading"
          class="w-full sm:w-auto"
          @click="emit('claim', card.team_id)"
        >
          <i v-if="card.claimed" class="bi bi-check-circle-fill mr-2"></i>
          <i v-else class="bi bi-gift mr-2"></i>
          <span>{{ card.claimed ? 'Bono Reclamado' : 'Reclamar en ' + card.team_name }}</span>
          <PearlAmount
            v-if="!card.claimed"
            :amount="card.bonus_pearls"
            class="ml-2 font-bold"
          />
        </BaseButton>

        <!-- Button: Go to Team Trivias -->
        <NuxtLink :to="`/app/e/${card.team_slug}/trivias`" class="w-full sm:w-auto">
          <BaseButton variant="outline" size="md" class="w-full">
            <i class="bi bi-controller mr-2"></i>
            <span>Trivias de {{ card.team_name }}</span>
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Button: Share -->
      <BaseButton
        variant="secondary"
        size="md"
        class="w-full sm:w-auto"
        @click="emit('share', card)"
      >
        <i class="bi bi-share-fill mr-2"></i>
        <span>Compartir</span>
      </BaseButton>
    </div>
  </BaseCard>
</template>
