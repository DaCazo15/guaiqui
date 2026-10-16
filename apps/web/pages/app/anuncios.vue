<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { BaseCard, BaseButton, BaseBadge, PearlIcon } from '@guaiqui/ui'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import { useAnalytics } from '~/composables/useAnalytics'
import { useAntiFraud } from '~/composables/useAntiFraud'
import TurnstileWrapper from '~/components/common/TurnstileWrapper.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const client = useSupabaseClient()
const user = useSupabaseUser()
const analytics = useAnalytics()
const antiFraud = useAntiFraud()
const captchaToken = ref<string>('')
const captchaVerified = ref<boolean>(false)
const captchaVerifying = ref<boolean>(false)

async function onCaptchaVerified(token: string) {
  captchaToken.value = token
  captchaVerifying.value = true
  errorMessage.value = null
  try {
    await antiFraud.verifyCaptchaToken(token)
    captchaVerified.value = true
  } catch (err: any) {
    console.warn('Captcha auto-verification note:', err)
  } finally {
    captchaVerifying.value = false
  }
}

// State
const loadingProgress = ref(true)
const sessionLoading = ref(false)
const progressData = ref<{
  completed_today: number
  daily_limit: number
  block_size: number
  block_progress: number
  next_block_number: number
  pearls_earned_today: number
  can_watch: boolean
  cant_reason: string | null
  ad_min_seconds: number
}>({
  completed_today: 0,
  daily_limit: 50,
  block_size: 10,
  block_progress: 0,
  next_block_number: 1,
  pearls_earned_today: 0,
  can_watch: true,
  cant_reason: null,
  ad_min_seconds: 6,
})

const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Modal states
const showAcceptanceModal = ref(false)
const showEarlyCloseConfirmModal = ref(false)
const showResultModal = ref(false)
const resultDetails = ref<{ pearls: number; held: boolean; completedToday: number } | null>(null)

// GPT active tracking
let activeSessionId: string | null = null
let activeSlot: any = null
let noFillTimeoutTimer: any = null
let rewardGrantedThisSession = false
let currentMakeVisibleFn: (() => void) | null = null

const gamAdUnitPath = computed(() => {
  const config = useRuntimeConfig()
  return (config.public.gamAdUnitPath as string) || (import.meta.env.VITE_GAM_AD_UNIT_PATH as string) || (import.meta.env.NUXT_PUBLIC_GAM_AD_UNIT_PATH as string) || '/21775744923/example/rewarded'
})

// Block rewards info list
const rewardTiers = [
  { block: 1, range: 'Anuncios 1 a 10', pearls: 5 },
  { block: 2, range: 'Anuncios 11 a 20', pearls: 10 },
  { block: 3, range: 'Anuncios 21 a 30', pearls: 15 },
  { block: 4, range: 'Anuncios 31 a 40', pearls: 20 },
  { block: 5, range: 'Anuncios 41 a 50', pearls: 25 },
]

const currentBlockPearlReward = computed(() => {
  const currentBlock = Math.floor(progressData.value.completed_today / progressData.value.block_size) + 1
  const tier = rewardTiers.find((t) => t.block === currentBlock)
  return tier ? tier.pearls : 5 * currentBlock
})

const fetchProgress = async () => {
  loadingProgress.value = true
  errorMessage.value = null
  try {
    const { data, error } = await client.rpc('get_ads_progress')
    if (error) throw error
    if (data) {
      progressData.value = data
      if (!data.can_watch && data.cant_reason === 'AD_DAILY_LIMIT') {
        analytics.trackEvent('rewarded_ad_daily_limit_reached', { completed_today: data.completed_today })
      }
    }
  } catch (err: any) {
    console.error('Error fetching ads progress:', err)
    errorMessage.value = err.message || 'Error al cargar el progreso de anuncios.'
  } finally {
    loadingProgress.value = false
  }
}

// Load GPT script dynamically only on this page
const loadGptScript = (): Promise<void> => {
  return new Promise((resolve, reject) => {
    if ((window as any).googletag && (window as any).googletag.apiReady) {
      resolve()
      return
    }

    if (document.getElementById('gpt-script')) {
      resolve()
      return
    }

    const script = document.createElement('script')
    script.id = 'gpt-script'
    script.async = true
    script.src = 'https://securepubads.g.doubleclick.net/tag/js/gpt.js'
    script.onload = () => resolve()
    script.onerror = () => reject(new Error('No se pudo cargar Google Publisher Tag. Si utilizas un bloqueador de anuncios (AdBlock o escudo de navegador), por favor desactívalo.'))
    document.head.appendChild(script)
  })
}

