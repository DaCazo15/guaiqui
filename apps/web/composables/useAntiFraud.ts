import { ref, onMounted } from 'vue'

export function useAntiFraud() {
  const supabase = useSupabaseClient()
  const deviceId = ref<string>('')

  const getOrCreateDeviceId = (): string => {
    if (typeof window === 'undefined') return ''
    let id = localStorage.getItem('guaiqui_device_id')
    if (!id) {
      id = crypto.randomUUID()
      localStorage.setItem('guaiqui_device_id', id)
    }
    deviceId.value = id
    return id
  }

  const verifyCaptchaToken = async (turnstileToken: string) => {
    const dId = getOrCreateDeviceId()
    const { data, error } = await supabase.functions.invoke('verify-captcha', {
      body: {
        token: turnstileToken,
        device_id: dId
      }
    })

    if (error) {
      throw new Error(error.message || 'Error al verificar el filtro de seguridad')
    }

    if (data?.error) {
      throw new Error(data.error)
    }

    return data
  }

  onMounted(() => {
    getOrCreateDeviceId()
  })

  return {
    deviceId,
    getOrCreateDeviceId,
    verifyCaptchaToken
  }
}
