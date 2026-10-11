<script setup lang="ts">
import { retiredJerseys } from '~/data/hallOfFameData'
</script>

<template>
  <section class="py-14 sm:py-20 bg-guaiqui-surface px-4 sm:px-8 border-b border-guaiqui-border">
    <div class="max-w-6xl mx-auto space-y-10">
      <div class="text-center max-w-2xl mx-auto space-y-2">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full border border-guaiqui-primary/20">
          En lo Más Alto de El Fortín
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Dorsales Retirados
        </h2>
        <p class="text-sm text-guaiqui-text-muted">
          Números inmortales que cuelgan del techo del Gimnasio Ciudad de La Asunción como tributo a su entrega total.
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="jersey in retiredJerseys"
          :key="jersey.number"
          class="bg-white rounded-guaiqui-xl border border-guaiqui-border shadow-guaiqui-sm hover:shadow-guaiqui-md transition-all duration-200 overflow-hidden flex flex-col justify-between group"
        >
          <!-- Top Jersey Banner -->
          <div class="bg-gradient-to-br from-guaiqui-primary to-emerald-900 p-6 text-white text-center relative overflow-hidden">
            <!-- Decorative Subtle Basketball Texture Lines -->
            <div class="absolute inset-0 opacity-10 bg-[radial-gradient(#fff_1px,transparent_1px)] [background-size:12px_12px]" />

            <!-- Giant Number -->
            <div class="font-display font-black text-6xl text-white tracking-tighter drop-shadow-md group-hover:scale-105 transition-transform duration-200">
              #{{ jersey.number }}
            </div>

            <!-- Position & Years -->
            <div class="mt-1 flex items-center justify-center gap-2 text-xs font-medium text-emerald-200">
              <span>{{ jersey.position }}</span>
              <span>•</span>
              <span>{{ jersey.years }}</span>
            </div>
          </div>

          <!-- Body Content -->
          <div class="p-6 space-y-3 flex-1 flex flex-col justify-between">
            <div class="space-y-1.5">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
                    {{ jersey.name }}
                  </h3>
                  <p class="text-xs font-semibold text-guaiqui-primary italic">
                    "{{ jersey.nickname }}"
                  </p>
                </div>
                <span class="inline-flex items-center gap-1 px-2.5 py-1 bg-amber-50 text-amber-800 rounded-full text-xs font-bold border border-amber-200 shrink-0">
                  <i class="bi bi-trophy-fill text-amber-500 text-[10px]"></i>
                  <span>{{ jersey.titlesCount }} {{ jersey.titlesCount === 1 ? 'título' : 'títulos' }}</span>
                </span>
              </div>

              <p class="text-xs text-guaiqui-text-muted leading-relaxed pt-1">
                {{ jersey.description }}
              </p>
            </div>

            <div class="pt-3 border-t border-guaiqui-border flex items-center gap-2 text-xs font-medium text-guaiqui-text">
              <i :class="['bi', jersey.badgeIcon, 'text-guaiqui-primary text-sm shrink-0']"></i>
              <span class="truncate">{{ jersey.highlight }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
