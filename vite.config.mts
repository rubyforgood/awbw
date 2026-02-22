import { defineConfig } from 'vite'
import RailsPlugin from 'vite-plugin-rails'
import tailwindcss from '@tailwindcss/vite'
import { visualizer } from 'rollup-plugin-visualizer'

// Default Vite port to PORT + 36 (e.g., Rails on 55480 -> Vite on 55516)
// VITE_RUBY_PORT is set by bin/conductor-server
const basePort = parseInt(process.env.PORT || '3000', 10)
const vitePort = parseInt(process.env.VITE_RUBY_PORT || String(basePort + 36), 10)

export default defineConfig({
  plugins: [
    tailwindcss(),
    RailsPlugin(),
    visualizer({
      filename: 'dist/stats.html',
      open: false,
      gzipSize: true,
      brotliSize: true,
    }),
  ],
  server: {
    port: vitePort,
    strictPort: true,
    allowedHosts: ["localhost", "vite"],
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules/prosemirror")) return "prosemirror";
          if (id.includes("node_modules/@tiptap")) return "tiptap";
          if (id.includes("node_modules/swiper")) return "swiper";
          if (id.includes("node_modules/sortablejs")) return "sortable";
        },
      },
    },
  },
})
