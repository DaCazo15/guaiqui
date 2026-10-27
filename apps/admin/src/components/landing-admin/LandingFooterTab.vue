<script setup lang="ts">
import FooterSocialLinks from './footer/FooterSocialLinks.vue'
import FooterGeneralSettings from './footer/FooterGeneralSettings.vue'
</script>

<template>
  <div class="space-y-8">
    <!-- Subcomponent: Social Links Management -->
    <FooterSocialLinks />

    <!-- Subcomponent: General Footer Texts & Settings -->
    <FooterGeneralSettings />
  </div>
</template>
