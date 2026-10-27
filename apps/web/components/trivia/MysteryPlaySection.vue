<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseModal, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveMysteryPlay } from '@guaiqui/shared'

const props = defineProps<{
  items: ActiveMysteryPlay[]
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'voted', payload: { challengeId: string; selectedOption: string; result: any }): void
}>()

const supabase = useSupabaseClient()
const selectedPlay = ref<ActiveMysteryPlay | null>(null)
const selectedOption = ref<string | null>(null)
const isModalOpen = ref(false)
const isSubmitting = ref(false)
const resultData = ref<any | null>(null)
const errorMessage = ref<string | null>(null)

const openPlayModal = (item: ActiveMysteryPlay) => {
  selectedPlay.value = item
  selectedOption.value = item.user_vote?.selected_option || null
  resultData.value = item.user_vote || null
  errorMessage.value = null
  isModalOpen.value = true
}

const submitPlayVote = async () => {
  if (!selectedPlay.value || !selectedOption.value || selectedPlay.value.user_vote) return
  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await (supabase.rpc as any)('submit_mystery_play_vote', {
      p_challenge_id: selectedPlay.value.id,
      p_selected_option: selectedOption.value
    })

    if (error) throw error

    resultData.value = data as any
    emit('voted', {
      challengeId: selectedPlay.value.id,
      selectedOption: selectedOption.value,
      result: data
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al enviar respuesta'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard v-for="i in 2" :key="i" class="p-6 bg-white border border-guaiqui-border animate-pulse h-48" />
    </div>

    <div v-else-if="items.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard
        v-for="item in items"
        :key="item.id"
        class="overflow-hidden bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between transition hover:border-guaiqui-primary"
      >
        <!-- Media / Header preview -->
        <div class="relative bg-slate-900 aspect-video flex items-center justify-center overflow-hidden">
          <img
            v-if="item.cover_image_url"
            :src="item.cover_image_url"
            :alt="item.title"
            class="w-full h-full object-cover opacity-80"
          />
          <div v-else class="w-full h-full bg-gradient-to-br from-emerald-950 via-slate-900 to-black flex items-center justify-center">
            <i class="bi bi-play-circle-fill text-5xl text-emerald-400/80"></i>
          </div>

          <div class="absolute top-3 left-3 bg-slate-950/80 backdrop-blur-sm px-2.5 py-1 rounded-md text-[11px] font-bold text-white flex items-center gap-1.5 border border-white/10">
            <i class="bi bi-camera-reels-fill text-emerald-400"></i>
            Jugada Congelada
          </div>

          <div class="absolute top-3 right-3">
            <PearlAmount :amount="item.reward_pearls" size="sm" />
          </div>

          <!-- Play prompt badge -->
          <button
            type="button"
            @click="openPlayModal(item)"
            class="absolute inset-0 flex items-center justify-center bg-black/20 hover:bg-black/40 transition group"
          >
            <div class="w-12 h-12 rounded-full bg-emerald-600 group-hover:bg-emerald-500 text-white flex items-center justify-center text-xl shadow-lg transition transform group-hover:scale-110">
              <i class="bi bi-play-fill ml-0.5"></i>
            </div>
          </button>
        </div>

        <div class="p-5 flex-1 flex flex-col justify-between space-y-3">
          <div>
            <h3 class="font-display font-bold text-base text-guaiqui-text leading-snug">
              {{ item.title }}
            </h3>
            <p class="text-xs text-emerald-700 font-semibold mt-1 flex items-center gap-1.5">
              <i class="bi bi-patch-question-fill"></i> {{ item.question }}
            </p>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-between">
            <span class="text-[11px] text-slate-400 font-mono">
              Cierre: {{ formatCaracas(item.closes_at) }}
            </span>

            <div v-if="item.user_vote" class="text-xs">
              <span v-if="item.user_vote.is_correct" class="font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 inline-flex items-center gap-1">
                <i class="bi bi-check-circle-fill"></i> ¡Acertaste! +{{ item.user_vote.pearls_awarded }}
              </span>
              <span v-else class="font-semibold text-slate-600 bg-slate-100 px-2.5 py-1 rounded-full border border-slate-300 inline-block">
                Opción elegida: {{ item.user_vote.selected_option }}
              </span>
            </div>

            <BaseButton
              v-else
              variant="primary"
              size="sm"
              @click="openPlayModal(item)"
            >
              <i class="bi bi-eye-fill me-1"></i> Ver & Resolver
            </BaseButton>
          </div>
        </div>
      </BaseCard>
    </div>

    <!-- Empty State -->
    <div v-else class="p-8 text-center bg-white rounded-2xl border border-guaiqui-border space-y-2">
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-xl">
        <i class="bi bi-camera-reels"></i>
      </div>
      <h3 class="font-display font-bold text-slate-700 text-base">No hay jugadas misteriosas activas</h3>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Pronto subiremos nuevas jugadas destacadas para que adivines el desenlace y ganes perlitas.
      </p>
    </div>

    <!-- Game Modal -->
    <BaseModal v-model="isModalOpen" title="«¿Qué pasó después?»" size="lg">
      <div v-if="selectedPlay" class="space-y-4 text-left">
        <!-- Video / Media Player Container -->
        <div class="relative bg-black rounded-xl overflow-hidden aspect-video border border-slate-800 flex items-center justify-center">
          <!-- If resolved and reveal video exists -->
          <video
            v-if="resultData?.reveal_video_url"
            :src="resultData.reveal_video_url"
            controls
            autoplay
            class="w-full h-full object-contain"
          ></video>
          <!-- Play video or paused preview -->
          <video
            v-else-if="selectedPlay.video_url"
            :src="selectedPlay.video_url"
            controls
            class="w-full h-full object-contain"
          ></video>
          <img
            v-else-if="selectedPlay.cover_image_url"
            :src="selectedPlay.cover_image_url"
            :alt="selectedPlay.title"
            class="w-full h-full object-contain"
          />
          <div v-else class="p-6 text-center text-slate-400 text-xs">
            <i class="bi bi-camera-reels text-3xl text-emerald-400 block mb-2"></i>
            Jugada congelada para adivinanza
          </div>
        </div>

        <div>
          <h3 class="font-display font-bold text-lg text-slate-900">{{ selectedPlay.title }}</h3>
          <p class="text-sm font-bold text-emerald-700 mt-1 flex items-center gap-1.5">
            <i class="bi bi-question-circle-fill"></i> {{ selectedPlay.question }}
          </p>
        </div>

        <!-- Result Banner if already voted -->
        <div v-if="resultData" class="p-4 rounded-xl border text-sm" :class="resultData.is_correct ? 'bg-emerald-50 border-emerald-300 text-emerald-900' : 'bg-slate-100 border-slate-300 text-slate-800'">
          <div class="flex items-center gap-2 font-bold text-base">
            <i :class="resultData.is_correct ? 'bi bi-check-circle-fill text-emerald-600' : 'bi bi-x-circle-fill text-slate-500'"></i>
            <span>{{ resultData.is_correct ? '¡Acertaste la jugada!' : 'No acertaste esta vez' }}</span>
          </div>
          <p class="text-xs mt-1">
            La respuesta correcta fue la opción <strong class="text-emerald-700 uppercase">({{ resultData.correct_option }})</strong>.
            <span v-if="resultData.pearls_awarded > 0"> ¡Se han acreditado <strong class="text-amber-800">+{{ resultData.pearls_awarded }} perlitas</strong> en tu billetera!</span>
          </p>
        </div>

        <!-- 4 Options Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 pt-1">
          <button
            v-for="(opt, key) in [
              { key: 'A', text: selectedPlay.option_a },
              { key: 'B', text: selectedPlay.option_b },
              { key: 'C', text: selectedPlay.option_c },
              { key: 'D', text: selectedPlay.option_d },
            ]"
            :key="opt.key"
            type="button"
            :disabled="!!resultData || isSubmitting"
            @click="selectedOption = opt.key"
            :class="[
              'p-3 rounded-xl border text-left transition flex items-center gap-3',
              selectedOption === opt.key
                ? 'bg-emerald-50 border-emerald-600 ring-2 ring-emerald-500/40'
                : 'bg-white border-slate-200 hover:border-slate-300 hover:bg-slate-50',
              resultData && resultData.correct_option === opt.key ? 'bg-emerald-100 border-emerald-500' : ''
            ]"
          >
            <div
              class="w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs shrink-0"
              :class="selectedOption === opt.key ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-700'"
            >
              {{ opt.key }}
            </div>
            <span class="text-xs font-semibold text-slate-800">{{ opt.text }}</span>
          </button>
        </div>

        <div v-if="errorMessage" class="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ errorMessage }}</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="isModalOpen = false">
            {{ resultData ? 'Cerrar' : 'Cancelar' }}
          </BaseButton>
          <BaseButton
            v-if="!resultData"
            variant="primary"
            size="sm"
            :disabled="!selectedOption || isSubmitting"
            :loading="isSubmitting"
            @click="submitPlayVote"
          >
            Confirmar y Revelar Desenlace
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
