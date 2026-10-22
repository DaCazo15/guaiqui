<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface MilestoneItem {
  id: string
  year: string
  title: string
  description: string
}

const supabase = useSupabaseClient()
const milestones = ref<MilestoneItem[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('history_milestones')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      milestones.value = data.map((m: any) => ({
        id: m.id,
        year: m.year,
        title: m.title,
        description: m.text,
      }))
    } else {
      milestones.value = []
    }
  } catch {
    milestones.value = []
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section v-if="!loading && milestones.length > 0" class="py-16 sm:py-24 bg-white px-4 sm:px-8">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="text-center max-w-3xl mx-auto space-y-3">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
          Orgullo Insular
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Línea del Tiempo Histórica
        </h2>
        <p class="text-guaiqui-text-muted text-base">
          De La Asunción para toda Venezuela. Hitos que construyeron la leyenda del club.
        </p>
      </div>

      <div class="relative border-l-2 border-guaiqui-primary/30 ml-4 sm:ml-32 space-y-8">
        <div
          v-for="m in milestones"
          :key="m.id"
          class="relative pl-6 sm:pl-8 group"
        >
          <!-- Bullet Dot -->
          <div class="absolute -left-[9px] top-1.5 w-4 h-4 rounded-full bg-guaiqui-primary border-4 border-white group-hover:scale-125 transition-transform" />

          <!-- Year Tag -->
          <div class="sm:absolute sm:-left-32 sm:top-1 font-display font-extrabold text-xl text-guaiqui-primary tracking-tight mb-1 sm:mb-0 sm:text-right sm:w-24">
            {{ m.year }}
          </div>

          <div class="bg-guaiqui-surface p-5 rounded-guaiqui-lg border border-guaiqui-border space-y-1 shadow-xs">
            <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
              {{ m.title }}
            </h3>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed">
              {{ m.description }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
