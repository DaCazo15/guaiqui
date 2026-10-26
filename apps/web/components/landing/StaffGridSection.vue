<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { BaseCard, BaseBadge } from '@guaiqui/ui'
import { useGSAP } from '~/composables/useGSAP'

interface TeamMember {
  id: string
  name: string
  role: string
  category: string
  photo_url?: string | null
}

const supabase = useSupabaseClient()
const { gsap, ScrollTrigger } = useGSAP()
const sectionRef = ref<HTMLElement | null>(null)
const members = ref<TeamMember[]>([])
const loading = ref(true)
let ctx: gsap.Context | null = null

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('site_team_members')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      members.value = data.map((d: any) => ({
        id: d.id,
        name: d.name,
        role: d.role,
        category: d.group_category || 'Técnico',
        photo_url: d.photo_url || null,
      }))
    } else {
      members.value = []
    }
  } catch {
    members.value = []
  } finally {
    loading.value = false
  }

  await nextTick()
  if (sectionRef.value && members.value.length > 0) {
    ctx = gsap.context(() => {
      const mm = gsap.matchMedia()
      mm.add(
        {
          reduceMotion: '(prefers-reduced-motion: reduce)',
          all: '(min-width: 0px)',
        },
        (context) => {
          const { reduceMotion } = context.conditions as { reduceMotion: boolean }
          if (reduceMotion) return

          gsap.from('.staff-card', {
            y: 30,
            autoAlpha: 0,
            duration: 0.6,
            stagger: 0.08,
            ease: 'power2.out',
            scrollTrigger: {
              trigger: sectionRef.value,
              start: 'top 85%',
              once: true,
            },
          })
        }
      )
    }, sectionRef.value)
    ScrollTrigger.refresh()
  }
})

onUnmounted(() => {
  ctx?.revert()
})
</script>

<template>
  <section v-if="!loading && members.length > 0" ref="sectionRef" class="py-16 sm:py-24 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto space-y-12">
      <div class="text-center max-w-2xl mx-auto space-y-2">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest">Detrás del Equipo</span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          Cuerpo Técnico y Directiva
        </h2>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="s in members"
          :key="s.id"
          variant="default"
          padding="md"
          class="staff-card"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary font-display font-bold text-xl flex items-center justify-center border border-green-200 shrink-0 overflow-hidden">
              <img v-if="s.photo_url" :src="s.photo_url" class="w-full h-full object-cover" />
              <span v-else>{{ s.name.charAt(0) }}</span>
            </div>
            <div>
              <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
                {{ s.name }}
              </h3>
              <div class="text-xs text-guaiqui-text-muted mt-0.5">
                {{ s.role }}
              </div>
              <BaseBadge variant="soft" size="sm" class="mt-2">
                {{ s.category }}
              </BaseBadge>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
