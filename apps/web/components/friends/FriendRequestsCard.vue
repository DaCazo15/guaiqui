<script setup lang="ts">
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useFriendships } from '~/composables/useFriendships'

const {
  incomingRequests,
  outgoingRequests,
  acceptRequest,
  declineRequest,
  removeFriend,
  responding,
} = useFriendships()
</script>

<template>
  <div class="space-y-6">
    <!-- Solicitudes Entrantes -->
    <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
      <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
        <div class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-emerald-100 text-emerald-800 flex items-center justify-center text-base">
            <i class="bi bi-inbox-fill"></i>
          </div>
          <div>
            <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
              Solicitudes Recibidas
            </h2>
            <p class="text-xs text-guaiqui-text-muted">
              Fanáticos que quieren conectar contigo.
            </p>
          </div>
        </div>
        <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
          {{ incomingRequests.length }}
        </span>
      </div>

      <!-- Lista o Vacío -->
      <div v-if="incomingRequests.length > 0" class="divide-y divide-gray-100">
        <div
          v-for="req in incomingRequests"
          :key="req.friendship_id"
          class="py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs"
        >
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-guaiqui-border">
              <img
                v-if="req.avatar_url"
                :src="req.avatar_url"
                :alt="req.display_name"
                class="w-full h-full object-cover"
              />
              <span v-else>{{ req.display_name.charAt(0).toUpperCase() }}</span>
            </div>
            <div>
              <p class="text-sm font-bold text-guaiqui-text">{{ req.display_name }}</p>
              <div class="flex items-center gap-2 text-[11px] text-guaiqui-text-muted">
                <span class="px-2 py-0.5 bg-gray-100 rounded text-gray-700 font-semibold">{{ req.tier_name }}</span>
                <span>Recibida el {{ new Date(req.created_at).toLocaleDateString('es-VE') }}</span>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <BaseButton
              variant="primary"
              size="sm"
              class="px-3"
              :disabled="responding"
              @click="acceptRequest(req.friendship_id)"
            >
              <i class="bi bi-check-lg mr-1"></i>
              Aceptar
            </BaseButton>
            <BaseButton
              variant="outline"
              size="sm"
              class="px-3 text-rose-600 hover:bg-rose-50 border-rose-200"
              :disabled="responding"
              @click="declineRequest(req.friendship_id)"
            >
              <i class="bi bi-x-lg mr-1"></i>
              Rechazar
            </BaseButton>
          </div>
        </div>
      </div>

      <div v-else class="text-center py-6 text-xs text-guaiqui-text-muted">
        No tienes solicitudes entrantes pendientes.
      </div>
    </BaseCard>

    <!-- Solicitudes Enviadas -->
    <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
      <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
        <div class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-gray-100 text-gray-700 flex items-center justify-center text-base">
            <i class="bi bi-send-check"></i>
          </div>
          <div>
            <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
              Solicitudes Enviadas
            </h2>
            <p class="text-xs text-guaiqui-text-muted">
              Esperando confirmación de otros fanáticos.
            </p>
          </div>
        </div>
        <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-gray-100 text-gray-700">
          {{ outgoingRequests.length }}
        </span>
      </div>

      <!-- Lista o Vacío -->
      <div v-if="outgoingRequests.length > 0" class="divide-y divide-gray-100">
        <div
          v-for="req in outgoingRequests"
          :key="req.friendship_id"
          class="py-3 flex items-center justify-between gap-3 text-xs"
        >
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-full bg-gray-200 text-gray-700 flex items-center justify-center font-bold text-xs shrink-0 overflow-hidden">
              <img
                v-if="req.avatar_url"
                :src="req.avatar_url"
                :alt="req.display_name"
                class="w-full h-full object-cover"
              />
              <span v-else>{{ req.display_name.charAt(0).toUpperCase() }}</span>
            </div>
            <div>
              <p class="font-semibold text-guaiqui-text">{{ req.display_name }}</p>
              <p class="text-[10px] text-guaiqui-text-muted">
                Enviada el {{ new Date(req.created_at).toLocaleDateString('es-VE') }}
              </p>
            </div>
          </div>

          <BaseButton
            variant="outline"
            size="sm"
            class="text-xs text-gray-500 hover:text-rose-600 hover:border-rose-300"
            :disabled="responding"
            @click="removeFriend(req.friendship_id)"
          >
            Cancelar
          </BaseButton>
        </div>
      </div>

      <div v-else class="text-center py-6 text-xs text-guaiqui-text-muted">
        No tienes solicitudes enviadas pendientes.
      </div>
    </BaseCard>
  </div>
</template>
