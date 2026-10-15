// Supabase Edge Function: compress-avatar
// Compresses profile avatar images and converts them to .avif format
// 1. Authenticates the caller via user JWT
// 2. Accepts either multipart/form-data (direct upload) or JSON { filePath } from avatars bucket
// 3. Resizes to max 400x400 (preserving aspect ratio) and encodes to AVIF (quality 75)
// 4. Stores in 'avatars' bucket at `${userId}/${uuid}.avif`
// 5. Cleans up previous avatars to prevent storage bloat
// 6. Updates user's avatar_url in profiles table

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ImageMagick, initializeImageMagick, MagickFormat } from 'npm:@imagemagick/magick-wasm@0.0.30'
import { logger } from '../_shared/logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

let wasmReady: Promise<void> | null = null

function ensureWasm(): Promise<void> {
  if (!wasmReady) {
    wasmReady = (async () => {
      try {
        const wasmUrl = new URL('magick.wasm', import.meta.resolve('npm:@imagemagick/magick-wasm@0.0.30'))
        const bytes = await Deno.readFile(wasmUrl)
        await initializeImageMagick(bytes)
      } catch (_localErr) {
        // Fallback to CDN if bundled filesystem path is not directly accessible
        const res = await fetch('https://cdn.jsdelivr.net/npm/@imagemagick/magick-wasm@0.0.30/dist/magick.wasm')
        if (!res.ok) {
          throw new Error(`Failed to load magick.wasm from CDN: ${res.statusText}`)
        }
        const bytes = new Uint8Array(await res.arrayBuffer())
        await initializeImageMagick(bytes)
      }
    })()
  }
  return wasmReady
}

async function compressToAvif(inputBytes: Uint8Array): Promise<Uint8Array> {
  await ensureWasm()

  return new Promise((resolve, reject) => {
    try {
      ImageMagick.read(inputBytes, (image) => {
        try {
          // Resize to max 400x400 keeping aspect ratio
          const maxDim = 400
          if (image.width > maxDim || image.height > maxDim) {
            if (image.width >= image.height) {
              image.resize(maxDim, 0)
            } else {
              image.resize(0, maxDim)
            }
          }

          image.quality = 75
          image.write(MagickFormat.Avif, (outputBytes: Uint8Array) => {
            resolve(new Uint8Array(outputBytes))
          })
        } catch (innerErr) {
          reject(innerErr)
        }
      })
    } catch (err) {
      reject(err)
    }
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No se proporcionó token de autenticación.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // 1. Authenticate caller
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Sesión no válida o expirada.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const userId = user.id
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // Verify user is not suspended or deleted
    const { data: profile, error: profErr } = await adminClient
      .from('profiles')
      .select('status, avatar_url')
      .eq('id', userId)
      .single()

    if (profErr || !profile || profile.status === 'suspended') {
      return new Response(JSON.stringify({ error: 'Cuenta suspendida o no encontrada.' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let inputBytes: Uint8Array | null = null
    let tempPathToDelete: string | null = null

    const contentType = req.headers.get('content-type') || ''

    if (contentType.includes('multipart/form-data')) {
      const formData = await req.formData()
      const file = formData.get('file') || formData.get('avatar')
      if (!(file instanceof Blob)) {
        return new Response(JSON.stringify({ error: 'No se proporcionó ningún archivo de imagen.' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      if (file.size > 5 * 1024 * 1024) {
        return new Response(JSON.stringify({ error: 'El archivo excede el tamaño máximo permitido de 5 MB.' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const buf = await file.arrayBuffer()
      inputBytes = new Uint8Array(buf)
    } else if (contentType.includes('application/json')) {
      const body = await req.json().catch(() => ({}))
      if (body.filePath) {
        // Enforce user can only process images in their own folder
        if (!body.filePath.startsWith(`${userId}/`)) {
          return new Response(JSON.stringify({ error: 'Ruta no autorizada.' }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }

        const { data: fileData, error: dlErr } = await adminClient.storage
          .from('avatars')
          .download(body.filePath)

        if (dlErr || !fileData) {
          return new Response(JSON.stringify({ error: 'No se pudo descargar la imagen original.' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }

        const buf = await fileData.arrayBuffer()
        inputBytes = new Uint8Array(buf)
        tempPathToDelete = body.filePath
      }
    } else {
      // Direct raw binary stream
      const buf = await req.arrayBuffer()
      if (buf.byteLength > 0) {
        inputBytes = new Uint8Array(buf)
      }
    }

    if (!inputBytes || inputBytes.byteLength === 0) {
      return new Response(JSON.stringify({ error: 'Cuerpo de solicitud vacío o formato no soportado.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Compress and convert to AVIF
    logger.info(`Comprimiendo avatar para usuario ${userId}, tamaño original: ${inputBytes.byteLength} bytes`)
    const avifBytes = await compressToAvif(inputBytes)
    logger.info(`Compresión a AVIF completada, tamaño final: ${avifBytes.byteLength} bytes`)

    // 3. Upload to avatars bucket
    const newFileName = `${crypto.randomUUID()}.avif`
    const newPath = `${userId}/${newFileName}`

    const { error: uploadErr } = await adminClient.storage
      .from('avatars')
      .upload(newPath, avifBytes, {
        contentType: 'image/avif',
        upsert: true,
      })

    if (uploadErr) {
      logger.error('Error al subir avatar AVIF a storage', uploadErr)
      return new Response(JSON.stringify({ error: 'Error al almacenar avatar comprimido.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 4. Get public URL
    const { data: publicUrlData } = adminClient.storage
      .from('avatars')
      .getPublicUrl(newPath)

    const avatarUrl = publicUrlData.publicUrl

    // 5. Update user's avatar_url in profiles
    const { error: updateErr } = await adminClient
      .from('profiles')
      .update({ avatar_url: avatarUrl })
      .eq('id', userId)

    if (updateErr) {
      logger.error('Error al actualizar avatar_url en profiles', updateErr)
    }

    // 6. Clean up old avatar files in storage for this user
    try {
      const { data: existingFiles } = await adminClient.storage
        .from('avatars')
        .list(userId)

      if (existingFiles && existingFiles.length > 0) {
        const toDelete = existingFiles
          .filter((f) => f.name !== newFileName)
          .map((f) => `${userId}/${f.name}`)

        if (toDelete.length > 0) {
          await adminClient.storage.from('avatars').remove(toDelete)
        }
      }

      if (tempPathToDelete && tempPathToDelete !== newPath) {
        await adminClient.storage.from('avatars').remove([tempPathToDelete])
      }
    } catch (cleanupErr) {
      logger.warn('Advertencia en limpieza de avatares anteriores:', cleanupErr)
    }

    return new Response(
      JSON.stringify({
        success: true,
        avatar_url: avatarUrl,
        path: newPath,
        original_size: inputBytes.byteLength,
        compressed_size: avifBytes.byteLength,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err: any) {
    logger.error('Error en compress-avatar edge function', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Error interno al procesar la imagen de avatar.' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
