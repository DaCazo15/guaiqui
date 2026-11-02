<script setup lang="ts">
import { ref, watch, onMounted, computed } from 'vue'
import { BaseInput, BaseSelect, BaseButton } from '@guaiqui/ui'
import { MUNICIPALITIES, GENDERS, SHIRT_SIZES, REFERRAL_SOURCES, type Profile } from '@guaiqui/shared'

type ProfileRow = Profile

const props = defineProps<{
  profile: ProfileRow | null
  loading?: boolean
  error?: string | null
  success?: string | null
}>()

const emit = defineEmits<{
  (e: 'save', payload: Partial<ProfileRow>): void
}>()

const supabase = useSupabaseClient()

const displayName = ref(props.profile?.display_name || '')
const municipality = ref(props.profile?.municipality || 'Mariño')
const birthDate = ref(props.profile?.birth_date || '')
const gender = ref(props.profile?.gender || '')
const favoritePlayerId = ref(props.profile?.favorite_player_id || '')
const shirtSize = ref(props.profile?.shirt_size || '')
const referralSource = ref(props.profile?.referral_source || '')
const favoriteSport = ref(props.profile?.favorite_sport || '')
const isPrivate = ref(Boolean(props.profile?.is_private))

const playersList = ref<{ value: string; label: string }[]>([])
const localError = ref<string | null>(null)

const isBirthDateSet = computed(() => !!props.profile?.birth_date)

const municipalityOptions = MUNICIPALITIES.map((m) => ({ value: m, label: m }))
const genderOptions = GENDERS.map((g) => ({ value: g, label: g }))
const shirtSizeOptions = SHIRT_SIZES.map((s) => ({ value: s, label: `Talla ${s}` }))
const referralOptions = REFERRAL_SOURCES.map((r) => ({ value: r, label: r }))

watch(
  () => props.profile,
  (newProf) => {
    if (newProf) {
      displayName.value = newProf.display_name || ''
      municipality.value = newProf.municipality || 'Mariño'
      birthDate.value = newProf.birth_date || ''
      gender.value = newProf.gender || ''
      favoritePlayerId.value = newProf.favorite_player_id || ''
      shirtSize.value = newProf.shirt_size || ''
      referralSource.value = newProf.referral_source || ''
      favoriteSport.value = newProf.favorite_sport || ''
      isPrivate.value = Boolean(newProf.is_private)
    }
  },
  { immediate: true }
)

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('players')
      .select('id, name, jersey_number')
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })

    if (data && data.length > 0) {
      playersList.value = data.map((p) => ({
        value: p.id,
        label: `#${p.jersey_number} ${p.name}`,
      }))
    }
  } catch (err) {
    console.warn('Could not load players list:', err)
  }
})

function handleSave() {
  localError.value = null

  if (!displayName.value.trim()) {
    localError.value = 'El nombre para mostrar es requerido.'
    return
  }

  emit('save', {
    display_name: displayName.value.trim(),
    municipality: municipality.value,
    birth_date: isBirthDateSet.value ? undefined : (birthDate.value || null),
    gender: gender.value || null,
    favorite_player_id: favoritePlayerId.value || null,
    shirt_size: shirtSize.value || null,
    referral_source: referralSource.value || null,
    favorite_sport: favoriteSport.value?.trim() || null,
    is_private: isPrivate.value,
  })
}
</script>

<template>
  <form @submit.prevent="handleSave" class="space-y-4">
    <div v-if="success" class="p-3 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-md text-guaiqui-status-success text-sm flex items-center gap-2">
      <i class="bi bi-check-circle-fill shrink-0"></i>
      <span>{{ success }}</span>
    </div>

    <div v-if="localError || error" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ localError || error }}</span>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseInput
        v-model="displayName"
        label="Nombre para mostrar"
        required
      />

      <BaseSelect
        v-model="municipality"
        label="Municipio / Ubicación"
        :options="municipalityOptions"
        required
      />

      <BaseInput
        v-model="birthDate"
        label="Fecha de nacimiento"
        type="date"
        :disabled="isBirthDateSet"
        :hint="isBirthDateSet ? 'Tu fecha de nacimiento no puede ser modificada una vez registrada.' : 'Solo se puede registrar una vez (para regalos de cumpleaños).'"
      />

      <BaseSelect
        v-model="gender"
        label="Género"
        :options="[{ value: '', label: 'Seleccionar...' }, ...genderOptions]"
      />

      <BaseSelect
        v-model="favoritePlayerId"
        label="Jugador favorito"
        :options="[{ value: '', label: 'Seleccionar...' }, ...playersList]"
      />

      <BaseSelect
        v-model="shirtSize"
        label="Talla de camisa"
        :options="[{ value: '', label: 'Seleccionar...' }, ...shirtSizeOptions]"
      />

      <BaseInput
        v-model="favoriteSport"
        label="Deporte favorito"
        placeholder="Ej: Baloncesto, Béisbol, Fútbol"
      />
    </div>

    <BaseSelect
      v-model="referralSource"
      label="¿Cómo te enteraste del equipo?"
      :options="[{ value: '', label: 'Seleccionar...' }, ...referralOptions]"
    />

    <!-- Privacidad de la Cuenta -->
    <div class="p-4 rounded-guaiqui-xl border border-guaiqui-border bg-slate-50/70">
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-full bg-slate-200/80 text-slate-700 flex items-center justify-center text-sm shrink-0">
            <i :class="isPrivate ? 'bi bi-lock-fill text-amber-600' : 'bi bi-globe-americas text-emerald-600'"></i>
          </div>
          <div>
            <label for="account-privacy-toggle" class="text-xs sm:text-sm font-bold text-guaiqui-text cursor-pointer">
              Cuenta Privada
            </label>
            <p class="text-[11px] text-guaiqui-text-muted leading-tight">
              {{ isPrivate ? 'Solo los fanáticos con solicitud aceptada podrán ver tus estadísticas de ranking, canjes y perlitas.' : 'Tu perfil es público por defecto. Cualquier fanático puede ver tus estadísticas y seguirte inmediatamente.' }}
            </p>
          </div>
        </div>
        <button
          id="account-privacy-toggle"
          type="button"
          role="switch"
          :aria-checked="isPrivate"
          @click="isPrivate = !isPrivate"
          class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-hidden"
          :class="isPrivate ? 'bg-amber-600' : 'bg-slate-300'"
        >
          <span
            class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out"
            :class="isPrivate ? 'translate-x-5' : 'translate-x-0'"
          />
        </button>
      </div>
    </div>

    <div class="pt-2">
      <BaseButton type="submit" variant="primary" block :loading="loading">
        <i class="bi bi-save-fill mr-1.5"></i>
        Guardar Cambios
      </BaseButton>
    </div>
  </form>
</template>
