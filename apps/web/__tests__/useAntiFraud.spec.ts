/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'

const mockInvoke = vi.fn()

const mockSupabase = {
  functions: {
    invoke: mockInvoke,
  },
}

;(globalThis as any).useSupabaseClient = () => mockSupabase

import { useAntiFraud } from '../composables/useAntiFraud'

describe('useAntiFraud composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorage.clear()
  })

  it('getOrCreateDeviceId generates and stores a new UUID in localStorage', () => {
    const { getOrCreateDeviceId, deviceId } = useAntiFraud()
    const id = getOrCreateDeviceId()

    expect(id).toBeDefined()
    expect(id.length).toBeGreaterThan(10)
    expect(localStorage.getItem('guaiqui_device_id')).toBe(id)
    expect(deviceId.value).toBe(id)
  })

  it('getOrCreateDeviceId reuses existing UUID from localStorage', () => {
    localStorage.setItem('guaiqui_device_id', 'existing-device-uuid-1234')
    const { getOrCreateDeviceId, deviceId } = useAntiFraud()
    const id = getOrCreateDeviceId()

    expect(id).toBe('existing-device-uuid-1234')
    expect(deviceId.value).toBe('existing-device-uuid-1234')
  })

  it('verifyCaptchaToken calls verify-captcha edge function with token and device_id', async () => {
    localStorage.setItem('guaiqui_device_id', 'test-device-id')
    mockInvoke.mockResolvedValueOnce({
      data: { success: true, verified: true },
      error: null,
    })

    const { verifyCaptchaToken } = useAntiFraud()
    const res = await verifyCaptchaToken('turnstile-token-abc')

    expect(mockInvoke).toHaveBeenCalledWith('verify-captcha', {
      body: {
        token: 'turnstile-token-abc',
        device_id: 'test-device-id',
      },
    })
    expect(res).toEqual({ success: true, verified: true })
  })

  it('verifyCaptchaToken throws error if invocation fails', async () => {
    mockInvoke.mockResolvedValueOnce({
      data: null,
      error: { message: 'Network failed' },
    })

    const { verifyCaptchaToken } = useAntiFraud()
    await expect(verifyCaptchaToken('invalid-token')).rejects.toThrow('Network failed')
  })

  it('verifyCaptchaToken throws error if edge function response contains data.error', async () => {
    mockInvoke.mockResolvedValueOnce({
      data: { error: 'Captcha validation failed' },
      error: null,
    })

    const { verifyCaptchaToken } = useAntiFraud()
    await expect(verifyCaptchaToken('failed-token')).rejects.toThrow('Captcha validation failed')
  })
})
