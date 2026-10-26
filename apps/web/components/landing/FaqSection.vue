<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseAccordion, BaseButton } from '@guaiqui/ui'

const props = withDefaults(defineProps<{
  hideIfEmpty?: boolean
}>(), {
  hideIfEmpty: true
})

const supabase = useSupabaseClient()
const accordionItems = ref<{ id: string; title: string; content: string }[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('faqs')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      accordionItems.value = data.map((f: any) => ({
        id: f.id,
        title: f.question,
        content: f.answer,
      }))
    } else {
      accordionItems.value = []
    }
  } catch {
    accordionItems.value = []
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <!-- Hidden completely when empty on landing -->
  <section
    v-if="!loading && (accordionItems.length > 0 || !hideIfEmpty)"
    id="faq"
    class="py-16 sm:py-24 bg-guaiqui-surface border-t border-guaiqui-border px-4 sm:px-8 scroll-mt-20"
  >
    <div class="max-w-4xl mx-auto space-y-10">
      <div class="text-center space-y-3">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
          Centro de Ayuda
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Preguntas Frecuentes
        </h2>
        <p class="text-guaiqui-text-muted text-sm sm:text-base">
          Resolvemos tus dudas sobre los puntos, trivias y el canje de premios.
        </p>
      </div>

      <BaseAccordion v-if="accordionItems.length > 0" :items="accordionItems" :default-open-id="accordionItems[0]?.id" />

      <div v-else class="text-center py-12 bg-white rounded-guaiqui-xl border border-guaiqui-border text-guaiqui-text-muted space-y-2">
        <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
          <i class="bi bi-question-circle"></i>
        </div>
        <p class="text-sm font-medium">El centro de ayuda está en preparación. Pronto se publicarán preguntas frecuentes.</p>
      </div>

      <div v-if="accordionItems.length > 0" class="text-center pt-4">
        <NuxtLink :to="{ name: 'faq' }">
          <BaseButton variant="ghost" size="md">
            Ver todas las preguntas en el Centro de Ayuda →
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </section>
</template>