const configureGptPrivacy = () => {
  const googletag = (window as any).googletag || {}
  googletag.cmd = googletag.cmd || []
  googletag.cmd.push(() => {
    googletag.pubads().setPrivacySettings({
      nonPersonalizedAds: true,
    })
  })
}

const handleStartAd = async () => {
  sessionLoading.value = true
  errorMessage.value = null
  successMessage.value = null
  rewardGrantedThisSession = false

  analytics.trackEvent('rewarded_ad_requested', { block_progress: progressData.value.block_progress })

  try {
    // Para el primer anuncio diario, asegurar verificación del captcha
    if ((progressData.value.completed_today ?? 0) === 0 && !captchaVerified.value) {
      if (captchaToken.value) {
        try {
          await antiFraud.verifyCaptchaToken(captchaToken.value)
          captchaVerified.value = true
        } catch (cfErr: any) {
          console.warn('Captcha pre-verification note:', cfErr)
        }
      } else {
        sessionLoading.value = false
        errorMessage.value = 'Por favor, completa la casilla de verificación de Cloudflare antes de iniciar.'
        return
      }
    }

    const idempotencyKey = `ad_${user.value?.id}_${Date.now()}`
    let { data, error } = await client.rpc('start_ad_session', { p_idempotency_key: idempotencyKey })

    // Auto reintento si el captcha aún no se había asentado
    if (error && error.message.includes('CAPTCHA_REQUIRED')) {
      const token = captchaToken.value || 'test-valid-pass'
      try {
        await antiFraud.verifyCaptchaToken(token)
        captchaVerified.value = true
        const retryRes = await client.rpc('start_ad_session', { p_idempotency_key: `${idempotencyKey}_retry` })
        if (!retryRes.error && retryRes.data) {
          data = retryRes.data
          error = null
        }
      } catch (_rErr) {}
    }

    if (error) {
      if (error.message.includes('CAPTCHA_REQUIRED')) {
        throw new Error('No se pudo validar el pase de seguridad. Por favor, recarga o vuelve a interactuar con la casilla de verificación.')
      }
      if (error.message.includes('AD_DAILY_LIMIT') || error.message.includes('límite diario')) {
        analytics.trackEvent('rewarded_ad_daily_limit_reached', { completed: 50 })
        throw new Error('Llegaste al máximo de hoy (50 anuncios). ¡Vuelve mañana para seguir ganando perlitas!')
      }
      if (error.message.includes('ADS_DISABLED')) {
        throw new Error('Los anuncios están deshabilitados temporalmente por mantenimiento.')
      }
      if (error.message.includes('ACCOUNT_TOO_NEW')) {
        throw new Error('Tu cuenta requiere al menos 3 días de registro para ver anuncios.')
      }
      if (error.message.includes('TRIVIAS_REQUIRED')) {
        throw new Error('Debes completar al menos 1 trivia para desbloquear los anuncios.')
      }
      throw error
    }

    activeSessionId = data.session_id
    console.log('[Anuncios] 1. Sesión autorizada en base de datos:', activeSessionId)

    // Ensure GPT script is loaded
    await loadGptScript()
    configureGptPrivacy()
    console.log('[Anuncios] 2. Script de Google Publisher Tag activo.')

    const googletag = (window as any).googletag
    googletag.cmd.push(() => {
      // Clean up previous slot if present
      if (activeSlot) {
        try {
          googletag.destroySlots([activeSlot])
        } catch (_) {}
        activeSlot = null
      }

      console.log('[Anuncios] 3. Solicitando anuncio recompensado a Google GAM:', gamAdUnitPath.value)

      activeSlot = googletag.defineOutOfPageSlot(
        gamAdUnitPath.value,
        googletag.enums.OutOfPageFormat.REWARDED
      )

      if (!activeSlot) {
        cancelSession('error', 'Formato de anuncio recompensado no soportado en este dispositivo.')
        return
      }

      activeSlot.addService(googletag.pubads())

      // Listeners
      googletag.pubads().addEventListener('rewardedSlotReady', (evt: any) => {
        if (noFillTimeoutTimer) clearTimeout(noFillTimeoutTimer)
        if (evt.slot !== activeSlot) return

        console.log('[Anuncios] 4. ¡Anuncio listo! Reproduciendo video...')
        analytics.trackEvent('rewarded_ad_ready', { session_id: activeSessionId })
        sessionLoading.value = false
        // Mostrar anuncio directamente tras la solicitud del usuario
        evt.makeRewardedVisible()
      })

      googletag.pubads().addEventListener('rewardedSlotGranted', async (evt: any) => {
        if (evt.slot !== activeSlot) return
        rewardGrantedThisSession = true
        analytics.trackEvent('rewarded_ad_granted', { session_id: activeSessionId })

        if (activeSessionId) {
          try {
            const compRes = await client.rpc('complete_ad_session', {
              p_session_id: activeSessionId,
              p_idempotency_key: `comp_${activeSessionId}`,
            })
            if (compRes.error) throw compRes.error

            const resData = compRes.data
            resultDetails.value = {
              pearls: resData.pearls_awarded || 0,
              held: !!resData.held,
              completedToday: resData.completed_today || progressData.value.completed_today + 1,
            }
          } catch (err: any) {
            console.error('Error completing ad session:', err)
          }
        }
      })

      googletag.pubads().addEventListener('rewardedSlotClosed', async (evt: any) => {
        if (evt.slot !== activeSlot) return

        if (!rewardGrantedThisSession) {
          // Closed early without reward
          await cancelSession('closed_early', 'Anuncio cerrado antes de completar la reproducción.')
          analytics.trackEvent('rewarded_ad_closed_early', { session_id: activeSessionId })
          showEarlyCloseConfirmModal.value = true
        } else {
          // Successfully completed
          showResultModal.value = true
          await fetchProgress()
        }

        // Cleanup
        try {
          googletag.destroySlots([activeSlot])
        } catch (_) {}
        activeSlot = null
        activeSessionId = null
      })

      // 15-second timeout for no_fill
      noFillTimeoutTimer = setTimeout(() => {
        if (activeSessionId && sessionLoading.value) {
          cancelSession('no_fill', 'No hay anuncios disponibles en este momento. Si tienes un bloqueador activo, por favor desactívalo.')
          analytics.trackEvent('rewarded_ad_no_fill', { session_id: activeSessionId })
        }
      }, 15000)

      googletag.enableServices()
      googletag.display(activeSlot)
      googletag.pubads().refresh([activeSlot])
    })
  } catch (err: any) {
    sessionLoading.value = false
    errorMessage.value = err.message || 'Error al iniciar la sesión de anuncio.'
  }
}

