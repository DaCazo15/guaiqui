<script setup lang="ts">
import { ref } from 'vue'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import { BaseInput, BaseButton, BaseCard } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'

const { trackEvent } = useAnalytics()

const name = ref('')
const email = ref('')
const message = ref('')
const sent = ref(false)

const handleSubmit = () => {
  if (name.value && email.value && message.value) {
    trackEvent('submit_contact_form', { name: name.value })
    sent.value = true
  }
}

useSeoMeta({
  title: 'Contacto & Atención al Fanático — Guaiqueríes de Margarita',
  description: 'Contáctanos para resolver dudas sobre tus canjes o la app oficial de fidelización.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-8">
        <div class="space-y-3 text-center max-w-xl mx-auto">
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Atención Directa
          </span>
          <h1 class="font-display font-extrabold text-4xl sm:text-5xl text-guaiqui-text uppercase">
            Contacto con la Tribu
          </h1>
          <p class="text-sm text-guaiqui-text-muted">
            ¿Tienes alguna consulta sobre tus puntos o un premio canjeado? Escríbenos directamente.
          </p>
        </div>

        <BaseCard padding="lg" class="max-w-2xl mx-auto">
          <div v-if="sent" class="text-center py-8 space-y-4">
            <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary font-bold text-2xl flex items-center justify-center mx-auto">
              <i class="bi bi-check-lg text-3xl"></i>
            </div>
            <h3 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
              ¡Mensaje Enviado!
            </h3>
            <p class="text-sm text-guaiqui-text-muted">
              Hemos recibido tu consulta. Te responderemos a tu correo en menos de 24 horas.
            </p>
          </div>

          <form v-else class="space-y-4" @submit.prevent="handleSubmit">
            <BaseInput
              v-model="name"
              label="Nombre Completo"
              placeholder="Ej. Juan Pérez"
              required
            />
            <BaseInput
              v-model="email"
              label="Correo Electrónico"
              type="email"
              placeholder="fan@ejemplo.com"
              required
            />

            <div class="flex flex-col gap-1.5 w-full">
              <label class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text">
                Mensaje <span class="text-guaiqui-accent">*</span>
              </label>
              <textarea
                v-model="message"
                rows="4"
                required
                placeholder="Escribe tu mensaje aquí..."
                class="w-full px-3.5 py-2.5 text-sm bg-white border border-guaiqui-border rounded-guaiqui-md text-guaiqui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
              />
            </div>

            <BaseButton variant="primary" type="submit" block size="lg">
              Enviar Mensaje
            </BaseButton>
          </form>
        </BaseCard>
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
