import axios from 'axios'
import { useAuthStore } from '../store/authStore'

const api = axios.create({ baseURL: '/api', withCredentials: true })

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken
  if (token) config.headers.Authorization = 'Bearer ' + token
  return config
})

let isRefreshing = false,
  queue = []

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const original = err.config

    // do not retry the refresh request itself
    if (original?.url?.includes('/auth/refresh')) {
      return Promise.reject(err)
    }

    if (err.response?.status === 401 && !original._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) =>
          queue.push({ resolve, reject })
        ).then((token) => {
          original.headers.Authorization = 'Bearer ' + token
          return api(original)
        })
      }

      original._retry = true
      isRefreshing = true

      try {
        const token = await useAuthStore.getState().refresh()
        if (!token) throw new Error('No token')

        queue.forEach(({ resolve }) => resolve(token))
        queue = []

        original.headers.Authorization = 'Bearer ' + token
        return api(original)
      } catch (refreshErr) {
        queue.forEach(({ reject }) => reject(refreshErr))
        queue = []
        window.location.href = '/login'
        return Promise.reject(refreshErr)
      } finally {
        isRefreshing = false
      }
    }

    return Promise.reject(err)
  }
)

export default api
