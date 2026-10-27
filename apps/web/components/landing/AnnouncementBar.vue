<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseBadge } from '@guaiqui/ui'

const supabase = useSupabaseClient()
const isVisible = ref(true)
const announcementText = ref<string | null>(null)
const announcementLink = ref<string | null>(null)

const dismiss = () => {
  isVisible.value = false
}

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('site_announcements')
      .select('*')
      .eq('is_published', true)
      .order('starts_at', { ascending: false })
      .limit(1)

    const items = data as any[]
    if (items && items.length > 0) {
      announcementText.value = items[0].message
      announcementLink.value = items[0].link_url || null
    }
  } catch (_e) {
    announcementText.value = null
  }
})
</script>

<template>
  <div
    v-if="isVisible && announcementText"
    class="bg-guaiqui-primary-dark text-white text-xs sm:text-sm py-2 px-4 flex items-center justify-between border-b border-emerald-800 relative z-50 select-none"
  >
    <div class="max-w-6xl mx-auto flex items-center justify-center gap-2 text-center flex-1 pr-6">
      <BaseBadge variant="accent" size="sm" class="hidden sm:inline-flex">ANUNCIO</BaseBadge>
      <span class="font-medium text-emerald-100 flex items-center gap-1.5 flex-wrap justify-center">
        <a v-if="announcementLink" :href="announcementLink" target="_blank" class="hover:underline flex items-center gap-1">
          <i class="bi bi-megaphone text-emerald-400"></i>
          <span>{{ announcementText }}</span>
        </a>
        <span v-else class="flex items-center gap-1">
          <i class="bi bi-megaphone text-emerald-400"></i>
          <span>{{ announcementText }}</span>
        </span>
      </span>
    </div>

    <button
      type="button"
      class="text-emerald-300 hover:text-white p-1 rounded-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-white"
      aria-label="Cerrar anuncio"
      @click="dismiss"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  </div>
</template>
