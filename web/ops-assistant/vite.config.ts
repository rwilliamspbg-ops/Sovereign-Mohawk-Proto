import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react()],
  root: './',
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: 'dist/client',
    rollupOptions: {
      input: 'public/index.html'
    }
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./client', import.meta.url))
    }
  }
})
