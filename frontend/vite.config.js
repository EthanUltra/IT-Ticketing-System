import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from 'tailwindcss'
import autoprefixer from 'autoprefixer'
export default defineConfig({
  plugins: [react()],
  css: { postcss: { plugins: [tailwindcss(), autoprefixer()] } },
  server: {
    port: 5173,
    host: true,
    proxy: { '/api': { target: 'http://backend:4000', changeOrigin: true } },
  },
})
