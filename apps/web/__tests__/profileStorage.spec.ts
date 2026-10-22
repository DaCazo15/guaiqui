import { describe, it, expect, vi } from 'vitest'
import { validateImageFile, uploadAvatarToStorage, uploadCoverToStorage } from '../utils/profileStorage'

describe('profileStorage utils', () => {
  describe('validateImageFile', () => {
    it('lanza error si no es un File válido', () => {
      // @ts-expect-error test null argument
      expect(() => validateImageFile(null)).toThrow('Debes seleccionar un archivo de imagen válido.')
    })

    it('lanza error si el formato no está permitido', () => {
      const badFile = new File(['bad-data'], 'doc.pdf', { type: 'application/pdf' })
      expect(() => validateImageFile(badFile)).toThrow('Formato no permitido. Usa JPG, PNG o WebP.')
    })

    it('lanza error si excede 20 MB', () => {
      const bigFile = new File(['a'], 'giant.jpg', { type: 'image/jpeg' })
      Object.defineProperty(bigFile, 'size', { value: 25 * 1024 * 1024 })
      expect(() => validateImageFile(bigFile)).toThrow('El archivo excede el tamaño máximo permitido de 20 MB.')
    })

    it('pasa la validación para imágenes permitidas de menos de 20 MB', () => {
      const okFile = new File(['image-bytes'], 'foto.webp', { type: 'image/webp' })
      expect(() => validateImageFile(okFile)).not.toThrow()
    })
  })

  describe('uploadAvatarToStorage y uploadCoverToStorage', () => {
    const mockSupabase = {
      storage: {
        from: () => ({
          upload: vi.fn().mockResolvedValue({ error: null }),
          getPublicUrl: () => ({ data: { publicUrl: 'https://example.com/avatar.webp' } }),
          list: vi.fn().mockResolvedValue({ data: [] }),
          remove: vi.fn().mockResolvedValue({ data: [] }),
        }),
      },
    }

    it('sube avatar a storage y devuelve publicUrl', async () => {
      const file = new File(['valid-image-bytes'], 'avatar.jpg', { type: 'image/jpeg' })
      const url = await uploadAvatarToStorage(mockSupabase, 'user-123', file)
      expect(url).toBe('https://example.com/avatar.webp')
    })

    it('sube cover a storage y devuelve publicUrl', async () => {
      const file = new File(['valid-cover-bytes'], 'cover.webp', { type: 'image/webp' })
      const url = await uploadCoverToStorage(mockSupabase, 'user-123', file)
      expect(url).toBe('https://example.com/avatar.webp')
    })
  })
})
