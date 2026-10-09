import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

import LoginView from '../pages/LoginView.vue'
import StaffQueueView from '../pages/StaffQueueView.vue'
import StaffScannerView from '../pages/StaffScannerView.vue'
import StaffRedemptionDetailView from '../pages/StaffRedemptionDetailView.vue'
import StaffIssuesView from '../pages/StaffIssuesView.vue'
import StaffInventoryView from '../pages/StaffInventoryView.vue'
import StaffFansView from '../pages/StaffFansView.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: '/staff/cola'
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
      meta: { guestOnly: true }
    },
    {
      path: '/staff/cola',
      name: 'staff-queue',
      component: StaffQueueView,
      meta: { requiresStaff: true }
    },
    {
      path: '/staff/escaner',
      name: 'staff-scanner',
      component: StaffScannerView,
      meta: { requiresStaff: true }
    },
    {
      path: '/staff/canjes/:id',
      name: 'staff-redemption-detail',
      component: StaffRedemptionDetailView,
      meta: { requiresStaff: true }
    },
    {
      path: '/staff/incidencias',
      name: 'staff-issues',
      component: StaffIssuesView,
      meta: { requiresStaff: true }
    },
    {
      path: '/staff/inventario',
      name: 'staff-inventory',
      component: StaffInventoryView,
      meta: { requiresStaff: true }
    },
    {
      path: '/staff/fanaticos',
      name: 'staff-fans',
      component: StaffFansView,
      meta: { requiresStaff: true }
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/staff/cola'
    }
  ]
})

router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  const isAuth = await authStore.checkAuth()

  if (to.meta.requiresStaff && !isAuth) {
    next({ name: 'login' })
  } else if (to.meta.guestOnly && isAuth) {
    next({ name: 'staff-queue' })
  } else {
    next()
  }
})
