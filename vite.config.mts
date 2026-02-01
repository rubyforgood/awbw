import { defineConfig } from 'vite'
import RailsPlugin from 'vite-plugin-rails'
import tailwindcss from '@tailwindcss/vite'
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    tailwindcss(),
    RailsPlugin(),
    visualizer({
      filename: 'dist/stats.html',
      open: true,        // auto-open in browser after build
      gzipSize: true,
      brotliSize: true,
    }),
  ],
  server: {
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
