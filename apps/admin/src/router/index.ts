import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'

import LoginView from '../pages/LoginView.vue'
import StaffQueueView from '../pages/StaffQueueView.vue'
import StaffScannerView from '../pages/StaffScannerView.vue'
import StaffRedemptionDetailView from '../pages/StaffRedemptionDetailView.vue'
import StaffIssuesView from '../pages/StaffIssuesView.vue'
import StaffInventoryView from '../pages/StaffInventoryView.vue'
import StaffFansView from '../pages/StaffFansView.vue'
import StaffTriviaView from '../pages/StaffTriviaView.vue'

import AdminDashboardView from '../pages/AdminDashboardView.vue'
import AdminAnalyticsView from '../pages/AdminAnalyticsView.vue'
import AdminTriviasView from '../pages/AdminTriviasView.vue'
import AdminProductsView from '../pages/AdminProductsView.vue'
import AdminPlayersView from '../pages/AdminPlayersView.vue'
import AdminGamesView from '../pages/AdminGamesView.vue'
import AdminEconomyView from '../pages/AdminEconomyView.vue'
import AdminPersonalView from '../pages/AdminPersonalView.vue'
import AdminFansView from '../pages/AdminFansView.vue'
import AdminSegmentsView from '../pages/AdminSegmentsView.vue'
import AdminRiskView from '../pages/AdminRiskView.vue'
import AdminIssuesView from '../pages/AdminIssuesView.vue'
import AdminAuditView from '../pages/AdminAuditView.vue'
import AdminAnnouncementsView from '../pages/AdminAnnouncementsView.vue'
import AdminCarouselView from '../pages/AdminCarouselView.vue'
import AdminHistoryView from '../pages/AdminHistoryView.vue'
import AdminTeamView from '../pages/AdminTeamView.vue'
import AdminFaqView from '../pages/AdminFaqView.vue'
import AdminStatsView from '../pages/AdminStatsView.vue'
import AdminPoliciesView from '../pages/AdminPoliciesView.vue'
import AdminInstagramView from '../pages/AdminInstagramView.vue'
import AdminLandingView from '../pages/AdminLandingView.vue'
import AdminBirthdayView from '../pages/AdminBirthdayView.vue'
import AdminLoginModalView from '../pages/AdminLoginModalView.vue'
import AdminAdsView from '../pages/AdminAdsView.vue'
import AdminCtaView from '../pages/AdminCtaView.vue'
import Enroll2FAView from '../pages/Enroll2FAView.vue'
import Verify2FAView from '../pages/Verify2FAView.vue'


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
      path: '/enroll-2fa',
      name: 'enroll-2fa',
      component: Enroll2FAView,
      meta: { requiresAuthOnly: true }
    },
    {
      path: '/verificar-2fa',
      name: 'verificar-2fa',
      component: Verify2FAView,
      meta: { requiresAuthOnly: true }
    },

    // Staff Routes
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
      path: '/staff/trivia',
      redirect: '/admin/trivias'
    },
    {
      path: '/staff/trivias',
      redirect: '/admin/trivias'
    },

    // Admin Routes (/admin/*)
    {
      path: '/admin',
      redirect: '/admin/dashboard'
    },
    {
      path: '/admin/dashboard',
      name: 'admin-dashboard',
      component: AdminDashboardView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/analitica',
      name: 'admin-analitica',
      component: AdminAnalyticsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/trivias',
      name: 'admin-trivias',
      component: AdminTriviasView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/productos',
      name: 'admin-productos',
      component: AdminProductsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/jugadores',
      name: 'admin-jugadores',
      component: AdminPlayersView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/partidos',
      name: 'admin-partidos',
      component: AdminGamesView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/economia',
      name: 'admin-economia',
      component: AdminEconomyView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/anuncios-recompensados',
      name: 'admin-rewarded-ads',
      component: AdminAdsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/personal',
      name: 'admin-personal',
      component: AdminPersonalView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/fanaticos',
      name: 'admin-fanaticos',
      component: AdminFansView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/segmentos',
      name: 'admin-segmentos',
      component: AdminSegmentsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/riesgo',
      name: 'admin-riesgo',
      component: AdminRiskView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/incidencias',
      name: 'admin-incidencias',
      component: AdminIssuesView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/auditoria',
      name: 'admin-auditoria',
      component: AdminAuditView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/landing',
      name: 'admin-landing',
      component: AdminLandingView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/cta',
      name: 'admin-cta',
      component: AdminCtaView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/anuncios',
      name: 'admin-anuncios',
      component: AdminAnnouncementsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/carrusel',
      name: 'admin-carrusel',
      component: AdminCarouselView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/historia',
      name: 'admin-historia',
      component: AdminHistoryView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/equipo',
      name: 'admin-equipo',
      component: AdminTeamView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/faq',
      name: 'admin-faq',
      component: AdminFaqView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/cifras',
      name: 'admin-cifras',
      component: AdminStatsView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/instagram',
      name: 'admin-instagram',
      component: AdminInstagramView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/contenido/modal-de-bienvenida',
      name: 'admin-login-modal',
      component: AdminLoginModalView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/politicas',

      name: 'admin-politicas',
      component: AdminPoliciesView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/admin/cumpleanos',
      name: 'admin-cumpleanos',
      component: AdminBirthdayView,
      meta: { requiresAdmin: true }
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/staff/cola'
    }
  ]
})

supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT') {
    const authStore = useAuthStore()
    authStore.user = null
    authStore.staffMember = null
    authStore.stopIdleMonitoring()
    if (router.currentRoute.value.name !== 'login') {
      router.replace({ name: 'login' })
    }
  }
})

router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()

  if (!authStore.isInitialized) {
    await authStore.checkAuth()
  }

  const isAuth = authStore.isAuthenticated

  if (isAuth && to.name !== 'enroll-2fa' && to.name !== 'verificar-2fa' && to.name !== 'login') {
    try {
      const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
      if (aalData) {
        if (aalData.currentLevel !== 'aal2') {
          if (aalData.nextLevel === 'aal2') {
            return next({ name: 'verificar-2fa' })
          } else {
            return next({ name: 'enroll-2fa' })
          }
        }
      }
    } catch (e) {
      console.warn('Error checking MFA assurance level:', e)
    }
  }

  if (to.meta.requiresAdmin) {
    if (!isAuth) {
      next({ name: 'login' })
    } else if (!authStore.isAdmin) {
      next({ name: 'staff-queue' })
    } else {
      next()
    }
  } else if (to.meta.requiresStaff) {
    if (!isAuth) {
      next({ name: 'login' })
    } else {
      next()
    }
  } else if (to.meta.guestOnly && isAuth) {
    if (authStore.isAdmin) {
      next({ name: 'admin-dashboard' })
    } else {
      next({ name: 'staff-queue' })
    }
  } else {
    next()
  }
})

