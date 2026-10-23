<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { PearlAmount } from '@guaiqui/ui'
import ProfileCoverCropperModal from './ProfileCoverCropperModal.vue'

const props = defineProps<{
  profile: any
  balance: number
  streakDays: number
  uploadingAvatar?: boolean
  uploadingCover?: boolean
}>()

const emit = defineEmits<{
  (e: 'uploadAvatar', file: File): void
  (e: 'uploadCover', file: File): void
  (e: 'updateCover', coverUrl: string): void
}>()

const avatarInputRef = ref<HTMLInputElement | null>(null)
const coverInputRef = ref<HTMLInputElement | null>(null)
const selectedCoverFile = ref<File | null>(null)
const isCropperOpen = ref(false)
const imageLoadFailed = ref(false)
const coverLoadFailed = ref(false)

watch(
  () => props.profile?.cover_url,
  () => {
    coverLoadFailed.value = false
  }
)

// Portada activa guardada en el perfil del usuario (o null si aún no ha subido portada)
const activeCoverUrl = computed(() => {
  return props.profile?.cover_url || null
})

// Fecha de registro formateada
const joinedDate = computed(() => {
  if (!props.profile?.created_at) return '2026'
  const d = new Date(props.profile.created_at)
  return d.toLocaleDateString('es-VE', { month: 'long', year: 'numeric' })
})

// Nivel del fanático
const fanLevel = computed(() => {
  const bal = props.balance
  if (bal >= 7000) return { name: 'Leyenda Guaiquerí', badge: 'bg-amber-500 text-white' }
  if (bal >= 3500) return { name: 'Capitán de Grada', badge: 'bg-emerald-600 text-white' }
  if (bal >= 1500) return { name: 'Guerrero Verde', badge: 'bg-guaiqui-primary text-white' }
  if (bal >= 500) return { name: 'Fanático Insular', badge: 'bg-emerald-700 text-white' }
  return { name: 'Novato de la Tribu', badge: 'bg-slate-700 text-white' }
})

function triggerAvatarInput() {
  avatarInputRef.value?.click()
}

function handleAvatarChange(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (file) {
    emit('uploadAvatar', file)
  }
}

function triggerCoverInput() {
  coverInputRef.value?.click()
}

function handleCoverFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (file) {
    selectedCoverFile.value = file
    isCropperOpen.value = true
  }
  // Reset input para permitir seleccionar el mismo archivo si es necesario
  target.value = ''
}

function handleCropperClose() {
  isCropperOpen.value = false
  selectedCoverFile.value = null
}

function handleCoverCroppedConfirmed(croppedFile: File) {
  isCropperOpen.value = false
  selectedCoverFile.value = null
  emit('uploadCover', croppedFile)
}
</script>

