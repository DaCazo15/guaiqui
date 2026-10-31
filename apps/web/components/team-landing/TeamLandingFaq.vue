<script setup lang="ts">
import { ref } from 'vue'
import type { TeamLandingProfile } from '@guaiqui/shared'

const props = defineProps<{
  team: TeamLandingProfile
  faqs: Array<{
    id: string
    question: string
    answer: string
    category?: string | null
  }>
}>()

const openFaqId = ref<string | null>(props.faqs?.[0]?.id || null)

function toggleFaq(id: string) {
  openFaqId.value = openFaqId.value === id ? null : id
}
</script>

<template>
  <section id="faq" class="py-16 sm:py-24 bg-gray-50 border-t border-gray-100">
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Section Header -->
      <div class="text-center max-w-2xl mx-auto mb-12">
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-gray-200 text-gray-800 mb-3">
          <i class="bi bi-patch-question-fill" aria-hidden="true"></i>
          Dudas Comunes
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-5xl text-gray-900 uppercase tracking-tight">
          Preguntas Frecuentes
        </h2>
        <p class="mt-3 text-base sm:text-lg text-gray-600">
          Todo lo que necesitas saber sobre la plataforma y el canje de perlitas de {{ team.name }}.
        </p>
      </div>

      <!-- FAQ Accordion -->
      <div v-if="faqs.length > 0" class="space-y-4">
        <div
          v-for="faq in faqs"
          :key="faq.id"
          class="bg-white rounded-2xl border border-gray-200/90 overflow-hidden transition-all duration-200"
        >
          <button
            type="button"
            @click="toggleFaq(faq.id)"
            class="w-full py-5 px-6 text-left flex items-center justify-between gap-4 font-display font-bold text-lg text-gray-900 hover:text-guaiqui-primary focus:outline-none"
            :aria-expanded="openFaqId === faq.id"
          >
            <span>{{ faq.question }}</span>
            <i
              class="bi bi-chevron-down text-base text-gray-400 transition-transform duration-200 shrink-0"
              :class="{ 'rotate-180 text-guaiqui-primary': openFaqId === faq.id }"
              aria-hidden="true"
            ></i>
          </button>
          <div
            v-if="openFaqId === faq.id"
            class="px-6 pb-6 pt-1 text-sm sm:text-base text-gray-600 leading-relaxed border-t border-gray-50"
          >
            {{ faq.answer }}
          </div>
        </div>
      </div>

      <!-- Default FAQs if none loaded from DB -->
      <div v-else class="space-y-4">
        <div class="bg-white rounded-2xl border border-gray-200 p-6 space-y-2">
          <h3 class="font-display font-bold text-lg text-gray-900">
            ¿Cómo gano perlitas para {{ team.name }}?
          </h3>
          <p class="text-sm text-gray-600 leading-relaxed">
            Puedes ganar perlitas respondiendo trivias semanales del equipo, viendo anuncios patrocinados e invitando a tus amigos con tu enlace de referidos.
          </p>
        </div>
        <div class="bg-white rounded-2xl border border-gray-200 p-6 space-y-2">
          <h3 class="font-display font-bold text-lg text-gray-900">
            ¿Los canjes de la tienda cuestan dinero real?
          </h3>
          <p class="text-sm text-gray-600 leading-relaxed">
            ¡No! La plataforma es 100% gratuita. Las perlitas no se compran con dinero real ni se venden boletos. Solo se consiguen con tu fidelidad y participación.
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