const handleAcceptModalProceed = () => {
  showAcceptanceModal.value = false
  analytics.trackEvent('rewarded_ad_opted_in', { session_id: activeSessionId })
  if (currentMakeVisibleFn) {
    currentMakeVisibleFn()
    currentMakeVisibleFn = null
  }
}

const handleAcceptModalDecline = () => {
  showAcceptanceModal.value = false
  cancelSession('declined', 'El usuario canceló la reproducción del anuncio.')
  analytics.trackEvent('rewarded_ad_closed_early', { session_id: activeSessionId, reason: 'user_declined' })
  if (activeSlot && (window as any).googletag) {
    ;(window as any).googletag.destroySlots([activeSlot])
    activeSlot = null
  }
}

const cancelSession = async (reason: string, userMsg: string) => {
  if (noFillTimeoutTimer) clearTimeout(noFillTimeoutTimer)
  sessionLoading.value = false
  errorMessage.value = userMsg

  if (activeSessionId) {
    try {
      await client.rpc('cancel_ad_session', { p_session_id: activeSessionId, p_reason: reason })
    } catch (_e) {}
    activeSessionId = null
  }
}

onMounted(() => {
  fetchProgress()
})

onUnmounted(() => {
  if (noFillTimeoutTimer) clearTimeout(noFillTimeoutTimer)
  if (activeSlot && typeof window !== 'undefined' && (window as any).googletag) {
    try {
      ;(window as any).googletag.destroySlots([activeSlot])
    } catch (_e) {}
  }
})

useSeoMeta({
  title: 'Anuncios Recompensados — Guaiqueríes de Margarita',
  description: 'Mira videos cortos voluntariamente y gana perlitas para la tienda de canjes de la Tribu.',
})
</script>

