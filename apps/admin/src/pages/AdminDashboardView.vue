<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseCard, BaseBadge, BaseButton, BaseSkeletonLayout } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

const pendingIssuesCount = ref(0)
const lowStockCount = ref(0)
const draftTriviasCount = ref(0)
const totalFansCount = ref(0)
const loading = ref(true)

const loadDashboardMetrics = async () => {
  loading.value = true
  try {
    const { count: issueCount } = await supabase
      .from('redemptions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'issue')

    pendingIssuesCount.value = issueCount || 0

    const { count: lowStock } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true })
      .filter('stock', 'lte', 5)

    lowStockCount.value = lowStock || 0

    const { count: draftTrivias } = await supabase
      .from('trivias')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'draft')

    draftTriviasCount.value = draftTrivias || 0

    const { count: fans } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })

    totalFansCount.value = fans || 0
  } catch (err) {
    console.error('Error loading dashboard metrics:', err)
  } finally {
    loading.value = false
  }
}

onMounted(loadDashboardMetrics)
</script>

<template>
  <AdminLayout>
    <div v-if="loading" class="max-w-7xl mx-auto">
      <BaseSkeletonLayout :dark="true" :show-sidebar="false" />
    </div>

    <div v-else class="max-w-7xl mx-auto space-y-8">
      <!-- Title header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-white tracking-tight">
            Dashboard de Administración
          </h1>
          <p class="text-sm text-slate-400 mt-1">
            Resumen global de actividad, ítems pendientes y acceso rápido a módulos.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <BaseButton variant="secondary" size="sm" @click="loadDashboardMetrics" :loading="loading">
            <i class="bi bi-arrow-clockwise mr-1.5"></i> Actualizar
          </BaseButton>
        </div>
      </div>

      <!-- Pending alerts grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <BaseCard class="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl hover:border-amber-500/50 transition-all">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-slate-400 tracking-wider">Incidencias de Canje</span>
            <div class="p-2 bg-amber-950/60 text-amber-400 border border-amber-800/60 rounded-lg">
              <i class="bi bi-exclamation-triangle text-xl"></i>
            </div>
          </div>
          <div class="mt-3 text-3xl font-bold text-white font-title">
            {{ pendingIssuesCount }}
          </div>
          <div class="mt-2 flex items-center justify-between text-xs">
            <span class="text-slate-400">Requieren atención</span>
            <RouterLink to="/admin/incidencias" class="text-emerald-400 hover:text-emerald-300 font-semibold hover:underline">Ver incidencias &rarr;</RouterLink>
          </div>
        </BaseCard>

        <BaseCard class="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl hover:border-red-500/50 transition-all">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-slate-400 tracking-wider">Productos Stock Bajo</span>
            <div class="p-2 bg-red-950/60 text-red-400 border border-red-800/60 rounded-lg">
              <i class="bi bi-box-seam text-xl"></i>
            </div>
          </div>
          <div class="mt-3 text-3xl font-bold text-white font-title">
            {{ lowStockCount }}
          </div>
          <div class="mt-2 flex items-center justify-between text-xs">
            <span class="text-slate-400">&le; 5 unidades</span>
            <RouterLink to="/admin/productos" class="text-emerald-400 hover:text-emerald-300 font-semibold hover:underline">Revisar stock &rarr;</RouterLink>
          </div>
        </BaseCard>

        <BaseCard class="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl hover:border-blue-500/50 transition-all">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-slate-400 tracking-wider">Trivias por Publicar</span>
            <div class="p-2 bg-blue-950/60 text-blue-400 border border-blue-800/60 rounded-lg">
              <i class="bi bi-journal-text text-xl"></i>
            </div>
          </div>
          <div class="mt-3 text-3xl font-bold text-white font-title">
            {{ draftTriviasCount }}
          </div>
          <div class="mt-2 flex items-center justify-between text-xs">
            <span class="text-slate-400">Borradores pendientes</span>
            <RouterLink to="/admin/trivias" class="text-emerald-400 hover:text-emerald-300 font-semibold hover:underline">Publicar &rarr;</RouterLink>
          </div>
        </BaseCard>

        <BaseCard class="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl hover:border-emerald-500/50 transition-all">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-slate-400 tracking-wider">Fanáticos Registrados</span>
            <div class="p-2 bg-emerald-950/60 text-emerald-400 border border-emerald-800/60 rounded-lg">
              <i class="bi bi-people text-xl"></i>
            </div>
          </div>
          <div class="mt-3 text-3xl font-bold text-white font-title">
            {{ totalFansCount }}
          </div>
          <div class="mt-2 flex items-center justify-between text-xs">
            <span class="text-slate-400">Fanáticos activos</span>
            <RouterLink to="/admin/fanaticos" class="text-emerald-400 hover:text-emerald-300 font-semibold hover:underline">Gestionar &rarr;</RouterLink>
          </div>
        </BaseCard>
      </div>

      <!-- Quick Access shortcuts -->
      <BaseCard class="bg-slate-900 border border-slate-800 p-6 rounded-2xl shadow-xl space-y-4">
        <h2 class="text-lg font-bold text-white flex items-center gap-2">
          <i class="bi bi-lightning-charge text-emerald-400"></i> Acceso Rápido a Módulos
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <RouterLink to="/admin/trivias" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-question-circle text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Editor de Trivias</div>
              <div class="text-xs text-slate-400">Crear, validar y publicar trivias con preguntas</div>
            </div>
          </RouterLink>

          <RouterLink to="/admin/productos" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-box-seam text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Gestión de Productos</div>
              <div class="text-xs text-slate-400">Variantes, imágenes, stock y costos de perlitas</div>
            </div>
          </RouterLink>

          <RouterLink to="/admin/personal" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-person-gear text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Personal y Roles</div>
              <div class="text-xs text-slate-400">Invitar staff/admin y administrar permisos</div>
            </div>
          </RouterLink>

          <RouterLink to="/admin/segmentos" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-pie-chart text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Segmentos de Fans</div>
              <div class="text-xs text-slate-400">Filtrar audiencia y exportar CSV auditado</div>
            </div>
          </RouterLink>

          <RouterLink to="/admin/economia" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-coin text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Reglas Económicas</div>
              <div class="text-xs text-slate-400">Caps diarios/semanales y bonos de racha</div>
            </div>
          </RouterLink>

          <RouterLink to="/admin/auditoria" class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-emerald-500 hover:bg-slate-800/50 transition-all flex items-center gap-4 group">
            <div class="p-3 rounded-lg bg-emerald-950/80 text-emerald-400 group-hover:scale-105 transition-transform">
              <i class="bi bi-shield-check text-2xl"></i>
            </div>
            <div>
              <div class="font-semibold text-slate-100 group-hover:text-emerald-400 transition-colors">Registros de Auditoría</div>
              <div class="text-xs text-slate-400">Inspeccionar actividad e historial inmutable</div>
            </div>
          </RouterLink>
        </div>
      </BaseCard>

      <!-- Note on charts -->
      <div class="p-4 rounded-xl bg-emerald-950/40 border border-emerald-800/80 text-xs text-emerald-300 flex items-center gap-3">
        <i class="bi bi-info-circle text-emerald-400 text-lg"></i>
        <span><strong>Nota de plataforma:</strong> El dashboard completo de analítica avanzada y gráficos interactivos se visualiza en la sección de <strong>Analítica</strong>.</span>
      </div>
    </div>
  </AdminLayout>
</template>
