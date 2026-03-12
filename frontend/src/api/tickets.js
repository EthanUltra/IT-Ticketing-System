import api from './client';
export const ticketsApi = {
  list: (params) => api.get('/tickets', { params }),
  get: (id) => api.get('/tickets/' + id),
  create: (data) => api.post('/tickets', data),
  update: (id, data) => api.patch('/tickets/' + id, data),
  delete: (id) => api.delete('/tickets/' + id),
  addComment: (id, data) => api.post('/tickets/' + id + '/comments', data),
  stats: () => api.get('/tickets/stats'),
};
export const usersApi = {
  list: () => api.get('/users'),
  updateRole: (id, role) => api.patch('/users/' + id + '/role', { role }),
  unlock: (id) => api.patch('/users/' + id + '/unlock'),
};