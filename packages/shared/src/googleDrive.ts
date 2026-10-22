/**
 * Utilidades para parsear y embeber videos de Google Drive en Guaiqueríes Fan Zone
 */

/**
 * Extrae el ID de archivo de Google Drive desde cualquier URL o ID directo.
 * Soporta formatos:
 * - https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/view?usp=sharing
 * - https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs/preview
 * - https://drive.google.com/open?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs
 * - https://drive.google.com/uc?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs
 * - ID directo: 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs
 */
export function extractGoogleDriveFileId(input: string): string | null {
  if (!input) return null
  const trimmed = input.trim()

  // 1. /file/d/{id}/ format
  const fileDMatch = trimmed.match(/\/file\/d\/([a-zA-Z0-9_-]+)/)
  if (fileDMatch && fileDMatch[1]) {
    return fileDMatch[1]
  }

  // 2. ?id={id} format
  const idParamMatch = trimmed.match(/[?&]id=([a-zA-Z0-9_-]+)/)
  if (idParamMatch && idParamMatch[1]) {
    return idParamMatch[1]
  }

  // 3. Direct alphanumeric token check
  if (/^[a-zA-Z0-9_-]{20,}$/.test(trimmed)) {
    return trimmed
  }

  return null
}

/**
 * Genera la URL de previsualización/embebido oficial de Google Drive
 */
export function getGoogleDriveEmbedUrl(input: string): string | null {
  const fileId = extractGoogleDriveFileId(input)
  if (!fileId) return null
  return `https://drive.google.com/file/d/${fileId}/preview`
}