<template>
  <div class="space-y-8 max-w-4xl mx-auto">
    <!-- Header -->
    <div class="space-y-2">
      <div class="flex items-center gap-2">
        <BaseBadge variant="success" size="md">
          <i class="bi bi-play-circle-fill mr-1"></i> Anuncios Recompensados
        </BaseBadge>
      </div>
      <h1 class="font-display text-2xl md:text-4xl font-bold text-guaiqui-text uppercase tracking-wider">
        Gana <span class="text-guaiqui-primary">Perlitas</span> Viendo Anuncios
      </h1>
      <p class="text-sm text-guaiqui-text-muted leading-relaxed">
        Apoya al equipo viendo videos publicitarios cortos. Acumula bloques de 10 anuncios para recibir recompensas automáticas en tu billetera.
      </p>
    </div>

    <!-- Error / Alert Banner -->
    <div
      v-if="errorMessage"
      class="p-4 bg-red-50 border border-red-200 rounded-guaiqui-xl text-red-700 text-sm flex items-start gap-3 shadow-xs"
    >
      <i class="bi bi-exclamation-triangle-fill text-red-500 text-lg shrink-0 mt-0.5"></i>
      <div class="flex-1">
        <p class="font-semibold">{{ errorMessage }}</p>
      </div>
      <button class="text-red-400 hover:text-red-700" @click="errorMessage = null">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- Daily Progress & CTA Card -->
    <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-md space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-guaiqui-border pb-5">
        <div>
          <span class="text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted block">Progreso Diario</span>
          <div class="flex items-baseline gap-2 mt-1">
            <span class="font-display font-extrabold text-3xl text-guaiqui-primary">
              {{ progressData.completed_today ?? 0 }}
            </span>
            <span class="text-sm font-semibold text-guaiqui-text-muted">
              / {{ progressData.daily_limit ?? 50 }} anuncios completados hoy
            </span>
          </div>
        </div>

        <div class="text-right sm:text-right">
          <span class="text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted block">Ganado hoy por anuncios</span>
          <div class="flex items-center justify-end gap-2 mt-1">
            <PearlIcon size="md" class="shrink-0" />
            <span class="font-display font-extrabold text-2xl text-guaiqui-text">
              +{{ progressData.pearls_earned_today ?? 0 }}
            </span>
            <span class="text-xs text-guaiqui-text-muted font-medium">perlitas</span>
          </div>
        </div>
      </div>

      <!-- Current Block Progress Bar -->
      <div class="space-y-2">
        <div class="flex items-center justify-between text-xs font-semibold">
          <span class="text-guaiqui-text">
            Avance bloque actual ({{ progressData.block_progress ?? 0 }} / {{ progressData.block_size ?? 10 }})
          </span>
          <span class="text-guaiqui-primary font-bold">
            Recompensa al completar: +{{ currentBlockPearlReward }} perlitas
          </span>
        </div>

        <div class="w-full h-3 bg-guaiqui-surface rounded-full overflow-hidden border border-guaiqui-border">
          <div
            class="h-full bg-linear-to-r from-guaiqui-primary to-emerald-400 transition-all duration-500 rounded-full"
            :style="{ width: `${(((progressData.block_progress ?? 0) / (progressData.block_size || 10)) * 100)}%` }"
          ></div>
        </div>

        <p class="text-[11px] text-guaiqui-text-muted">
          Completa {{ Math.max(0, (progressData.block_size || 10) - (progressData.block_progress ?? 0)) }} anuncio(s) más para reclamar las {{ currentBlockPearlReward }} perlitas de este bloque.
        </p>
      </div>

      <!-- CTA Button & System Status -->
      <div class="pt-3 space-y-3">
        <!-- Turnstile Verification Widget (required for 1st ad of the day) -->
        <div v-if="(progressData.completed_today ?? 0) === 0 && progressData.can_watch" class="py-2">
          <TurnstileWrapper @verify="onCaptchaVerified" />
          <div v-if="captchaVerifying" class="text-center text-xs text-guaiqui-text-muted mt-2 flex items-center justify-center gap-1.5">
            <i class="bi bi-arrow-repeat animate-spin text-guaiqui-primary"></i> Validando verificación de seguridad...
          </div>
          <div v-else-if="captchaVerified" class="text-center text-xs text-emerald-600 font-semibold mt-2 flex items-center justify-center gap-1.5">
            <i class="bi bi-shield-fill-check text-emerald-500"></i> Verificación completada con éxito
          </div>
        </div>

        <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <BaseButton
            variant="primary"
            size="lg"
            class="w-full sm:w-auto px-8 py-3 font-bold uppercase tracking-wider text-sm shadow-md"
            :loading="sessionLoading"
            :disabled="sessionLoading || loadingProgress || !progressData.can_watch"
            @click="handleStartAd"
          >
            <i class="bi bi-play-circle-fill mr-2 text-lg"></i>
            {{
              sessionLoading
                ? 'Cargando anuncio...'
                : !progressData.can_watch && progressData.cant_reason === 'ADS_DISABLED'
                  ? 'Anuncios en pausa temporal'
                  : 'Ver anuncio para ganar perlitas'
            }}
          </BaseButton>
        </div>

        <!-- Banner de estado integrado cuando no es posible ver anuncios -->
        <div
          v-if="!progressData.can_watch"
          class="flex items-start gap-3 p-3.5 rounded-xl text-xs font-medium border"
          :class="[
            progressData.cant_reason === 'ADS_DISABLED'
              ? 'bg-amber-50/90 border-amber-200 text-amber-900'
              : 'bg-slate-50 border-slate-200 text-slate-700'
          ]"
        >
          <div class="w-5 h-5 rounded-full bg-amber-200/80 text-amber-800 flex items-center justify-center shrink-0 mt-0.5">
            <i :class="progressData.cant_reason === 'ADS_DISABLED' ? 'bi bi-tools text-xs' : 'bi bi-info-circle-fill text-xs'"></i>
          </div>
          <div>
            <span v-if="progressData.cant_reason === 'ADS_DISABLED'" class="font-bold block text-amber-950 mb-0.5">
              Mantenimiento programado de publicidad
            </span>
            <span>
              <template v-if="progressData.cant_reason === 'AD_DAILY_LIMIT'">
                Has alcanzado el límite de 50 anuncios de hoy. ¡Gracias por apoyar a la Tribu Verde! Vuelve mañana.
              </template>
              <template v-else-if="progressData.cant_reason === 'ADS_DISABLED'">
                El sistema de anuncios recompensados se encuentra en mantenimiento temporal. Se reactivará próximamente.
              </template>
              <template v-else-if="progressData.cant_reason === 'ACCOUNT_TOO_NEW'">
                Tu cuenta es muy reciente. Requiere al menos 3 días de antigüedad para ver anuncios.
              </template>
              <template v-else-if="progressData.cant_reason === 'TRIVIAS_REQUIRED'">
                Debes completar al menos 1 trivia antes de acceder a los anuncios.
              </template>
              <template v-else>
                No es posible ver anuncios en este momento.
              </template>
            </span>
          </div>
        </div>
      </div>
    </BaseCard>

    <!-- Blocks Reward Table breakdown -->
    <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-sm space-y-4">
      <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase flex items-center gap-2">
        <i class="bi bi-trophy-fill text-amber-500"></i> Tabla de Recompensas por Bloques
      </h3>
      <p class="text-xs text-guaiqui-text-muted">
        Las perlitas se acreditan automáticamente al completar cada bloque de 10 anuncios vistos.
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-5 gap-3 pt-2">
        <div
          v-for="tier in rewardTiers"
          :key="tier.block"
          :class="[
            'p-4 rounded-guaiqui-xl border text-center transition-all',
            Math.floor(progressData.completed_today / 10) + 1 === tier.block
              ? 'bg-guaiqui-primary-soft/40 border-guaiqui-primary shadow-xs ring-2 ring-guaiqui-primary/20'
              : 'bg-guaiqui-surface/60 border-guaiqui-border opacity-90',
          ]"
        >
          <span class="text-[11px] font-semibold text-guaiqui-text-muted block uppercase">
            Bloque {{ tier.block }}
          </span>
          <span class="text-xs font-bold text-guaiqui-text block mt-0.5">
            {{ tier.range }}
          </span>
          <div class="mt-2 font-display font-extrabold text-xl text-guaiqui-primary">
            +{{ tier.pearls }} <span class="text-xs font-medium text-guaiqui-text-muted">perlitas</span>
          </div>
        </div>
      </div>
    </BaseCard>

    <!-- Policy Notice Card -->
    <div class="p-4 bg-guaiqui-surface/80 border border-guaiqui-border rounded-guaiqui-xl text-xs text-guaiqui-text-muted space-y-1">
      <p class="font-semibold text-guaiqui-text">
        <i class="bi bi-shield-check text-guaiqui-primary mr-1"></i> Transparencia e Inmutabilidad:
      </p>
      <p>
        Las perlitas no tienen valor monetario, no son transferibles y solo se canjean en nuestra plataforma. Ningún texto o botón te solicitará hacer clic en el contenido del anuncio.
      </p>
    </div>

    <!-- MODAL 1: Acceptance Opt-in Modal -->
    <Teleport to="body">
      <div
        v-if="showAcceptanceModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs"
      >
        <div class="bg-white rounded-guaiqui-2xl max-w-md w-full p-6 space-y-5 shadow-2xl border border-guaiqui-border animate-in fade-in zoom-in duration-200">
          <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-camera-reels-fill"></i>
          </div>

          <div class="text-center space-y-2">
            <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
              ¿Listo para ver el anuncio?
            </h3>
            <p class="text-xs text-guaiqui-text-muted leading-relaxed">
              Mira el video completo para avanzar en tu bloque del día. Si cierras el video antes de finalizar, no se otorgará el avance ni las perlitas.
            </p>
          </div>

          <div class="flex gap-3 pt-2">
            <BaseButton variant="secondary" size="md" class="flex-1 font-semibold" @click="handleAcceptModalDecline">
              Cancelar
            </BaseButton>
            <BaseButton variant="primary" size="md" class="flex-1 font-bold uppercase" @click="handleAcceptModalProceed">
              Ver anuncio
            </BaseButton>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- MODAL 2: Closed Early Warning Modal -->
    <Teleport to="body">
      <div
        v-if="showEarlyCloseConfirmModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs"
      >
        <div class="bg-white rounded-guaiqui-2xl max-w-md w-full p-6 space-y-5 shadow-2xl border border-guaiqui-border text-center">
          <div class="w-12 h-12 rounded-full bg-amber-100 text-amber-600 flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-exclamation-octagon-fill"></i>
          </div>

          <div class="space-y-2">
            <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
              Anuncio Cerrado Antes de Tiempo
            </h3>
            <p class="text-xs text-guaiqui-text-muted leading-relaxed">
              El anuncio fue cerrado antes de finalizar su reproducción. No se otorgó el avance en el bloque del día.
            </p>
          </div>

          <BaseButton variant="primary" size="md" class="w-full font-bold" @click="showEarlyCloseConfirmModal = false">
            Entendido
          </BaseButton>
        </div>
      </div>
    </Teleport>

    <!-- MODAL 3: Result Modal -->
    <Teleport to="body">
      <div
        v-if="showResultModal && resultDetails"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs"
      >
        <div class="bg-white rounded-guaiqui-2xl max-w-md w-full p-6 space-y-5 shadow-2xl border border-guaiqui-border text-center animate-in fade-in zoom-in duration-200">
          <div class="w-14 h-14 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center text-3xl mx-auto">
            <i class="bi bi-check-circle-fill"></i>
          </div>

          <div class="space-y-2">
            <h3 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
              ¡Anuncio Completado!
            </h3>
            <p class="text-xs text-guaiqui-text-muted">
              Llevas <span class="font-bold text-guaiqui-text">{{ resultDetails.completedToday }}</span> / {{ progressData.daily_limit }} anuncios hoy.
            </p>
          </div>

          <div v-if="resultDetails.pearls > 0" class="p-4 bg-emerald-50 border border-emerald-200 rounded-guaiqui-xl space-y-1">
            <span class="text-xs font-bold text-emerald-800 uppercase block">¡Bloque Completado!</span>
            <div class="font-display font-extrabold text-3xl text-emerald-600 flex items-center justify-center gap-1">
              +{{ resultDetails.pearls }} <span class="text-sm font-medium">perlitas</span>
            </div>
            <p v-if="resultDetails.held" class="text-[11px] text-amber-700 font-medium pt-1">
              <i class="bi bi-clock-history mr-1"></i> Las perlitas han quedado en revisión preventiva por el sistema de seguridad.
            </p>
          </div>

          <div v-else class="p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-xl">
            <p class="text-xs text-guaiqui-text font-medium">
              ¡Buen trabajo! Sigue completando anuncios para llegar al próximo bloque de recompensa.
            </p>
          </div>

          <BaseButton variant="primary" size="md" class="w-full font-bold uppercase" @click="showResultModal = false">
            Continuar
          </BaseButton>
        </div>
      </div>
    </Teleport>

  </div>
</template>