<template>
  <div class="bg-white rounded-guaiqui-2xl border border-guaiqui-border shadow-guaiqui-sm overflow-hidden">
    <!-- 1. FOTO DE PORTADA HORIZONTAL (PROPORCIÓN 8:3) -->
    <div class="relative h-44 sm:h-56 md:h-64 w-full overflow-hidden bg-gradient-to-r from-emerald-950 via-guaiqui-primary-dark to-stone-950">
      <!-- Portada personalizada del usuario -->
      <img
        v-if="!coverLoadFailed && activeCoverUrl"
        :src="activeCoverUrl"
        alt="Foto de Portada Personalizada"
        class="w-full h-full object-cover transition-transform duration-700 hover:scale-102"
        referrerpolicy="no-referrer"
        @error="coverLoadFailed = true"
      />

      <!-- Fondo predeterminado institucional de Guaiqueríes de Margarita si el fan aún no tiene portada -->
      <div
        v-else
        class="w-full h-full flex flex-col items-center justify-center bg-gradient-to-br from-emerald-950 via-guaiqui-primary-dark to-slate-950 relative select-none"
      >
        <div class="w-14 h-14 rounded-full bg-white/10 border border-white/20 flex items-center justify-center text-white/60 text-2xl shadow-inner">
          <i class="bi bi-dribbble"></i>
        </div>
        <span class="text-xs font-bold uppercase tracking-widest text-emerald-300/80 mt-2">
          Guaiqueríes de Margarita
        </span>
        <span class="text-[10px] text-white/50 tracking-wider">
          Personaliza tu perfil con tu foto de portada
        </span>
      </div>

      <!-- Gradiente oscuro inferior para contraste de texto y avatar -->
      <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/25 to-transparent pointer-events-none"></div>

      <!-- Overlay cargando portada -->
      <div v-if="uploadingCover" class="absolute inset-0 bg-black/60 flex items-center justify-center text-white z-20 backdrop-blur-xs">
        <div class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider bg-black/60 px-4 py-2 rounded-full border border-white/20">
          <i class="bi bi-arrow-repeat animate-spin text-emerald-400 text-lg"></i>
          <span>Guardando portada recortada...</span>
        </div>
      </div>

      <!-- Botón Flotante: Subir / Cambiar Portada Personalizada -->
      <div class="absolute bottom-3 right-3 sm:bottom-4 sm:right-4 z-10">
        <button
          type="button"
          @click="triggerCoverInput"
          :disabled="uploadingCover"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-guaiqui-md bg-black/60 hover:bg-black/85 text-white text-xs font-bold uppercase tracking-wider backdrop-blur-md border border-white/20 shadow-md transition-all active:scale-95 disabled:opacity-50"
          :title="activeCoverUrl ? 'Cambiar foto de portada' : 'Subir foto de portada'"
        >
          <i class="bi bi-camera-fill text-sm"></i>
        </button>

        <input
          ref="coverInputRef"
          type="file"
          accept="image/jpeg,image/jpg,image/png,image/webp,image/avif,image/heic,image/heif"
          class="hidden"
          @change="handleCoverFileChange"
        />
      </div>
    </div>

    <!-- 2. AVATAR SUPERPUESTO & DATOS DE IDENTIDAD (ESTILO FACEBOOK) -->
    <div class="px-5 sm:px-8 pb-5 pt-0">
      <div class="flex flex-col sm:flex-row items-center sm:items-end justify-between gap-4 -mt-14 sm:-mt-16 md:-mt-20">
        <!-- Avatar Circular y Nombre -->
        <div class="flex flex-col sm:flex-row items-center sm:items-end gap-4 text-center sm:text-left">
          <!-- Avatar con Anillo Blanco y Disparador de Cámara -->
          <div class="relative group shrink-0">
            <div class="w-28 h-28 sm:w-32 sm:h-32 md:w-36 md:h-36 rounded-full bg-white border-4 border-white shadow-xl overflow-hidden flex items-center justify-center relative ring-2 ring-emerald-500/20">
              <img
                v-if="profile?.avatar_url && !imageLoadFailed"
                :src="profile.avatar_url"
                :alt="profile.display_name || 'Fanático'"
                class="w-full h-full object-cover rounded-full"
                referrerpolicy="no-referrer"
                @error="imageLoadFailed = true"
              />
              <div v-else class="w-full h-full bg-emerald-50 text-guaiqui-primary flex items-center justify-center font-display font-black text-4xl">
                {{ profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
              </div>

              <!-- Overlay cargando avatar -->
              <div v-if="uploadingAvatar" class="absolute inset-0 bg-black/50 flex items-center justify-center text-white">
                <i class="bi bi-arrow-repeat animate-spin text-2xl text-emerald-400"></i>
              </div>
            </div>

            <!-- Botón flotante de cámara para foto de perfil -->
            <button
              type="button"
              @click="triggerAvatarInput"
              :disabled="uploadingAvatar"
              class="absolute bottom-1 right-1 sm:bottom-2 sm:right-2 w-9 h-9 rounded-full bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white flex items-center justify-center shadow-lg border-2 border-white transition-all active:scale-95 disabled:opacity-50"
              title="Cambiar foto de perfil"
            >
              <i class="bi bi-camera-fill text-sm"></i>
            </button>

            <input
              ref="avatarInputRef"
              type="file"
              accept="image/jpeg,image/jpg,image/png,image/webp,image/avif"
              class="hidden"
              @change="handleAvatarChange"
            />
          </div>

          <!-- Nombre y Rango del Fanático -->
          <div class="space-y-1 pb-1">
            <div class="flex items-center justify-center sm:justify-start gap-2">
              <h1 class="font-display font-extrabold text-2xl sm:text-3xl text-guaiqui-text uppercase tracking-wide">
                {{ profile?.display_name || 'Fanático Guaiquerí' }}
              </h1>
              <i class="bi bi-patch-check-fill text-guaiqui-primary text-xl" title="Fanático Verificado"></i>
            </div>

            <div class="flex flex-wrap items-center justify-center sm:justify-start gap-2 text-xs">
              <span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider" :class="fanLevel.badge">
                {{ fanLevel.name }}
              </span>
              <span class="text-guaiqui-text-muted flex items-center gap-1 font-medium">
                <i class="bi bi-geo-alt-fill text-guaiqui-accent"></i>
                {{ profile?.municipality || 'Nueva Esparta' }}
              </span>
              <span class="text-guaiqui-text-subtle text-[11px] hidden md:inline">
                · Miembro desde {{ joinedDate }}
              </span>
            </div>
          </div>
        </div>

        <!-- 3. Píldoras Rápidas de Estadísticas del Fan -->
        <div class="flex items-center gap-3 sm:pb-2">
          <!-- Perlitas -->
          <div class="px-3.5 py-1.5 rounded-guaiqui-lg bg-emerald-50 border border-emerald-200 text-center">
            <div class="flex items-center justify-center gap-1">
              <PearlAmount :amount="balance" size="sm" />
            </div>
            <span class="text-[9px] uppercase tracking-wider text-emerald-800 font-bold block">Saldo</span>
          </div>

          <!-- Racha -->
          <div class="px-3.5 py-1.5 rounded-guaiqui-lg bg-rose-50 border border-rose-200 text-center">
            <div class="flex items-center justify-center gap-1 font-display font-black text-sm text-guaiqui-accent">
              <i class="bi bi-fire text-amber-500"></i>
              <span>{{ streakDays }}</span>
            </div>
            <span class="text-[9px] uppercase tracking-wider text-rose-800 font-bold block">Racha</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Encuadre y Recorte Horizontal -->
    <ProfileCoverCropperModal
      :is-open="isCropperOpen"
      :file="selectedCoverFile"
      @close="handleCropperClose"
      @confirm="handleCoverCroppedConfirmed"
    />
  </div>
</template>
