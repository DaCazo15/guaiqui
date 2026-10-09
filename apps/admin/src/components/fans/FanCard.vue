<script setup lang="ts">
defineProps<{
  fan: any
}>()

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('es-VE', {
    dateStyle: 'medium'
  })
}
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl space-y-4">
    <!-- Header: Display Name & Avatar (NO email or birthdate!) -->
    <div class="flex items-center justify-between border-b border-slate-800 pb-4">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-bold text-lg overflow-hidden">
          <img v-if="fan.avatar_url" :src="fan.avatar_url" :alt="fan.display_name" class="w-full h-full object-cover" />
          <span v-else>{{ (fan.display_name || 'F')[0] }}</span>
        </div>
        <div>
          <h3 class="font-bold text-base text-white">{{ fan.display_name }}</h3>
          <span class="text-xs text-slate-400 font-mono">ID: {{ fan.id?.slice(0, 8) }}...</span>
        </div>
      </div>

      <div class="text-right">
        <span class="text-[11px] text-slate-400 uppercase font-semibold block mb-0.5">Saldo en Billetera</span>
        <span class="font-bold text-emerald-400 text-lg">{{ fan.pearl_balance }} perlitas</span>
      </div>
    </div>

    <!-- Last 5 Redemptions -->
    <div class="space-y-2">
      <h4 class="font-semibold text-xs text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
        <i class="bi bi-clock-history text-emerald-400"></i>
        Últimos Canjes Realizados (Máx 5)
      </h4>

      <div v-if="!fan.last_5_redemptions || fan.last_5_redemptions.length === 0" class="text-xs text-slate-500 italic p-3 bg-slate-950/60 rounded-xl border border-slate-800/80">
        Este fanático no ha registrado canjes recientemente.
      </div>

      <div v-else class="space-y-2">
        <div
          v-for="r in fan.last_5_redemptions"
          :key="r.id"
          class="p-3 bg-slate-950/60 border border-slate-800/80 rounded-xl text-xs flex items-center justify-between"
        >
          <div>
            <div class="font-semibold text-white">{{ r.product_name }}</div>
            <div class="text-[11px] text-slate-400">
              <span v-if="r.variant" class="font-mono text-slate-300 mr-2">Talla: {{ r.variant }}</span>
              <span>{{ formatDate(r.created_at) }}</span>
            </div>
          </div>

          <div class="text-right">
            <span class="px-2 py-0.5 bg-slate-800 text-emerald-400 rounded-md font-mono text-[11px] uppercase font-bold block mb-1">
              {{ r.status }}
            </span>
            <span class="text-[11px] text-emerald-400 font-semibold">{{ r.cost_pearls }} 🦪</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
