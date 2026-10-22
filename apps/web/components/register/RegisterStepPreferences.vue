<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseInput, BaseSelect, BaseButton } from '@guaiqui/ui'
import { GENDERS, SHIRT_SIZES, REFERRAL_SOURCES } from '@guaiqui/shared'

const props = defineProps<{
  loading?: boolean
  error?: string | null
}>()

const emit = defineEmits<{
  (e: 'submit', payload: {
    birthDate?: string
    gender?: string
    favoritePlayerId?: string
    shirtSize?: string
    referralSource?: string
  }): void
  (e: 'skip'): void
  (e: 'back'): void
}>()

const supabase = useSupabaseClient()

const birthDate = ref('')
const gender = ref('')
const favoritePlayerId = ref('')
const shirtSize = ref('')
const referralSource = ref('')

const playersList = ref<{ value: string; label: string }[]>([])

const genderOptions = GENDERS.map((g) => ({ value: g, label: g }))
const shirtSizeOptions = SHIRT_SIZES.map((s) => ({ value: s, label: `Talla ${s}` }))
const referralOptions = REFERRAL_SOURCES.map((r) => ({ value: r, label: r }))

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
    console.warn('Could not load players list for preferences:', err)
  }
})

function handleSubmit() {
  emit('submit', {
    birthDate: birthDate.value || undefined,
    gender: gender.value || undefined,
    favoritePlayerId: favoritePlayerId.value || undefined,
    shirtSize: shirtSize.value || undefined,
    referralSource: referralSource.value || undefined,
  })
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="space-y-4">
    <div v-if="error" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ error }}</span>
    </div>

    <div>
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-guaiqui-text">Preferencias de Fanático</h3>
        <span class="text-xs bg-guaiqui-primary-soft text-guaiqui-primary font-medium px-2 py-0.5 rounded-full border border-guaiqui-primary/20">Opcional</span>
      </div>
      <p class="text-xs text-guaiqui-text-muted mt-1">
        Estos datos nos ayudan a personalizar tu experiencia, ofrecerte trivias personalizadas y asegurar la talla adecuada para tus canjes.
      </p>
    </div>

    <BaseInput
      v-model="birthDate"
      label="Fecha de nacimiento"
      type="date"
      hint="Se utiliza para enviarte un saludo especial del equipo el día de tu cumpleaños."
    />

    <BaseSelect
      v-model="gender"
      label="Género"
      :options="[{ value: '', label: 'Seleccionar...' }, ...genderOptions]"
    />

    <BaseSelect
      v-show="playersList.length > 0"
      v-model="favoritePlayerId"
      label="Jugador favorito"
      :options="[{ value: '', label: 'Seleccionar...' }, ...playersList]"
    />

    <BaseSelect
      v-model="shirtSize"
      label="Talla de camisa favorita"
      :options="[{ value: '', label: 'Seleccionar...' }, ...shirtSizeOptions]"
    />

    <BaseSelect
      v-model="referralSource"
      label="¿Cómo te enteraste de la plataforma?"
      :options="[{ value: '', label: 'Seleccionar...' }, ...referralOptions]"
    />

    <div class="flex gap-3 pt-2">
      <BaseButton type="button" variant="outline" class="w-1/3" @click="emit('back')">
        <i class="bi bi-arrow-left mr-1"></i>
        Volver
      </BaseButton>
      <BaseButton type="button" variant="outline" class="w-1/3" @click="emit('skip')">
        Omitir
      </BaseButton>
      <BaseButton type="submit" variant="primary" class="w-1/3" :loading="loading">
        <i class="bi bi-check-lg mr-1"></i>
        Finalizar
      </BaseButton>
    </div>
  </form>
</template>
