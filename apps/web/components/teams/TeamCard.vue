<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseBadge } from '@guaiqui/ui'
import { formatPerlitas } from '@guaiqui/shared'

export interface TeamItem {
  id: string
  name: string
  slug: string
  short_name?: string | null
  logo_url?: string | null
  primary_color?: string | null
  secondary_color?: string | null
  follower_count: number
  is_following: boolean
}

const props = defineProps<{
  team: TeamItem
  isToggling?: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-follow', team: TeamItem): void
}>()

const logoError = ref(false)
</script>

<template>
  <BaseCard
    class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs hover:shadow-guaiqui-sm transition-all flex flex-col justify-between relative overflow-hidden"
  >
    <!-- Accent Color Top Bar -->
    <div
      class="absolute top-0 left-0 right-0 h-1"
      :style="{ backgroundColor: team.primary_color || '#005a36' }"
    ></div>

    <div class="space-y-4 pt-1">
      <!-- Header: Logo & Team Info -->
      <div class="flex items-start gap-3.5">
        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 p-2 flex items-center justify-center shrink-0 shadow-sm overflow-hidden">
          <img
            v-if="team.logo_url && !logoError"
            :src="team.logo_url"
            :alt="team.name"
            class="w-full h-full object-contain"
            @error="logoError = true"
          />
          <div
            v-else
            class="w-full h-full flex items-center justify-center font-display font-black text-lg text-guaiqui-primary"
          >
            <i class="bi bi-shield-shaded text-2xl"></i>
          </div>
        </div>

        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <h3 class="font-display font-bold text-base text-guaiqui-text truncate leading-tight">
              {{ team.name }}
            </h3>
            <BaseBadge
              v-if="team.is_following"
              variant="success"
              size="sm"
              class="shrink-0 text-[10px]"
            >
              Siguiendo
            </BaseBadge>
          </div>
          <p v-if="team.short_name" class="text-xs text-guaiqui-text-muted mt-0.5 truncate">
            {{ team.short_name }}
          </p>
          <div class="flex items-center gap-1.5 text-xs text-guaiqui-text-subtle mt-1.5">
            <i class="bi bi-people-fill text-guaiqui-primary"></i>
            <span>{{ formatPerlitas(team.follower_count || 0) }} seguidores</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Action Button -->
    <div class="mt-5 pt-3 border-t border-slate-100 flex items-center justify-end">
      <BaseButton
        :variant="team.is_following ? 'outline' : 'primary'"
        size="sm"
        :loading="isToggling"
        :disabled="isToggling"
        class="w-full sm:w-auto"
        @click="emit('toggle-follow', team)"
      >
        <template v-if="team.is_following">
          <i class="bi bi-check2 mr-1.5"></i>
          <span>Siguiendo</span>
        </template>
        <template v-else>
          <i class="bi bi-plus-lg mr-1.5"></i>
          <span>Seguir</span>
        </template>
      </BaseButton>
    </div>
  </BaseCard>
</template>
