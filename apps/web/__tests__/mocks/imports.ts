/* eslint-disable @typescript-eslint/no-explicit-any */
import { vi } from 'vitest'

export const useSupabaseClient = () => {
  if (typeof (globalThis as any).useSupabaseClient === 'function') {
    return (globalThis as any).useSupabaseClient()
  }
  return {}
}

export const useSupabaseUser = () => {
  if (typeof (globalThis as any).useSupabaseUser === 'function') {
    return (globalThis as any).useSupabaseUser()
  }
  return { value: null }
}

export const navigateTo = (...args: any[]) => {
  if (typeof (globalThis as any).navigateTo === 'function') {
    return (globalThis as any).navigateTo(...args)
  }
  return vi.fn()
}

export const useRoute = () => {
  if (typeof (globalThis as any).useRoute === 'function') {
    return (globalThis as any).useRoute()
  }
  return { params: {}, query: {} }
}

export const useRouter = () => {
  if (typeof (globalThis as any).useRouter === 'function') {
    return (globalThis as any).useRouter()
  }
  return { push: vi.fn(), replace: vi.fn(), back: vi.fn() }
}
