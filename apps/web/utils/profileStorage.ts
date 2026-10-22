/**
 * Guaiqueríes de Margarita — Profile Storage Utilities
 *
 * Encapsula la validación, compresión y almacenamiento en Supabase Storage
 * para avatares y fotos de portada del fanático.
 */

import { compressThumbnail } from '@guaiqui/shared'

const ALLOWED_IMAGE_TYPES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/avif',
  'image/heic',
  'image/heif',
]

const MAX_IMAGE_SIZE = 20 * 1024 * 1024 // 20 MB

/**
 * Valida tipo MIME y peso máximo de entrada antes de procesar cualquier imagen.
 */
export function validateImageFile(file: File): void {
  if (!file || !(file instanceof File)) {
    throw new Error('Debes seleccionar un archivo de imagen válido.')
  }

  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new Error('Formato no permitido. Usa JPG, PNG o WebP.')
  }

  if (file.size > MAX_IMAGE_SIZE) {
    throw new Error('El archivo excede el tamaño máximo permitido de 20 MB.')
  }
}

/**
 * Procesa y sube un avatar a Supabase Storage:
 * 1. Comprime instantáneamente a miniatura WebP ultraligera (2 KB a 5 KB, máx < 10 KB).
 * 2. Sube el archivo a `avatars/{userId}/{uuid}.webp`.
 * 3. Limpia en segundo plano avatares anteriores del usuario.
 */
export async function uploadAvatarToStorage(supabase: any, userId: string, file: File): Promise<string> {
  validateImageFile(file)

  // 1. Compresión en navegador
  const compressedFile = await compressThumbnail(file, {
    maxDimension: 128,
    targetMaxBytes: 5 * 1024,
  })

  // 2. Subida a Supabase Storage
  const fileName = `${crypto.randomUUID()}.webp`
  const path = `${userId}/${fileName}`

  const { error: uploadErr } = await supabase.storage
    .from('avatars')
    .upload(path, compressedFile, {
      contentType: 'image/webp',
      upsert: true,
    })

  if (uploadErr) throw uploadErr

  const { data: publicUrlData } = supabase.storage
    .from('avatars')
    .getPublicUrl(path)

  const avatarUrl = publicUrlData.publicUrl

  // 3. Limpieza en segundo plano de avatares previos (excluyendo portadas que empiezan con 'cover_')
  try {
    const { data: existingFiles } = await supabase.storage.from('avatars').list(userId)
    if (existingFiles && existingFiles.length > 0) {
      const toDelete = existingFiles
        .filter((f: any) => !f.name.startsWith('cover_') && f.name !== fileName)
        .map((f: any) => `${userId}/${f.name}`)
      if (toDelete.length > 0) {
        await supabase.storage.from('avatars').remove(toDelete)
      }
    }
  } catch {
    // Ignorar fallo no crítico en limpieza de archivos antiguos
  }

  return avatarUrl
}

/**
 * Sube una portada de perfil ya recortada (8:3) y comprimida (5 KB a 10 KB) a Supabase Storage:
 * 1. Sube a `avatars/{userId}/cover_{uuid}.webp`.
 * 2. Limpia en segundo plano portadas anteriores del usuario.
 */
export async function uploadCoverToStorage(supabase: any, userId: string, file: File): Promise<string> {
  validateImageFile(file)

  const fileName = `cover_${crypto.randomUUID()}.webp`
  const path = `${userId}/${fileName}`

  const { error: uploadErr } = await supabase.storage
    .from('avatars')
    .upload(path, file, {
      contentType: 'image/webp',
      upsert: true,
    })

  if (uploadErr) throw uploadErr

  const { data: publicUrlData } = supabase.storage
    .from('avatars')
    .getPublicUrl(path)

  const coverUrl = publicUrlData.publicUrl

  // Limpieza en segundo plano de portadas previas
  try {
    const { data: existingFiles } = await supabase.storage.from('avatars').list(userId)
    if (existingFiles && existingFiles.length > 0) {
      const toDelete = existingFiles
        .filter((f: any) => f.name.startsWith('cover_') && f.name !== fileName)
        .map((f: any) => `${userId}/${f.name}`)
      if (toDelete.length > 0) {
        await supabase.storage.from('avatars').remove(toDelete)
      }
    }
  } catch {
    // Ignorar fallo no crítico en limpieza de archivos antiguos
  }

  return coverUrl
}
