import { create } from 'zustand';
import api from '../api/client';
export const useAuthStore = create((set, get) => ({
  user: null, accessToken: null, loading: true,
  setAuth: (user, accessToken) => set({ user, accessToken }),
  logout: async () => { await api.post('/auth/logout').catch(() => {}); set({ user: null, accessToken: null }); },
  refresh: async () => { try { const { data } = await api.post('/auth/refresh'); set({ user: data.data.user, accessToken: data.data.accessToken, loading: false }); return data.data.accessToken; } catch { set({ user: null, accessToken: null, loading: false }); return null; } },
  init: async () => { await get().refresh(); },
}));