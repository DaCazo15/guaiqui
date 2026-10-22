import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { compressThumbnail, cropAndCompressCover } from '../imageCompression'

describe('compressThumbnail', () => {
  it('lanza error si no se proporciona un File válido', async () => {
    // @ts-expect-error test invalid param
    await expect(compressThumbnail(null)).rejects.toThrow('El argumento debe ser un archivo de tipo File válido.')
  })

  it('devuelve el archivo sin modificar si se ejecuta en un entorno sin window o document', async () => {
    const fakeFile = new File(['dummy content'], 'photo.jpg', { type: 'image/jpeg' })
    const result = await compressThumbnail(fakeFile)
    expect(result).toBe(fakeFile)
  })

  describe('con entorno DOM simulado', () => {
    let originalWindow: any
    let originalDocument: any
    let originalImage: any

    beforeEach(() => {
      originalWindow = (global as any).window
      originalDocument = (global as any).document
      originalImage = (global as any).Image
    })

    afterEach(() => {
      ;(global as any).window = originalWindow
      ;(global as any).document = originalDocument
      ;(global as any).Image = originalImage
      vi.restoreAllMocks()
    })

    it('comprime y formatea en WebP con tamaño < 10 KB', async () => {
      const mockBlob = new Blob(['x'.repeat(3500)], { type: 'image/webp' }) // 3.5 KB

      // Simular document y canvas
      ;(global as any).window = {}
      ;(global as any).document = {
        createElement: (tag: string) => {
          if (tag === 'canvas') {
            return {
              width: 0,
              height: 0,
              getContext: () => ({
                imageSmoothingEnabled: false,
                imageSmoothingQuality: 'low',
                drawImage: vi.fn(),
              }),
              toBlob: (cb: (b: Blob) => void) => {
                cb(mockBlob)
              },
            }
          }
          return {}
        },
      }

      class MockImage {
        width = 3000
        height = 2000
        naturalWidth = 3000
        naturalHeight = 2000
        src = ''
        onload: (() => void) | null = null
        constructor() {
          setTimeout(() => {
            if (this.onload) this.onload()
          }, 5)
        }
      }
      ;(global as any).Image = MockImage
      vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-image-url')
      vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})

      // Simular foto pesada de 15 MB
      const largeFile = new File(['a'.repeat(1024)], 'foto_alta_resolucion.jpg', {
        type: 'image/jpeg',
      })

      const compressed = await compressThumbnail(largeFile, {
        maxDimension: 128,
        targetMaxBytes: 5 * 1024,
      })

      expect(compressed).toBeInstanceOf(File)
      expect(compressed.name).toBe('foto_alta_resolucion_thumb.webp')
      expect(compressed.type).toBe('image/webp')
      expect(compressed.size).toBe(3500) // 3.5 KB
      expect(compressed.size).toBeLessThanOrEqual(10 * 1024)
    })

    it('cropAndCompressCover recorta a 8:3 y comprime a WebP < 10 KB', async () => {
      const mockBlob = new Blob(['x'.repeat(7200)], { type: 'image/webp' }) // 7.2 KB (entre 5 KB y 10 KB)

      ;(global as any).window = {}
      ;(global as any).document = {
        createElement: (tag: string) => {
          if (tag === 'canvas') {
            return {
              width: 0,
              height: 0,
              getContext: () => ({
                imageSmoothingEnabled: false,
                imageSmoothingQuality: 'low',
                drawImage: vi.fn(),
              }),
              toBlob: (cb: (b: Blob) => void) => {
                cb(mockBlob)
              },
            }
          }
          return {}
        },
      }

      class MockVerticalImage {
        width = 1080
        height = 1920 // Foto vertical de teléfono
        naturalWidth = 1080
        naturalHeight = 1920
        src = ''
        onload: (() => void) | null = null
        constructor() {
          setTimeout(() => {
            if (this.onload) this.onload()
          }, 5)
        }
      }
      ;(global as any).Image = MockVerticalImage
      vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-vertical-url')
      vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})

      const verticalFile = new File(['vertical-content'], 'selfie_vertical.jpg', {
        type: 'image/jpeg',
      })

      const coverFile = await cropAndCompressCover(verticalFile, { yPercent: 0.3 })

      expect(coverFile).toBeInstanceOf(File)
      expect(coverFile.name).toBe('selfie_vertical_cover.webp')
      expect(coverFile.type).toBe('image/webp')
      expect(coverFile.size).toBe(7200) // 7.2 KB
      expect(coverFile.size).toBeLessThanOrEqual(10 * 1024)
    })
  })
})
