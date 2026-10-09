<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { Html5Qrcode } from 'html5-qrcode'

const emit = defineEmits<{
  (e: 'scan', code: string): void
}>()

const scannerContainerId = 'qr-reader-container'
const isScanning = ref(false)
const errorMessage = ref<string | null>(null)
const cameras = ref<any[]>([])
const selectedCameraId = ref<string>('')
const hasTorch = ref(false)
const isTorchOn = ref(false)

let html5QrCode: Html5Qrcode | null = null
let lastScannedCode = ''
let lastScanTime = 0

const initScanner = async () => {
  try {
    const devices = await Html5Qrcode.getCameras()
    if (devices && devices.length > 0) {
      cameras.value = devices
      // Prefer back camera if available
      const backCam = devices.find(d => d.label.toLowerCase().includes('back') || d.label.toLowerCase().includes('trasera'))
      selectedCameraId.value = backCam ? backCam.id : devices[0].id
      await startScanning()
    } else {
      errorMessage.value = 'No se detectaron cámaras en el dispositivo.'
    }
  } catch (err: any) {
    console.error('Error listing cameras:', err)
    errorMessage.value = 'Permiso de cámara denegado o no disponible.'
  }
}

const startScanning = async () => {
  if (!selectedCameraId.value) return
  if (html5QrCode) {
    await stopScanning()
  }

  html5QrCode = new Html5Qrcode(scannerContainerId)
  isScanning.value = true
  errorMessage.value = null

  try {
    await html5QrCode.start(
      selectedCameraId.value,
      {
        fps: 10,
        qrbox: { width: 250, height: 250 }
      },
      (decodedText) => {
        const now = Date.now()
        // 3-second debounce for identical scans
        if (decodedText === lastScannedCode && now - lastScanTime < 3000) {
          return
        }
        lastScannedCode = decodedText
        lastScanTime = now
        emit('scan', decodedText)
      },
      () => {
        // Ignore frame decode failures
      }
    )

    // Check torch capability
    const capabilities = html5QrCode.getRunningTrackCapabilities() as any
    hasTorch.value = !!capabilities?.torch
  } catch (err: any) {
    console.error('Error starting QR scanner:', err)
    isScanning.value = false
    errorMessage.value = 'No se pudo iniciar el escáner de cámara. Verifica los permisos.'
  }
}

const stopScanning = async () => {
  if (html5QrCode && isScanning.value) {
    try {
      await html5QrCode.stop()
      html5QrCode.clear()
    } catch (err) {
      console.error('Error stopping scanner:', err)
    } finally {
      isScanning.value = false
    }
  }
}

const toggleTorch = async () => {
  if (html5QrCode && hasTorch.value) {
    try {
      isTorchOn.value = !isTorchOn.value
      await html5QrCode.applyVideoConstraints({
        advanced: [{ torch: isTorchOn.value }]
      } as any)
    } catch (err) {
      console.error('Torch toggle failed:', err)
    }
  }
}

onMounted(() => {
  initScanner()
})

onUnmounted(() => {
  stopScanning()
})
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 sm:p-6 shadow-xl space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="font-semibold text-sm text-slate-200 flex items-center gap-2">
        <i class="bi bi-camera text-emerald-400 text-base"></i>
        Escáner de Cámara
      </h2>

      <div class="flex items-center gap-2">
        <button
          v-if="hasTorch"
          @click="toggleTorch"
          :class="[
            'px-2.5 py-1 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors',
            isTorchOn ? 'bg-amber-500 text-slate-950' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
          ]"
        >
          <i :class="['bi', isTorchOn ? 'bi-lightbulb-fill' : 'bi-lightbulb']"></i>
          <span>Flash</span>
        </button>

        <select
          v-if="cameras.length > 1"
          v-model="selectedCameraId"
          @change="startScanning"
          class="px-2.5 py-1 bg-slate-950 border border-slate-800 rounded-lg text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
        >
          <option v-for="cam in cameras" :key="cam.id" :value="cam.id">
            {{ cam.label || 'Cámara ' + cam.id }}
          </option>
        </select>
      </div>
    </div>

    <!-- Scanner container viewport -->
    <div class="relative w-full aspect-square max-w-sm mx-auto bg-slate-950 rounded-2xl overflow-hidden border-2 border-dashed border-emerald-500/30 flex items-center justify-center">
      <div :id="scannerContainerId" class="w-full h-full"></div>

      <div v-if="errorMessage" class="absolute inset-0 bg-slate-950/90 flex flex-col items-center justify-center p-6 text-center">
        <i class="bi bi-camera-video-off text-3xl text-red-400 mb-2"></i>
        <p class="text-xs text-red-300 font-medium mb-3">{{ errorMessage }}</p>
        <button
          @click="startScanning"
          class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold rounded-lg"
        >
          Reintentar Cámara
        </button>
      </div>
    </div>

    <p class="text-center text-[11px] text-slate-500">
      Apunta la cámara al código QR opaco de 12 caracteres presentado por el fanático.
    </p>
  </div>
</template>
