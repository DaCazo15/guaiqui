import { defineNuxtPlugin } from '#app'
import { Capacitor } from '@capacitor/core'
import { App as CapApp } from '@capacitor/app'
import { StatusBar, Style } from '@capacitor/status-bar'
import { SplashScreen } from '@capacitor/splash-screen'
import { Browser } from '@capacitor/browser'
import { PushNotifications } from '@capacitor/push-notifications'
import { parseDeepLinkUrl } from '~/utils/deepLinks'
import { useSupabaseClient } from '#imports'

export default defineNuxtPlugin(async (nuxtApp) => {
  if (!process.client) return

  const isNative = Capacitor.isNativePlatform()
  const router = nuxtApp.$router as any
  const supabase = useSupabaseClient()

  // 1. Configuración de StatusBar y SplashScreen en móvil nativo
  if (isNative) {
    try {
      await StatusBar.setStyle({ style: Style.Dark })
      if (Capacitor.getPlatform() === 'android') {
        await StatusBar.setBackgroundColor({ color: '#005A36' })
      }
    } catch (e) {
      console.warn('StatusBar not available:', e)
    }

    try {
      await SplashScreen.hide()
    } catch (e) {
      console.warn('SplashScreen not available:', e)
    }
  }

  // 2. Manejador de Botón Atrás en Android
  if (isNative && Capacitor.getPlatform() === 'android') {
    CapApp.addListener('backButton', ({ canGoBack }) => {
      const currentPath = router.currentRoute.value.path
      const rootPaths = ['/', '/app']

      if (rootPaths.includes(currentPath) || !canGoBack) {
        CapApp.exitApp()
      } else {
        router.back()
      }
    })
  }

  // 3. Manejador de Deep Links (guaiqui:// y Universal Links)
  if (isNative) {
    CapApp.addListener('appUrlOpen', async (event) => {
      const parsed = parseDeepLinkUrl(event.url)

      // Si es un callback de OAuth / Magic Link
      if (parsed.isAuthCallback) {
        try {
          await Browser.close()
        } catch {}

        if (parsed.accessToken && parsed.refreshToken) {
          await supabase.auth.setSession({
            access_token: parsed.accessToken,
            refresh_token: parsed.refreshToken
          })
        } else if (parsed.authCode) {
          await supabase.auth.exchangeCodeForSession(parsed.authCode)
        }

        router.push('/app')
        return
      }

      // Navegación interna a perfiles, equipos o referidos
      if (parsed.path) {
        router.push(parsed.path)
      }
    })
  }

  // 4. Registro de Notificaciones Push (FCM)
  const initPushNotifications = async () => {
    if (!isNative) return

    try {
      let permStatus = await PushNotifications.checkPermissions()
      if (permStatus.receive === 'prompt') {
        permStatus = await PushNotifications.requestPermissions()
      }

      if (permStatus.receive === 'granted') {
        await PushNotifications.register()
      }

      PushNotifications.addListener('registration', async (token) => {
        const platform = Capacitor.getPlatform() as 'android' | 'ios'
        try {
          await (supabase.rpc as any)('register_device_token', {
            p_token: token.value,
            p_platform: platform
          })
        } catch (err) {
          console.warn('Failed to save device token to Supabase:', err)
        }
      })

      PushNotifications.addListener('registrationError', (error) => {
        console.warn('Push registration error:', error)
      })
    } catch (err) {
      console.warn('Push notifications setup skipped:', err)
    }
  }

  // Inicializar push al montar el cliente
  if (isNative) {
    initPushNotifications()
  }

  return {
    provide: {
      capacitor: {
        isNative,
        platform: Capacitor.getPlatform(),
        initPushNotifications
      }
    }
  }
})
