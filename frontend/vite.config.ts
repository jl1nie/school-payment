import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  // Tauri 環境変数の処理
  clearScreen: false,
  server: {
    host: '0.0.0.0',  // コンテナ外からアクセス可能に
    port: 5173,
    strictPort: true,
    watch: {
      // Tauri が使用するため
      ignored: ['**/src-tauri/**'],
    },
  },
  // Tauri ビルド時のベースパス
  envPrefix: ['VITE_', 'TAURI_'],
})
