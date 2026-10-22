import { describe, it, expect } from 'vitest'
import { extractGoogleDriveFileId, getGoogleDriveEmbedUrl } from '../googleDrive'

describe('googleDrive helpers', () => {
  it('extracts ID from standard view sharing link', () => {
    const url = 'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/view?usp=sharing'
    expect(extractGoogleDriveFileId(url)).toBe('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs')
    expect(getGoogleDriveEmbedUrl(url)).toBe('https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/preview')
  })

  it('extracts ID from preview link', () => {
    const url = 'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/preview'
    expect(extractGoogleDriveFileId(url)).toBe('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs')
  })

  it('extracts ID from open?id= format', () => {
    const url = 'https://drive.google.com/open?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs'
    expect(extractGoogleDriveFileId(url)).toBe('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs')
  })

  it('accepts raw file ID directly', () => {
    const id = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs'
    expect(extractGoogleDriveFileId(id)).toBe('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs')
    expect(getGoogleDriveEmbedUrl(id)).toBe('https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/preview')
  })

  it('returns null on invalid input or empty string', () => {
    expect(extractGoogleDriveFileId('')).toBeNull()
    expect(extractGoogleDriveFileId('invalid-short')).toBeNull()
    expect(getGoogleDriveEmbedUrl('invalid')).toBeNull()
  })
})
