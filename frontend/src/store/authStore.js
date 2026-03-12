import { create } from 'zustand'
import api from '../api/client'

export const useAuthStore = create((set, get) => ({
  user: null,
  accessToken: null,
  loading: true,

  setAuth: (user, accessToken) => set({ user, accessToken }),

  login: async (email, password) => {
    const { data } = await api.post('/auth/login', { email, password })
    const user = data?.data?.user ?? null
    const accessToken = data?.data?.accessToken ?? null

    if (accessToken) {
      localStorage.setItem('accessToken', accessToken)
    }

    set({
      user,
      accessToken,
      loading: false,
    })

    return data
  },

  logout: async () => {
    await api.post('/auth/logout').catch(() => {})
    localStorage.removeItem('accessToken')
    set({
      user: null,
      accessToken: null,
      loading: false,
    })
  },

  refresh: async () => {
    try {
      const { data } = await api.post('/auth/refresh', {}, { timeout: 10000 })
      const user = data?.data?.user ?? null
      const accessToken = data?.data?.accessToken ?? null

      if (accessToken) {
        localStorage.setItem('accessToken', accessToken)
      } else {
        localStorage.removeItem('accessToken')
      }

      set({
        user,
        accessToken,
        loading: false,
      })

      return accessToken
    } catch (err) {
      localStorage.removeItem('accessToken')
      set({
        user: null,
        accessToken: null,
        loading: false,
      })
      return null
    }
  },

  init: async () => {
    try {
      await get().refresh()
    } finally {
      set({ loading: false })
    }
  },
}))
