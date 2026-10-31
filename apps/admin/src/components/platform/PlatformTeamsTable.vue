<script setup lang="ts">
export interface TeamRow {
  id: string
  name: string
  slug: string
  short_name: string | null
  logo_url: string | null
  primary_color: string | null
  secondary_color: string | null
  status: 'active' | 'inactive'
  sport: string
  joined_at: string
  paid_until: string | null
  billing_status: 'current' | 'expiring_soon' | 'expired' | 'no_payment'
  team_follower_count: number
  active_staff_count: number
}

defineProps<{
  teams: TeamRow[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'edit', team: TeamRow): void
  (e: 'recordPayment', team: TeamRow): void
  (e: 'viewHistory', team: TeamRow): void
  (e: 'toggleStatus', team: TeamRow): void
}>()

const formatDate = (isoString?: string | null) => {
  if (!isoString) return 'Sin fecha'
  const d = new Date(isoString)
  return d.toLocaleDateString('es-VE', { year: 'numeric', month: 'short', day: 'numeric' })
}

const getBillingBadgeClass = (status: TeamRow['billing_status']) => {
  switch (status) {
    case 'current':
      return 'bg-emerald-950/80 text-emerald-400 border-emerald-800'
    case 'expiring_soon':
      return 'bg-amber-950/80 text-amber-400 border-amber-800 animate-pulse'
    case 'expired':
      return 'bg-red-950/80 text-red-400 border-red-800'
    default:
      return 'bg-slate-800 text-slate-400 border-slate-700'
  }
}

const getBillingLabel = (status: TeamRow['billing_status']) => {
  switch (status) {
    case 'current':
      return 'Al Día'
    case 'expiring_soon':
      return 'Por Vencer'
    case 'expired':
      return 'Vencido'
    default:
      return 'Pendiente'
  }
}
</script>

<template>
  <div class="bg-slate-850 border border-slate-800 rounded-xl overflow-hidden shadow-sm">
    <!-- Loading State -->
    <div v-if="loading" class="p-12 text-center text-slate-400">
      <i class="bi bi-arrow-repeat animate-spin text-2xl text-emerald-500 mb-2 inline-block"></i>
      <p class="text-xs">Cargando clubes de la plataforma...</p>
    </div>

    <!-- Empty State -->
    <div v-else-if="teams.length === 0" class="p-12 text-center text-slate-400">
      <i class="bi bi-shield-x text-3xl text-slate-600 mb-2 inline-block"></i>
      <h3 class="text-sm font-semibold text-slate-300">No se encontraron clubes</h3>
      <p class="text-xs text-slate-500 mt-1">No hay franquicias que coincidan con los filtros seleccionados.</p>
    </div>

    <!-- Teams Table -->
    <div v-else class="overflow-x-auto">
      <table class="w-full text-left border-collapse text-xs">
        <thead>
          <tr class="border-b border-slate-800 bg-slate-900/60 text-slate-400 font-semibold uppercase tracking-wider">
            <th class="py-3 px-4">Club</th>
            <th class="py-3 px-4">Deporte</th>
            <th class="py-3 px-4">Ingreso</th>
            <th class="py-3 px-4">Estatus Servicio</th>
            <th class="py-3 px-4">Estado Club</th>
            <th class="py-3 px-4 text-center">Seguidores</th>
            <th class="py-3 px-4 text-center">Staff Activo</th>
            <th class="py-3 px-4 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-800 text-slate-300">
          <tr v-for="team in teams" :key="team.id" class="hover:bg-slate-800/40 transition-colors">
            <!-- Club Info -->
            <td class="py-3 px-4">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-lg bg-slate-800 border border-slate-700 p-1 flex items-center justify-center shrink-0">
                  <img v-if="team.logo_url" :src="team.logo_url" :alt="team.name" class="w-full h-full object-contain" />
                  <i v-else class="bi bi-shield-fill text-slate-500 text-base"></i>
                </div>
                <div>
                  <div class="font-bold text-white text-sm flex items-center gap-1.5">
                    {{ team.name }}
                    <span v-if="team.short_name" class="text-[11px] font-normal text-slate-400 font-mono">({{ team.short_name }})</span>
                  </div>
                  <div class="text-[11px] text-slate-400 font-mono">slug: {{ team.slug }}</div>
                </div>
              </div>
            </td>

            <!-- Sport -->
            <td class="py-3 px-4">
              <span class="capitalize px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 border border-slate-700 text-[11px] font-medium">
                {{ team.sport }}
              </span>
            </td>

            <!-- Joined at -->
            <td class="py-3 px-4 font-mono text-slate-400">
              {{ formatDate(team.joined_at) }}
            </td>

            <!-- Billing Status -->
            <td class="py-3 px-4">
              <div>
                <span :class="['px-2 py-0.5 text-[11px] font-semibold border rounded-full inline-block', getBillingBadgeClass(team.billing_status)]">
                  {{ getBillingLabel(team.billing_status) }}
                </span>
                <div class="text-[10px] text-slate-400 mt-0.5 font-mono">
                  Hasta: {{ formatDate(team.paid_until) }}
                </div>
              </div>
            </td>

            <!-- Team Status -->
            <td class="py-3 px-4">
              <span
                :class="[
                  'px-2 py-0.5 text-[11px] font-semibold rounded-full border inline-flex items-center gap-1',
                  team.status === 'active'
                    ? 'bg-emerald-950/80 text-emerald-400 border-emerald-800'
                    : 'bg-red-950/80 text-red-400 border-red-800'
                ]"
              >
                <span :class="['w-1.5 h-1.5 rounded-full', team.status === 'active' ? 'bg-emerald-400' : 'bg-red-400']"></span>
                {{ team.status === 'active' ? 'Activo' : 'Inactivo' }}
              </span>
            </td>

            <!-- Followers -->
            <td class="py-3 px-4 text-center font-mono font-semibold text-slate-200">
              {{ team.team_follower_count.toLocaleString() }}
            </td>

            <!-- Staff -->
            <td class="py-3 px-4 text-center font-mono font-semibold text-slate-200">
              {{ team.active_staff_count }}
            </td>

            <!-- Actions -->
            <td class="py-3 px-4 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <button
                  class="p-1.5 text-slate-400 hover:text-emerald-400 hover:bg-slate-800 rounded-md transition-colors"
                  title="Editar equipo"
                  @click="emit('edit', team)"
                >
                  <i class="bi bi-pencil-square"></i>
                </button>

                <button
                  class="p-1.5 text-slate-400 hover:text-blue-400 hover:bg-slate-800 rounded-md transition-colors"
                  title="Registrar pago"
                  @click="emit('recordPayment', team)"
                >
                  <i class="bi bi-credit-card-2-front"></i>
                </button>

                <button
                  class="p-1.5 text-slate-400 hover:text-purple-400 hover:bg-slate-800 rounded-md transition-colors"
                  title="Historial de pagos"
                  @click="emit('viewHistory', team)"
                >
                  <i class="bi bi-clock-history"></i>
                </button>

                <button
                  :class="[
                    'p-1.5 rounded-md transition-colors',
                    team.status === 'active' ? 'text-slate-400 hover:text-red-400 hover:bg-slate-800' : 'text-slate-400 hover:text-emerald-400 hover:bg-slate-800'
                  ]"
                  :title="team.status === 'active' ? 'Desactivar franquicia' : 'Reactivar franquicia'"
                  @click="emit('toggleStatus', team)"
                >
                  <i :class="team.status === 'active' ? 'bi bi-slash-circle' : 'bi bi-check-circle'"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
