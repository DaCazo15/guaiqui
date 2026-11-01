import { Capacitor } from '@capacitor/core'
import { Preferences } from '@capacitor/preferences'

export interface StorageAdapter {
  getItem(key: string): Promise<string | null>
  setItem(key: string, value: string): Promise<void>
  removeItem(key: string): Promise<void>
}

/**
 * Adaptador de almacenamiento de sesión para Supabase.
 * En plataformas móviles nativas (Android/iOS) utiliza @capacitor/preferences
 * para almacenamiento persistente y seguro que no se borra por cuotas de WebView.
 * En navegador web utiliza localStorage.
 */
export const capacitorStorage: StorageAdapter = {
  async getItem(key: string): Promise<string | null> {
    if (Capacitor.isNativePlatform()) {
      try {
        const { value } = await Preferences.get({ key })
        return value
      } catch (err) {
        console.warn('Error reading from Capacitor Preferences:', err)
        return null
      }
    }

    if (typeof window !== 'undefined' && window.localStorage) {
      return window.localStorage.getItem(key)
    }

    return null
  },

  async setItem(key: string, value: string): Promise<void> {
    if (Capacitor.isNativePlatform()) {
      try {
        await Preferences.set({ key, value })
        return
      } catch (err) {
        console.warn('Error writing to Capacitor Preferences:', err)
      }
    }

    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.setItem(key, value)
    }
  },

  async removeItem(key: string): Promise<void> {
    if (Capacitor.isNativePlatform()) {
      try {
        await Preferences.remove({ key })
        return
      } catch (err) {
        console.warn('Error removing from Capacitor Preferences:', err)
      }
    }

    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.removeItem(key)
    }
  }
}
