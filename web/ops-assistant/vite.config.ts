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
      output: {
        // Split React itself into its own chunk so browsers can cache it
        // separately from app/CopilotKit code that changes more often on
        // each deploy. Per-language syntax-highlighter chunks are already
        // split automatically by react-syntax-highlighter's own dynamic
        // imports - this only targets the vendor baseline.
        manualChunks: {
          'vendor-react': ['react', 'react-dom']
        }
      }
    }
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./client', import.meta.url))
    }
  }
})
