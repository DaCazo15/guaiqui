<script setup lang="ts">
import type { UserSearchResultItem } from '@guaiqui/shared'

defineProps<{
  user: UserSearchResultItem
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'action', userId: string, currentStatus: string): void
}>()
</script>

<template>
  <article
    class="relative flex flex-col justify-between p-4 sm:p-5 rounded-2xl bg-white hover:bg-slate-50/70 border border-slate-200/90 hover:border-emerald-500/50 shadow-xs hover:shadow-md transition-all duration-200 group"
  >
    <!-- Header / User Info -->
    <div class="flex items-start gap-3.5 min-w-0">
      <NuxtLink :to="`/u/${user.id}`" class="relative shrink-0 block cursor-pointer">
        <img
          v-if="user.avatar_url"
          :src="user.avatar_url"
          :alt="user.display_name"
          class="w-12 h-12 rounded-2xl object-cover border border-slate-200 ring-2 ring-emerald-500/10 group-hover:ring-emerald-500/30 transition-all shadow-xs"
        />
        <div
          v-else
          class="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-600 via-emerald-700 to-teal-800 text-white font-extrabold text-base flex items-center justify-center shadow-xs ring-2 ring-emerald-500/10 group-hover:ring-emerald-500/30 transition-all uppercase"
        >
          {{ user.display_name?.charAt(0) || 'F' }}
        </div>
      </NuxtLink>

      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-1.5">
          <NuxtLink
            :to="`/u/${user.id}`"
            class="font-bold text-sm text-slate-900 group-hover:text-emerald-700 transition-colors truncate block"
            :title="user.display_name"
          >
            {{ user.display_name }}
          </NuxtLink>
          <i
            class="bi bi-patch-check-fill text-emerald-600 text-xs shrink-0"
            title="Fanático Verificado"
          ></i>
        </div>

        <div class="flex items-center gap-1.5 mt-1.5">
          <span
            v-if="user.favorite_sport"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200/60 truncate"
          >
            <i class="bi bi-dribbble text-[10px] text-emerald-600"></i>
            <span>{{ user.favorite_sport }}</span>
          </span>
          <span
            v-else
            class="inline-flex items-center gap-1 text-[11px] font-medium text-slate-400"
          >
            <i class="bi bi-person-heart text-xs text-slate-400"></i>
            <span>Fan de La Tribu</span>
          </span>
        </div>
      </div>
    </div>

    <!-- Actions Footer -->
    <div class="grid grid-cols-2 gap-2 mt-4 pt-3.5 border-t border-slate-100">
      <NuxtLink
        :to="`/u/${user.id}`"
        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 hover:text-slate-900 transition-all cursor-pointer select-none active:scale-[0.98]"
      >
        <i class="bi bi-person text-xs text-slate-500"></i>
        <span>Ver Perfil</span>
      </NuxtLink>

      <button
        v-if="user.relation_status !== 'incoming_pending'"
        type="button"
        :disabled="loading"
        @click="emit('action', user.id, user.relation_status)"
        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer select-none active:scale-[0.98] disabled:opacity-60 disabled:cursor-not-allowed"
        :class="[
          user.relation_status === 'none'
            ? 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-xs hover:shadow-emerald-950/20'
            : user.relation_status === 'pending'
              ? 'bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-200/90'
              : 'bg-slate-100 hover:bg-rose-50 text-slate-700 hover:text-rose-700 hover:border-rose-200 border border-slate-200/90 group/btn'
        ]"
      >
        <template v-if="user.relation_status === 'none'">
          <i class="bi bi-person-plus-fill text-xs"></i>
          <span>Seguir</span>
        </template>
        <template v-else-if="user.relation_status === 'pending'">
          <i class="bi bi-hourglass-split text-xs text-amber-600"></i>
          <span>Pendiente</span>
        </template>
        <template v-else-if="user.relation_status === 'accepted'">
          <i class="bi bi-check2 text-xs text-emerald-600 group-hover/btn:hidden"></i>
          <i class="bi bi-person-dash text-xs text-rose-600 hidden group-hover/btn:inline"></i>
          <span class="group-hover/btn:hidden">Siguiendo</span>
          <span class="hidden group-hover/btn:inline">Dejar</span>
        </template>
      </button>

      <NuxtLink
        v-else
        :to="`/u/${user.id}`"
        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-sky-800 bg-sky-50 border border-sky-200/90 hover:bg-sky-100 transition-all select-none cursor-pointer active:scale-[0.98]"
      >
        <i class="bi bi-reply-fill text-xs text-sky-600"></i>
        <span>Te sigue</span>
      </NuxtLink>
    </div>
  </article>
</template>
