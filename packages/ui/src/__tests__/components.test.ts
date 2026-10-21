import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import BaseButton from '../components/BaseButton.vue'
import BaseInput from '../components/BaseInput.vue'
import BaseCheckbox from '../components/BaseCheckbox.vue'
import BaseModal from '../components/BaseModal.vue'
import BaseTabs from '../components/BaseTabs.vue'
import PearlAmount from '../components/PearlAmount.vue'

describe('@guaiqui/ui components', () => {
  describe('BaseButton', () => {
    it('renders button text correctly', () => {
      const wrapper = mount(BaseButton, {
        slots: { default: 'Canjear Premio' }
      })
      expect(wrapper.text()).toContain('Canjear Premio')
      expect(wrapper.classes()).toContain('bg-guaiqui-primary')
    })

    it('emits click event when clicked', async () => {
      const wrapper = mount(BaseButton)
      await wrapper.trigger('click')
      expect(wrapper.emitted('click')).toBeTruthy()
    })

    it('does not emit click when disabled or loading', async () => {
      const wrapper = mount(BaseButton, {
        props: { disabled: true }
      })
      await wrapper.trigger('click')
      expect(wrapper.emitted('click')).toBeFalsy()
    })
  })

  describe('BaseInput', () => {
    it('renders label and error message', () => {
      const wrapper = mount(BaseInput, {
        props: {
          label: 'Correo Electrónico',
          error: 'Formato de correo inválido',
          modelValue: 'usuario@domain'
        }
      })
      expect(wrapper.text()).toContain('Correo Electrónico')
      expect(wrapper.text()).toContain('Formato de correo inválido')
    })

    it('emits update:modelValue on input change', async () => {
      const wrapper = mount(BaseInput, {
        props: { modelValue: '' }
      })
      const input = wrapper.find('input')
      await input.setValue('fan@guaiqueries.com')
      expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['fan@guaiqueries.com'])
    })
  })

  describe('BaseCheckbox', () => {
    it('toggles value on click', async () => {
      const wrapper = mount(BaseCheckbox, {
        props: { modelValue: false, label: 'Acepto términos y condiciones' }
      })
      await wrapper.find('.cursor-pointer').trigger('click')
      expect(wrapper.emitted('update:modelValue')?.[0]).toEqual([true])
    })
  })

  describe('BaseModal', () => {
    it('renders title when open', () => {
      const wrapper = mount(BaseModal, {
        props: { open: true, title: 'Confirmar Canje' },
        global: {
          stubs: { Teleport: true }
        }
      })
      expect(wrapper.text()).toContain('Confirmar Canje')
    })
  })

  describe('BaseTabs', () => {
    it('switches active tab when clicked', async () => {
      const tabs = [
        { id: 'all', label: 'Todos' },
        { id: 'active', label: 'Activos' }
      ]
      const wrapper = mount(BaseTabs, {
        props: { tabs, modelValue: 'all' }
      })
      const buttons = wrapper.findAll('button')
      await buttons[1].trigger('click')
      expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['active'])
    })
  })

  describe('PearlAmount', () => {
    it('formats perlitas properly with icon', () => {
      const wrapper = mount(PearlAmount, {
        props: { amount: 1500, showLabel: true }
      })
      expect(wrapper.text()).toContain('1.500')
      expect(wrapper.text()).toContain('puntos')
    })
  })
})
