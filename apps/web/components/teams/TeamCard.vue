<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
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
    class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-xs hover:shadow-guaiqui-md transition-all flex flex-col justify-between relative overflow-hidden text-center group"
  >
    <!-- Accent Color Top Bar -->
    <div
      class="absolute top-0 left-0 right-0 h-1.5"
      :style="{ backgroundColor: team.primary_color || '#005a36' }"
    ></div>

    <!-- Centered Content: Logo, Name & Follower Info -->
    <div class="flex flex-col items-center pt-2">
      <!-- Centered Team Logo -->
      <NuxtLink
        :to="team.slug ? `/app/e/${team.slug}` : undefined"
        class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-2xl"
        :title="`Ver ${team.name}`"
      >
        <div class="w-20 h-20 rounded-2xl bg-slate-50 border border-slate-200 p-2.5 flex items-center justify-center shadow-xs overflow-hidden mx-auto group-hover:scale-105 group-hover:border-slate-300 transition-all">
          <img
            v-if="team.logo_url && !logoError"
            :src="team.logo_url"
            :alt="team.name"
            class="w-full h-full object-contain"
            @error="logoError = true"
          />
          <div
            v-else
            class="w-full h-full flex items-center justify-center font-display font-black text-2xl text-guaiqui-primary"
          >
            <i class="bi bi-shield-shaded text-3xl"></i>
          </div>
        </div>
      </NuxtLink>

      <!-- Team Name below logo -->
      <div class="mt-3.5 space-y-1 w-full">
        <NuxtLink
          :to="team.slug ? `/app/e/${team.slug}` : undefined"
          class="block group-hover:text-guaiqui-primary transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary rounded-lg"
        >
          <h3 class="font-display font-bold text-base sm:text-lg text-guaiqui-text leading-snug line-clamp-2 px-1">
            {{ team.name }}
          </h3>
        </NuxtLink>

        <p v-if="team.short_name" class="text-xs text-guaiqui-text-muted font-medium truncate">
          {{ team.short_name }}
        </p>

        <div class="flex items-center justify-center gap-1.5 text-xs text-guaiqui-text-subtle pt-0.5">
          <i class="bi bi-people-fill text-guaiqui-primary"></i>
          <span>{{ formatPerlitas(team.follower_count || 0) }} seguidores</span>
        </div>
      </div>
    </div>

    <!-- Divider Line -->
    <div class="w-full border-t border-slate-100 my-4"></div>

    <!-- Follow Action Button -->
    <div class="w-full">
      <BaseButton
        :variant="team.is_following ? 'outline' : 'primary'"
        size="sm"
        :loading="isToggling"
        :disabled="isToggling"
        class="w-full justify-center"
        @click="emit('toggle-follow', team)"
      >
        <template v-if="team.is_following">
          <i class="bi bi-check2 mr-1.5 text-base"></i>
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
