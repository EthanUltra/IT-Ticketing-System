import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  withCredentials: true,
})

api.interceptors.request.use((config) => {
  try {
    const token = localStorage.getItem('accessToken')
    if (token) config.headers.Authorization = 'Bearer ' + token
  } catch {}
  return config
})

let isRefreshing = false
let queue = []

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const original = err.config

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
        const res = await api.post('/auth/refresh')
        const token = res.data?.data?.accessToken

        if (!token) throw new Error('No access token returned')

        localStorage.setItem('accessToken', token)
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
